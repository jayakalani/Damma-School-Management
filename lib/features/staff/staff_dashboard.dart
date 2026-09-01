import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../core/services/auth_service.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key, required this.auth});

  final AuthService auth;

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  int _selectedIndex = 0;
  bool _isSidebarVisible = true;

  @override
  void initState() {
    super.initState();
    widget.auth.requireRole('staff');
  }

  void _navigate(int index, String route) {
    setState(() => _selectedIndex = index);
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
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          if (!isMobile && _isSidebarVisible) _buildSidebar(context),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Header Bar
                _buildHeaderBar(context, session),
                // Main Dashboard Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _buildDashboardContent(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final navItems = [
      ('Dashboard', Icons.dashboard_outlined, 0),
      ('Teachers', Icons.person_outlined, 1),
      ('Batches', Icons.groups_outlined, 2),
      ('Students', Icons.school_outlined, 3),
      ('Past Pupils', Icons.history_edu_outlined, 4),
      ('Exams', Icons.assignment_outlined, 5),
      ('Backup', Icons.backup_outlined, 6),
    ];

    final navRoutes = [
      AppRoutes.staff,
      AppRoutes.teacherManagement,
      AppRoutes.batchManagement,
      AppRoutes.studentManagement,
      AppRoutes.historicalPastPupils,
      AppRoutes.examinationManagement,
      AppRoutes.backupManagement,
    ];

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo/Branding
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.school,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Damma',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        'School Mgmt',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Navigation Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final (label, icon, _) = navItems[index];
                final isSelected = _selectedIndex == index;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: NavigationTile(
                    label: label,
                    icon: icon,
                    isSelected: isSelected,
                    onTap: () => _navigate(index, navRoutes[index]),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          // Logout Button
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Logout'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context, dynamic session) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _isSidebarVisible = !_isSidebarVisible;
              });
            },
            tooltip: _isSidebarVisible ? 'Hide sidebar' : 'Show sidebar',
            icon: const Icon(Icons.menu),
          ),
          const SizedBox(width: 8),
          // Screen Title
          Text(
            'Staff Dashboard',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Spacer(),
          // Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 16,
                  color: Colors.amber.shade800,
                ),
                const SizedBox(width: 8),
                Text(
                  'Offline',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.amber.shade800,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // User Profile Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primary,
                  child: Text(
                    session.fullName[0].toUpperCase(),
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.fullName,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Staff',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Metric Summary Cards
        _buildMetricCards(context),
        const SizedBox(height: 32),
        // Quick Actions Section
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        _buildQuickActionsGrid(context),
      ],
    );
  }

  Widget _buildMetricCards(BuildContext context) {
    final metrics = [
      ('Active Teachers', '12', Icons.person, Colors.blue),
      ('Active Batches', '8', Icons.groups, Colors.green),
      ('Enrolled Students', '245', Icons.school, Colors.orange),
      ('Past Pupils', '1,842', Icons.history_edu, Colors.purple),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: metrics
          .map(
            (metric) => Flexible(
              child: MetricCard(
                label: metric.$1,
                value: metric.$2,
                icon: metric.$3,
                color: metric.$4,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    final actions = [
      ('Teachers', Icons.person_outlined, 'Manage teacher records',
          AppRoutes.teacherManagement),
      ('Batch Management', Icons.groups_outlined, 'Create and manage batches',
          AppRoutes.batchManagement),
      ('Students', Icons.school_outlined, 'Manage student records',
          AppRoutes.studentManagement),
      ('Examinations', Icons.assignment_outlined, 'Manage exams and marks',
          AppRoutes.examinationManagement),
      ('Past Pupils', Icons.history_edu_outlined, 'Review alumni records',
          AppRoutes.historicalPastPupils),
      ('Database Backup', Icons.backup_outlined, 'Backup application data',
          AppRoutes.backupManagement),
    ];

    return GridView.extent(
      maxCrossAxisExtent: 300,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: actions
          .map(
            (action) => QuickActionCard(
              title: action.$1,
              icon: action.$2,
              subtitle: action.$3,
              onTap: () => Navigator.of(context).pushNamed(action.$4),
            ),
          )
          .toList(),
    );
  }
}

class NavigationTile extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const NavigationTile({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<NavigationTile> createState() => _NavigationTileState();
}

class _NavigationTileState extends State<NavigationTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? colorScheme.primaryContainer
                  : _isHovered
                      ? colorScheme.secondaryContainer.withValues(alpha: 0.5)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: widget.isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: widget.isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                          fontWeight: widget.isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class QuickActionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final String subtitle;
  final VoidCallback onTap;

  const QuickActionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<QuickActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border.all(
                color: _isHovered
                    ? colorScheme.primary.withValues(alpha: 0.5)
                    : colorScheme.outlineVariant,
                width: _isHovered ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.icon,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward,
                      size: 18,
                      color: _isHovered
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}