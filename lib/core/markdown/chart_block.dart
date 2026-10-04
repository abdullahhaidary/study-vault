import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'chart_spec.dart';

/// Renders a [ChartSpec] (bar / line / pie) with a title and legend.
class ChartBlock extends StatelessWidget {
  const ChartBlock({super.key, required this.spec, this.height = 220});

  final ChartSpec spec;
  final double height;

  static List<Color> palette(ColorScheme scheme) => [
    scheme.primary,
    scheme.tertiary,
    scheme.secondary,
    scheme.error,
    scheme.primaryContainer,
    scheme.tertiaryContainer,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = palette(theme.colorScheme);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final chart = switch (spec.kind) {
      ChartKind.bar => _BarChart(spec: spec, colors: colors, style: labelStyle),
      ChartKind.line => _LineChart(
        spec: spec,
        colors: colors,
        style: labelStyle,
      ),
      ChartKind.pie => _PieChart(spec: spec, colors: colors, style: labelStyle),
    };

    final showLegend =
        spec.kind == ChartKind.pie ||
        spec.series.length > 1 ||
        spec.series.first.name.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spec.title != null) ...[
            Text(
              spec.title!,
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          SizedBox(height: height, child: chart),
          if (spec.xLabel != null && spec.kind != ChartKind.pie) ...[
            const SizedBox(height: AppSpacing.xxs),
            Center(child: Text(spec.xLabel!, style: labelStyle)),
          ],
          if (showLegend) ...[
            const SizedBox(height: AppSpacing.xs),
            _Legend(
              entries: spec.kind == ChartKind.pie
                  ? [
                      for (final (i, label) in spec.labels.indexed)
                        (label, colors[i % colors.length]),
                    ]
                  : [
                      for (final (i, s) in spec.series.indexed)
                        (s.name, colors[i % colors.length]),
                    ],
              style: labelStyle,
            ),
          ],
        ],
      ),
    );
  }
}

String _formatNumber(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
  return v.toStringAsFixed(v.abs() < 10 ? 2 : 1);
}

/// Picks a "nice" interval so axis labels do not overlap.
double _niceInterval(double range, {int targetTicks = 5}) {
  if (range <= 0) return 1;
  final rough = range / targetTicks;
  final magnitude = math.pow(10, (math.log(rough) / math.ln10).floor());
  final residual = rough / magnitude;
  final nice = residual >= 5
      ? 10
      : residual >= 2
      ? 5
      : residual >= 1
      ? 2
      : 1;
  return (nice * magnitude).toDouble();
}

(double, double) _yBounds(ChartSpec spec) {
  var min = math.min(0.0, spec.minValue);
  var max = math.max(0.0, spec.maxValue);
  if (min == max) max = min + 1;
  final interval = _niceInterval(max - min);
  min = (min / interval).floor() * interval;
  max = (max / interval).ceil() * interval;
  return (min, max);
}

FlTitlesData _axisTitles(
  ChartSpec spec,
  TextStyle? style, {
  required double interval,
}) {
  final dense = spec.labels.length > 12;
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      axisNameWidget: spec.yLabel == null
          ? null
          : Text(spec.yLabel!, style: style),
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 44,
        interval: interval,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: Text(_formatNumber(value), style: style),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: dense ? 40 : 28,
        interval: 1,
        getTitlesWidget: (value, meta) {
          final index = value.round();
          if (index < 0 || index >= spec.labels.length || value != index) {
            return const SizedBox.shrink();
          }
          if (dense && index.isOdd) return const SizedBox.shrink();
          return SideTitleWidget(
            meta: meta,
            angle: dense ? -0.6 : 0,
            child: Text(
              spec.labels[index],
              style: style,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          );
        },
      ),
    ),
  );
}

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.spec,
    required this.colors,
    required this.style,
  });

  final ChartSpec spec;
  final List<Color> colors;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final (minY, maxY) = _yBounds(spec);
    final interval = _niceInterval(maxY - minY);
    final rodWidth = (160 / (spec.labels.length * spec.series.length)).clamp(
      4.0,
      22.0,
    );
    final theme = Theme.of(context);

    return BarChart(
      BarChartData(
        minY: minY,
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: theme.colorScheme.outlineVariant, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _axisTitles(spec, style, interval: interval),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
              '${spec.labels[group.x]}\n'
              '${spec.series[rodIndex].name}: ${_formatNumber(rod.toY)}',
              theme.textTheme.labelSmall!.copyWith(
                color: theme.colorScheme.onInverseSurface,
              ),
            ),
          ),
        ),
        barGroups: [
          for (final (i, _) in spec.labels.indexed)
            BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                for (final (s, series) in spec.series.indexed)
                  BarChartRodData(
                    toY: series.data[i],
                    width: rodWidth,
                    color: colors[s % colors.length],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.spec,
    required this.colors,
    required this.style,
  });

  final ChartSpec spec;
  final List<Color> colors;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final (minY, maxY) = _yBounds(spec);
    final interval = _niceInterval(maxY - minY);
    final theme = Theme.of(context);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (spec.labels.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: theme.colorScheme.outlineVariant, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _axisTitles(spec, style, interval: interval),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  '${spec.series[spot.barIndex].name}: '
                  '${_formatNumber(spot.y)}',
                  theme.textTheme.labelSmall!.copyWith(
                    color: theme.colorScheme.onInverseSurface,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          for (final (s, series) in spec.series.indexed)
            LineChartBarData(
              color: colors[s % colors.length],
              barWidth: 2.5,
              isCurved: false,
              dotData: FlDotData(show: spec.labels.length <= 24),
              spots: [
                for (final (i, v) in series.data.indexed)
                  FlSpot(i.toDouble(), v),
              ],
            ),
        ],
      ),
    );
  }
}

class _PieChart extends StatelessWidget {
  const _PieChart({
    required this.spec,
    required this.colors,
    required this.style,
  });

  final ChartSpec spec;
  final List<Color> colors;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = spec.series.first.data;
    final total = data.fold<double>(0, (a, b) => a + b.abs());
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 0,
        sections: [
          for (final (i, v) in data.indexed)
            PieChartSectionData(
              value: v.abs(),
              color: colors[i % colors.length],
              radius: 90,
              title: total == 0
                  ? ''
                  : '${(v.abs() / total * 100).toStringAsFixed(0)}%',
              titleStyle: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
              showTitle: total > 0 && v.abs() / total >= 0.05,
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.entries, required this.style});

  final List<(String, Color)> entries;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xxs,
      children: [
        for (final (label, color) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(label, style: style),
            ],
          ),
      ],
    );
  }
}
