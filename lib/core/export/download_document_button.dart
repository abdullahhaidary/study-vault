import 'package:flutter/material.dart';

import '../widgets/transient_snack_bar.dart';
import 'document_download.dart';

export 'document_download.dart';

/// Saves [request] and tells the user where it went.
///
/// A null request means there is no document yet.
Future<void> runDocumentDownload(
  BuildContext context,
  DocumentDownloadRequest? request, {
  DocumentDownload download = const DocumentDownload(),
}) async {
  if (request == null) {
    _show(context, 'Nothing to download.');
    return;
  }
  try {
    final result = await download.save(request);
    if (!context.mounted) return;
    switch (result) {
      case DocumentDownloadCancelled():
        return;
      case DocumentDownloadSaved(:final path):
        _show(context, 'Saved to $path');
      case DocumentDownloadShared(:final fileName):
        _show(context, 'Saved $fileName');
    }
  } on DocumentDownloadException catch (error) {
    if (!context.mounted) return;
    _show(context, error.message);
  } catch (error) {
    if (!context.mounted) return;
    _show(context, 'Could not download: $error');
  }
}

void _show(BuildContext context, String message) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(TransientSnackBar(content: Text(message)));
}

/// App-bar action that saves the document returned by [request].
class DownloadDocumentButton extends StatefulWidget {
  const DownloadDocumentButton({
    super.key,
    required this.request,
    this.tooltip = 'Download',
    this.download = const DocumentDownload(),
  });

  final Future<DocumentDownloadRequest?> Function() request;
  final String tooltip;
  final DocumentDownload download;

  @override
  State<DownloadDocumentButton> createState() => _DownloadDocumentButtonState();
}

class _DownloadDocumentButtonState extends State<DownloadDocumentButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      final request = await widget.request();
      if (!mounted) return;
      await runDocumentDownload(context, request, download: widget.download);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: _busy ? null : _run,
      icon: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_outlined),
    );
  }
}
