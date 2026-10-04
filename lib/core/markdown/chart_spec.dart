import 'dart:convert';

/// Chart kinds the in-app renderer supports.
enum ChartKind { bar, line, pie }

/// One named data series (e.g. "Score") of a chart.
class ChartSeries {
  const ChartSeries({required this.name, required this.data});

  final String name;
  final List<double> data;
}

/// Declarative chart description emitted by the AI inside a ```chart block.
///
/// Schema (JSON):
/// ```json
/// {"type":"bar|line|pie","title":"...","labels":["a","b"],
///  "series":[{"name":"...","data":[1,2]}],"xLabel":"...","yLabel":"..."}
/// ```
class ChartSpec {
  const ChartSpec({
    required this.kind,
    required this.labels,
    required this.series,
    this.title,
    this.xLabel,
    this.yLabel,
  });

  final ChartKind kind;
  final String? title;
  final List<String> labels;
  final List<ChartSeries> series;
  final String? xLabel;
  final String? yLabel;

  /// Fenced-code language tag that triggers chart rendering.
  static const language = 'chart';

  static const maxPoints = 60;
  static const maxSeries = 6;

  /// Short instruction appended to AI system prompts so models know the format.
  static const promptInstruction =
      'When numeric/tabular data would be clearer as a chart, emit a fenced '
      'code block tagged `chart` containing only JSON: '
      '{"type":"bar"|"line"|"pie","title":string,"labels":[string],'
      '"series":[{"name":string,"data":[number]}],"xLabel"?:string,'
      '"yLabel"?:string}. Every series must have one number per label; '
      'pie charts use a single series. Keep charts small (<= 20 labels) and '
      'still explain the data in text.';

  /// Parses the JSON body of a ```chart block. Returns null when invalid so
  /// the caller can fall back to rendering the raw code block.
  static ChartSpec? tryParse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source.trim());
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final map = decoded;

    final kind = switch ((map['type'] as String?)?.trim().toLowerCase()) {
      'bar' || 'column' || 'histogram' => ChartKind.bar,
      'line' || 'area' => ChartKind.line,
      'pie' || 'donut' || 'doughnut' => ChartKind.pie,
      _ => null,
    };
    if (kind == null) return null;

    final rawLabels = map['labels'];
    if (rawLabels is! List || rawLabels.isEmpty) return null;
    final labels = [for (final l in rawLabels) l.toString()];
    if (labels.length > maxPoints) return null;

    final rawSeries = map['series'];
    final series = <ChartSeries>[];
    if (rawSeries is List) {
      for (final (index, entry) in rawSeries.indexed) {
        final parsed = _parseSeries(entry, index, labels.length);
        if (parsed == null) return null;
        series.add(parsed);
      }
    } else if (map['data'] is List) {
      // Shorthand: {"labels":[...],"data":[...]} → single series.
      final parsed = _parseSeries(
        {'name': map['title'] ?? 'Value', 'data': map['data']},
        0,
        labels.length,
      );
      if (parsed == null) return null;
      series.add(parsed);
    }
    if (series.isEmpty || series.length > maxSeries) return null;
    if (kind == ChartKind.pie && series.length != 1) return null;

    return ChartSpec(
      kind: kind,
      title: _optionalString(map['title']),
      labels: labels,
      series: series,
      xLabel: _optionalString(map['xLabel'] ?? map['x_label']),
      yLabel: _optionalString(map['yLabel'] ?? map['y_label']),
    );
  }

  static ChartSeries? _parseSeries(Object? entry, int index, int expected) {
    if (entry is! Map) return null;
    final rawData = entry['data'] ?? entry['values'];
    if (rawData is! List || rawData.length != expected) return null;
    final data = <double>[];
    for (final v in rawData) {
      final n = v is num ? v.toDouble() : double.tryParse(v.toString());
      if (n == null || !n.isFinite) return null;
      data.add(n);
    }
    final name = _optionalString(entry['name'] ?? entry['label']);
    return ChartSeries(name: name ?? 'Series ${index + 1}', data: data);
  }

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  double get maxValue => series
      .expand((s) => s.data)
      .fold<double>(0, (max, v) => v > max ? v : max);

  double get minValue => series
      .expand((s) => s.data)
      .fold<double>(0, (min, v) => v < min ? v : min);
}
