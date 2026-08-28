import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/services/auth_service.dart';
import '../../features/admin/admin_dashboard.dart';
import '../../features/auth/login_page.dart';
import '../../features/staff/staff_dashboard.dart';
import '../../features/admin/staff_management_page.dart';
import '../../features/admin/teacher_management_page.dart';
import '../../features/admin/batch_management_page.dart';

class AppRoutes {
  const AppRoutes._();

  static const login = '/login';
  static const admin = '/admin';
  static const staff = '/staff';
  static const staffManagement = '/admin/staff-management';
  static const teacherManagement = '/admin/teachers';
  static const batchManagement = '/admin/batches';

  static Route<dynamic> generate(
    RouteSettings settings, {
    required Database database,
    required AuthService auth,
  }) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => LoginPage(database: database, auth: auth),
        );
      case admin:
        if (!auth.canAccess(role: 'admin'))
          return _redirect(settings, database, auth);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AdminDashboard(auth: auth, database: database),
        );
      case staff:
        if (!auth.canAccess(role: 'staff'))
          return _redirect(settings, database, auth);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => StaffDashboard(auth: auth),
        );
      case staffManagement:
        if (!auth.canAccess(role: 'admin'))
          return _redirect(settings, database, auth);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => StaffManagementPage(database: database, auth: auth),
        );
      case teacherManagement:
        if (!auth.canAccess(role: 'admin'))
          return _redirect(settings, database, auth);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => TeacherManagementPage(database: database, auth: auth),
        );
      case batchManagement:
        if (!auth.canAccess(role: 'admin'))
          return _redirect(settings, database, auth);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => BatchManagementPage(database: database, auth: auth),
        );
      default:
        return _redirect(settings, database, auth);
    }
  }

  static Route<dynamic> _redirect(
    RouteSettings settings,
    Database database,
    AuthService auth,
  ) {
    final session = auth.currentSession;
    final destination = session?.isAdmin == true ? admin : login;
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => destination == admin
          ? AdminDashboard(auth: auth, database: database)
          : LoginPage(database: database, auth: auth),
    );
  }
}
