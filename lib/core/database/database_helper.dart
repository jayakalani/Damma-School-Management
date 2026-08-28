import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_schema.dart';
import 'database_seeder.dart';
import 'database_verifier.dart';

class DatabaseHelper {
  DatabaseHelper({DatabaseFactory? factory}) : _factory = factory ?? databaseFactory;

  static const fileName = 'damma_school.db';
  final DatabaseFactory _factory;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final directory = await getApplicationSupportDirectory();
    return openAt(path.join(directory.path, fileName));
  }

  Future<Database> openAt(String databasePath) async {
    if (_database != null) return _database!;
    _database = await _factory.openDatabase(databasePath, options: OpenDatabaseOptions(
      version: DatabaseSchema.version,
      onConfigure: DatabaseSchema.onConfigure,
      onCreate: DatabaseSchema.onCreate,
      onUpgrade: DatabaseSchema.onUpgrade,
    ));
    await DatabaseSchema.ensureComplete(_database!);
    await DatabaseSeeder().seed(_database!);
    await DatabaseVerifier.verify(_database!);
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}

typedef AppDatabase = DatabaseHelper;