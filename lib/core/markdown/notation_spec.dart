import 'dart:math' as math;

/// Parsed study-diagram ASCII that we can render as cards instead of a
/// monospace code block (ChatGPT-style mappings, UML boxes, and flows).
sealed class NotationSpec {
  const NotationSpec();

  static NotationSpec? tryParse(String source, {String? language}) {
    final lang = language?.trim().toLowerCase() ?? '';
    if (_codeLanguages.contains(lang)) return null;
    final text = source.replaceAll('\r\n', '\n').trim();
    if (text.isEmpty) return null;

    final looksMermaid =
        lang == 'mermaid' ||
        text.trimLeft().toLowerCase().startsWith('graph') ||
        text.trimLeft().toLowerCase().startsWith('flowchart');
    if (looksMermaid) {
      final mermaid = MappingNotation.tryParseMermaid(text);
      if (mermaid != null) return mermaid;
    }

    return ClassBoxNotation.tryParse(text) ??
        PipelineNotation.tryParse(text) ??
        StackFlowNotation.tryParse(text) ??
        RelationshipNotation.tryParse(text) ??
        TableNotation.tryParse(text) ??
        MappingNotation.tryParse(text) ??
        TreeNotation.tryParse(text) ??
        MappingNotation.tryParseMermaid(text);
  }

  static const _codeLanguages = {
    'dart',
    'java',
    'kotlin',
    'swift',
    'python',
    'py',
    'js',
    'javascript',
    'ts',
    'typescript',
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
    'chart',
  };
}

class NotationPair {
  const NotationPair({required this.from, required this.to});

  final String from;
  final String to;
}

class MappingNotation extends NotationSpec {
  const MappingNotation(this.pairs);

  final List<NotationPair> pairs;

  static final _arrow = RegExp(
    r'^\s*(?:\[([^\]]+)\]|(.+?))\s*(?:-{2,}>|→|⇒|=>)\s*(.+?)\s*$',
  );

  static MappingNotation? tryParse(String text) {
    final pairs = <NotationPair>[];
    var contentLines = 0;
    for (final raw in text.split('\n')) {
      if (raw.trim().isEmpty) continue;
      contentLines++;
      final match = _arrow.firstMatch(raw);
      if (match == null) continue;
      final from = (match.group(1) ?? match.group(2) ?? '').trim();
      final to = (match.group(3) ?? '').trim();
      if (from.isEmpty || to.isEmpty) continue;
      pairs.add(NotationPair(from: from, to: to));
    }
    if (pairs.length < 2) return null;
    if (pairs.length < (contentLines / 2).ceil()) return null;
    return MappingNotation(List.unmodifiable(pairs));
  }

  static final _mermaidEdge = RegExp(
    r'([A-Za-z][\w-]*)(?:\[([^\]]+)\])?\s*-->\s*([A-Za-z][\w-]*)(?:\[([^\]]+)\])?',
  );

  static MappingNotation? tryParseMermaid(String text) {
    final lower = text.trimLeft().toLowerCase();
    if (!(lower.startsWith('graph') ||
        lower.startsWith('flowchart') ||
        lower.contains('-->'))) {
      return null;
    }
    final labels = <String, String>{};
    final pairs = <NotationPair>[];
    final seen = <String>{};
    for (final match in _mermaidEdge.allMatches(text)) {
      final fromId = match.group(1)!;
      final toId = match.group(3)!;
      final fromLabel = (match.group(2) ?? '').trim();
      final toLabel = (match.group(4) ?? '').trim();
      if (fromLabel.isNotEmpty) labels[fromId] = fromLabel;
      if (toLabel.isNotEmpty) labels[toId] = toLabel;
      final from = labels[fromId] ?? fromId;
      final to = labels[toId] ?? toId;
      final key = '$from\u0000$to';
      if (!seen.add(key)) continue;
      pairs.add(NotationPair(from: from, to: to));
    }
    if (pairs.length < 2) return null;
    return MappingNotation(List.unmodifiable(pairs));
  }
}

class ClassCompartment {
  const ClassCompartment({required this.lines, this.label});

  final String? label;
  final List<String> lines;
}

class ClassBoxNotation extends NotationSpec {
  const ClassBoxNotation({required this.className, required this.compartments});

  final String className;
  final List<ClassCompartment> compartments;

  static final _rule = RegExp(r'^\s*\+[.\-=]+\+\s*$');
  static final _content = RegExp(r'^\s*\|(.*)\|\s*(?:(?:<--|←)\s*(.*))?\s*$');

  static ClassBoxNotation? tryParse(String text) {
    final lines = text.split('\n');
    if (!_looksLikeSingleClassBox(lines)) return null;

    final compartments = <ClassCompartment>[];
    var currentLines = <String>[];
    String? currentLabel;
    var sawRule = false;

    void flush() {
      if (currentLines.isEmpty && currentLabel == null) return;
      compartments.add(
        ClassCompartment(
          label: currentLabel?.trim(),
          lines: List.unmodifiable(currentLines),
        ),
      );
      currentLines = [];
      currentLabel = null;
    }

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      if (_rule.hasMatch(line)) {
        if (sawRule) flush();
        sawRule = true;
        continue;
      }
      final match = _content.firstMatch(line);
      if (match == null) return null;
      final cell = match.group(1)!.trim();
      final comment = match.group(2)?.trim();
      if (comment != null && comment.isNotEmpty) {
        currentLabel ??= comment;
      }
      if (cell.isNotEmpty) currentLines.add(cell);
    }
    flush();
    if (compartments.length < 2) return null;
    final nameLines = compartments.first.lines;
    if (nameLines.isEmpty) return null;
    return ClassBoxNotation(
      className: nameLines.first,
      compartments: [
        if (nameLines.length > 1)
          ClassCompartment(
            label: compartments.first.label,
            lines: nameLines.sublist(1),
          ),
        ...compartments.skip(1),
      ],
    );
  }

  static bool _looksLikeSingleClassBox(List<String> lines) {
    var rules = 0;
    var twoPipe = 0;
    var manyPipe = 0;
    var sideLabel = false;
    var connectors = 0;
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      if (PipelineNotation.isConnector(line)) {
        connectors++;
        continue;
      }
      if (_rule.hasMatch(line)) {
        rules++;
        if (_sideText(line).$1.isNotEmpty || _sideText(line).$2.isNotEmpty) {
          sideLabel = true;
        }
        continue;
      }
      final pipes = '|'.allMatches(line).length;
      if (pipes >= 3) manyPipe++;
      if (pipes == 2) twoPipe++;
    }
    return rules >= 2 &&
        twoPipe >= 1 &&
        manyPipe == 0 &&
        !sideLabel &&
        connectors == 0;
  }
}

(String, String) _sideText(String line) {
  final start = line.indexOf('+');
  final end = line.lastIndexOf('+');
  if (start < 0) {
    final pipe = line.indexOf('|');
    final lastPipe = line.lastIndexOf('|');
    if (pipe < 0) return ('', '');
    return (
      line.substring(0, pipe).trim(),
      lastPipe + 1 < line.length ? line.substring(lastPipe + 1).trim() : '',
    );
  }
  final left = line.substring(0, start).trim();
  var right = end + 1 < line.length ? line.substring(end + 1).trim() : '';
  if (right.startsWith('<--') || right.startsWith('←')) right = '';
  return (left, right);
}

class PipelineStep {
  const PipelineStep({required this.title, this.left, this.right});

  final String title;
  final String? left;
  final String? right;
}

class PipelineNotation extends NotationSpec {
  const PipelineNotation(this.steps);

  final List<PipelineStep> steps;

  static final _rule = RegExp(r'\+[.\-=]+\+');
  static final _boxLine = RegExp(r'\|\s*(.+?)\s*\|');

  static bool isConnector(String line) {
    final t = line.trim();
    return RegExp(r'^[|vV▼↓▾^]+$').hasMatch(t);
  }

  static PipelineNotation? tryParse(String text) {
    final lines = text.split('\n');
    var boxRules = 0;
    var connectors = 0;
    for (final line in lines) {
      if (isConnector(line)) connectors++;
      if (_rule.hasMatch(line)) boxRules++;
    }
    if (boxRules < 2 || connectors == 0) return null;

    final groups = <List<String>>[];
    var current = <String>[];
    for (final line in lines) {
      if (line.trim().isEmpty || isConnector(line)) {
        if (current.isNotEmpty) {
          groups.add(current);
          current = [];
        }
        continue;
      }
      current.add(line);
    }
    if (current.isNotEmpty) groups.add(current);

    final steps = <PipelineStep>[];
    for (final group in groups) {
      final titles = <String>[];
      var left = '';
      var right = '';
      for (final line in group) {
        final sides = _sideText(line);
        if (sides.$1.isNotEmpty) left = sides.$1;
        if (sides.$2.isNotEmpty) right = sides.$2;
        if (ClassBoxNotation._rule.hasMatch(line.trim()) ||
            ClassBoxNotation._rule.hasMatch(line)) {
          continue;
        }
        final box = _boxLine.firstMatch(line);
        if (box != null && '|'.allMatches(line).length == 2) {
          final title = box.group(1)!.trim();
          if (title.isNotEmpty) titles.add(title);
        }
      }
      if (titles.isEmpty) continue;
      steps.add(
        PipelineStep(
          title: titles.join('\n'),
          left: left.isEmpty ? null : left,
          right: right.isEmpty ? null : right,
        ),
      );
    }
    if (steps.length < 2) return null;
    return PipelineNotation(List.unmodifiable(steps));
  }
}

class StackFlowItem {
  const StackFlowItem({required this.title, this.detail});

  final String title;
  final String? detail;
}

class StackFlowNotation extends NotationSpec {
  const StackFlowNotation({this.title, required this.items});

  final String? title;
  final List<StackFlowItem> items;

  static final _box = RegExp(r'^\s*\[\s*(.+?)\s*\]\s*$');

  static StackFlowNotation? tryParse(String text) {
    final lines = text.split('\n');
    final items = <StackFlowItem>[];
    final heading = <String>[];
    String? pendingTitle;
    final pendingDetail = <String>[];

    void flush() {
      if (pendingTitle == null) return;
      items.add(
        StackFlowItem(
          title: pendingTitle!,
          detail: pendingDetail.isEmpty ? null : pendingDetail.join('\n'),
        ),
      );
      pendingTitle = null;
      pendingDetail.clear();
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || PipelineNotation.isConnector(trimmed)) continue;
      final box = _box.firstMatch(trimmed);
      if (box != null) {
        flush();
        pendingTitle = box.group(1)!.trim();
        continue;
      }
      if (pendingTitle == null) {
        heading.add(trimmed);
      } else {
        pendingDetail.add(trimmed);
      }
    }
    flush();
    if (items.length < 2) return null;
    return StackFlowNotation(
      title: heading.isEmpty ? null : heading.join(' '),
      items: List.unmodifiable(items),
    );
  }
}

enum UmlConnectorKind {
  association,
  directed,
  generalization,
  aggregation,
  composition,
}

class UmlRelationship {
  const UmlRelationship({
    required this.left,
    required this.right,
    required this.kind,
    this.label,
    this.leftMultiplicity,
    this.rightMultiplicity,
    this.note,
  });

  final String? label;
  final String left;
  final String right;
  final UmlConnectorKind kind;
  final String? leftMultiplicity;
  final String? rightMultiplicity;
  final String? note;
}

class RelationshipNotation extends NotationSpec {
  const RelationshipNotation(this.items);

  final List<UmlRelationship> items;

  static final connector = RegExp(
    r'[<>\[\]()oO*♦◆◇|\\/]{0,2}[-–—]{3,}[<>\[\]()|*♦◆◇\\/]{0,3}',
  );

  static bool looksLikeLine(String line) => parseLine(line) != null;

  static RelationshipNotation? tryParse(String text) {
    final items = <UmlRelationship>[];
    var contentLines = 0;
    for (final raw in text.split('\n')) {
      if (raw.trim().isEmpty) continue;
      contentLines++;
      final item = parseLine(raw);
      if (item != null) items.add(item);
    }
    if (items.isEmpty) return null;
    if (items.length < contentLines / 2) return null;
    return RelationshipNotation(List.unmodifiable(items));
  }

  static UmlRelationship? parseLine(String raw) {
    var line = raw.trim();
    if (line.startsWith('- ') || line.startsWith('* ')) {
      line = line.substring(2).trim();
    }
    if (RegExp(r'-{2,}>').hasMatch(line) && !line.contains('|>')) {
      return null;
    }
    final match = connector.firstMatch(line);
    if (match == null) return null;
    var left = line.substring(0, match.start).trim();
    var right = line.substring(match.end).trim();
    if (left.isEmpty || right.isEmpty) return null;

    String? label;
    final labeled = RegExp(
      r'^([A-Za-z][A-Za-z0-9 /]*?):\s+(.*)$',
    ).firstMatch(left);
    if (labeled != null) {
      label = labeled.group(1)!.trim();
      left = labeled.group(2)!.trim();
    }
    if (left.isEmpty) return null;

    String? leftMulti;
    String? rightMulti;
    final leftM = RegExp(r'^(.*?)\s*\[([^\]]+)\]$').firstMatch(left);
    if (leftM != null && leftM.group(1)!.trim().isNotEmpty) {
      left = leftM.group(1)!.trim();
      leftMulti = leftM.group(2);
    }
    final rightM = RegExp(r'^\[([^\]]+)\]\s*(.*)$').firstMatch(right);
    if (rightM != null && rightM.group(2)!.trim().isNotEmpty) {
      rightMulti = rightM.group(1);
      right = rightM.group(2)!.trim();
    }

    String? note;
    final noteSplit = RegExp(r'^([^:]{1,48}):\s+(.+)$').firstMatch(right);
    if (noteSplit != null) {
      right = noteSplit.group(1)!.trim();
      note = noteSplit.group(2)!.trim();
    }
    if (right.isEmpty) return null;

    return UmlRelationship(
      label: label,
      left: left,
      right: right,
      kind: _kindFor(match.group(0)!),
      leftMultiplicity: leftMulti,
      rightMultiplicity: rightMulti,
      note: note,
    );
  }

  static UmlConnectorKind _kindFor(String connector) {
    final t = connector.replaceAll(' ', '');
    if (t.contains('|>') || t.contains('▷') || t.endsWith('>')) {
      if (t.contains('|>') || t.contains('△') || t.contains('▷')) {
        return UmlConnectorKind.generalization;
      }
      return UmlConnectorKind.directed;
    }
    if (t.startsWith('<>') ||
        t.startsWith('o-') ||
        t.startsWith('O-') ||
        t.startsWith('◇')) {
      return UmlConnectorKind.aggregation;
    }
    if (t.startsWith('♦') ||
        t.startsWith('◆') ||
        t.startsWith('*-') ||
        t.startsWith('*─')) {
      return UmlConnectorKind.composition;
    }
    return UmlConnectorKind.association;
  }
}

class TableNotation extends NotationSpec {
  const TableNotation({
    this.caption,
    required this.headers,
    required this.rows,
  });

  final String? caption;
  final List<String> headers;
  final List<List<String>> rows;

  static TableNotation? tryParse(String text) {
    final parsed = <List<String>>[];
    String? caption;
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (RegExp(r'^[\s+\-|.:\=]+$').hasMatch(line)) continue;
      final cells = _cells(line);
      if (cells.every((cell) => cell.isEmpty)) continue;
      if (parsed.isEmpty && cells.length == 1) {
        caption = cells.single;
        continue;
      }
      if (cells.length < 2) return null;
      parsed.add(cells);
    }
    if (parsed.length < 2) return null;
    final width = parsed
        .map((row) => row.length)
        .reduce((a, b) => a > b ? a : b);
    if (width < 2) return null;
    List<String> pad(List<String> row) => [
      for (var i = 0; i < width; i++) i < row.length ? row[i] : '',
    ];
    return TableNotation(
      caption: caption,
      headers: pad(parsed.first),
      rows: [for (final row in parsed.skip(1)) pad(row)],
    );
  }

  static List<String> _cells(String line) {
    var t = line.trim();
    if (t.startsWith('|')) t = t.substring(1);
    if (t.endsWith('|')) t = t.substring(0, t.length - 1);
    return [for (final cell in t.split('|')) cell.trim()];
  }
}

class TreeBranch {
  const TreeBranch({required this.title, required this.details});

  final String title;
  final List<String> details;
}

class TreeNotation extends NotationSpec {
  const TreeNotation({
    required this.root,
    this.subtitle,
    required this.branches,
  });

  final String root;
  final String? subtitle;
  final List<TreeBranch> branches;

  static TreeNotation? tryParse(String text) {
    final lines = text.split('\n');
    if (lines.length < 4) return null;

    var anchorIndex = -1;
    var anchors = const <int>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final pipes = <int>[];
      for (var c = 0; c < line.length; c++) {
        if (line[c] == '|') pipes.add(c);
      }
      if (pipes.length >= 2 && RegExp(r'^[\s|]+$').hasMatch(line)) {
        anchorIndex = i;
        anchors = pipes;
      }
    }
    if (anchorIndex < 0 || anchors.length < 2) return null;

    final heading = <String>[];
    for (var i = 0; i < anchorIndex; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty ||
          RegExp(r'^[\s|./\\_+*=\-–—•·]+$').hasMatch(trimmed)) {
        continue;
      }
      heading.add(_stripQuotes(trimmed));
    }
    if (heading.isEmpty) return null;

    final columns = List<List<String>>.generate(anchors.length, (_) => []);
    for (var i = anchorIndex + 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      if (RegExp(r'^[\s|./\\_+*=\-–—•·]+$').hasMatch(line.trim())) continue;
      final cells = _splitByAnchors(line, anchors);
      for (var c = 0; c < cells.length; c++) {
        if (cells[c].isNotEmpty) columns[c].add(cells[c]);
      }
    }

    final branches = <TreeBranch>[
      for (final column in columns)
        if (column.isNotEmpty)
          TreeBranch(
            title: column.first,
            details: [for (final line in column.skip(1)) line],
          ),
    ];
    if (branches.length < 2) return null;

    return TreeNotation(
      root: heading.first,
      subtitle: heading.length > 1 ? heading.sublist(1).join(' ') : null,
      branches: List.unmodifiable(branches),
    );
  }

  static String _stripQuotes(String value) {
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1).trim();
    }
    return value;
  }

  static List<String> _splitByAnchors(String line, List<int> anchors) {
    final width = math.max(line.length, anchors.last + 8);
    final padded = line.padRight(width);
    final bounds = <int>[0];
    for (var i = 0; i < anchors.length - 1; i++) {
      bounds.add(((anchors[i] + anchors[i + 1]) / 2).round());
    }
    bounds.add(padded.length);
    return [
      for (var i = 0; i < anchors.length; i++)
        padded.substring(bounds[i], bounds[i + 1]).trim(),
    ];
  }
}
