import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:damma_school_management_system/core/services/auth_service.dart';
import 'package:damma_school_management_system/core/database/app_database.dart';
import 'package:damma_school_management_system/core/users/user_repository.dart';

void main() {
  test('authenticates active users and creates an in-memory session', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final users = UserRepository();
    final adminId = (await connection.query('users')).single['id']! as int;
    final staffId = await users.createStaff(
      database: connection,
      adminId: adminId,
      fullName: 'Active Staff',
      username: 'active.staff',
      password: 'StaffPassword123!',
    );

    final auth = AuthService(database: connection);
    final session = await auth.login(
      username: 'active.staff',
      password: 'StaffPassword123!',
    );

    expect(session.userId, staffId);
    expect(session.isStaff, isTrue);
    expect(auth.currentSession?.username, 'active.staff');
    auth.logout();
    expect(auth.isAuthenticated, isFalse);
    await database.close();
  });

  test('rejects inactive accounts with a safe message', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final users = UserRepository();
    final adminId = (await connection.query('users')).single['id']! as int;
    final staffId = await users.createStaff(
      database: connection,
      adminId: adminId,
      fullName: 'Inactive Staff',
      username: 'inactive.staff',
      password: 'StaffPassword123!',
    );
    await users.setStaffStatus(
      database: connection,
      adminId: adminId,
      staffId: staffId,
      active: false,
    );

    expect(
      () => AuthService(database: connection).login(
        username: 'inactive.staff',
        password: 'StaffPassword123!',
      ),
      throwsA(isA<AuthenticationException>()),
    );
    await database.close();
  });
}
