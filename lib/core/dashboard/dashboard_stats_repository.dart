import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class StaffDashboardStats {
  const StaffDashboardStats({
    required this.activeTeachers,
    required this.activeBatches,
    required this.enrolledStudents,
    required this.pastPupils,
    required this.examinations,
    required this.competitions,
    required this.legacyBatches,
    required this.historicalPastPupils,
    required this.inactiveStudents,
  });

  final int activeTeachers;
  final int activeBatches;
  final int enrolledStudents;
  final int pastPupils;
  final int examinations;
  final int competitions;
  final int legacyBatches;
  final int historicalPastPupils;
  final int inactiveStudents;

  static const empty = StaffDashboardStats(
    activeTeachers: 0,
    activeBatches: 0,
    enrolledStudents: 0,
    pastPupils: 0,
    examinations: 0,
    competitions: 0,
    legacyBatches: 0,
    historicalPastPupils: 0,
    inactiveStudents: 0,
  );
}

class DashboardStatsRepository {
  const DashboardStatsRepository();

  Future<StaffDashboardStats> loadStaffStats(Database database) async {
    Future<int> count(String sql) async {
      final rows = await database.rawQuery(sql);
      final value = rows.first.values.first;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? 0;
    }

    final results = await Future.wait([
      count("SELECT COUNT(*) FROM teachers WHERE status = 'active'"),
      count('SELECT COUNT(*) FROM batches WHERE is_active = 1'),
      count(
        "SELECT COUNT(*) FROM students WHERE status = 'student' AND is_active = 1",
      ),
      count("SELECT COUNT(*) FROM students WHERE status = 'past_pupil'"),
      count('SELECT COUNT(*) FROM examinations'),
      count('SELECT COUNT(*) FROM competitions'),
      count('SELECT COUNT(*) FROM past_pupil_batches'),
      count('SELECT COUNT(*) FROM historical_past_pupils'),
      count(
        "SELECT COUNT(*) FROM students WHERE status = 'student' AND is_active = 0",
      ),
    ]);

    return StaffDashboardStats(
      activeTeachers: results[0],
      activeBatches: results[1],
      enrolledStudents: results[2],
      pastPupils: results[3] + results[7],
      examinations: results[4],
      competitions: results[5],
      legacyBatches: results[6],
      historicalPastPupils: results[7],
      inactiveStudents: results[8],
    );
  }
}

String formatCount(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
