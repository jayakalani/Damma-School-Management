import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:damma_school_management_system/core/batches/batch_repository.dart';
import 'package:damma_school_management_system/core/database/app_database.dart';
import 'package:damma_school_management_system/core/users/user_repository.dart';

Future<int> _createStaff(Database connection, int adminId) {
  return UserRepository().createStaff(
    database: connection,
    adminId: adminId,
    fullName: 'Staff User',
    username: 'staff.batch.${DateTime.now().microsecondsSinceEpoch}',
    password: 'StaffPassword123!',
  );
}

void main() {
  test('creates batch details and promotes without losing history', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final adminId = (await connection.query('users')).single['id']! as int;
    final staffId = await _createStaff(connection, adminId);
    final repository = BatchRepository();

    await repository.createBatch(
      database: connection,
      adminId: staffId,
      name: 'Class of 2026',
      startingYear: 2026,
      startingGrade: 'Grade 1',
    );

    final created = await connection.query('batches');
    final batchId = created.single['id']! as int;
    final initialHistory = await connection.query('batch_history');
    expect(initialHistory, hasLength(1));
    expect(initialHistory.single['academic_year'], 2026);
    expect(initialHistory.single['grade'], 'Grade 1');

    final details = await repository.getBatchDetails(
      database: connection,
      adminId: adminId,
      batchId: batchId,
    );
    expect(details.batch['batch_name'], 'Class of 2026');
    expect(details.history, hasLength(1));

    await repository.promoteBatch(
      database: connection,
      adminId: adminId,
      batchId: batchId,
      academicYear: 2027,
      grade: 'Grade 2',
    );

    final history = await connection.query(
      'batch_history',
      where: 'batch_id = ?',
      whereArgs: [batchId],
      orderBy: 'id',
    );
    expect(history, hasLength(2));
    expect(history[0]['academic_year'], 2026);
    expect(history[0]['grade'], 'Grade 1');
    expect(history[0]['is_current'], 0);
    expect(history[1]['academic_year'], 2027);
    expect(history[1]['grade'], 'Grade 2');
    expect(history[1]['is_current'], 1);

    final current = await connection.query(
      'batch_history',
      where: 'batch_id = ? AND is_current = 1',
      whereArgs: [batchId],
    );
    expect(current, hasLength(1));
    await database.close();
  });

  test(
    'preserves teacher assignment and student membership timelines',
    () async {
      sqfliteFfiInit();
      final database = AppDatabase(factory: databaseFactoryFfi);
      final connection = await database.openAt(inMemoryDatabasePath);
      final adminId = (await connection.query('users')).single['id']! as int;
      final staffId = await _createStaff(connection, adminId);
      final repository = BatchRepository();

      final batchHistoryId = await repository.createBatch(
        database: connection,
        adminId: staffId,
        name: 'Timeline Batch',
        startingYear: 2026,
        startingGrade: 'Grade 1',
      );
      final batchId = (await connection.query('batches')).single['id']! as int;
      final teacherOne = await connection.insert('teachers', {
        'full_name': 'Teacher One',
        'name_with_initials': 'T. One',
        'registered_date': '2026-01-01',
        'status': 'active',
        'created_at': '2026-01-01',
        'updated_at': '2026-01-01',
      });
      final teacherTwo = await connection.insert('teachers', {
        'full_name': 'Teacher Two',
        'name_with_initials': 'T. Two',
        'registered_date': '2026-01-01',
        'status': 'active',
        'created_at': '2026-01-01',
        'updated_at': '2026-01-01',
      });
      await repository.assignClassTeacher(
        database: connection,
        adminId: adminId,
        batchId: batchId,
        teacherId: teacherOne,
      );
      await repository.assignClassTeacher(
        database: connection,
        adminId: adminId,
        batchId: batchId,
        teacherId: teacherTwo,
      );

      final assignments = await connection.query(
        'batch_teacher_history',
        where: 'batch_history_id = ?',
        whereArgs: [batchHistoryId],
        orderBy: 'id',
      );
      expect(assignments, hasLength(2));
      expect(assignments[0]['is_current'], 0);
      expect(assignments[0]['assigned_date'], isNotNull);
      expect(assignments[0]['removed_date'], isNotNull);
      expect(assignments[1]['teacher_id'], teacherTwo);
      expect(assignments[1]['is_current'], 1);
      expect(assignments[1]['removed_date'], isNull);

      final studentId = await connection.insert('students', {
        'full_name': 'Student One',
        'name_with_initials': 'S. One',
        'joined_date': '2026-01-01',
        'status': 'student',
        'created_at': '2026-01-01',
        'updated_at': '2026-01-01',
      });
      await repository.addStudentToBatch(
        database: connection,
        adminId: adminId,
        batchId: batchId,
        studentId: studentId,
      );
      await repository.promoteBatch(
        database: connection,
        adminId: adminId,
        batchId: batchId,
        academicYear: 2027,
        grade: 'Grade 2',
      );
      await repository.addStudentToBatch(
        database: connection,
        adminId: adminId,
        batchId: batchId,
        studentId: studentId,
      );

      final memberships = await connection.query(
        'student_batch_history',
        where: 'student_id = ?',
        whereArgs: [studentId],
        orderBy: 'id',
      );
      expect(memberships, hasLength(2));
      expect(memberships[0]['batch_history_id'], batchHistoryId);
      expect(memberships[0]['is_current'], 0);
      expect(memberships[0]['left_date'], isNotNull);
      expect(memberships[1]['is_current'], 1);
      expect(memberships[1]['joined_date'], isNotNull);
      await database.close();
    },
  );

  test('allows active staff to manage batches', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final adminId = (await connection.query('users')).single['id']! as int;
    final users = UserRepository();
    final staffId = await users.createStaff(
      database: connection,
      adminId: adminId,
      fullName: 'Staff User',
      username: 'staff.batch',
      password: 'StaffPassword123!',
    );
    final repository = BatchRepository();

    await repository.createBatch(
      database: connection,
      adminId: staffId,
      name: 'Staff Batch',
      startingYear: 2026,
      startingGrade: 'Grade 1',
    );

    final batches = await repository.listBatches(
      database: connection,
      adminId: staffId,
    );
    expect(batches.single['batch_name'], 'Staff Batch');

    await database.close();
  });

  test('rejects admin from creating batches', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final adminId = (await connection.query('users')).single['id']! as int;
    final repository = BatchRepository();

    await expectLater(
      repository.createBatch(
        database: connection,
        adminId: adminId,
        name: 'Admin Batch',
        startingYear: 2026,
        startingGrade: 'Grade 1',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Only an active staff member can create batches.',
        ),
      ),
    );

    await database.close();
  });

  test('updates batch name, starting year, and current grade', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final adminId = (await connection.query('users')).single['id']! as int;
    final staffId = await _createStaff(connection, adminId);
    final repository = BatchRepository();

    await repository.createBatch(
      database: connection,
      adminId: staffId,
      name: 'Original Batch',
      startingYear: 2026,
      startingGrade: 'Grade 1',
    );
    final batchId = (await connection.query('batches')).single['id']! as int;

    await repository.updateBatch(
      database: connection,
      adminId: staffId,
      batchId: batchId,
      name: 'Updated Batch',
      startingYear: 2025,
      grade: 'Grade 2',
    );

    final batch = (await connection.query('batches')).single;
    final history = await connection.query(
      'batch_history',
      where: 'batch_id = ? AND is_current = 1',
      whereArgs: [batchId],
    );

    expect(batch['batch_name'], 'Updated Batch');
    expect(batch['starting_year'], 2025);
    expect(history.single['grade'], 'Grade 2');

    await database.close();
  });
}
