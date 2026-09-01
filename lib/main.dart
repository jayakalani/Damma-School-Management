import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/app.dart';
import 'core/database/database_helper.dart';
import 'core/services/auth_service.dart';

Future<void> main() => bootstrap();

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'This app uses a native SQLite database and cannot run on the web browser. '
                'Please run it on Windows, Android, or iOS.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final database = await DatabaseHelper().database;
  runApp(
    DammaSchoolApp(
      database: database,
      auth: AuthService(database: database),
      onRestore: bootstrap,
    ),
  );
}
