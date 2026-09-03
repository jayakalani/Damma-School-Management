import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/routes/app_routes.dart';
import '../../app/widgets/glass_ui.dart';
import '../../core/dashboard/dashboard_stats_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/error_messages.dart';
import '../profile/user_profile_menu.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key, required this.auth, required this.database});

  final AuthService auth;
  final Database database;

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  int _selectedIndex = 0;
  bool _isSidebarVisible = true;
  final _statsRepository = const DashboardStatsRepository();
  late Future<StaffDashboardStats> _stats;

  static const _navItems = [
    ('Dashboard', Icons.dashboard_rounded, AppRoutes.staff),
    ('Teachers', Icons.person_rounded, AppRoutes.teacherManagement),
    ('Batches', Icons.groups_rounded, AppRoutes.batchManagement),
    ('Students', Icons.school_rounded, AppRoutes.studentManagement),
    ('Past Pupils', Icons.history_edu_rounded, AppRoutes.historicalPastPupils),
    ('Exams', Icons.assignment_rounded, AppRoutes.examinationManagement),
    ('Competitions', Icons.emoji_events_rounded, AppRoutes.competitionManagement),
    ('Reports', Icons.insights_rounded, AppRoutes.reports),
    ('Backup', Icons.backup_rounded, AppRoutes.backupManagement),
  ];

  @override
  void initState() {
    super.initState();
    widget.auth.requireRole('staff');
    _loadStats();
  }

  void _loadStats() {
    _stats = _statsRepository.loadStaffStats(widget.database);
  }

  Future<void> _navigate(int index, String route) async {
    setState(() => _selectedIndex = index);
    if (route == AppRoutes.staff) {
      setState(_loadStats);
      return;
    }
    await Navigator.of(context).pushNamed(route);
    if (mounted) setState(_loadStats);
  }

  Future<void> _openRoute(String route) async {
    await Navigator.of(context).pushNamed(route);
    if (mounted) setState(_loadStats);
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
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 12 : 16,
                      16,
                      isMobile ? 12 : 24,
                      8,
                    ),
                    child: _buildHeaderBar(context, session),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 16 : 24,
                        0,
                        isMobile ? 16 : 24,
                        24,
                      ),
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
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary.withValues(alpha: 0.75),
                        ],
                      ),
                      boxShadow: floatingShadow(
                        color: colorScheme.primary,
                        blur: 14,
                        y: 6,
                        opacity: 0.16,
                      ),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Damma School',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Staff Portal',
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
                      isSelected: _selectedIndex == index,
                      onTap: () => _navigate(index, route),
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
            onPressed: () =>
                setState(() => _isSidebarVisible = !_isSidebarVisible),
            tooltip: _isSidebarVisible ? 'Hide sidebar' : 'Show sidebar',
            icon: const Icon(Icons.menu_rounded),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Staff Dashboard',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Manage school records in your offline workspace.',
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
            roleLabel: 'Staff',
            onLogout: _logout,
            onProfileUpdated: () => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context) {
    final actions = [
      (
        'Teachers',
        Icons.person_rounded,
        'Manage teacher records',
        AppRoutes.teacherManagement,
      ),
      (
        'Batch Management',
        Icons.groups_rounded,
        'Create and manage batches',
        AppRoutes.batchManagement,
      ),
      (
        'Students',
        Icons.school_rounded,
        'Manage student records',
        AppRoutes.studentManagement,
      ),
      (
        'Examinations',
        Icons.assignment_rounded,
        'Manage exams and marks',
        AppRoutes.examinationManagement,
      ),
      (
        'Past Pupils',
        Icons.history_edu_rounded,
        'Review alumni records',
        AppRoutes.historicalPastPupils,
      ),
      (
        'Competitions',
        Icons.emoji_events_rounded,
        'Manage and view school competitions.',
        AppRoutes.competitionManagement,
      ),
      (
        'Reports',
        Icons.insights_rounded,
        'Export school reports as CSV or PDF',
        AppRoutes.reports,
      ),
      (
        'Database Backup',
        Icons.backup_rounded,
        'Backup application data',
        AppRoutes.backupManagement,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<StaffDashboardStats>(
          future: _stats,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  userFacingError(
                    snapshot.error!,
                    fallback: 'Unable to load dashboard metrics.',
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final data = snapshot.data ?? StaffDashboardStats.empty;
            final loading = !snapshot.hasData;
            final metrics = [
              (
                'Active Teachers',
                loading ? '—' : formatCount(data.activeTeachers),
                Icons.person_rounded,
                const Color(0xFF3B82F6),
              ),
              (
                'Active Batches',
                loading ? '—' : formatCount(data.activeBatches),
                Icons.groups_rounded,
                const Color(0xFF22C55E),
              ),
              (
                'Enrolled Students',
                loading ? '—' : formatCount(data.enrolledStudents),
                Icons.school_rounded,
                const Color(0xFFF97316),
              ),
              (
                'Past Pupils',
                loading ? '—' : formatCount(data.pastPupils),
                Icons.history_edu_rounded,
                const Color(0xFF8B5CF6),
              ),
            ];

            return LayoutBuilder(
              builder: (context, constraints) {
                final width = MediaQuery.sizeOf(context).width;
                final columns = width >= 900
                    ? 4
                    : width >= 600
                        ? 2
                        : 1;
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
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Quick Actions',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Jump directly into the modules you use most.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = MediaQuery.sizeOf(context).width;
            final columns = width >= 900
                ? 3
                : width >= 600
                    ? 2
                    : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: columns == 1 ? 3.2 : 2.6,
              children: actions
                  .map(
                    (a) => GlassQuickActionCard(
                      title: a.$1,
                      subtitle: a.$3,
                      icon: a.$2,
                      onTap: () => _openRoute(a.$4),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
