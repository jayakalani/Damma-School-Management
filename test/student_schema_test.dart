import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:damma_school_management_system/core/database/app_database.dart';
import 'package:damma_school_management_system/core/database/database_schema.dart';
import 'package:damma_school_management_system/core/students/student_repository.dart';
import 'package:damma_school_management_system/core/users/user_repository.dart';
import 'package:damma_school_management_system/core/utils/error_messages.dart';

Future<int> _createStaff(Database connection, int adminId) {
  return UserRepository().createStaff(
    database: connection,
    adminId: adminId,
    fullName: 'Staff User',
    username: 'staff.repair.${DateTime.now().microsecondsSinceEpoch}',
    password: 'StaffPassword123!',
  );
}

void main() {
  test('ensureComplete repairs missing is_active column', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    await connection.execute('ALTER TABLE students DROP COLUMN is_active');
    final adminId = (await connection.query('users')).single['id']! as int;
    final staffId = await _createStaff(connection, adminId);
    final now = DateTime.now().toUtc().toIso8601String();
    await connection.insert('students', {
      'full_name': 'Legacy Student',
      'name_with_initials': 'L. Student',
      'joined_date': '2026-09-02',
      'status': 'student',
      'created_at': now,
      'updated_at': now,
    });

    await DatabaseSchema.ensureComplete(connection);

    await StudentRepository().createStudent(
      database: connection,
      adminId: staffId,
      details: {
        'full_name': 'New Student',
        'name_with_initials': 'N. Student',
        'joined_date': '2026-09-02',
        'date_of_birth': '2010-05-01',
      },
    );

    expect(await connection.query('students'), hasLength(2));
    await database.close();
  });

  test('userFacingError exposes sqlite detail for missing columns', () {
    const message =
        'SqfliteFfiException(sqlite_error: 1, , SqliteException(1): while preparing statement, table students has no column named is_active, SQL logic error (code 1))';
    expect(
      userFacingError(Exception(message), fallback: 'Unable to register student.'),
      contains('database needs an update'),
    );
  });
}
