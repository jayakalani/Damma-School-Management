import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../core/services/auth_service.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key, required this.auth});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    auth.requireRole('admin');
    final session = auth.currentSession!;
    return Scaffold(
      appBar: AppBar(title: const Text('Damma School Management System'), actions: [_LogoutButton(auth: auth)]),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: Padding(padding: const EdgeInsets.all(32), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Admin Dashboard', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 12), Text(session.fullName), const Text('Role: Administrator'), const SizedBox(height: 32), const _PlaceholderList(items: ['Dashboard', 'Staff Management', 'Audit Logs'])])))),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) => IconButton(tooltip: 'Logout', icon: const Icon(Icons.logout), onPressed: () { auth.logout(); Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false); });
}

class _PlaceholderList extends StatelessWidget {
  const _PlaceholderList({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) => Column(children: [for (final item in items) ListTile(enabled: false, leading: const Icon(Icons.arrow_forward_ios, size: 16), title: Text(item), subtitle: const Text('Coming in a later module'))]);
}