import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Thrown when the Linux page window cannot start on this computer.
class LinuxHtmlWindowUnavailable implements Exception {
  const LinuxHtmlWindowUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Opens an interactive page in its own Linux window.
///
/// Flutter web views do not run inside a Linux app window, so this starts a
/// small GTK program that uses the system WebKit engine (`python3-gi` and
/// `gir1.2-webkit2-4.1`). Page storage lives in a device-local folder that is
/// never synced or backed up.
abstract final class LinuxHtmlWindow {
  /// Exit code the viewer uses when Python's WebKit bindings are missing.
  static const missingWebKitExitCode = 3;

  static Future<Process> open({
    required Uri url,
    required String title,
    required String allowedPrefix,
  }) async {
    final support = await getApplicationSupportDirectory();
    final dataDir = Directory(p.join(support.path, 'study_vault_html_webdata'));
    await dataDir.create(recursive: true);
    final script = File(p.join(support.path, 'study_vault_html_viewer.py'));
    if (!await script.exists() || await script.readAsString() != viewerScript) {
      await script.writeAsString(viewerScript, flush: true);
    }

    final Process process;
    try {
      process = await Process.start('python3', [
        script.path,
        url.toString(),
        title,
        allowedPrefix,
        dataDir.path,
      ]);
    } on ProcessException {
      throw const LinuxHtmlWindowUnavailable(
        'python3 is not installed, so the page window cannot open.',
      );
    }
    final stderr = StringBuffer();
    process.stderr
        .transform(utf8.decoder)
        .listen(stderr.write, onError: (_) {});
    process.stdout.drain<void>().ignore();

    final early = await process.exitCode
        .then<int?>((code) => code)
        .timeout(const Duration(milliseconds: 1500), onTimeout: () => null);
    if (early == null) return process;
    if (early == missingWebKitExitCode) {
      throw const LinuxHtmlWindowUnavailable(
        'The page window needs WebKit for Python. Install it with '
        '"sudo apt install python3-gi gir1.2-webkit2-4.1", or open the page '
        'in your browser.',
      );
    }
    final detail = stderr.toString().trim();
    throw LinuxHtmlWindowUnavailable(
      detail.isEmpty
          ? 'The page window closed immediately (code $early).'
          : 'The page window could not start: '
                '${detail.length > 300 ? detail.substring(detail.length - 300) : detail}',
    );
  }

  /// GTK + WebKit viewer. Links the user clicks that leave the page open in
  /// the default browser. Iframes and scripts may still load web content.
  static const viewerScript = r'''
import sys

try:
    import gi
    gi.require_version("Gtk", "3.0")
    gi.require_version("WebKit2", "4.1")
    from gi.repository import Gio, GLib, Gtk, WebKit2
except (ImportError, ValueError):
    sys.exit(3)


def main():
    url, title, allowed, data_dir = sys.argv[1:5]
    manager = WebKit2.WebsiteDataManager(
        base_data_directory=data_dir,
        base_cache_directory=data_dir + "/cache",
    )
    context = WebKit2.WebContext.new_with_website_data_manager(manager)
    view = WebKit2.WebView.new_with_context(context)

    settings = view.get_settings()
    settings.set_enable_javascript(True)
    settings.set_javascript_can_open_windows_automatically(False)
    settings.set_allow_file_access_from_file_urls(False)
    settings.set_allow_universal_access_from_file_urls(False)
    settings.set_enable_developer_extras(True)
    settings.set_enable_write_console_messages_to_stdout(False)
    settings.set_media_playback_requires_user_gesture(False)

    def external(uri):
        try:
            Gio.AppInfo.launch_default_for_uri(uri, None)
        except GLib.Error:
            pass

    def inside(uri):
        return uri.startswith(allowed) or uri.startswith(("about:", "data:", "blob:"))

    def decide(_view, decision, kind):
        if kind == WebKit2.PolicyDecisionType.NEW_WINDOW_ACTION:
            uri = decision.get_navigation_action().get_request().get_uri()
            if inside(uri):
                view.load_uri(uri)
            else:
                external(uri)
            decision.ignore()
            return True
        if kind == WebKit2.PolicyDecisionType.NAVIGATION_ACTION:
            action = decision.get_navigation_action()
            uri = action.get_request().get_uri()
            clicked = action.get_navigation_type() == WebKit2.NavigationType.LINK_CLICKED
            if clicked and not inside(uri):
                external(uri)
                decision.ignore()
                return True
        return False

    view.connect("decide-policy", decide)

    window = Gtk.Window(title=title)
    window.set_default_size(1200, 860)
    window.connect("destroy", Gtk.main_quit)
    window.add(view)
    window.show_all()
    view.load_uri(url)
    Gtk.main()


main()
''';
}
