import 'package:bmi_bodyfat_tracker/body_composition_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BMI', () {
    test('70 kg / 175 cm = 22.9, bình thường theo chuẩn Châu Á', () {
      final r = BodyCompositionCalculator.calculateBmi(weightKg: 70, heightCm: 175);
      expect(r.bmi, 22.9);
      expect(r.category, BmiCategory.normal);
    });

    test('BMI đúng 23.0 là thừa cân theo chuẩn Châu Á', () {
      final r = BodyCompositionCalculator.calculateBmi(weightKg: 23, heightCm: 100);
      expect(r.bmi, 23.0);
      expect(r.category, BmiCategory.overweight);
    });

    test('80 kg / 170 cm: béo phì độ I theo chuẩn Châu Á, thừa cân theo WHO', () {
      final asian = BodyCompositionCalculator.calculateBmi(weightKg: 80, heightCm: 170);
      expect(asian.category, BmiCategory.obeseClass1);

      final who = BodyCompositionCalculator.calculateBmi(
        weightKg: 80,
        heightCm: 170,
        standard: BmiStandard.who,
      );
      expect(who.category, BmiCategory.overweight);
    });

    test('cân nặng <= 0 ném MeasurementException', () {
      expect(
        () => BodyCompositionCalculator.calculateBmi(weightKg: 0, heightCm: 170),
        throwsA(isA<MeasurementException>()),
      );
    });
  });

  group('Tỷ lệ mỡ', () {
    test('US Navy nam 170 cm, cổ 37, eo 78 cm xấp xỉ 12.8%', () {
      final r = BodyCompositionCalculator.calculateNavyBodyFat(
        gender: Gender.male,
        heightCm: 170,
        weightKg: 65,
        neckCm: 37,
        waistCm: 78,
      );
      expect(r.percentage, closeTo(12.8, 0.1));
      expect(r.category, BodyFatCategory.athletes);
      expect(r.method, BodyFatMethod.usNavy);
    });

    test('US Navy: eo nhỏ hơn hoặc bằng cổ thì báo lỗi', () {
      expect(
        () => BodyCompositionCalculator.calculateNavyBodyFat(
          gender: Gender.male,
          heightCm: 170,
          weightKg: 65,
          neckCm: 37,
          waistCm: 37,
        ),
        throwsA(isA<MeasurementException>()),
      );
    });

    test('US Navy nữ thiếu vòng hông thì báo lỗi', () {
      expect(
        () => BodyCompositionCalculator.calculateNavyBodyFat(
          gender: Gender.female,
          heightCm: 165,
          weightKg: 60,
          neckCm: 32,
          waistCm: 70,
        ),
        throwsA(isA<MeasurementException>()),
      );
    });

    test('Deurenberg nam BMI 22, 30 tuổi xấp xỉ 17.1%', () {
      final r = BodyCompositionCalculator.calculateDeurenbergBodyFat(
        bmi: 22,
        age: 30,
        gender: Gender.male,
        weightKg: 70,
      );
      expect(r.percentage, closeTo(17.1, 0.05));
      expect(r.method, BodyFatMethod.deurenberg);
    });
  });

  group('BMR (Mifflin-St Jeor)', () {
    test('nam 70 kg, 175 cm, 30 tuổi = 1649 kcal', () {
      final bmr = BodyCompositionCalculator.calculateBmr(
        gender: Gender.male,
        weightKg: 70,
        heightCm: 175,
        age: 30,
      );
      expect(bmr, 1649);
    });

    test('nữ 60 kg, 165 cm, 25 tuổi = 1345 kcal', () {
      final bmr = BodyCompositionCalculator.calculateBmr(
        gender: Gender.female,
        weightKg: 60,
        heightCm: 165,
        age: 25,
      );
      expect(bmr, 1345);
    });
  });

  group('WHtR', () {
    test('vòng eo 78 / cao 170 = 0.46, trong ngưỡng khuyến cáo', () {
      final r = BodyCompositionCalculator.calculateWhtr(waistCm: 78, heightCm: 170);
      expect(r.ratio, 0.46);
      expect(r.assessment, startsWith('Trong ngưỡng'));
    });
  });

  group('compute', () {
    test('US Navy nữ có WHtR, tỷ lệ mỡ nằm trong khoảng hợp lý', () {
      final s = BodyCompositionCalculator.compute(
        const MeasurementInput(
          gender: Gender.female,
          method: BodyFatMethod.usNavy,
          bmiStandard: BmiStandard.asian,
          heightCm: 165,
          weightKg: 60,
          age: 25,
          neckCm: 32,
          waistCm: 70,
          hipCm: 95,
        ),
      );
      expect(s.whtr, isNotNull);
      final pct = s.bodyFat.percentage;
      expect(pct >= 2 && pct <= 60, isTrue);
    });

    test('Deurenberg không có WHtR', () {
      final s = BodyCompositionCalculator.compute(
        const MeasurementInput(
          gender: Gender.male,
          method: BodyFatMethod.deurenberg,
          bmiStandard: BmiStandard.asian,
          heightCm: 170,
          weightKg: 65,
          age: 28,
        ),
      );
      expect(s.whtr, isNull);
    });
  });
}
