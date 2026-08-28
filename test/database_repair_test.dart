import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:damma_school_management_system/core/database/app_database.dart';
import 'package:damma_school_management_system/core/database/database_verifier.dart';

void main() {
  test('repairs an incomplete on-disk database during open', () async {
    sqfliteFfiInit();
    final tempDir = Directory.systemTemp.createTempSync('damma_db_repair_test');
    final dbPath = path.join(tempDir.path, AppDatabase.fileName);
    final partial = await databaseFactoryFfi.openDatabase(dbPath);
    await partial.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        username TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await partial.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        module TEXT NOT NULL,
        description TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await partial.execute('PRAGMA user_version = 1');
    await partial.close();

    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(dbPath);
    await DatabaseVerifier.verify(connection);
    await database.close();
    tempDir.deleteSync(recursive: true);
  });
}
