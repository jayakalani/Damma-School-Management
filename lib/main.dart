import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/app.dart';
import 'core/database/database_helper.dart';
import 'core/services/auth_service.dart';

Future<void> main() => bootstrap();

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final database = await DatabaseHelper().database;
  runApp(
    DammaSchoolApp(
      database: database,
      auth: AuthService(database: database),
      onRestore: bootstrap,
    ),
  );
}
