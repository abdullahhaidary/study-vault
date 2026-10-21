import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/interactive_html_repository.dart';
import '../domain/html_bundle.dart';
import '../services/html_page_server.dart';
import '../services/linux_html_window.dart';

/// How a page is shown on this platform.
enum HtmlViewMode { inApp, linuxWindow, browser }

HtmlViewMode htmlViewModeForPlatform() {
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    return HtmlViewMode.inApp;
  }
  if (Platform.isLinux) return HtmlViewMode.linuxWindow;
  return HtmlViewMode.browser;
}

/// Opens one interactive HTML material.
///
/// The page is served from a private `127.0.0.1` address while this screen is
/// open. Closing the screen stops the server and closes the Linux window.
class HtmlStudyScreen extends ConsumerStatefulWidget {
  const HtmlStudyScreen({
    super.key,
    required this.resourceId,
    required this.title,
    required this.filePath,
  });

  final String resourceId;
  final String title;
  final String filePath;

  @override
  ConsumerState<HtmlStudyScreen> createState() => _HtmlStudyScreenState();
}

sealed class _ViewState {
  const _ViewState();
}

class _Loading extends _ViewState {
  const _Loading();
}

class _Failed extends _ViewState {
  const _Failed(this.message);

  final String message;
}

class _InApp extends _ViewState {
  const _InApp(this.controller);

  final WebViewController controller;
}

class _External extends _ViewState {
  const _External({required this.windowOpen, this.notice});

  final bool windowOpen;
  final String? notice;
}

class _HtmlStudyScreenState extends ConsumerState<HtmlStudyScreen> {
  _ViewState _state = const _Loading();
  HtmlPageServer? _server;
  Process? _window;
  final HtmlViewMode _mode = htmlViewModeForPlatform();

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _window?.kill();
    unawaited(_server?.close());
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final db = ref.read(databaseProvider);
      final material = await db.getMaterialById(widget.resourceId);
      if (material == null) {
        throw const InteractiveHtmlException('This page was deleted.');
      }
      final page = await ref
          .read(interactiveHtmlRepositoryProvider)
          .files
          .prepare(
            materialId: material.id,
            filePath: widget.filePath,
            mimeType: material.mimeType,
          );
      final server = await HtmlPageServer.start(
        materialId: material.id,
        page: page,
      );
      if (!mounted) {
        await server.close();
        return;
      }
      _server = server;
      switch (_mode) {
        case HtmlViewMode.inApp:
          _showInApp(server);
        case HtmlViewMode.linuxWindow:
          await _openLinuxWindow();
        case HtmlViewMode.browser:
          await _openInBrowser();
      }
    } on InteractiveHtmlException catch (error) {
      _fail(error.message);
    } on Object catch (error) {
      _fail('Could not open this page: $error');
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => _state = _Failed(message));
  }

  void _showInApp(HtmlPageServer server) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null || !request.isMainFrame) {
              return NavigationDecision.navigate;
            }
            if (server.owns(uri) ||
                const {'about', 'data', 'blob'}.contains(uri.scheme)) {
              return NavigationDecision.navigate;
            }
            unawaited(_launchExternal(uri));
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(server.entryUri);
    setState(() => _state = _InApp(controller));
  }

  Future<void> _openLinuxWindow() async {
    final server = _server;
    if (server == null) return;
    _window?.kill();
    try {
      final process = await LinuxHtmlWindow.open(
        url: server.entryUri,
        title: widget.title,
        allowedPrefix: server.pagePrefix,
      );
      _window = process;
      if (!mounted) {
        process.kill();
        return;
      }
      setState(() => _state = const _External(windowOpen: true));
      unawaited(
        process.exitCode.then((_) {
          if (!mounted || !identical(_window, process)) return;
          _window = null;
          setState(() => _state = const _External(windowOpen: false));
        }),
      );
    } on LinuxHtmlWindowUnavailable catch (error) {
      if (!mounted) return;
      setState(
        () => _state = _External(windowOpen: false, notice: error.message),
      );
    }
  }

  Future<void> _openInBrowser() async {
    final server = _server;
    if (server == null) return;
    final opened = await launchUrl(
      server.entryUri,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    setState(
      () => _state = _External(
        windowOpen: false,
        notice: opened
            ? 'Opened in your browser. Keep this screen open while you use '
                  'the page; closing it stops the page.'
            : 'No browser could open the page.',
      ),
    );
  }

  Future<void> _launchExternal(Uri uri) async {
    if (!const {'http', 'https', 'mailto'}.contains(uri.scheme)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final usesInternet =
        ref.watch(htmlUsesInternetProvider(widget.resourceId)).valueOrNull ??
        false;
    final state = _state;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (usesInternet) const _InternetBadge(),
          if (state is _InApp)
            IconButton(
              tooltip: 'Reload page',
              icon: const Icon(Icons.refresh),
              onPressed: () => state.controller.reload(),
            ),
          if (_server != null && _mode != HtmlViewMode.browser)
            IconButton(
              tooltip: 'Open in browser',
              icon: const Icon(Icons.open_in_browser),
              onPressed: _openInBrowser,
            ),
        ],
      ),
      body: switch (state) {
        _Loading() => const Center(child: CircularProgressIndicator()),
        _Failed(:final message) => _Message(
          icon: Icons.error_outline,
          text: message,
        ),
        _InApp(:final controller) => WebViewWidget(controller: controller),
        _External(:final windowOpen, :final notice) => _ExternalPanel(
          mode: _mode,
          windowOpen: windowOpen,
          notice: notice,
          onOpenWindow: _mode == HtmlViewMode.linuxWindow
              ? _openLinuxWindow
              : null,
          onOpenBrowser: _openInBrowser,
        ),
      },
    );
  }
}

class _InternetBadge extends StatelessWidget {
  const _InternetBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message:
          'This page loads scripts, styles, or images from the internet. '
          'Parts of it may not work offline.',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Chip(
          avatar: const Icon(Icons.public, size: 16),
          label: const Text('Uses internet'),
          visualDensity: VisualDensity.compact,
          labelStyle: theme.textTheme.labelSmall,
        ),
      ),
    );
  }
}

class _ExternalPanel extends StatelessWidget {
  const _ExternalPanel({
    required this.mode,
    required this.windowOpen,
    required this.notice,
    required this.onOpenWindow,
    required this.onOpenBrowser,
  });

  final HtmlViewMode mode;
  final bool windowOpen;
  final String? notice;
  final VoidCallback? onOpenWindow;
  final VoidCallback onOpenBrowser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text =
        notice ??
        (windowOpen
            ? 'The page is open in its own window. Closing this screen closes '
                  'that window.'
            : 'The page window was closed.');
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                windowOpen ? Icons.open_in_new : Icons.web_asset_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  if (onOpenWindow != null)
                    FilledButton.icon(
                      onPressed: onOpenWindow,
                      icon: const Icon(Icons.open_in_new),
                      label: Text(
                        windowOpen ? 'Reopen window' : 'Open page window',
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: onOpenBrowser,
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Open in browser'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: AppSpacing.sm),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
