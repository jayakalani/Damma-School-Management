import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/services/auth_service.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

class DammaSchoolApp extends StatelessWidget {
  const DammaSchoolApp({super.key, required this.database, required this.auth});

  final Database database;
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Damma School Management System',
      theme: AppTheme.light(),
      initialRoute: AppRoutes.login,
      onGenerateRoute: (settings) => AppRoutes.generate(
        settings,
        database: database,
        auth: auth,
      ),
    );
  }
}