import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_schema.dart';

class AppDatabase {
  AppDatabase({DatabaseFactory? factory}) : _factory = factory ?? databaseFactory;

  static const fileName = 'damma_school.db';
  final DatabaseFactory _factory;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final supportDirectory = await getApplicationSupportDirectory();
    final databasePath = path.join(supportDirectory.path, fileName);
    return openAt(databasePath);
  }

  Future<Database> openAt(String databasePath) async {
    if (_database != null) {
      return _database!;
    }
    _database = await _factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      ),
    );
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}