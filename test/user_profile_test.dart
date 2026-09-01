import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:damma_school_management_system/core/audit/audit_actions.dart';
import 'package:damma_school_management_system/core/database/app_database.dart';
import 'package:damma_school_management_system/core/security/password_hasher.dart';
import 'package:damma_school_management_system/core/services/auth_service.dart';
import 'package:damma_school_management_system/core/users/user_repository.dart';

void main() {
  test('updates profile name and records audit log', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final users = UserRepository();
    final adminId = (await connection.query('users')).single['id']! as int;

    await users.updateUserProfile(
      database: connection,
      userId: adminId,
      fullName: 'Updated Administrator',
      username: 'admin',
    );

    final row = await connection.query(
      'users',
      where: 'id = ?',
      whereArgs: [adminId],
    );
    expect(row.single['full_name'], 'Updated Administrator');

    final logs = await connection.query(
      'audit_logs',
      where: 'action = ?',
      whereArgs: [AuditActions.profileUpdated],
    );
    expect(logs, hasLength(1));
    expect(logs.single['user_id'], adminId);

    await database.close();
  });

  test('updates password after validating current password', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final users = UserRepository();
    final hasher = const PasswordHasher();
    final adminId = (await connection.query('users')).single['id']! as int;
    const currentPassword = 'ChangeMe123!';
    const newPassword = 'SecurePass123!';

    await users.updateUserPassword(
      database: connection,
      userId: adminId,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    final row = await connection.query(
      'users',
      where: 'id = ?',
      whereArgs: [adminId],
    );
    expect(hasher.verify(newPassword, row.single['password_hash']! as String), isTrue);
    expect(hasher.verify(currentPassword, row.single['password_hash']! as String), isFalse);

    final logs = await connection.query(
      'audit_logs',
      where: 'action = ?',
      whereArgs: [AuditActions.passwordChanged],
    );
    expect(logs, hasLength(1));

    await database.close();
  });

  test('rejects password update when current password is wrong', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final users = UserRepository();
    final adminId = (await connection.query('users')).single['id']! as int;

    await expectLater(
      users.updateUserPassword(
        database: connection,
        userId: adminId,
        currentPassword: 'WrongPassword123!',
        newPassword: 'SecurePass123!',
      ),
      throwsA(isA<InvalidCurrentPasswordException>()),
    );

    await database.close();
  });

  test('refreshes auth session after profile update', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final users = UserRepository();
    final auth = AuthService(database: connection);
    await auth.login(username: 'admin', password: 'ChangeMe123!');
    final adminId = auth.currentSession!.userId;

    await users.updateUserProfile(
      database: connection,
      userId: adminId,
      fullName: 'Renamed Admin',
      username: 'admin.renamed',
    );
    await auth.refreshSessionFromDatabase();

    expect(auth.currentSession?.fullName, 'Renamed Admin');
    expect(auth.currentSession?.username, 'admin.renamed');

    await database.close();
  });

  test('rejects duplicate username on profile update', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final users = UserRepository();
    final adminId = (await connection.query('users')).single['id']! as int;
    await users.createStaff(
      database: connection,
      adminId: adminId,
      fullName: 'Other Staff',
      username: 'taken.user',
      password: 'StaffPassword123!',
    );

    await expectLater(
      users.updateUserProfile(
        database: connection,
        userId: adminId,
        fullName: 'System Administrator',
        username: 'taken.user',
      ),
      throwsA(isA<UsernameAlreadyInUseException>()),
    );

    await database.close();
  });

  test('admin can delete a staff account', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final users = UserRepository();
    final adminId = (await connection.query('users')).single['id']! as int;
    final staffId = await users.createStaff(
      database: connection,
      adminId: adminId,
      fullName: 'Delete Me',
      username: 'delete.me',
      password: 'StaffPassword123!',
    );

    await users.deleteStaff(
      database: connection,
      adminId: adminId,
      staffId: staffId,
    );

    final remaining = await connection.query(
      'users',
      where: 'id = ?',
      whereArgs: [staffId],
    );
    expect(remaining, isEmpty);

    await database.close();
  });
}
