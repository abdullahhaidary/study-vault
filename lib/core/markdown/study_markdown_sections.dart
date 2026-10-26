/// Breaks a long study document into pieces the reader can lay out one at a time.
///
/// A heading outside a code fence starts a piece. A piece that is still long
/// is cut on a blank line. Cuts never fall inside a fence, a display equation,
/// or a table, so each piece remains valid Markdown on its own.
List<String> splitStudyMarkdown(String source) {
  if (source.trim().isEmpty) return const [];
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final sections = <List<String>>[];
  var current = <String>[];
  var fence = false;

  void flush() {
    if (current.any((line) => line.trim().isNotEmpty)) {
      sections.add(List<String>.of(current));
    }
    current = [];
  }

  for (final line in lines) {
    final fenceLine = line.trimLeft().startsWith('```');
    final heading = !fence && !fenceLine && _heading.hasMatch(line);
    if (heading && current.isNotEmpty) flush();
    if (fenceLine) fence = !fence;
    current.add(line);
  }
  flush();

  final pieces = <String>[];
  for (final section in sections) {
    for (final piece in _pack(section)) {
      pieces.add(piece.join('\n'));
    }
  }
  return pieces;
}

final _heading = RegExp(r'^#{1,3}[ \t]');

const _maxLines = 36;

List<List<String>> _pack(List<String> section) {
  if (section.length <= _maxLines && _dollars(section) <= 48) {
    return [section];
  }
  final pieces = <List<String>>[];
  var current = <String>[];
  var fence = false;
  var displayMath = false;

  void flush() {
    if (current.any((line) => line.trim().isNotEmpty)) {
      pieces.add(current);
    }
    current = [];
  }

  for (var i = 0; i < section.length; i++) {
    final line = section[i];
    if (line.trimLeft().startsWith('```')) fence = !fence;
    if (!fence && '\$\$'.allMatches(line).length.isOdd) {
      displayMath = !displayMath;
    }
    current.add(line);
    final next = i + 1 < section.length ? section[i + 1] : '';
    final inTable =
        line.trimLeft().startsWith('|') || next.trimLeft().startsWith('|');
    final roomToCut = section.length - (i + 1) > 6;
    final heavy = current.length >= 24 || _dollars(current) >= 40;
    if (!fence &&
        !displayMath &&
        !inTable &&
        line.trim().isEmpty &&
        heavy &&
        roomToCut) {
      flush();
    }
  }
  flush();
  return pieces.isEmpty ? [section] : pieces;
}

int _dollars(List<String> lines) {
  var count = 0;
  for (final line in lines) {
    count += '\$'.allMatches(line).length;
  }
  return count;
}
