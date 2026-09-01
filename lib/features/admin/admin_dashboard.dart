import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/routes/app_routes.dart';
import '../../app/widgets/glass_ui.dart';
import '../../core/services/auth_service.dart';
import '../profile/user_profile_menu.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.auth, required this.database});

  final AuthService auth;
  final Database database;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _isSidebarVisible = true;

  static const _navItems = [
    ('Staff Management', Icons.people_rounded, AppRoutes.staffManagement),
    ('Backup & Restore', Icons.backup_rounded, AppRoutes.backupManagement),
    ('Audit Logs', Icons.fact_check_rounded, AppRoutes.auditLogs),
  ];

  @override
  void initState() {
    super.initState();
    widget.auth.requireRole('admin');
  }

  void _navigateTo(String route) {
    Navigator.of(context).pushNamed(route);
  }

  void _logout() {
    widget.auth.logout();
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.auth.currentSession!;
    final isMobile = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF4F7),
      body: DashboardBackdrop(
        child: Row(
          children: [
            if (!isMobile && _isSidebarVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                child: _buildSidebar(context),
              ),
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(isMobile ? 12 : 16, 16, isMobile ? 12 : 24, 8),
                    child: _buildHeaderBar(context, session),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 0, isMobile ? 16 : 24, 24),
                      child: _buildDashboardContent(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 260,
      child: GlassSurface(
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.symmetric(vertical: 18),
        opacity: 0.74,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.75)],
                      ),
                      boxShadow: floatingShadow(color: colorScheme.primary, blur: 14, y: 6, opacity: 0.16),
                    ),
                    child: Icon(Icons.admin_panel_settings_rounded, color: colorScheme.onPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Damma School', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          'Admin Panel',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: _navItems.length,
                itemBuilder: (context, index) {
                  final (label, icon, route) = _navItems[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: GlassNavTile(
                      label: label,
                      icon: icon,
                      isSelected: index == 0,
                      onTap: () => _navigateTo(route),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: GlassLogoutButton(onPressed: _logout),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context, AuthSession session) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      opacity: 0.76,
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() => _isSidebarVisible = !_isSidebarVisible),
            tooltip: _isSidebarVisible ? 'Hide sidebar' : 'Show sidebar',
            icon: const Icon(Icons.menu_rounded),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Dashboard',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Oversee staff, backups, and audit activity.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const GlassStatusChip(),
          const SizedBox(width: 16),
          UserProfileMenu(
            session: session,
            auth: widget.auth,
            database: widget.database,
            roleLabel: 'Admin',
            onLogout: _logout,
            onProfileUpdated: () => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context) {
    final metrics = [
      ('Staff Accounts', '12', Icons.people_rounded, const Color(0xFF3B82F6)),
      ('Backup Jobs', '03', Icons.backup_rounded, const Color(0xFF22C55E)),
      ('Audit Events', '1,240', Icons.fact_check_rounded, const Color(0xFF8B5CF6)),
    ];

    final actions = [
      ('Staff Management', Icons.people_rounded, 'Manage staff accounts and access.', AppRoutes.staffManagement),
      ('Backup & Restore', Icons.backup_rounded, 'Protect and recover the database.', AppRoutes.backupManagement),
      ('Audit Logs', Icons.fact_check_rounded, 'Review recorded system activity.', AppRoutes.auditLogs),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 3 : constraints.maxWidth >= 600 ? 2 : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: columns == 1 ? 3.6 : 2.8,
              children: metrics
                  .map(
                    (m) => GlassMetricCard(
                      label: m.$1,
                      value: m.$2,
                      icon: m.$3,
                      color: m.$4,
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          'Administrative tools at a glance.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width >= 900 ? 3 : MediaQuery.sizeOf(context).width >= 600 ? 2 : 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: MediaQuery.sizeOf(context).width < 600 ? 3.2 : 2.6,
          children: actions
              .map(
                (a) => GlassQuickActionCard(
                  title: a.$1,
                  subtitle: a.$3,
                  icon: a.$2,
                  onTap: () => _navigateTo(a.$4),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
