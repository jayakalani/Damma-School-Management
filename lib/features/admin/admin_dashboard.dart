import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/routes/app_routes.dart';
import '../../core/services/auth_service.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key, required this.auth, required this.database});

  final AuthService auth;
  final Database database;

  @override
  Widget build(BuildContext context) {
    auth.requireRole('admin');
    final session = auth.currentSession!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Damma School Management System'),
        actions: [_LogoutButton(auth: auth)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Dashboard',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(session.fullName),
                const Text('Role: Administrator'),
                const SizedBox(height: 32),
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const Text('Staff Management'),
                  subtitle: const Text('Manage staff accounts and access.'),
                  onTap: () =>
                      Navigator.of(context)
                          .pushNamed(AppRoutes.staffManagement),
                ),
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('Teachers'),
                  subtitle: const Text('Manage teachers and qualifications.'),
                  onTap: () =>
                      Navigator.of(context)
                          .pushNamed(AppRoutes.teacherManagement),
                ),
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('Batch Management'),
                  subtitle: const Text('Create, view, and promote batches.'),
                  onTap: () =>
                      Navigator.of(context)
                          .pushNamed(AppRoutes.batchManagement),
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Student Management'),
                  subtitle: const Text('Register, edit, and convert students.'),
                  onTap: () =>
                      Navigator.of(context)
                          .pushNamed(AppRoutes.studentManagement),
                ),
                ListTile(
                  leading: const Icon(Icons.history_edu),
                  title: const Text('Historical Past Pupils'),
                  subtitle: const Text('Enter legacy alumni records.'),
                  onTap: () =>
                      Navigator.of(context)
                          .pushNamed(AppRoutes.historicalPastPupils),
                ),
                ListTile(
                  leading: const Icon(Icons.assignment_outlined),
                  title: const Text('Examinations'),
                  subtitle: const Text('Define exams and enter marks.'),
                  onTap: () =>
                      Navigator.of(context)
                          .pushNamed(AppRoutes.examinationManagement),
                ),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Backup & Restore'),
                  subtitle: const Text('Protect and recover the database.'),
                  onTap: () =>
                      Navigator.of(context)
                          .pushNamed(AppRoutes.backupManagement),
                ),
                ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: const Text('Audit Logs'),
                  subtitle: const Text('Review recorded system activity.'),
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.auditLogs),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Logout',
    icon: const Icon(Icons.logout),
    onPressed: () {
      auth.logout();
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    },
  );
}
