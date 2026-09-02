import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:damma_school_management_system/core/batches/batch_repository.dart';
import 'package:damma_school_management_system/core/database/app_database.dart';
import 'package:damma_school_management_system/core/examinations/examination_repository.dart';
import 'package:damma_school_management_system/core/users/user_repository.dart';

Future<int> _createStaff(Database connection, int adminId) {
  return UserRepository().createStaff(
    database: connection,
    adminId: adminId,
    fullName: 'Staff User',
    username: 'staff.exam.${DateTime.now().microsecondsSinceEpoch}',
    password: 'StaffPassword123!',
  );
}

void main() {
  test(
    'records marks and calculates aggregates and tied rankings dynamically',
    () async {
      sqfliteFfiInit();
      final database = AppDatabase(factory: databaseFactoryFfi);
      final connection = await database.openAt(inMemoryDatabasePath);
      final adminId = (await connection.query('users')).single['id']! as int;
      final staffId = await _createStaff(connection, adminId);
      final batches = BatchRepository();
      final examinations = ExaminationRepository();
      await batches.createBatch(
        database: connection,
        adminId: staffId,
        name: 'Exam Batch',
        startingYear: 2026,
        startingGrade: 'Grade 1',
      );
      final batchId = (await connection.query('batches')).single['id']! as int;
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
        adminId: staffId,
        name: 'Term 1',
        date: '2026-03-01',
        totalMarks: 100,
      );

      await examinations.saveResults(
        database: connection,
        adminId: adminId,
        examinationId: examId,
        batchId: batchId,
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
        batchId: batchId,
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

  test(
    'lists current batch students for exams after promotion and accepts Ab',
    () async {
      sqfliteFfiInit();
      final database = AppDatabase(factory: databaseFactoryFfi);
      final connection = await database.openAt(inMemoryDatabasePath);
      final adminId = (await connection.query('users')).single['id']! as int;
      final staffId = await _createStaff(connection, adminId);
      final batches = BatchRepository();
      final examinations = ExaminationRepository();
      await batches.createBatch(
        database: connection,
        adminId: staffId,
        name: 'Promote Exam Batch',
        startingYear: 2026,
        startingGrade: 'Grade 1',
      );
      final batchId = (await connection.query('batches')).single['id']! as int;
      final studentId = await connection.insert('students', {
        'full_name': 'Roster Student',
        'name_with_initials': 'R. S.',
        'joined_date': '2026-01-01',
        'status': 'student',
        'created_at': '2026-01-01',
        'updated_at': '2026-01-01',
      });
      await batches.addStudentToBatch(
        database: connection,
        adminId: adminId,
        batchId: batchId,
        studentId: studentId,
      );
      await batches.promoteBatch(
        database: connection,
        adminId: adminId,
        batchId: batchId,
        academicYear: 2027,
        grade: 'Grade 2',
      );
      // Re-attach student to the current year so they remain current members.
      await batches.addStudentToBatch(
        database: connection,
        adminId: adminId,
        batchId: batchId,
        studentId: studentId,
      );
      final examId = await examinations.createExamination(
        database: connection,
        adminId: staffId,
        name: 'After Promote',
        date: '2027-03-01',
        totalMarks: 100,
      );

      final details = await examinations.getDetails(
        database: connection,
        adminId: adminId,
        examinationId: examId,
        batchId: batchId,
      );
      expect(details.students, hasLength(1));
      expect(details.students.single['full_name'], 'Roster Student');

      await examinations.saveResults(
        database: connection,
        adminId: adminId,
        examinationId: examId,
        batchId: batchId,
        results: [
          ExamMarkInput(studentId: studentId, attendanceStatus: 'absent'),
        ],
      );
      final saved = await examinations.getDetails(
        database: connection,
        adminId: adminId,
        examinationId: examId,
        batchId: batchId,
      );
      expect(saved.analytics.absentCount, 1);
      expect(saved.analytics.presentCount, 0);

      final parsedAbsent = ExaminationRepository.parseMarkEntry('Ab');
      final parsedPresent = ExaminationRepository.parseMarkEntry('88');
      expect(parsedAbsent?.absent, isTrue);
      expect(parsedPresent?.marks, 88);
      await database.close();
    },
  );

  test('creates school-wide exams and lists only active batches', () async {
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
      adminId: staffId,
      name: 'Active Batch',
      startingYear: 2026,
      startingGrade: 'Grade 1',
    );
    await batches.createBatch(
      database: connection,
      adminId: staffId,
      name: 'Inactive Batch',
      startingYear: 2026,
      startingGrade: 'Grade 2',
    );
    final inactiveId =
        (await connection.query(
              'batches',
              where: 'batch_name = ?',
              whereArgs: ['Inactive Batch'],
            )).single['id']!
            as int;
    await batches.setBatchActive(
      database: connection,
      adminId: adminId,
      batchId: inactiveId,
      active: false,
    );

    final examId = await examinations.createExamination(
      database: connection,
      adminId: staffId,
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
    expect(listed.single.containsKey('batch_history_id'), isFalse);

    final active = await examinations.listActiveBatches(
      database: connection,
      adminId: staffId,
    );
    expect(active, hasLength(1));
    expect(active.single['batch_name'], 'Active Batch');

    await database.close();
  });
}
