import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:damma_school_management_system/core/batches/batch_repository.dart';
import 'package:damma_school_management_system/core/database/app_database.dart';
import 'package:damma_school_management_system/core/past_pupils/past_pupil_repository.dart';
import 'package:damma_school_management_system/core/students/student_repository.dart';

void main() {
  test('converts a student without purging exams or batch history', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final adminId = (await connection.query('users')).single['id']! as int;
    final students = StudentRepository();
    final batches = BatchRepository();
    final studentId = await students.createStudent(
      database: connection,
      adminId: adminId,
      details: {
        'full_name': 'A Student',
        'name_with_initials': 'A. Student',
        'joined_date': '2026-01-01',
      },
    );
    await batches.createBatch(
      database: connection,
      adminId: adminId,
      name: 'Student Batch',
      startingYear: 2026,
      startingGrade: 'Grade 1',
    );
    final batchId = (await connection.query('batches')).single['id']! as int;
    await batches.addStudentToBatch(
      database: connection,
      adminId: adminId,
      batchId: batchId,
      studentId: studentId,
    );
    final historyId =
        (await connection.query('batch_history')).single['id']! as int;
    final examinationId = await connection.insert('examinations', {
      'batch_history_id': historyId,
      'examination_name': 'Term 1',
      'examination_date': '2026-03-01',
      'total_marks': 100,
      'created_at': '2026-03-01',
      'updated_at': '2026-03-01',
    });
    await connection.insert('exam_results', {
      'examination_id': examinationId,
      'student_id': studentId,
      'attendance_status': 'present',
      'marks': 80,
      'created_at': '2026-03-01',
      'updated_at': '2026-03-01',
    });

    await students.convertToPastPupil(
      database: connection,
      adminId: adminId,
      studentId: studentId,
    );

    expect(
      (await connection.query(
        'students',
        where: 'id = ?',
        whereArgs: [studentId],
      )).single['status'],
      'past_pupil',
    );
    expect(
      (await connection.query(
        'student_batch_history',
        where: 'student_id = ?',
        whereArgs: [studentId],
      )).single['is_current'],
      0,
    );
    expect(
      await connection.query(
        'examinations',
        where: 'id = ?',
        whereArgs: [examinationId],
      ),
      hasLength(1),
    );
    expect(
      await connection.query(
        'exam_results',
        where: 'student_id = ?',
        whereArgs: [studentId],
      ),
      hasLength(1),
    );
    await database.close();
  });

  test(
    'bulk conversion updates current batch students in one operation',
    () async {
      sqfliteFfiInit();
      final database = AppDatabase(factory: databaseFactoryFfi);
      final connection = await database.openAt(inMemoryDatabasePath);
      final adminId = (await connection.query('users')).single['id']! as int;
      final students = StudentRepository();
      final batches = BatchRepository();
      final first = await students.createStudent(
        database: connection,
        adminId: adminId,
        details: {
          'full_name': 'First Student',
          'name_with_initials': 'F. Student',
          'joined_date': '2026-01-01',
        },
      );
      final second = await students.createStudent(
        database: connection,
        adminId: adminId,
        details: {
          'full_name': 'Second Student',
          'name_with_initials': 'S. Student',
          'joined_date': '2026-01-01',
        },
      );
      await batches.createBatch(
        database: connection,
        adminId: adminId,
        name: 'Bulk Batch',
        startingYear: 2026,
        startingGrade: 'Grade 1',
      );
      final batchId = (await connection.query('batches')).single['id']! as int;
      await batches.addStudentToBatch(
        database: connection,
        adminId: adminId,
        batchId: batchId,
        studentId: first,
      );
      await batches.addStudentToBatch(
        database: connection,
        adminId: adminId,
        batchId: batchId,
        studentId: second,
      );

      expect(
        await students.bulkConvertBatchToPastPupils(
          database: connection,
          adminId: adminId,
          batchId: batchId,
        ),
        2,
      );
      expect(
        await connection.query(
          'students',
          where: 'status = ?',
          whereArgs: ['past_pupil'],
        ),
        hasLength(2),
      );
      expect(
        await connection.query(
          'student_batch_history',
          where: 'batch_id = ? AND is_current = 1',
          whereArgs: [batchId],
        ),
        isEmpty,
      );
      expect(
        await connection.query(
          'student_batch_history',
          where: 'batch_id = ?',
          whereArgs: [batchId],
        ),
        hasLength(2),
      );
      await database.close();
    },
  );

  test('adds legacy alumni to a historical past pupil batch', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final adminId = (await connection.query('users')).single['id']! as int;
    final repository = PastPupilRepository();
    final batchId = await repository.createBatch(
      database: connection,
      adminId: adminId,
      name: 'Alumni 1998',
      year: 1998,
      notes: 'Paper register',
    );
    await repository.addPupil(
      database: connection,
      adminId: adminId,
      batchId: batchId,
      details: {
        'full_name': 'Legacy Student',
        'name_with_initials': 'L. Student',
        'notes': 'Transferred record',
      },
    );
    expect(
      await repository.listPupils(
        database: connection,
        adminId: adminId,
        batchId: batchId,
      ),
      hasLength(1),
    );
    await database.close();
  });
}
