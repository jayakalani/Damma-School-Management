import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../config/initial_admin_config.dart';
import '../security/password_hasher.dart';

class DatabaseSeeder {
  const DatabaseSeeder({this.passwordHasher = const PasswordHasher()});

  final PasswordHasher passwordHasher;

  Future<void> seed(Database database) async {
    await database.transaction((transaction) async {
      final admins = await transaction.query('users', columns: ['id'], where: 'role = ?', whereArgs: ['admin'], limit: 1);
      if (admins.isNotEmpty) return;
      final now = DateTime.now().toUtc().toIso8601String();
      await transaction.insert('users', {
        'full_name': InitialAdminConfig.fullName,
        'username': InitialAdminConfig.username,
        'password_hash': passwordHasher.hash(InitialAdminConfig.password),
        'role': 'admin',
        'status': 'active',
        'created_at': now,
        'updated_at': now,
      });
    });
  }
}