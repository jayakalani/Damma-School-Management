import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/widgets/glass_ui.dart';
import '../../core/audit/audit_log_repository.dart';
import '../../core/export/audit_log_export_service.dart';
import '../../core/services/auth_service.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key, required this.database, required this.auth});
  final Database database;
  final AuthService auth;
  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  final repository = const AuditLogRepository();
  final exportService = const AuditLogExportService();
  final search = TextEditingController();
  late Future<List<Map<String, Object?>>> logs;
  late Future<List<Map<String, Object?>>> users;
  late Future<List<String>> modules;
  int? userId;
  String? selectedUserLabel;
  String? module;
  DateTime? startDate;
  DateTime? endDate;
  int get adminId => widget.auth.currentSession!.userId;

  @override
  void initState() {
    super.initState();
    widget.auth.requireRole('admin');
    users = repository.listUsersForFilter(
      database: widget.database,
      adminId: adminId,
    );
    modules = repository.listModulesForFilter(
      database: widget.database,
      adminId: adminId,
    );
    reload();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void reload() {
    logs = repository.listForAdmin(
      database: widget.database,
      adminId: adminId,
      query: search.text,
      userId: userId,
      module: module,
      startDate: startDate,
      endDate: endDate,
    );
  }

  void clearFilters() {
    search.clear();
    setState(() {
      userId = null;
      selectedUserLabel = null;
      module = null;
      startDate = null;
      endDate = null;
      reload();
    });
  }

  AuditLogExportFilters get _exportFilters => AuditLogExportFilters(
        searchQuery: search.text,
        userLabel: selectedUserLabel,
        module: module,
        startDate: startDate,
        endDate: endDate,
      );

  String _exportTimestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _exportCsv() async {
    if (kIsWeb) {
      _message('Export is available in the desktop app.', error: true);
      return;
    }
    try {
      final exportedLogs = await logs;
      final location = await getSaveLocation(
        suggestedName: 'audit_logs_${_exportTimestamp()}.csv',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null || !mounted) return;
      await exportService.writeTextFile(
        path: location.path,
        contents: exportService.buildCsv(
          exportedLogs,
          filters: _exportFilters,
        ),
      );
      _message('Audit log CSV exported (${exportedLogs.length} record(s)).');
    } catch (_) {
      _message('Unable to export audit log CSV.', error: true);
    }
  }

  Future<void> _exportPdf() async {
    if (kIsWeb) {
      _message('Export is available in the desktop app.', error: true);
      return;
    }
    try {
      final exportedLogs = await logs;
      final location = await getSaveLocation(
        suggestedName: 'audit_logs_${_exportTimestamp()}.pdf',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PDF', extensions: ['pdf']),
        ],
      );
      if (location == null || !mounted) return;
      final bytes = await exportService.buildPdf(
        exportedLogs,
        filters: _exportFilters,
      );
      await exportService.writeBytesFile(path: location.path, bytes: bytes);
      _message('Audit log PDF exported (${exportedLogs.length} record(s)).');
    } catch (_) {
      _message('Unable to export audit log PDF.', error: true);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> chooseStart() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
      initialDate: startDate ?? DateTime.now(),
    );
    if (value != null) {
      setState(() {
        startDate = value;
        reload();
      });
    }
  }

  Future<void> chooseEnd() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
      initialDate: endDate ?? DateTime.now(),
    );
    if (value != null) {
      setState(() {
        endDate = value;
        reload();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    widget.auth.requireRole('admin');
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF4F7),
      body: DashboardBackdrop(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: GlassSurface(
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                opacity: 0.78,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Audit Logs',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Review system activity and administrative changes',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _BlendedToolbarButton(
                      label: 'Export CSV',
                      icon: Icons.table_chart_outlined,
                      accent: const Color(0xFF16A34A),
                      onPressed: _exportCsv,
                    ),
                    _BlendedToolbarButton(
                      label: 'Export PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      accent: const Color(0xFFE11D48),
                      onPressed: _exportPdf,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: logs,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: _StateMessage(
                        icon: Icons.error_outline,
                        text: 'Unable to load audit logs.',
                        action: TextButton.icon(
                          onPressed: () => setState(reload),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final visibleLogs = snapshot.data!;
                  final uniqueUsers = visibleLogs
                      .map((log) => log['actor_username'])
                      .whereType<String>()
                      .toSet()
                      .length;
                  final uniqueModules = visibleLogs
                      .map((log) => log['module'])
                      .whereType<String>()
                      .toSet()
                      .length;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 900
                                ? 3
                                : constraints.maxWidth >= 560
                                    ? 2
                                    : 1;
                            return GridView.count(
                              crossAxisCount: columns,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: columns == 1 ? 4.8 : 4.2,
                              children: [
                                _SummaryStatCard(
                                  label: 'Total Logs',
                                  value: '${visibleLogs.length}',
                                  valueColor: theme.colorScheme.onSurface,
                                  accentColor: accent,
                                ),
                                _SummaryStatCard(
                                  label: 'Users',
                                  value: '$uniqueUsers',
                                  valueColor: const Color(0xFF2563EB),
                                  accentColor: const Color(0xFF2563EB),
                                ),
                                _SummaryStatCard(
                                  label: 'Modules',
                                  value: '$uniqueModules',
                                  valueColor: const Color(0xFF7C3AED),
                                  accentColor: const Color(0xFF7C3AED),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _GlassPanel(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final maxWidth = constraints.maxWidth;
                              final compact = maxWidth < 720;
                              final fieldWidth = compact ? maxWidth : 180.0;
                              final moduleWidth = compact ? maxWidth : 200.0;
                              final searchWidth =
                                  compact ? maxWidth : 280.0;

                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SizedBox(
                                    width: searchWidth,
                                    child: TextField(
                                      controller: search,
                                      onChanged: (_) => setState(reload),
                                      decoration: _glassInputDecoration(
                                        context,
                                        hint: 'Search logs...',
                                        prefixIcon: Icons.search_rounded,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: fieldWidth,
                                    child: FutureBuilder<
                                        List<Map<String, Object?>>>(
                                      future: users,
                                      builder: (context, userSnapshot) =>
                                          DropdownButtonFormField<int?>(
                                        key: ValueKey(userId),
                                        initialValue: userId,
                                        isExpanded: true,
                                        decoration: _glassInputDecoration(
                                          context,
                                          hint: 'All users',
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        items: [
                                          const DropdownMenuItem<int?>(
                                            value: null,
                                            child: Text(
                                              'All users',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (userSnapshot.hasData)
                                            for (final user
                                                in userSnapshot.data!)
                                              DropdownMenuItem(
                                                value: user['id']! as int,
                                                child: Text(
                                                  user['username']! as String,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                        ],
                                        onChanged: (value) => setState(() {
                                          userId = value;
                                          selectedUserLabel = null;
                                          if (value != null &&
                                              userSnapshot.hasData) {
                                            for (final user
                                                in userSnapshot.data!) {
                                              if (user['id'] == value) {
                                                selectedUserLabel =
                                                    user['username'] as String?;
                                                break;
                                              }
                                            }
                                          }
                                          reload();
                                        }),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: moduleWidth,
                                    child: FutureBuilder<List<String>>(
                                      future: modules,
                                      builder: (context, moduleSnapshot) =>
                                          DropdownButtonFormField<String?>(
                                        key: ValueKey(module),
                                        initialValue: module,
                                        isExpanded: true,
                                        decoration: _glassInputDecoration(
                                          context,
                                          hint: 'All modules',
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        items: [
                                          const DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text(
                                              'All modules',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (moduleSnapshot.hasData)
                                            for (final value
                                                in moduleSnapshot.data!)
                                              DropdownMenuItem(
                                                value: value,
                                                child: Text(
                                                  value,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                        ],
                                        onChanged: (value) => setState(() {
                                          module = value;
                                          reload();
                                        }),
                                      ),
                                    ),
                                  ),
                                  _GlassDateButton(
                                    label: startDate == null
                                        ? 'From date'
                                        : _dateLabel(startDate!),
                                    onPressed: chooseStart,
                                  ),
                                  _GlassDateButton(
                                    label: endDate == null
                                        ? 'To date'
                                        : _dateLabel(endDate!),
                                    onPressed: chooseEnd,
                                  ),
                                  _GlassActionButton(
                                    label: 'Reset',
                                    onPressed: clearFilters,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        _GlassPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.fact_check_outlined,
                                    color: accent,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Activity Log',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${visibleLogs.length} shown',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (visibleLogs.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 48,
                                  ),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.fact_check_outlined,
                                          size: 48,
                                          color: theme.colorScheme.outline,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No audit logs match the current filters.',
                                          style: theme.textTheme.titleMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else ...[
                                const _AuditLogTableHeader(),
                                const SizedBox(height: 8),
                                for (final log in visibleLogs)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _AuditLogTableRow(log: log),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStatCard extends StatefulWidget {
  const _SummaryStatCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.accentColor,
  });

  final String label;
  final String value;
  final Color valueColor;
  final Color accentColor;

  @override
  State<_SummaryStatCard> createState() => _SummaryStatCardState();
}

class _SummaryStatCardState extends State<_SummaryStatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: GlassSurface(
            borderRadius: BorderRadius.circular(14),
            padding: EdgeInsets.zero,
            opacity: _hovered ? 0.84 : 0.74,
            borderOpacity: _hovered ? 0.72 : 0.55,
            tint: _hovered
                ? Color.alphaBlend(
                    widget.accentColor.withValues(alpha: 0.05),
                    Colors.white,
                  )
                : Colors.white,
            elevated: _hovered,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(height: 3, color: widget.accentColor),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.value,
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: widget.valueColor,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                  letterSpacing: -0.5,
                                ),
                      ),
                    ],
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

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(20),
      opacity: 0.76,
      child: child,
    );
  }
}

class _GlassActionButton extends StatefulWidget {
  const _GlassActionButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_GlassActionButton> createState() => _GlassActionButtonState();
}

class _GlassActionButtonState extends State<_GlassActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.03 : 1,
        duration: const Duration(milliseconds: 180),
        child: OutlinedButton(
          onPressed: widget.onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(
              color: accent.withValues(alpha: _hovered ? 0.6 : 0.35),
            ),
            backgroundColor: _hovered
                ? accent.withValues(alpha: 0.06)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

class _GlassDateButton extends StatefulWidget {
  const _GlassDateButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_GlassDateButton> createState() => _GlassDateButtonState();
}

class _GlassDateButtonState extends State<_GlassDateButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.03 : 1,
        duration: const Duration(milliseconds: 180),
        child: OutlinedButton.icon(
          onPressed: widget.onPressed,
          icon: Icon(
            Icons.event_rounded,
            size: 18,
            color: accent.withValues(alpha: _hovered ? 0.9 : 0.75),
          ),
          label: Text(widget.label),
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(
              color: accent.withValues(alpha: _hovered ? 0.6 : 0.35),
            ),
            backgroundColor: _hovered
                ? accent.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.45),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuditLogTableHeader extends StatelessWidget {
  const _AuditLogTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('DATE/TIME', style: style)),
          Expanded(flex: 2, child: Text('USER', style: style)),
          Expanded(flex: 2, child: Text('ACTION', style: style)),
          Expanded(flex: 2, child: Text('MODULE', style: style)),
          Expanded(flex: 4, child: Text('DESCRIPTION', style: style)),
        ],
      ),
    );
  }
}

class _AuditLogTableRow extends StatefulWidget {
  const _AuditLogTableRow({required this.log});

  final Map<String, Object?> log;

  @override
  State<_AuditLogTableRow> createState() => _AuditLogTableRowState();
}

class _AuditLogTableRowState extends State<_AuditLogTableRow> {
  bool _hovered = false;

  String _formatDateTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.005 : 1,
        duration: const Duration(milliseconds: 180),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          opacity: _hovered ? 0.84 : 0.7,
          borderOpacity: _hovered ? 0.7 : 0.5,
          tint: _hovered
              ? Color.alphaBlend(accent.withValues(alpha: 0.04), Colors.white)
              : Colors.white,
          elevated: _hovered,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  _formatDateTime(widget.log['created_at']! as String),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${widget.log['actor_username'] ?? '-'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  widget.log['action']! as String,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  widget.log['module']! as String,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  widget.log['description']! as String,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlendedToolbarButton extends StatefulWidget {
  const _BlendedToolbarButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onPressed;

  @override
  State<_BlendedToolbarButton> createState() => _BlendedToolbarButtonState();
}

class _BlendedToolbarButtonState extends State<_BlendedToolbarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = _hovered
        ? Color.alphaBlend(Colors.black.withValues(alpha: 0.08), widget.accent)
        : widget.accent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.03 : 1,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(12),
            splashColor: Colors.white.withValues(alpha: 0.2),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _hovered
                    ? floatingShadow(
                        color: widget.accent,
                        opacity: 0.2,
                        blur: 14,
                        y: 6,
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(text),
            if (action != null) action!,
          ],
        ),
      );
}

InputDecoration _glassInputDecoration(
  BuildContext context, {
  required String hint,
  IconData? prefixIcon,
}) {
  final theme = Theme.of(context);
  final accent = theme.colorScheme.primary;
  return InputDecoration(
    hintText: hint,
    prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.45),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: theme.dividerColor.withValues(alpha: 0.35),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: accent, width: 1.5),
    ),
  );
}

String _dateLabel(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
