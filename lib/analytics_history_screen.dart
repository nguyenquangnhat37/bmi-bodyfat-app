import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'local_database_helper.dart';

enum ChartMetric { bodyFat, weight, leanMass }

const List<int?> _rangeOptions = [7, 30, 90, null];

String _two(int v) => v.toString().padLeft(2, '0');
String _shortDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}';
String _fullDate(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
String _rangeLabel(int? days) => days == null ? 'Tất cả' : (days == 90 ? '3 tháng' : '$days ngày');

class AnalyticsHistoryScreen extends StatefulWidget {
  const AnalyticsHistoryScreen({super.key});

  @override
  State<AnalyticsHistoryScreen> createState() => _AnalyticsHistoryScreenState();
}

class _AnalyticsHistoryScreenState extends State<AnalyticsHistoryScreen> {
  int? _days = 30;
  ChartMetric _metric = ChartMetric.bodyFat;
  List<MeasurementRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await LocalDatabaseHelper.instance.getRecords(days: _days);
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  double _valueOf(MeasurementRecord r) {
    switch (_metric) {
      case ChartMetric.bodyFat:
        return r.bodyFatPercentage;
      case ChartMetric.weight:
        return r.weightKg;
      case ChartMetric.leanMass:
        return r.leanMassKg;
    }
  }

  Future<void> _confirmDelete(MeasurementRecord r) async {
    final id = r.id;
    if (id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bản ghi này?'),
        content: Text('Bản ghi ngày ${_fullDate(r.recordedAt)} sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;

    await LocalDatabaseHelper.instance.deleteRecord(id);
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final delta = ProgressDelta.between(_records);
    final newestFirst = _records.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử & biểu đồ'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Làm mới', onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final d in _rangeOptions)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(_rangeLabel(d)),
                              selected: _days == d,
                              onSelected: (_) {
                                setState(() => _days = d);
                                _load();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _DeltaCard(title: 'Tỷ lệ mỡ', delta: delta.bodyFatPct, unit: '%', lowerIsBetter: true),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DeltaCard(title: 'Cân nặng', delta: delta.weightKg, unit: 'kg', lowerIsBetter: null),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DeltaCard(title: 'Cơ nạc', delta: delta.leanMassKg, unit: 'kg', lowerIsBetter: false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          SegmentedButton<ChartMetric>(
                            segments: const [
                              ButtonSegment(value: ChartMetric.bodyFat, label: Text('% Mỡ')),
                              ButtonSegment(value: ChartMetric.weight, label: Text('Cân nặng')),
                              ButtonSegment(value: ChartMetric.leanMass, label: Text('Cơ nạc')),
                            ],
                            selected: {_metric},
                            onSelectionChanged: (s) => setState(() => _metric = s.first),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: _records.length < 2
                                ? Center(
                                    child: Text(
                                      'Cần ít nhất 2 bản ghi trong khoảng này để vẽ biểu đồ.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: cs.onSurfaceVariant),
                                    ),
                                  )
                                : CustomPaint(
                                    size: Size.infinite,
                                    painter: _TrendPainter(
                                      values: _records.map(_valueOf).toList(),
                                      labels: _records.map((r) => _shortDate(r.recordedAt)).toList(),
                                      lineColor: cs.primary,
                                      gridColor: cs.outlineVariant,
                                      textColor: cs.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Nhật ký (${_records.length} bản ghi)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Chưa có bản ghi nào trong khoảng thời gian này.', textAlign: TextAlign.center),
                    ),
                  for (final r in newestFirst)
                    _RecordTile(record: r, onDelete: () => _confirmDelete(r)),
                ],
              ),
            ),
    );
  }
}

class _DeltaCard extends StatelessWidget {
  final String title;
  final double delta;
  final String unit;

  /// true: giảm là tốt; false: tăng là tốt; null: không đánh giá màu.
  final bool? lowerIsBetter;

  const _DeltaCard({
    required this.title,
    required this.delta,
    required this.unit,
    required this.lowerIsBetter,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    var color = cs.onSurface;
    final lib = lowerIsBetter;
    if (lib != null && delta != 0) {
      final good = lib ? delta < 0 : delta > 0;
      color = good ? Colors.teal.shade700 : Colors.deepOrange.shade700;
    }
    final sign = delta > 0 ? '+' : '';

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(
              '$sign${delta.toStringAsFixed(1)} $unit',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final MeasurementRecord record;
  final VoidCallback onDelete;

  const _RecordTile({required this.record, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 16, right: 4),
        title: Text(
          '${_fullDate(record.recordedAt)} — Mỡ ${record.bodyFatPercentage.toStringAsFixed(1)}%',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'BMI ${record.bmi.toStringAsFixed(1)} · Cân nặng ${record.weightKg.toStringAsFixed(1)} kg · '
          'Cơ nạc ${record.leanMassKg.toStringAsFixed(1)} kg',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: 'Xóa',
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  const _TrendPainter({
    required this.values,
    required this.labels,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double padL = 44, padR = 12, padT = 12, padB = 24;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;
    if (w <= 0 || h <= 0 || values.length < 2) return;

    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final span = maxV - minV;
    final pad = span < 0.5 ? 1.0 : span * 0.15;
    final yMin = minV - pad;
    final yMax = maxV + pad;

    double xAt(int i) => padL + (i / (values.length - 1)) * w;
    double yAt(double v) => padT + h - ((v - yMin) / (yMax - yMin)) * h;

    // Lưới ngang và nhãn trục Y
    final gridPaint = Paint()
      ..color = gridColor.withOpacity(0.5)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = padT + h * i / 3;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), gridPaint);
      final value = yMax - (yMax - yMin) * i / 3;
      _drawText(canvas, value.toStringAsFixed(1), Offset(0, y - 6));
    }

    final points = [for (var i = 0; i < values.length; i++) Offset(xAt(i), yAt(values[i]))];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    final fill = Path.from(path)
      ..lineTo(points.last.dx, padT + h)
      ..lineTo(points.first.dx, padT + h)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withOpacity(0.25), lineColor.withOpacity(0)],
      ).createShader(Rect.fromLTWH(padL, padT, w, h));
    canvas.drawPath(fill, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = lineColor;
    for (final p in points) {
      canvas.drawCircle(p, 3.5, dotPaint);
    }

    // Nhãn trục X: điểm đầu, giữa, cuối
    for (final i in {0, values.length ~/ 2, values.length - 1}) {
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: TextStyle(color: textColor, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(xAt(i) - tp.width / 2, padT + h + 6));
    }
  }

  void _drawText(Canvas canvas, String text, Offset topLeft) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: textColor, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, topLeft);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.values != values || old.labels != labels || old.lineColor != lineColor;
}
