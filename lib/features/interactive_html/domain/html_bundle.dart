import 'package:path/path.dart' as p;

/// Largest interactive page or bundle accepted. Matches the sync file limit.
const kMaxInteractiveHtmlBytes = 256 * 1024 * 1024;

/// Largest unpacked size of one bundle, to stop zip bombs.
const kMaxUnpackedHtmlBundleBytes = 512 * 1024 * 1024;

/// Most entries one bundle may contain.
const kMaxHtmlBundleEntries = 5000;

/// Thrown when a page or bundle cannot be imported or opened.
class InteractiveHtmlException implements Exception {
  const InteractiveHtmlException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Rules for the files inside an HTML bundle.
abstract final class HtmlBundleLayout {
  /// Returns a safe relative POSIX path for an archive entry, or null when the
  /// entry is a directory, metadata, or would escape the bundle folder.
  static String? safeEntryPath(String rawName) {
    final name = rawName.replaceAll('\\', '/');
    if (name.isEmpty || name.endsWith('/')) return null;
    if (name.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(name)) {
      return null;
    }
    final segments = name.split('/');
    if (segments.any((s) => s == '..')) return null;
    final cleaned = [
      for (final segment in segments)
        if (segment.isNotEmpty && segment != '.') segment,
    ];
    if (cleaned.isEmpty) return null;
    if (cleaned.first == '__MACOSX' || cleaned.last == '.DS_Store') {
      return null;
    }
    return cleaned.join('/');
  }

  /// Picks the page that opens first.
  ///
  /// Order: `index.html` at the root, then `index.html` inside a single
  /// top-level folder, then the only `.html` file in the bundle.
  static String entryPage(Iterable<String> safePaths) {
    final paths = safePaths.toList();
    final html = [
      for (final path in paths)
        if (_isHtml(path)) path,
    ];
    if (html.isEmpty) {
      throw const InteractiveHtmlException(
        'The zip has no .html page. Add an index.html file.',
      );
    }
    for (final path in html) {
      if (path.toLowerCase() == 'index.html' ||
          path.toLowerCase() == 'index.htm') {
        return path;
      }
    }
    final roots = {for (final path in paths) path.split('/').first};
    if (roots.length == 1) {
      final root = roots.single;
      for (final path in html) {
        final lower = path.toLowerCase();
        if (lower == '${root.toLowerCase()}/index.html' ||
            lower == '${root.toLowerCase()}/index.htm') {
          return path;
        }
      }
    }
    if (html.length == 1) return html.single;
    throw const InteractiveHtmlException(
      'The zip has several .html pages and no index.html. '
      'Name the start page index.html.',
    );
  }

  static bool _isHtml(String path) {
    final ext = p.posix.extension(path).toLowerCase();
    return ext == '.html' || ext == '.htm';
  }

  /// Text files worth scanning for internet references.
  static bool isScannableText(String path) {
    final ext = p.posix.extension(path).toLowerCase();
    return const {
      '.html',
      '.htm',
      '.js',
      '.mjs',
      '.css',
      '.json',
      '.svg',
    }.contains(ext);
  }
}

/// Finds references that make a page need the internet.
abstract final class HtmlInternetScan {
  static final _remote = RegExp(
    r'''(?:\b(?:src|href|action|poster|data)\s*=\s*["']?\s*|url\(\s*["']?|@import\s+["']|\bimport\s*(?:[\w*{}\s,]+from\s*)?["']|\bimport\(\s*["']|\bfetch\(\s*["']|\bXMLHttpRequest\b[^;]*["']|\bnew\s+WebSocket\(\s*["']|\bEventSource\(\s*["'])(?:https?:|wss?:)?//''',
    caseSensitive: false,
  );

  static final _anchorTag = RegExp(r'<a\b[^>]*>', caseSensitive: false);

  /// True when [text] loads a script, style, image, font, module, or request
  /// from another host. Ordinary `<a href>` links do not count: the page
  /// works offline and only that link needs the internet.
  static bool usesInternet(String text) =>
      _remote.hasMatch(text.replaceAll(_anchorTag, ''));
}

/// Content types for files served from a page folder.
String htmlAssetContentType(String path) {
  final ext = p.extension(path).toLowerCase();
  return switch (ext) {
    '.html' || '.htm' => 'text/html; charset=utf-8',
    '.js' || '.mjs' => 'text/javascript; charset=utf-8',
    '.css' => 'text/css; charset=utf-8',
    '.json' || '.map' => 'application/json; charset=utf-8',
    '.svg' => 'image/svg+xml',
    '.png' => 'image/png',
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.gif' => 'image/gif',
    '.webp' => 'image/webp',
    '.avif' => 'image/avif',
    '.ico' => 'image/x-icon',
    '.bmp' => 'image/bmp',
    '.woff' => 'font/woff',
    '.woff2' => 'font/woff2',
    '.ttf' => 'font/ttf',
    '.otf' => 'font/otf',
    '.mp3' => 'audio/mpeg',
    '.wav' => 'audio/wav',
    '.ogg' => 'audio/ogg',
    '.mp4' => 'video/mp4',
    '.webm' => 'video/webm',
    '.wasm' => 'application/wasm',
    '.txt' || '.md' || '.csv' => 'text/plain; charset=utf-8',
    '.xml' => 'application/xml',
    '.pdf' => 'application/pdf',
    _ => 'application/octet-stream',
  };
}
