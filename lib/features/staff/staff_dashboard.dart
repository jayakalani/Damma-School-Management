import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../core/services/auth_service.dart';

class StaffDashboard extends StatelessWidget {
  const StaffDashboard({super.key, required this.auth});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    auth.requireRole('staff');
    final session = auth.currentSession!;
    return Scaffold(
      appBar: AppBar(title: const Text('Damma School Management System'), actions: [IconButton(tooltip: 'Logout', icon: const Icon(Icons.logout), onPressed: () { auth.logout(); Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false); })]),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: Padding(padding: const EdgeInsets.all(32), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Staff Dashboard', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 12), Text(session.fullName), const Text('Role: Staff'), const SizedBox(height: 32), ListTile(leading: const Icon(Icons.backup_outlined), title: const Text('Backup Database'), subtitle: const Text('Create a backup of the application database.'), onTap: () => Navigator.of(context).pushNamed(AppRoutes.backupManagement)), for (final item in const ['Dashboard', 'Teachers', 'Students / Batches', 'Examinations', 'Past Pupils']) ListTile(enabled: false, leading: const Icon(Icons.arrow_forward_ios, size: 16), title: Text(item), subtitle: const Text('Coming in a later module'))])))),
    );
  }
}