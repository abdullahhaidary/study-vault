/// Restores Markdown code fences when an importer dropped the backticks
/// and left only a bare language tag (e.g. a line `jsx` above source code).
///
/// Outside models often misread "no markdown fences around the JSON" as
/// "never emit ``` inside content", which breaks Study Vault's code/chart
/// rendering.
abstract final class BareFenceRepair {
  static const languages = {
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
    'json',
    'yaml',
    'yml',
    'xml',
    'html',
    'css',
    'sql',
    'sh',
    'bash',
    'shell',
    'c',
    'cpp',
    'csharp',
    'cs',
    'go',
    'rust',
    'php',
    'ruby',
    'r',
    'react',
    'mermaid',
    'chart',
    'plaintext',
    'vue',
    'svelte',
    'gradle',
    'md',
    'markdown',
    'dockerfile',
    'docker',
    'toml',
    'graphql',
    'diff',
    'scss',
    'less',
    'text',
    'ascii',
    'uml',
    'notation',
    'flow',
    'diagram',
  };

  static final _startsCode = RegExp(
    r'^(?:'
    r'[{}\[\]();]'
    r'|(?:const|let|var|function|import|export|class|interface|type|enum|return|'
    r'if|else|for|while|switch|case|break|continue|try|catch|throw|new|await|async|'
    r'def|public|private|protected|static|void|package|using|from|select|create|'
    r'useState|useEffect|useMemo|useCallback|useRef|useContext)\b'
    r'|</?[A-Za-z]'
    r'|//|/\*|\* '
    r'|#include|#pragma'
    r'|"type"\s*:'
    r')',
  );

  static final _inlineCodey = RegExp(
    r'''=>|::|</?\w|;\s*$|\w\(|=\s*[\[{'"`]|console\.|document\.|React\.|JSON\.|"type"\s*:''',
  );

  static final _boxDrawing = RegExp(r'[┌┐└┘├┤┬┴┼─│▼▲►◄╔╗╚╝║═]');

  static final _sentenceProseStart = RegExp(
    r'^(Why|Because|Here|This|That|These|Those|It|If|When|Then|So|But|And|Note|'
    r'Remember|Important|Both|Modern|Traditional|Expecting|Never|Always|After|'
    r'Before|With|Without|In practice|Symbol)\b',
    caseSensitive: false,
  );

  /// Returns [source] with bare language tags wrapped as fenced blocks.
  static String repair(String source) {
    final lines = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final out = <String>[];
    var i = 0;
    var inFence = false;
    while (i < lines.length) {
      final line = lines[i];
      if (line.trimLeft().startsWith('```')) {
        inFence = !inFence;
        out.add(line);
        i++;
        continue;
      }

      if (!inFence && _isLangLine(line)) {
        var j = i + 1;
        while (j < lines.length && lines[j].trim().isEmpty) {
          j++;
        }
        if (j < lines.length && _isCodeLine(lines[j], afterBlank: false)) {
          final lang = line.trim().toLowerCase();
          i++;
          final body = <String>[];
          while (i < lines.length) {
            final cur = lines[i];
            if (cur.trimLeft().startsWith('```') ||
                _isLangLine(cur) ||
                _isHeading(cur)) {
              break;
            }
            if (cur.trim().isEmpty) {
              var k = i + 1;
              while (k < lines.length && lines[k].trim().isEmpty) {
                k++;
              }
              if (k >= lines.length) break;
              final nxt = lines[k];
              if (_isLangLine(nxt) ||
                  _isHeading(nxt) ||
                  _isSentenceProse(nxt) ||
                  !_isCodeLine(nxt, afterBlank: true)) {
                break;
              }
              body.add(cur);
              i++;
              continue;
            }
            if (_isSentenceProse(cur) || !_isCodeLine(cur, afterBlank: false)) {
              break;
            }
            body.add(cur);
            i++;
          }
          while (body.isNotEmpty && body.last.trim().isEmpty) {
            body.removeLast();
          }
          if (body.isNotEmpty) {
            out.add('```$lang');
            out.addAll(body);
            out.add('```');
          } else {
            out.add(lang);
          }
          continue;
        }
      }

      out.add(line);
      i++;
    }
    return out.join('\n');
  }

  static bool _isLangLine(String line) {
    final s = line.trim();
    return s.isNotEmpty && !s.contains(' ') && languages.contains(s.toLowerCase());
  }

  static bool _isHeading(String line) =>
      RegExp(r'^#{1,6}\s+\S').hasMatch(line.trim());

  static bool _isSentenceProse(String line) {
    final s = line.trim();
    if (s.isEmpty) return false;
    if (_isHeading(s) || _isLangLine(s)) return true;
    if (RegExp(r'^[A-Z][A-Za-z0-9 /-]{0,30}:\s*$').hasMatch(s)) return true;
    if (s.startsWith('>')) return true;
    if (RegExp(r'^[-*+]\s+\S').hasMatch(s) && !_inlineCodey.hasMatch(s)) {
      return true;
    }
    if (RegExp(r'^\d+\.\s+\S').hasMatch(s) && !_startsCode.hasMatch(s)) {
      return true;
    }
    if (s.contains(' ') &&
        RegExp(r'[.!?]\"?$').hasMatch(s) &&
        !_startsCode.hasMatch(s)) {
      final words = s.split(RegExp(r'\s+'));
      if (words.length >= 4) return true;
      if (words.length >= 2 && !_inlineCodey.hasMatch(s)) return true;
    }
    if (_sentenceProseStart.hasMatch(s) && !_startsCode.hasMatch(s)) {
      return true;
    }
    return false;
  }

  static bool _isCodeLine(String line, {required bool afterBlank}) {
    final raw = line;
    final s = line.trim();
    if (s.isEmpty) return false;
    if (_isLangLine(s) || _isHeading(s) || s.startsWith('```')) return false;
    // Box-drawing diagrams are repaired separately; never pull them into code.
    if (_boxDrawing.hasMatch(s)) return false;
    if (_isSentenceProse(raw)) return false;
    if (raw.startsWith('    ') || raw.startsWith('\t')) return true;
    if (_startsCode.hasMatch(s)) return true;
    if (afterBlank) {
      return s == '{' ||
          s == '}' ||
          s == ';' ||
          s.startsWith('}') ||
          s.startsWith(')');
    }
    if (_inlineCodey.hasMatch(s)) return true;
    if (s.startsWith('}') ||
        s.startsWith(')') ||
        s.startsWith(']') ||
        s.startsWith(',')) {
      return true;
    }
    if (s.endsWith('{') ||
        s.endsWith(',') ||
        s.endsWith('(') ||
        s.endsWith(';')) {
      return true;
    }
    return RegExp(r'^[A-Za-z_$][\w$]*$').hasMatch(s);
  }
}
