import 'dart:math' as math;

enum Gender { male, female }

/// Chuẩn phân loại BMI. asian: WHO Châu Á-Thái Bình Dương. who: WHO toàn cầu.
enum BmiStandard { asian, who }

enum BmiCategory { underweight, normal, overweight, obeseClass1, obeseClass2, obeseClass3 }

/// Phân loại tỷ lệ mỡ theo bảng tham khảo ACE (American Council on Exercise).
enum BodyFatCategory { essential, athletes, fitness, average, obese }

enum BodyFatMethod { usNavy, deurenberg }

/// Lỗi dữ liệu đầu vào. Thông điệp hiển thị trực tiếp cho người dùng.
class MeasurementException implements Exception {
  final String message;
  const MeasurementException(this.message);

  @override
  String toString() => message;
}

class MeasurementInput {
  final Gender gender;
  final BodyFatMethod method;
  final BmiStandard bmiStandard;
  final double heightCm;
  final double weightKg;
  final int age;
  final double? neckCm;
  final double? waistCm;
  final double? hipCm;

  const MeasurementInput({
    required this.gender,
    required this.method,
    required this.bmiStandard,
    required this.heightCm,
    required this.weightKg,
    required this.age,
    this.neckCm,
    this.waistCm,
    this.hipCm,
  });
}

class BmiResult {
  final double bmi;
  final BmiCategory category;
  final String label;
  final double healthyWeightMinKg;
  final double healthyWeightMaxKg;

  const BmiResult({
    required this.bmi,
    required this.category,
    required this.label,
    required this.healthyWeightMinKg,
    required this.healthyWeightMaxKg,
  });
}

class BodyFatResult {
  final double percentage;
  final double fatMassKg;
  final double leanMassKg;
  final BodyFatCategory category;
  final String label;
  final BodyFatMethod method;

  const BodyFatResult({
    required this.percentage,
    required this.fatMassKg,
    required this.leanMassKg,
    required this.category,
    required this.label,
    required this.method,
  });
}

class WhtrResult {
  final double ratio;
  final String assessment;

  const WhtrResult({required this.ratio, required this.assessment});
}

class MeasurementSnapshot {
  final BmiResult bmi;
  final BodyFatResult bodyFat;

  /// Chỉ có khi đo bằng US Navy (cần vòng eo).
  final WhtrResult? whtr;
  final int bmrKcal;

  const MeasurementSnapshot({
    required this.bmi,
    required this.bodyFat,
    required this.whtr,
    required this.bmrKcal,
  });
}

double _round(double v, int digits) {
  final factor = math.pow(10, digits).toDouble();
  return (v * factor).roundToDouble() / factor;
}

double _log10(double x) => math.log(x) / math.ln10;

void _requirePositive(Map<String, double> values) {
  for (final e in values.entries) {
    if (!e.value.isFinite || e.value <= 0) {
      throw MeasurementException('${e.key} phải là số dương');
    }
  }
}

class BodyCompositionCalculator {
  BodyCompositionCalculator._();

  /// Tính toàn bộ chỉ số từ một bộ đầu vào. Ném [MeasurementException] nếu dữ liệu không hợp lệ.
  static MeasurementSnapshot compute(MeasurementInput input) {
    final bmi = calculateBmi(
      weightKg: input.weightKg,
      heightCm: input.heightCm,
      standard: input.bmiStandard,
    );

    final BodyFatResult bodyFat;
    final WhtrResult? whtr;
    if (input.method == BodyFatMethod.usNavy) {
      final neck = input.neckCm;
      final waist = input.waistCm;
      if (neck == null || waist == null) {
        throw const MeasurementException('Thiếu số đo vòng cổ hoặc vòng eo');
      }
      bodyFat = calculateNavyBodyFat(
        gender: input.gender,
        heightCm: input.heightCm,
        weightKg: input.weightKg,
        neckCm: neck,
        waistCm: waist,
        hipCm: input.gender == Gender.female ? input.hipCm : null,
      );
      whtr = calculateWhtr(waistCm: waist, heightCm: input.heightCm);
    } else {
      bodyFat = calculateDeurenbergBodyFat(
        bmi: bmi.bmi,
        age: input.age,
        gender: input.gender,
        weightKg: input.weightKg,
      );
      whtr = null;
    }

    return MeasurementSnapshot(
      bmi: bmi,
      bodyFat: bodyFat,
      whtr: whtr,
      bmrKcal: calculateBmr(
        gender: input.gender,
        weightKg: input.weightKg,
        heightCm: input.heightCm,
        age: input.age,
      ),
    );
  }

  /// BMI. Phân loại dùng đúng giá trị đã làm tròn 1 chữ số để khớp với giá trị hiển thị.
  static BmiResult calculateBmi({
    required double weightKg,
    required double heightCm,
    BmiStandard standard = BmiStandard.asian,
  }) {
    _requirePositive({'Cân nặng': weightKg, 'Chiều cao': heightCm});

    final heightM = heightCm / 100.0;
    final bmi = _round(weightKg / (heightM * heightM), 1);

    final BmiCategory category;
    final String label;
    final double healthyMaxBmi;

    if (standard == BmiStandard.asian) {
      healthyMaxBmi = 22.9;
      if (bmi < 18.5) {
        category = BmiCategory.underweight;
        label = 'Thiếu cân';
      } else if (bmi < 23.0) {
        category = BmiCategory.normal;
        label = 'Bình thường (chuẩn Châu Á)';
      } else if (bmi < 25.0) {
        category = BmiCategory.overweight;
        label = 'Thừa cân / tiền béo phì';
      } else if (bmi < 30.0) {
        category = BmiCategory.obeseClass1;
        label = 'Béo phì độ I';
      } else {
        category = BmiCategory.obeseClass2;
        label = 'Béo phì độ II';
      }
    } else {
      healthyMaxBmi = 24.9;
      if (bmi < 18.5) {
        category = BmiCategory.underweight;
        label = 'Thiếu cân';
      } else if (bmi < 25.0) {
        category = BmiCategory.normal;
        label = 'Bình thường (chuẩn WHO)';
      } else if (bmi < 30.0) {
        category = BmiCategory.overweight;
        label = 'Thừa cân';
      } else if (bmi < 35.0) {
        category = BmiCategory.obeseClass1;
        label = 'Béo phì độ I';
      } else if (bmi < 40.0) {
        category = BmiCategory.obeseClass2;
        label = 'Béo phì độ II';
      } else {
        category = BmiCategory.obeseClass3;
        label = 'Béo phì độ III';
      }
    }

    return BmiResult(
      bmi: bmi,
      category: category,
      label: label,
      healthyWeightMinKg: _round(18.5 * heightM * heightM, 1),
      healthyWeightMaxKg: _round(healthyMaxBmi * heightM * heightM, 1),
    );
  }

  /// US Navy (công thức thang cm, tương đương bản inch chuẩn).
  static BodyFatResult calculateNavyBodyFat({
    required Gender gender,
    required double heightCm,
    required double weightKg,
    required double neckCm,
    required double waistCm,
    double? hipCm,
  }) {
    _requirePositive({
      'Chiều cao': heightCm,
      'Cân nặng': weightKg,
      'Vòng cổ': neckCm,
      'Vòng eo': waistCm,
    });

    final double percent;
    if (gender == Gender.male) {
      final diff = waistCm - neckCm;
      if (diff <= 0) {
        throw const MeasurementException('Vòng eo phải lớn hơn vòng cổ');
      }
      final denominator = 1.0324 - 0.19077 * _log10(diff) + 0.15456 * _log10(heightCm);
      percent = 495.0 / denominator - 450.0;
    } else {
      if (hipCm == null || hipCm <= 0) {
        throw const MeasurementException('Cần nhập vòng hông đối với nữ');
      }
      final sum = waistCm + hipCm - neckCm;
      if (sum <= 0) {
        throw const MeasurementException('Tổng vòng eo và vòng hông phải lớn hơn vòng cổ');
      }
      final denominator = 1.29579 - 0.35004 * _log10(sum) + 0.22100 * _log10(heightCm);
      percent = 495.0 / denominator - 450.0;
    }

    return _buildBodyFat(
      percent: percent,
      gender: gender,
      weightKg: weightKg,
      method: BodyFatMethod.usNavy,
    );
  }

  /// Công thức Deurenberg (1991): chỉ là ước lượng nhanh, sai số có thể lớn.
  static BodyFatResult calculateDeurenbergBodyFat({
    required double bmi,
    required int age,
    required Gender gender,
    required double weightKg,
  }) {
    _requirePositive({'BMI': bmi, 'Tuổi': age.toDouble(), 'Cân nặng': weightKg});

    final sex = gender == Gender.male ? 1.0 : 0.0;
    final percent = 1.20 * bmi + 0.23 * age - 10.8 * sex - 5.4;

    return _buildBodyFat(
      percent: percent,
      gender: gender,
      weightKg: weightKg,
      method: BodyFatMethod.deurenberg,
    );
  }

  /// Chỉ số vòng eo / chiều cao. Ngưỡng tham khảo, không phải chẩn đoán.
  static WhtrResult calculateWhtr({required double waistCm, required double heightCm}) {
    _requirePositive({'Vòng eo': waistCm, 'Chiều cao': heightCm});

    final ratio = _round(waistCm / heightCm, 2);
    final String assessment;
    if (ratio < 0.5) {
      assessment = 'Trong ngưỡng khuyến cáo (dưới 0.5)';
    } else if (ratio < 0.6) {
      assessment = 'Tăng nguy cơ (0.5 – 0.59)';
    } else {
      assessment = 'Nguy cơ cao (từ 0.6)';
    }
    return WhtrResult(ratio: ratio, assessment: assessment);
  }

  /// BMR theo Mifflin-St Jeor.
  static int calculateBmr({
    required Gender gender,
    required double weightKg,
    required double heightCm,
    required int age,
  }) {
    _requirePositive({'Cân nặng': weightKg, 'Chiều cao': heightCm, 'Tuổi': age.toDouble()});

    final base = 10.0 * weightKg + 6.25 * heightCm - 5.0 * age;
    return (gender == Gender.male ? base + 5.0 : base - 161.0).round();
  }

  static BodyFatResult _buildBodyFat({
    required double percent,
    required Gender gender,
    required double weightKg,
    required BodyFatMethod method,
  }) {
    if (!percent.isFinite || percent < 2 || percent > 60) {
      throw const MeasurementException(
        'Kết quả tỷ lệ mỡ nằm ngoài khoảng hợp lý (2–60%). Hãy kiểm tra lại các số đo.',
      );
    }

    final pct = _round(percent, 1);
    final fat = _round(weightKg * pct / 100.0, 1);
    final lean = _round(weightKg - fat, 1);
    final category = _categorizeBodyFat(gender, pct);

    return BodyFatResult(
      percentage: pct,
      fatMassKg: fat,
      leanMassKg: lean,
      category: category,
      label: _bodyFatLabel(category),
      method: method,
    );
  }

  static BodyFatCategory _categorizeBodyFat(Gender gender, double pct) {
    if (gender == Gender.male) {
      if (pct < 6) return BodyFatCategory.essential;
      if (pct < 14) return BodyFatCategory.athletes;
      if (pct < 18) return BodyFatCategory.fitness;
      if (pct < 25) return BodyFatCategory.average;
      return BodyFatCategory.obese;
    } else {
      if (pct < 14) return BodyFatCategory.essential;
      if (pct < 21) return BodyFatCategory.athletes;
      if (pct < 25) return BodyFatCategory.fitness;
      if (pct < 32) return BodyFatCategory.average;
      return BodyFatCategory.obese;
    }
  }

  static String _bodyFatLabel(BodyFatCategory c) {
    switch (c) {
      case BodyFatCategory.essential:
        return 'Thiết yếu (rất thấp)';
      case BodyFatCategory.athletes:
        return 'Vận động viên';
      case BodyFatCategory.fitness:
        return 'Săn chắc (fitness)';
      case BodyFatCategory.average:
        return 'Trung bình';
      case BodyFatCategory.obese:
        return 'Cao / béo phì';
    }
  }
}
