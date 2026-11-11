import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'body_composition_calculator.dart';

class MeasurementRecord {
  final int? id;
  final DateTime recordedAt;
  final Gender gender;
  final double heightCm;
  final double weightKg;
  final int age;
  final double? neckCm;
  final double? waistCm;
  final double? hipCm;
  final double bmi;
  final String bmiLabel;
  final double bodyFatPercentage;
  final String bodyFatLabel;
  final double fatMassKg;
  final double leanMassKg;
  final double bmrKcal;
  final BodyFatMethod method;

  const MeasurementRecord({
    this.id,
    required this.recordedAt,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.age,
    this.neckCm,
    this.waistCm,
    this.hipCm,
    required this.bmi,
    required this.bmiLabel,
    required this.bodyFatPercentage,
    required this.bodyFatLabel,
    required this.fatMassKg,
    required this.leanMassKg,
    required this.bmrKcal,
    required this.method,
  });

  factory MeasurementRecord.create({
    required MeasurementInput input,
    required MeasurementSnapshot result,
    required DateTime at,
  }) {
    return MeasurementRecord(
      recordedAt: at,
      gender: input.gender,
      heightCm: input.heightCm,
      weightKg: input.weightKg,
      age: input.age,
      neckCm: input.neckCm,
      waistCm: input.waistCm,
      hipCm: input.hipCm,
      bmi: result.bmi.bmi,
      bmiLabel: result.bmi.label,
      bodyFatPercentage: result.bodyFat.percentage,
      bodyFatLabel: result.bodyFat.label,
      fatMassKg: result.bodyFat.fatMassKg,
      leanMassKg: result.bodyFat.leanMassKg,
      bmrKcal: result.bmrKcal.toDouble(),
      method: input.method,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'recorded_at': recordedAt.toIso8601String(),
      'gender': gender.name,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'age': age,
      'neck_cm': neckCm,
      'waist_cm': waistCm,
      'hip_cm': hipCm,
      'bmi': bmi,
      'bmi_label': bmiLabel,
      'body_fat_percentage': bodyFatPercentage,
      'body_fat_label': bodyFatLabel,
      'fat_mass_kg': fatMassKg,
      'lean_mass_kg': leanMassKg,
      'bmr_kcal': bmrKcal,
      'method': method.name,
    };
  }

  factory MeasurementRecord.fromMap(Map<String, dynamic> map) {
    return MeasurementRecord(
      id: map['id'] as int?,
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      gender: map['gender'] == 'female' ? Gender.female : Gender.male,
      heightCm: (map['height_cm'] as num).toDouble(),
      weightKg: (map['weight_kg'] as num).toDouble(),
      age: map['age'] as int,
      neckCm: (map['neck_cm'] as num?)?.toDouble(),
      waistCm: (map['waist_cm'] as num?)?.toDouble(),
      hipCm: (map['hip_cm'] as num?)?.toDouble(),
      bmi: (map['bmi'] as num).toDouble(),
      bmiLabel: map['bmi_label'] as String,
      bodyFatPercentage: (map['body_fat_percentage'] as num).toDouble(),
      bodyFatLabel: map['body_fat_label'] as String,
      fatMassKg: (map['fat_mass_kg'] as num).toDouble(),
      leanMassKg: (map['lean_mass_kg'] as num).toDouble(),
      bmrKcal: (map['bmr_kcal'] as num).toDouble(),
      method: map['method'] == 'deurenberg' ? BodyFatMethod.deurenberg : BodyFatMethod.usNavy,
    );
  }
}

/// Thay đổi giữa bản ghi đầu và bản ghi cuối trong một khoảng thời gian.
class ProgressDelta {
  final double weightKg;
  final double bodyFatPct;
  final double leanMassKg;

  const ProgressDelta({required this.weightKg, required this.bodyFatPct, required this.leanMassKg});

  static const ProgressDelta zero = ProgressDelta(weightKg: 0, bodyFatPct: 0, leanMassKg: 0);

  factory ProgressDelta.between(List<MeasurementRecord> records) {
    if (records.length < 2) return zero;
    final first = records.first;
    final last = records.last;
    return ProgressDelta(
      weightKg: _r1(last.weightKg - first.weightKg),
      bodyFatPct: _r1(last.bodyFatPercentage - first.bodyFatPercentage),
      leanMassKg: _r1(last.leanMassKg - first.leanMassKg),
    );
  }

  static double _r1(double v) => v.abs() < 0.05 ? 0.0 : double.parse(v.toStringAsFixed(1));
}

class LocalDatabaseHelper {
  static final LocalDatabaseHelper instance = LocalDatabaseHelper._();
  LocalDatabaseHelper._();

  static const String _dbName = 'body_composition_tracker.db';
  static const int _dbVersion = 1;
  static const String _table = 'measurements';

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            recorded_at TEXT NOT NULL,
            gender TEXT NOT NULL,
            height_cm REAL NOT NULL,
            weight_kg REAL NOT NULL,
            age INTEGER NOT NULL,
            neck_cm REAL,
            waist_cm REAL,
            hip_cm REAL,
            bmi REAL NOT NULL,
            bmi_label TEXT NOT NULL,
            body_fat_percentage REAL NOT NULL,
            body_fat_label TEXT NOT NULL,
            fat_mass_kg REAL NOT NULL,
            lean_mass_kg REAL NOT NULL,
            bmr_kcal REAL NOT NULL,
            method TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_measurements_date ON $_table (recorded_at)');
      },
    );
  }

  Future<int> insertRecord(MeasurementRecord record) async {
    final db = await database;
    return db.insert(_table, record.toMap());
  }

  /// Trả về theo thứ tự thời gian tăng dần. [days] = null nghĩa là tất cả.
  Future<List<MeasurementRecord>> getRecords({int? days}) async {
    final db = await database;
    String? where;
    List<Object?>? args;
    if (days != null) {
      where = 'recorded_at >= ?';
      args = [DateTime.now().subtract(Duration(days: days)).toIso8601String()];
    }
    final rows = await db.query(_table, where: where, whereArgs: args, orderBy: 'recorded_at ASC');
    return rows.map((row) => MeasurementRecord.fromMap(row)).toList();
  }

  Future<int> deleteRecord(int id) async {
    final db = await database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
