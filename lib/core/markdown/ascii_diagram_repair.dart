/// Wraps unfenced box-drawing / tree ASCII in `plaintext` fences so Markdown
/// does not treat indented lines as a partial code block (which collapses the
/// rest of the diagram into a single prose line).
abstract final class AsciiDiagramRepair {
  static final _box = RegExp(r'[┌┐└┘├┤┬┴┼─│▼▲►◄╔╗╚╝║═]');
  static final _connector = RegExp(r'^\s*[│├┤┬┴┼▼▲►◄|+/\\-]+\s*$');

  /// Returns [source] with fragile ASCII diagrams fenced as `plaintext`.
  static String repair(String source) {
    final lines =
        source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
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

      if (!inFence &&
          (_box.hasMatch(line) ||
              (_looksDiagramLine(line) &&
                  i + 1 < lines.length &&
                  _box.hasMatch(lines[i + 1])))) {
        final block = <String>[line];
        var j = i + 1;
        while (j < lines.length) {
          final nxt = lines[j];
          if (nxt.trimLeft().startsWith('```') ||
              RegExp(r'^#{1,6}\s+\S').hasMatch(nxt.trim())) {
            break;
          }
          if (nxt.trim().isEmpty) {
            var k = j + 1;
            while (k < lines.length && lines[k].trim().isEmpty) {
              k++;
            }
            if (k < lines.length && _looksDiagramLine(lines[k])) {
              block.add(nxt);
              j++;
              continue;
            }
            break;
          }
          if (_looksDiagramLine(nxt)) {
            block.add(nxt);
            j++;
            continue;
          }
          break;
        }
        final nonEmpty = block.where((b) => b.trim().isNotEmpty).length;
        if (block.any(_box.hasMatch) && nonEmpty >= 3) {
          while (block.isNotEmpty && block.last.trim().isEmpty) {
            block.removeLast();
          }
          out.add('```plaintext');
          out.addAll(block);
          out.add('```');
          i = j;
          continue;
        }
      }

      out.add(line);
      i++;
    }
    return out.join('\n');
  }

  static bool _looksDiagramLine(String line) {
    final s = line.replaceAll(RegExp(r'[ \t]+$'), '');
    if (s.trim().isEmpty) return false;
    if (_box.hasMatch(s)) return true;
    if (_connector.hasMatch(s)) return true;
    final stripped = s.trim();
    if (stripped.startsWith('#') || stripped.startsWith('>')) return false;
    if (stripped.length > 80) return false;
    const markers = [
      'props',
      'callback',
      'owns state',
      're-renders',
      'Parent',
      'Child',
    ];
    if (!markers.any(stripped.contains)) return false;
    return s.startsWith(' ') ||
        s.startsWith('\t') ||
        stripped.startsWith('Parent') ||
        stripped.startsWith('Child');
  }
}
