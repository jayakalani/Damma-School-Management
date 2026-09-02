import 'dart:developer' as developer;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseVerifier {
  const DatabaseVerifier._();

  static const tables = <String>[
    'users', 'audit_logs', 'teachers', 'teacher_qualifications', 'batches',
    'batch_history', 'students', 'student_batch_history',
    'batch_teacher_history', 'examinations', 'exam_results',
    'past_pupil_batches', 'historical_past_pupils', 'competitions',
  ];

  static Future<void> verify(Database database) async {
    final foreignKeys = await database.rawQuery('PRAGMA foreign_keys');
    if (foreignKeys.single.values.single != 1) throw StateError('SQLite foreign keys are disabled.');
    final rows = await database.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
    final actual = rows.map((row) => row['name']).toSet();
    final missing = tables.where((table) => !actual.contains(table)).toList();
    if (missing.isNotEmpty) {
      throw StateError('Database tables are incomplete. Missing: ${missing.join(', ')}');
    }
    final admins = await database.query('users', where: 'role = ?', whereArgs: ['admin']);
    if (admins.isEmpty) throw StateError('Default admin was not seeded.');
    assert(() {
      developer.log('Database initialized successfully.');
      developer.log('Foreign keys enabled.');
      developer.log('Tables verified.');
      developer.log('Default admin verified.');
      return true;
    }());
  }
}