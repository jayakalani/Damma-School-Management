import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/routes/app_routes.dart';
import '../../app/widgets/glass_admin_ui.dart';
import '../../core/dashboard/dashboard_stats_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/error_messages.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    super.key,
    required this.database,
    required this.auth,
  });

  final Database database;
  final AuthService auth;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final repository = const DashboardStatsRepository();
  late Future<StaffDashboardStats> stats;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    stats = repository.loadStaffStats(widget.database);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.auth.canAccess(role: 'staff')) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return GlassAdminPage(
      title: 'Reports',
      subtitle: 'School overview and module summaries',
      toolbar: GlassToolbarButton(
        label: 'Refresh',
        icon: Icons.refresh_rounded,
        accent: accent,
        onPressed: () => setState(reload),
      ),
      body: FutureBuilder<StaffDashboardStats>(
        future: stats,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        userFacingError(
                          snapshot.error!,
                          fallback: 'Unable to load reports.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : const CircularProgressIndicator(),
            );
          }

          final data = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                glassSummaryGrid(
                  context: context,
                  accent: accent,
                  columns: 4,
                  cards: [
                    GlassSummaryStatCard(
                      label: 'Active Teachers',
                      value: formatCount(data.activeTeachers),
                      valueColor: const Color(0xFF2563EB),
                      accentColor: const Color(0xFF2563EB),
                      dense: true,
                    ),
                    GlassSummaryStatCard(
                      label: 'Active Batches',
                      value: formatCount(data.activeBatches),
                      valueColor: const Color(0xFF16A34A),
                      accentColor: const Color(0xFF16A34A),
                      dense: true,
                    ),
                    GlassSummaryStatCard(
                      label: 'Enrolled Students',
                      value: formatCount(data.enrolledStudents),
                      valueColor: const Color(0xFFEA580C),
                      accentColor: const Color(0xFFEA580C),
                      dense: true,
                    ),
                    GlassSummaryStatCard(
                      label: 'Past Pupils',
                      value: formatCount(data.pastPupils),
                      valueColor: const Color(0xFF7C3AED),
                      accentColor: const Color(0xFF7C3AED),
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const GlassDirectoryHeader(
                        title: 'Academic Summary',
                        icon: Icons.insights_rounded,
                        countLabel: 'Live counts',
                      ),
                      const SizedBox(height: 16),
                      _ReportRow(
                        label: 'Examinations defined',
                        value: formatCount(data.examinations),
                        icon: Icons.assignment_rounded,
                        color: accent,
                        onTap: () => Navigator.of(context)
                            .pushNamed(AppRoutes.examinationManagement),
                      ),
                      const SizedBox(height: 8),
                      _ReportRow(
                        label: 'Competitions recorded',
                        value: formatCount(data.competitions),
                        icon: Icons.emoji_events_rounded,
                        color: const Color(0xFFEA580C),
                        onTap: () => Navigator.of(context)
                            .pushNamed(AppRoutes.competitionManagement),
                      ),
                      const SizedBox(height: 8),
                      _ReportRow(
                        label: 'Inactive enrolled students',
                        value: formatCount(data.inactiveStudents),
                        icon: Icons.person_off_outlined,
                        color: const Color(0xFFDC2626),
                        onTap: () => Navigator.of(context)
                            .pushNamed(AppRoutes.studentManagement),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const GlassDirectoryHeader(
                        title: 'Alumni Summary',
                        icon: Icons.history_edu_rounded,
                        countLabel: 'Legacy records',
                      ),
                      const SizedBox(height: 16),
                      _ReportRow(
                        label: 'Legacy alumni batches',
                        value: formatCount(data.legacyBatches),
                        icon: Icons.groups_outlined,
                        color: const Color(0xFF7C3AED),
                        onTap: () => Navigator.of(context)
                            .pushNamed(AppRoutes.historicalPastPupils),
                      ),
                      const SizedBox(height: 8),
                      _ReportRow(
                        label: 'Historical past pupils',
                        value: formatCount(data.historicalPastPupils),
                        icon: Icons.school_outlined,
                        color: const Color(0xFF2563EB),
                        onTap: () => Navigator.of(context)
                            .pushNamed(AppRoutes.historicalPastPupils),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const GlassDirectoryHeader(
                        title: 'Open Module Reports',
                        icon: Icons.open_in_new_rounded,
                        countLabel: 'Quick links',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          GlassActionChipButton(
                            label: 'Teachers',
                            color: const Color(0xFF2563EB),
                            onPressed: () => Navigator.of(context)
                                .pushNamed(AppRoutes.teacherManagement),
                          ),
                          GlassActionChipButton(
                            label: 'Batches',
                            color: const Color(0xFF16A34A),
                            onPressed: () => Navigator.of(context)
                                .pushNamed(AppRoutes.batchManagement),
                          ),
                          GlassActionChipButton(
                            label: 'Students',
                            color: const Color(0xFFEA580C),
                            onPressed: () => Navigator.of(context)
                                .pushNamed(AppRoutes.studentManagement),
                          ),
                          GlassActionChipButton(
                            label: 'Examinations',
                            color: accent,
                            onPressed: () => Navigator.of(context)
                                .pushNamed(AppRoutes.examinationManagement),
                          ),
                          GlassActionChipButton(
                            label: 'Past Pupils',
                            color: const Color(0xFF7C3AED),
                            onPressed: () => Navigator.of(context)
                                .pushNamed(AppRoutes.historicalPastPupils),
                          ),
                          GlassActionChipButton(
                            label: 'Competitions',
                            color: const Color(0xFFDC2626),
                            onPressed: () => Navigator.of(context)
                                .pushNamed(AppRoutes.competitionManagement),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassListRow(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
