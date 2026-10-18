/// Cleans fenced code that outside models often break: corrupt fence markers,
/// a lone `` `lang `` line instead of a real fence, and doublespaced bodies.
abstract final class CodeFenceCleanup {
  static const codeLanguages = {
    'jsx',
    'tsx',
    'js',
    'javascript',
    'ts',
    'typescript',
    'dart',
    'java',
    'kotlin',
    'swift',
    'python',
    'py',
    'csharp',
    'cs',
    'c',
    'cpp',
    'go',
    'rust',
    'php',
    'ruby',
    'sql',
    'html',
    'css',
    'json',
    'sh',
    'bash',
    'shell',
    'chart',
  };

  static final _fenceLine = RegExp(r'^([ \t]*)```([^\n]*)$');
  static final _tickLang = RegExp(r'^`([A-Za-z][\w+-]*)\s*$');
  static final _cleanLang = RegExp(r'^[A-Za-z0-9+-]*$');

  /// Normalize fence markers and turn `` `lang `` into a bare language line.
  static String preprocess(String source) {
    return _normalizeFenceMarkers(_stripTickLanguageTags(source));
  }

  /// Densify doublespaced code fence bodies (run after fences are restored).
  static String densify(String source) => _densifyCodeFences(source);

  static String _stripTickLanguageTags(String source) {
    final lines =
        source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final out = <String>[];
    var inFence = false;
    for (final line in lines) {
      if (line.trimLeft().startsWith('```')) {
        inFence = !inFence;
        out.add(line);
        continue;
      }
      if (!inFence) {
        final match = _tickLang.firstMatch(line.trim());
        if (match != null &&
            codeLanguages.contains(match.group(1)!.toLowerCase())) {
          out.add(match.group(1)!.toLowerCase());
          continue;
        }
      }
      out.add(line);
    }
    return out.join('\n');
  }

  static String _normalizeFenceMarkers(String source) {
    final lines =
        source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final out = <String>[];
    for (final line in lines) {
      final match = _fenceLine.firstMatch(line);
      if (match == null) {
        out.add(line);
        continue;
      }
      final indent = match.group(1)!;
      final lang = match.group(2)!.trim();
      if (lang.isEmpty) {
        out.add('$indent```');
        continue;
      }
      final token = RegExp(r'^([A-Za-z0-9+-]+)').firstMatch(lang);
      if (token != null && _cleanLang.hasMatch(token.group(1)!)) {
        out.add('$indent```${token.group(1)!.toLowerCase()}');
      } else {
        out.add('$indent```');
      }
    }
    return out.join('\n');
  }

  static String _densifyCodeFences(String source) {
    final lines =
        source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final out = <String>[];
    var i = 0;
    while (i < lines.length) {
      final open = _fenceLine.firstMatch(lines[i]);
      if (open == null) {
        out.add(lines[i]);
        i++;
        continue;
      }
      final lang = () {
        final raw = open.group(2)!.trim();
        final token = RegExp(r'^([A-Za-z0-9+-]+)').firstMatch(raw);
        return (token?.group(1) ?? '').toLowerCase();
      }();
      out.add(lines[i]);
      i++;
      final body = <String>[];
      while (i < lines.length && _fenceLine.firstMatch(lines[i]) == null) {
        body.add(lines[i]);
        i++;
      }
      final densified = List<String>.from(
        _shouldDensify(lang, body) ? _densifyBody(body) : body,
      );
      while (densified.isNotEmpty && densified.first.trim().isEmpty) {
        densified.removeAt(0);
      }
      while (densified.isNotEmpty && densified.last.trim().isEmpty) {
        densified.removeLast();
      }
      out.addAll(densified);
      if (i < lines.length) {
        out.add(lines[i]);
        i++;
      }
    }
    return out.join('\n');
  }

  static bool _shouldDensify(String lang, List<String> body) {
    if (!codeLanguages.contains(lang)) return false;
    if (body.length < 6) return false;
    final blank = body.where((l) => l.trim().isEmpty).length;
    final nonempty = body.length - blank;
    // Models often insert a blank line between every statement. Catch that
    // even when the fence does not end with a trailing blank line.
    return nonempty >= 4 && blank >= 3 && blank * 2 >= nonempty;
  }

  static List<String> _densifyBody(List<String> body) {
    return [for (final line in body) if (line.trim().isNotEmpty) line];
  }
}
