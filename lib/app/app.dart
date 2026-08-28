import 'package:flutter/material.dart';

import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

class DammaSchoolApp extends StatelessWidget {
  const DammaSchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Damma School Management System',
      theme: AppTheme.light(),
      initialRoute: AppRoutes.foundation,
      routes: AppRoutes.routes,
    );
  }
}