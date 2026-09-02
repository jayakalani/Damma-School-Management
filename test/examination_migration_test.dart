import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:damma_school_management_system/core/database/database_schema.dart';

void main() {
  test('migrates legacy batch-linked examinations to school-wide schema', () async {
    sqfliteFfiInit();
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE students (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              full_name TEXT NOT NULL,
              name_with_initials TEXT NOT NULL,
              joined_date TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'student',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE batch_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              batch_id INTEGER NOT NULL,
              academic_year INTEGER NOT NULL,
              grade TEXT NOT NULL,
              started_date TEXT NOT NULL,
              is_current INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE examinations (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              batch_history_id INTEGER NOT NULL,
              examination_name TEXT NOT NULL,
              examination_date TEXT NOT NULL,
              total_marks REAL NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (batch_history_id) REFERENCES batch_history(id)
            )
          ''');
          await db.execute('''
            CREATE TABLE exam_results (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              examination_id INTEGER NOT NULL,
              student_id INTEGER NOT NULL,
              attendance_status TEXT NOT NULL,
              marks REAL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (examination_id) REFERENCES examinations(id),
              FOREIGN KEY (student_id) REFERENCES students(id)
            )
          ''');
          await db.insert('batch_history', {
            'batch_id': 1,
            'academic_year': 2026,
            'grade': 'Grade 1',
            'started_date': '2026-01-01',
            'is_current': 1,
            'created_at': '2026-01-01',
            'updated_at': '2026-01-01',
          });
          await db.insert('students', {
            'full_name': 'Test Student',
            'name_with_initials': 'T. S.',
            'joined_date': '2026-01-01',
            'status': 'student',
            'created_at': '2026-01-01',
            'updated_at': '2026-01-01',
          });
          await db.insert('examinations', {
            'batch_history_id': 1,
            'examination_name': 'Term 1',
            'examination_date': '2026-03-01',
            'total_marks': 100,
            'created_at': '2026-01-01',
            'updated_at': '2026-01-01',
          });
          await db.insert('exam_results', {
            'examination_id': 1,
            'student_id': 1,
            'attendance_status': 'present',
            'marks': 88,
            'created_at': '2026-01-01',
            'updated_at': '2026-01-01',
          });
        },
      ),
    );

    await DatabaseSchema.onUpgrade(database, 4, 5);

    final columns = await database.rawQuery('PRAGMA table_info(examinations)');
    expect(
      columns.any((row) => row['name'] == 'batch_history_id'),
      isFalse,
    );
    final exams = await database.query('examinations');
    expect(exams, hasLength(1));
    expect(exams.single['examination_name'], 'Term 1');
    final results = await database.query('exam_results');
    expect(results, hasLength(1));
    expect(results.single['marks'], 88);

    await database.close();
  });
}
