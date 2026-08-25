// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:damma_school_management_system/core/config/initial_admin_config.dart';
import 'package:damma_school_management_system/core/database/app_database.dart';
import 'package:damma_school_management_system/core/security/password_hasher.dart';
import 'package:damma_school_management_system/core/users/user_repository.dart';

void main() {
  test('password hashes verify without storing the plain-text password', () {
    const password = 'correct horse battery staple';
    final hash = const PasswordHasher(iterations: 1000).hash(password);

    expect(hash, isNot(contains(password)));
    expect(const PasswordHasher().verify(password, hash), isTrue);
    expect(const PasswordHasher().verify('wrong password', hash), isFalse);
  });

  test('first database initialization seeds one active admin', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);

    final users = await connection.query('users');
    expect(users, hasLength(1));
    expect(users.single['username'], InitialAdminConfig.username);
    expect(users.single['role'], 'admin');
    expect(users.single['status'], 'active');
    expect(
      const PasswordHasher().verify(
        InitialAdminConfig.password,
        users.single['password_hash']! as String,
      ),
      isTrue,
    );

    await database.close();
  });

  test('admin staff operations are audited and staff cannot view audit logs', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final users = UserRepository();
    final adminId = (await connection.query('users')).single['id']! as int;

    final staffId = await users.createStaff(
      database: connection,
      adminId: adminId,
      fullName: 'Staff Member',
      username: 'staff.one',
      password: 'StaffPassword123!',
    );
    await users.setStaffStatus(
      database: connection,
      adminId: adminId,
      staffId: staffId,
      active: false,
    );

    final staff = await users.listStaff(database: connection, adminId: adminId);
    final auditLogs = await connection.query('audit_logs');
    expect(staff.single['status'], 'inactive');
    expect(auditLogs, hasLength(2));
    expect(
      () => users.listStaff(database: connection, adminId: staffId),
      throwsStateError,
    );

    await database.close();
  });
}
