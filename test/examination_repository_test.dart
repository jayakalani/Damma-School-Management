import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:damma_school_management_system/core/batches/batch_repository.dart';
import 'package:damma_school_management_system/core/database/app_database.dart';
import 'package:damma_school_management_system/core/examinations/examination_repository.dart';
import 'package:damma_school_management_system/core/users/user_repository.dart';

void main() {
  test(
    'records marks and calculates aggregates and tied rankings dynamically',
    () async {
      sqfliteFfiInit();
      final database = AppDatabase(factory: databaseFactoryFfi);
      final connection = await database.openAt(inMemoryDatabasePath);
      final adminId = (await connection.query('users')).single['id']! as int;
      final batches = BatchRepository();
      final examinations = ExaminationRepository();
      await batches.createBatch(
        database: connection,
        adminId: adminId,
        name: 'Exam Batch',
        startingYear: 2026,
        startingGrade: 'Grade 1',
      );
      final batchId = (await connection.query('batches')).single['id']! as int;
      final historyId =
          (await connection.query('batch_history')).single['id']! as int;
      final studentIds = <int>[];
      for (final name in ['First', 'Second', 'Third', 'Fourth']) {
        final id = await connection.insert('students', {
          'full_name': '$name Student',
          'name_with_initials': '$name S.',
          'joined_date': '2026-01-01',
          'status': 'student',
          'created_at': '2026-01-01',
          'updated_at': '2026-01-01',
        });
        studentIds.add(id);
        await batches.addStudentToBatch(
          database: connection,
          adminId: adminId,
          batchId: batchId,
          studentId: id,
        );
      }
      final examId = await examinations.createExamination(
        database: connection,
        adminId: adminId,
        batchHistoryId: historyId,
        name: 'Term 1',
        date: '2026-03-01',
        totalMarks: 100,
      );

      await examinations.saveResults(
        database: connection,
        adminId: adminId,
        examinationId: examId,
        results: [
          ExamMarkInput(
            studentId: studentIds[0],
            attendanceStatus: 'present',
            marks: 90,
          ),
          ExamMarkInput(
            studentId: studentIds[1],
            attendanceStatus: 'present',
            marks: 90,
          ),
          ExamMarkInput(
            studentId: studentIds[2],
            attendanceStatus: 'present',
            marks: 80,
          ),
          ExamMarkInput(studentId: studentIds[3], attendanceStatus: 'absent'),
        ],
      );

      final details = await examinations.getDetails(
        database: connection,
        adminId: adminId,
        examinationId: examId,
      );
      expect(details.examination['batch_id'], batchId);
      expect(details.examination['academic_year'], 2026);
      expect(details.analytics.presentCount, 3);
      expect(details.analytics.absentCount, 1);
      expect(details.analytics.highest, 90);
      expect(details.analytics.lowest, 80);
      expect(details.analytics.average, closeTo(86.6666667, 0.0001));
      expect(details.analytics.rankings.map((item) => item.rank), [1, 1, 3]);
      expect(details.analytics.rankings.map((item) => item.studentName), [
        'First Student',
        'Second Student',
        'Third Student',
      ]);

      final absent = await connection.query(
        'exam_results',
        where: 'student_id = ?',
        whereArgs: [studentIds[3]],
      );
      expect(absent.single['marks'], isNull);
      expect(absent.single['attendance_status'], 'absent');
      await database.close();
    },
  );

  test('allows active staff to list and create examinations', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final users = UserRepository();
    final batches = BatchRepository();
    final examinations = ExaminationRepository();
    final adminId = (await connection.query('users')).single['id']! as int;
    final staffId = await users.createStaff(
      database: connection,
      adminId: adminId,
      fullName: 'Staff User',
      username: 'staff.exam',
      password: 'StaffPassword123!',
    );

    await batches.createBatch(
      database: connection,
      adminId: adminId,
      name: 'Staff Exam Batch',
      startingYear: 2026,
      startingGrade: 'Grade 1',
    );
    final historyId =
        (await connection.query('batch_history')).single['id']! as int;

    final examId = await examinations.createExamination(
      database: connection,
      adminId: staffId,
      batchHistoryId: historyId,
      name: 'Staff Term 1',
      date: '2026-04-01',
      totalMarks: 50,
    );

    final listed = await examinations.listExaminations(
      database: connection,
      adminId: staffId,
    );
    expect(listed.single['id'], examId);
    expect(listed.single['examination_name'], 'Staff Term 1');

    await database.close();
  });
}
