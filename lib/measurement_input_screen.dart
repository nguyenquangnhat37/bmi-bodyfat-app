import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admob_service.dart';
import 'analytics_history_screen.dart';
import 'body_composition_calculator.dart';
import 'local_database_helper.dart';

class MeasurementInputScreen extends StatefulWidget {
  const MeasurementInputScreen({super.key});

  @override
  State<MeasurementInputScreen> createState() => _MeasurementInputScreenState();
}

/// Kết quả đọc form: hoặc có kết quả hợp lệ, hoặc có thông báo lỗi.
class _Outcome {
  final MeasurementInput? input;
  final MeasurementSnapshot? snapshot;
  final String? error;

  const _Outcome({this.input, this.snapshot, this.error});
}

class _MeasurementInputScreenState extends State<MeasurementInputScreen> {
  Gender _gender = Gender.male;
  BodyFatMethod _method = BodyFatMethod.usNavy;
  BmiStandard _standard = BmiStandard.asian;
  bool _saving = false;

  final _heightCtrl = TextEditingController(text: '170');
  final _weightCtrl = TextEditingController(text: '65');
  final _ageCtrl = TextEditingController(text: '28');
  final _neckCtrl = TextEditingController(text: '37');
  final _waistCtrl = TextEditingController(text: '78');
  final _hipCtrl = TextEditingController(text: '94');

  @override
  void dispose() {
    for (final c in [_heightCtrl, _weightCtrl, _ageCtrl, _neckCtrl, _waistCtrl, _hipCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  static double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static String? _checkRange(String name, double? v, double min, double max, String unit) {
    if (v == null) return 'Vui lòng nhập $name';
    if (v < min || v > max) return '$name phải từ ${_fmt(min)} đến ${_fmt(max)} $unit';
    return null;
  }

  /// Đọc form, kiểm tra và tính kết quả. Không có setState ở đây.
  _Outcome _evaluate() {
    final isNavy = _method == BodyFatMethod.usNavy;
    final isFemale = _gender == Gender.female;

    final height = _num(_heightCtrl.text);
    final weight = _num(_weightCtrl.text);
    final age = int.tryParse(_ageCtrl.text.trim());
    final neck = _num(_neckCtrl.text);
    final waist = _num(_waistCtrl.text);
    final hip = _num(_hipCtrl.text);

    final errors = <String?>[
      _checkRange('Chiều cao', height, 100, 230, 'cm'),
      _checkRange('Cân nặng', weight, 20, 300, 'kg'),
      (age == null || age < 10 || age > 100) ? 'Tuổi phải từ 10 đến 100' : null,
    ];
    if (isNavy) {
      errors.add(_checkRange('Vòng cổ', neck, 20, 70, 'cm'));
      errors.add(_checkRange('Vòng eo', waist, 40, 180, 'cm'));
      if (isFemale) errors.add(_checkRange('Vòng hông', hip, 50, 180, 'cm'));
    }

    String? firstError;
    for (final e in errors) {
      if (e != null) {
        firstError = e;
        break;
      }
    }
    if (firstError != null) return _Outcome(error: firstError);

    final input = MeasurementInput(
      gender: _gender,
      method: _method,
      bmiStandard: _standard,
      heightCm: height!,
      weightKg: weight!,
      age: age!,
      neckCm: isNavy ? neck : null,
      waistCm: isNavy ? waist : null,
      hipCm: (isNavy && isFemale) ? hip : null,
    );

    try {
      return _Outcome(input: input, snapshot: BodyCompositionCalculator.compute(input));
    } on MeasurementException catch (e) {
      return _Outcome(input: input, error: e.message);
    }
  }

  Future<void> _save(_Outcome o) async {
    final input = o.input;
    final snapshot = o.snapshot;
    if (input == null || snapshot == null) return;

    setState(() => _saving = true);
    try {
      await LocalDatabaseHelper.instance.insertRecord(
        MeasurementRecord.create(input: input, result: snapshot, at: DateTime.now()),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Không lưu được dữ liệu: $e');
      }
      return;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    HapticFeedback.mediumImpact();

    AdMobService.instance.onMeasurementSaved(onDone: () {
      if (!mounted) return;
      _snack('Đã lưu vào lịch sử', action: SnackBarAction(label: 'Xem', onPressed: _openHistory));
    });
  }

  void _snack(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, action: action),
    );
  }

  void _openHistory() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsHistoryScreen()));
  }

  void _showDisclaimer(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Miễn trừ trách nhiệm y tế'),
        content: const Text(
          'Ứng dụng không phải thiết bị y tế và không chẩn đoán hay điều trị bệnh.\n\n'
          'BMI, tỷ lệ mỡ (US Navy hoặc Deurenberg), chỉ số vòng eo/chiều cao và BMR chỉ là ước lượng, có sai số.\n\n'
          'Hãy hỏi ý kiến bác sĩ trước khi thay đổi chế độ ăn hoặc luyện tập.',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đã hiểu')),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String unit, {bool integer = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.numberWithOptions(decimal: !integer),
        inputFormatters: [
          FilteringTextInputFormatter.allow(integer ? RegExp(r'[0-9]') : RegExp(r'[0-9.,]')),
        ],
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          suffixText: unit,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final o = _evaluate();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đo BMI & Tỷ lệ mỡ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Miễn trừ y tế',
            onPressed: () => _showDisclaimer(context),
          ),
          IconButton(
            icon: const Icon(Icons.show_chart_rounded),
            tooltip: 'Lịch sử & biểu đồ',
            onPressed: _openHistory,
          ),
        ],
      ),
      bottomNavigationBar: const AdMobBanner(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (o.snapshot != null)
              _ResultCard(s: o.snapshot!)
            else
              _MessageCard(
                text: o.error ?? 'Nhập số đo để xem kết quả',
                color: cs.errorContainer,
                textColor: cs.onErrorContainer,
              ),
            const SizedBox(height: 16),
            SegmentedButton<Gender>(
              segments: const [
                ButtonSegment(value: Gender.male, label: Text('Nam')),
                ButtonSegment(value: Gender.female, label: Text('Nữ')),
              ],
              selected: {_gender},
              onSelectionChanged: (s) => setState(() => _gender = s.first),
            ),
            const SizedBox(height: 10),
            SegmentedButton<BodyFatMethod>(
              segments: const [
                ButtonSegment(value: BodyFatMethod.usNavy, label: Text('US Navy (thước dây)')),
                ButtonSegment(value: BodyFatMethod.deurenberg, label: Text('Ước tính nhanh')),
              ],
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.first),
            ),
            const SizedBox(height: 10),
            SegmentedButton<BmiStandard>(
              segments: const [
                ButtonSegment(value: BmiStandard.asian, label: Text('BMI chuẩn Châu Á')),
                ButtonSegment(value: BmiStandard.who, label: Text('BMI chuẩn WHO')),
              ],
              selected: {_standard},
              onSelectionChanged: (s) => setState(() => _standard = s.first),
            ),
            const SizedBox(height: 16),
            _field(_heightCtrl, 'Chiều cao', 'cm'),
            _field(_weightCtrl, 'Cân nặng', 'kg'),
            _field(_ageCtrl, 'Tuổi', 'tuổi', integer: true),
            if (_method == BodyFatMethod.usNavy) ...[
              _field(_neckCtrl, 'Vòng cổ', 'cm'),
              _field(_waistCtrl, 'Vòng eo', 'cm'),
              if (_gender == Gender.female) _field(_hipCtrl, 'Vòng hông', 'cm'),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: (o.snapshot == null || _saving) ? null : () => _save(o),
              icon: const Icon(Icons.save_outlined),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_saving ? 'Đang lưu...' : 'Lưu vào lịch sử'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ứng dụng chỉ mang tính tham khảo, không thay thế chẩn đoán của bác sĩ.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const _MessageCard({required this.text, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(text, style: TextStyle(color: textColor)),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final MeasurementSnapshot s;

  const _ResultCard({required this.s});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bmi = s.bmi;
    final bf = s.bodyFat;
    final whtr = s.whtr;

    return Card(
      elevation: 0,
      color: cs.primaryContainer.withOpacity(0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _BigStat(title: 'BMI', value: bmi.bmi.toStringAsFixed(1), sub: bmi.label),
                  ),
                  VerticalDivider(width: 24, color: cs.outlineVariant),
                  Expanded(
                    child: _BigStat(
                      title: 'TỶ LỆ MỠ',
                      value: '${bf.percentage.toStringAsFixed(1)}%',
                      sub: bf.label,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 16,
              runSpacing: 10,
              children: [
                _SmallStat(label: 'Cơ nạc', value: '${bf.leanMassKg.toStringAsFixed(1)} kg'),
                _SmallStat(label: 'Khối mỡ', value: '${bf.fatMassKg.toStringAsFixed(1)} kg'),
                _SmallStat(label: 'BMR', value: '${s.bmrKcal} kcal'),
                _SmallStat(
                  label: 'Cân nặng khỏe mạnh',
                  value: '${bmi.healthyWeightMinKg.toStringAsFixed(1)}–${bmi.healthyWeightMaxKg.toStringAsFixed(1)} kg',
                ),
              ],
            ),
            if (whtr != null) ...[
              const SizedBox(height: 12),
              Text(
                'Vòng eo/chiều cao: ${whtr.ratio.toStringAsFixed(2)} — ${whtr.assessment}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String title;
  final String value;
  final String sub;

  const _BigStat({required this.title, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        Text(sub, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: cs.primary)),
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;

  const _SmallStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
