import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../config/initial_admin_config.dart';
import '../security/password_hasher.dart';

class DatabaseSchema {
  const DatabaseSchema._();

  static const version = 2;

  static Future<void> onConfigure(Database database) async {
    await database.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> onCreate(Database database, int version) async {
    await database.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        username TEXT NOT NULL COLLATE NOCASE UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL CHECK (role IN ('admin', 'staff')),
        status TEXT NOT NULL DEFAULT 'active'
          CHECK (status IN ('active', 'inactive')),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await _createAuditLogsTable(database);

    await _seedInitialAdmin(database);
  }

  static Future<void> onUpgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createAuditLogsTable(database);
    }
  }

  static Future<void> _createAuditLogsTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        module TEXT NOT NULL,
        entity_type TEXT,
        entity_id INTEGER,
        description TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');
    await database.execute('''
      CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at
      ON audit_logs (created_at)
    ''');
    await database.execute('''
      CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id
      ON audit_logs (user_id)
    ''');
  }

  static Future<void> _seedInitialAdmin(Database database) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final passwordHash =
        const PasswordHasher().hash(InitialAdminConfig.password);
    await database.insert('users', {
      'full_name': InitialAdminConfig.fullName,
      'username': InitialAdminConfig.username,
      'password_hash': passwordHash,
      'role': 'admin',
      'status': 'active',
      'created_at': now,
      'updated_at': now,
    });
  }
}