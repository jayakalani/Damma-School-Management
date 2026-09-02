import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:damma_school_management_system/core/database/app_database.dart';
import 'package:damma_school_management_system/core/teachers/teacher_repository.dart';
import 'package:damma_school_management_system/core/users/user_repository.dart';

void main() {
  test(
    'creates, searches, updates status, and protects assigned teachers',
    () async {
      sqfliteFfiInit();
      final database = AppDatabase(factory: databaseFactoryFfi);
      final connection = await database.openAt(inMemoryDatabasePath);
      final adminId = (await connection.query('users')).single['id']! as int;
      final repository = TeacherRepository();
      final teacherId = await repository.createTeacher(
        database: connection,
        adminId: adminId,
        details: {
          'full_name': 'Nimal Perera',
          'name_with_initials': 'N. Perera',
          'registered_date': '2026-01-01',
          'status': 'active',
          'bank_name': 'Test Bank',
        },
        qualifications: [
          {
            'qualification': 'B.Ed',
            'institution': 'Test University',
            'completion_year': 2020,
          },
          {'qualification': 'Diploma in ICT'},
        ],
      );

      expect(
        (await repository.searchTeachers(
          database: connection,
          adminId: adminId,
          query: 'Perera',
        )).single['id'],
        teacherId,
      );
      expect(
        (await repository.qualifications(
          database: connection,
          adminId: adminId,
          teacherId: teacherId,
        )),
        hasLength(2),
      );
      await repository.setTeacherStatus(
        database: connection,
        adminId: adminId,
        teacherId: teacherId,
        active: false,
      );
      expect(
        (await repository.searchTeachers(
          database: connection,
          adminId: adminId,
          status: 'inactive',
        )).single['id'],
        teacherId,
      );

      final batchId = await connection.insert('batches', {
        'batch_name': '2026 A',
        'starting_year': 2026,
        'created_at': '2026-01-01',
        'updated_at': '2026-01-01',
      });
      final historyId = await connection.insert('batch_history', {
        'batch_id': batchId,
        'academic_year': 2026,
        'grade': '10',
        'started_date': '2026-01-01',
        'is_current': 1,
        'created_at': '2026-01-01',
        'updated_at': '2026-01-01',
      });
      await connection.insert('batch_teacher_history', {
        'batch_history_id': historyId,
        'teacher_id': teacherId,
        'assigned_date': '2026-01-01',
        'is_current': 1,
        'created_at': '2026-01-01',
        'updated_at': '2026-01-01',
      });
      expect(
        () => repository.deleteTeacher(
          database: connection,
          adminId: adminId,
          teacherId: teacherId,
        ),
        throwsA(isA<TeacherHasAssignmentsException>()),
      );
      expect(
        (await connection.query(
          'teachers',
          where: 'id = ?',
          whereArgs: [teacherId],
        )),
        hasLength(1),
      );
      await database.close();
    },
  );

  test('allows active staff to manage teachers', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final users = UserRepository();
    final adminId = (await connection.query('users')).single['id']! as int;
    final staffId = await users.createStaff(
      database: connection,
      adminId: adminId,
      fullName: 'Staff User',
      username: 'staff.teacher',
      password: 'StaffPassword123!',
    );
    final repository = TeacherRepository();

    final teacherId = await repository.createTeacher(
      database: connection,
      adminId: staffId,
      details: {
        'full_name': 'Staff Added Teacher',
        'name_with_initials': 'S. Teacher',
        'registered_date': '2026-01-01',
        'status': 'active',
      },
      qualifications: const [],
    );

    final teachers = await repository.searchTeachers(
      database: connection,
      adminId: staffId,
    );
    expect(teachers.single['id'], teacherId);

    await database.close();
  });

  test('filters teachers by registered date range', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final adminId = (await connection.query('users')).single['id']! as int;
    final repository = TeacherRepository();

    await repository.createTeacher(
      database: connection,
      adminId: adminId,
      details: {
        'full_name': 'Early Teacher',
        'name_with_initials': 'E. Teacher',
        'registered_date': '2026-01-10',
        'status': 'active',
      },
      qualifications: const [],
    );
    await repository.createTeacher(
      database: connection,
      adminId: adminId,
      details: {
        'full_name': 'Late Teacher',
        'name_with_initials': 'L. Teacher',
        'registered_date': '2026-03-15',
        'status': 'active',
      },
      qualifications: const [],
    );

    final filtered = await repository.searchTeachers(
      database: connection,
      adminId: adminId,
      startDate: DateTime(2026, 2, 1),
      endDate: DateTime(2026, 3, 31),
    );

    expect(filtered, hasLength(1));
    expect(filtered.single['full_name'], 'Late Teacher');

    await database.close();
  });
}
