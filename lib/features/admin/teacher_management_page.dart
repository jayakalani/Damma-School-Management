import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/widgets/date_picker_field.dart';
import '../../app/widgets/glass_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/export/teacher_export_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/teachers/teacher_repository.dart';
import '../../core/utils/app_validators.dart';
import '../../core/utils/error_messages.dart';

class TeacherManagementPage extends StatefulWidget {
  const TeacherManagementPage({
    super.key,
    required this.database,
    required this.auth,
  });

  final Database database;
  final AuthService auth;

  @override
  State<TeacherManagementPage> createState() => _TeacherManagementPageState();
}

class _TeacherManagementPageState extends State<TeacherManagementPage> {
  final search = TextEditingController();
  final repository = TeacherRepository();
  final exportService = const TeacherExportService();
  String? statusFilter;
  DateTime? startDate;
  DateTime? endDate;
  late Future<List<Map<String, Object?>>> teachers;

  int get adminId => widget.auth.currentSession!.userId;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void reload() {
    teachers = repository.searchTeachers(
      database: widget.database,
      adminId: adminId,
      query: search.text,
      status: statusFilter,
      startDate: startDate,
      endDate: endDate,
    );
  }

  void refreshList() => setState(reload);

  void _resetFilters() {
    setState(() {
      search.clear();
      statusFilter = null;
      startDate = null;
      endDate = null;
      reload();
    });
  }

  TeacherExportFilters get _exportFilters => TeacherExportFilters(
        searchQuery: search.text,
        statusFilter: statusFilter,
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
      final exportedTeachers = await teachers;
      final location = await getSaveLocation(
        suggestedName: 'teachers_${_exportTimestamp()}.csv',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null || !mounted) return;
      await exportService.writeTextFile(
        path: location.path,
        contents: exportService.buildCsv(
          exportedTeachers,
          filters: _exportFilters,
        ),
      );
      _message('Teacher CSV exported (${exportedTeachers.length} record(s)).');
    } catch (_) {
      _message('Unable to export teacher CSV.', error: true);
    }
  }

  Future<void> _exportPdf() async {
    if (kIsWeb) {
      _message('Export is available in the desktop app.', error: true);
      return;
    }
    try {
      final exportedTeachers = await teachers;
      final location = await getSaveLocation(
        suggestedName: 'teachers_${_exportTimestamp()}.pdf',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PDF', extensions: ['pdf']),
        ],
      );
      if (location == null || !mounted) return;
      final bytes = await exportService.buildPdf(
        exportedTeachers,
        filters: _exportFilters,
      );
      await exportService.writeBytesFile(path: location.path, bytes: bytes);
      _message('Teacher PDF exported (${exportedTeachers.length} record(s)).');
    } catch (_) {
      _message('Unable to export teacher PDF.', error: true);
    }
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

  Future<void> addTeacher() async {
    final values = await showTeacherEditor(context);
    if (values == null || !mounted) return;
    await _perform(
      operation: () async {
        await repository.createTeacher(
          database: widget.database,
          adminId: adminId,
          details: values.details,
          qualifications: values.qualifications,
        );
        _message('Teacher added.');
        refreshList();
      },
      failureMessage: 'Unable to add teacher.',
    );
  }

  Future<void> editTeacher(Map<String, Object?> teacher) async {
    final qualificationRows = await repository.qualifications(
      database: widget.database,
      adminId: adminId,
      teacherId: teacher['id']! as int,
    );
    if (!mounted) return;
    final values = await showTeacherEditor(
      context,
      teacher: teacher,
      qualifications: qualificationRows,
    );
    if (values == null || !mounted) return;
    await _perform(
      operation: () async {
        await repository.updateTeacher(
          database: widget.database,
          adminId: adminId,
          teacherId: teacher['id']! as int,
          details: values.details,
          qualifications: values.qualifications,
        );
        _message('Teacher updated.');
        refreshList();
      },
      failureMessage: 'Unable to update teacher.',
    );
  }

  Future<void> toggleStatus(Map<String, Object?> teacher) async {
    final active = teacher['status'] == 'active';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(active ? 'Deactivate teacher?' : 'Activate teacher?'),
        content: Text('Change the status of ${teacher['full_name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(active ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _perform(
      operation: () async {
        await repository.setTeacherStatus(
          database: widget.database,
          adminId: adminId,
          teacherId: teacher['id']! as int,
          active: !active,
        );
        _message(active ? 'Teacher deactivated.' : 'Teacher activated.');
        refreshList();
      },
      failureMessage: 'Unable to change teacher status.',
    );
  }

  Future<void> _perform({
    required Future<void> Function() operation,
    required String failureMessage,
  }) async {
    try {
      await operation();
    } catch (error) {
      _message(
        userFacingError(error, fallback: failureMessage),
        error: true,
      );
    }
  }

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!widget.auth.canAccess(role: 'admin') &&
        !widget.auth.canAccess(role: 'staff')) {
      return const SizedBox.shrink();
    }

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
                            'Teachers',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Manage teacher records and qualifications',
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
                    _BlendedToolbarButton(
                      label: 'Add Teacher',
                      icon: Icons.person_add_outlined,
                      accent: accent,
                      onPressed: addTeacher,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: teachers,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          userFacingError(
                            snapshot.error!,
                            fallback: 'Unable to load teachers.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allTeachers = snapshot.data!;
                  final activeCount = allTeachers
                      .where((t) => t['status'] == 'active')
                      .length;
                  final inactiveCount = allTeachers
                      .where((t) => t['status'] == 'inactive')
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
                                  label: 'Total Teachers',
                                  value: '${allTeachers.length}',
                                  valueColor: theme.colorScheme.onSurface,
                                  accentColor: accent,
                                ),
                                _SummaryStatCard(
                                  label: 'Active',
                                  value: '$activeCount',
                                  valueColor: const Color(0xFF16A34A),
                                  accentColor: const Color(0xFF16A34A),
                                ),
                                _SummaryStatCard(
                                  label: 'Inactive',
                                  value: '$inactiveCount',
                                  valueColor: const Color(0xFFEA580C),
                                  accentColor: const Color(0xFFEA580C),
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
                              final searchWidth = compact ? maxWidth : 280.0;
                              final statusWidth = compact ? maxWidth : 180.0;

                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SizedBox(
                                    width: searchWidth,
                                    child: TextField(
                                      controller: search,
                                      onChanged: (_) => refreshList(),
                                      decoration: _glassInputDecoration(
                                        context,
                                        hint: 'Search teachers...',
                                        prefixIcon: Icons.search_rounded,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: statusWidth,
                                    child: DropdownButtonFormField<String?>(
                                      key: ValueKey(statusFilter),
                                      initialValue: statusFilter,
                                      isExpanded: true,
                                      decoration: _glassInputDecoration(
                                        context,
                                        hint: 'All Status',
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      items: const [
                                        DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text(
                                            'All Status',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'active',
                                          child: Text(
                                            'Active',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'inactive',
                                          child: Text(
                                            'Inactive',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        statusFilter = value;
                                        refreshList();
                                      },
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
                                    label: 'Apply',
                                    filled: true,
                                    onPressed: refreshList,
                                  ),
                                  _GlassActionButton(
                                    label: 'Reset',
                                    onPressed: _resetFilters,
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
                                    Icons.school_outlined,
                                    color: accent,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Teacher Directory',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${allTeachers.length} shown',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (allTeachers.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 48,
                                  ),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.person_outline,
                                          size: 48,
                                          color: theme.colorScheme.outline,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No teachers found.',
                                          style: theme.textTheme.titleMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else ...[
                                const _TeacherTableHeader(),
                                const SizedBox(height: 8),
                                for (final teacher in allTeachers)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _TeacherTableRow(
                                      teacher: teacher,
                                      onEdit: () => editTeacher(teacher),
                                      onToggleStatus: () =>
                                          toggleStatus(teacher),
                                    ),
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
    this.filled = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

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
        child: widget.filled
            ? FilledButton(
                onPressed: widget.onPressed,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: _hovered ? 3 : 0,
                ),
                child: Text(widget.label),
              )
            : OutlinedButton(
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

class _TeacherTableHeader extends StatelessWidget {
  const _TeacherTableHeader();

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
          Expanded(flex: 1, child: Text('ID', style: style)),
          Expanded(flex: 3, child: Text('FULL NAME', style: style)),
          Expanded(flex: 2, child: Text('INITIALS', style: style)),
          Expanded(flex: 2, child: Text('REGISTERED', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          Expanded(flex: 3, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }
}

class _TeacherTableRow extends StatefulWidget {
  const _TeacherTableRow({
    required this.teacher,
    required this.onEdit,
    required this.onToggleStatus,
  });

  final Map<String, Object?> teacher;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  @override
  State<_TeacherTableRow> createState() => _TeacherTableRowState();
}

class _TeacherTableRowState extends State<_TeacherTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final active = widget.teacher['status'] == 'active';

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
                flex: 1,
                child: Text(
                  '#${widget.teacher['id']}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  widget.teacher['full_name']! as String,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  widget.teacher['name_with_initials']! as String,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  widget.teacher['registered_date']! as String,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: _TeacherStatusToggle(
                  active: active,
                  onChanged: widget.onToggleStatus,
                ),
              ),
              Expanded(
                flex: 3,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ActionChipButton(
                      label: 'Edit',
                      color: const Color(0xFF2563EB),
                      onPressed: widget.onEdit,
                    ),
                    _ActionChipButton(
                      label: active ? 'Deactivate' : 'Activate',
                      color: active
                          ? const Color(0xFFEA580C)
                          : const Color(0xFF16A34A),
                      onPressed: widget.onToggleStatus,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherStatusToggle extends StatelessWidget {
  const _TeacherStatusToggle({
    required this.active,
    required this.onChanged,
  });

  final bool active;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(
          value: active,
          onChanged: (_) => onChanged(),
          activeTrackColor: const Color(0xFF16A34A).withValues(alpha: 0.55),
          activeThumbColor: const Color(0xFF16A34A),
          inactiveTrackColor: Colors.grey.shade400.withValues(alpha: 0.5),
          inactiveThumbColor: Colors.grey.shade600,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        const SizedBox(width: 4),
        Text(
          active ? 'Active' : 'Inactive',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: active
                    ? const Color(0xFF16A34A)
                    : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _ActionChipButton extends StatefulWidget {
  const _ActionChipButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_ActionChipButton> createState() => _ActionChipButtonState();
}

class _ActionChipButtonState extends State<_ActionChipButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.05 : 1,
        duration: const Duration(milliseconds: 160),
        child: OutlinedButton(
          onPressed: widget.onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: widget.color,
            side: BorderSide(
              color: widget.color.withValues(alpha: _hovered ? 0.55 : 0.35),
            ),
            backgroundColor: widget.color.withValues(
              alpha: _hovered ? 0.14 : 0.06,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                ),
          ),
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

class TeacherEditorValues {
  const TeacherEditorValues({
    required this.details,
    required this.qualifications,
  });
  final Map<String, Object?> details;
  final List<Map<String, Object?>> qualifications;
}

class _QualificationDraft {
  _QualificationDraft(Map<String, Object?>? value)
    : qualification = TextEditingController(
        text: value?['qualification'] as String?,
      ),
      institution = TextEditingController(
        text: value?['institution'] as String?,
      ),
      year = TextEditingController(text: value?['completion_year']?.toString()),
      notes = TextEditingController(text: value?['notes'] as String?);
  late final TextEditingController qualification;
  late final TextEditingController institution;
  late final TextEditingController year;
  late final TextEditingController notes;
  Map<String, Object?> toMap() => {
    'qualification': qualification.text,
    'institution': institution.text,
    'completion_year': int.tryParse(year.text.trim()),
    'notes': notes.text,
  };
  void dispose() {
    qualification.dispose();
    institution.dispose();
    year.dispose();
    notes.dispose();
  }
}

Future<TeacherEditorValues?> showTeacherEditor(
  BuildContext context, {
  Map<String, Object?>? teacher,
  List<Map<String, Object?>> qualifications = const [],
}) async {
  final fields = {
    for (final key in [
      'full_name',
      'name_with_initials',
      'date_of_birth',
      'nic',
      'phone_number',
      'address',
      'registered_date',
      'bank_account_number',
      'bank_name',
      'bank_branch',
    ])
      key: TextEditingController(text: teacher?[key] as String?),
  };
  fields['registered_date']!.text = fields['registered_date']!.text.isEmpty
      ? AppDateFormats.storage(DateTime.now())
      : fields['registered_date']!.text;
  var status = teacher?['status'] as String? ?? 'active';
  final drafts = qualifications.map(_QualificationDraft.new).toList();
  if (drafts.isEmpty) drafts.add(_QualificationDraft(null));
  final result = await showDialog<TeacherEditorValues>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(teacher == null ? 'Add Teacher' : 'Edit Teacher'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in fields.entries)
                  if (isStorageDateFieldKey(entry.key))
                    datePickerForKey(
                      key: entry.key,
                      controller: entry.value,
                      label: _label(entry.key),
                    )
                  else
                    TextField(
                      controller: entry.value,
                      decoration: InputDecoration(labelText: _label(entry.key)),
                    ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                  ],
                  onChanged: (value) => setState(() => status = value!),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Qualifications',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Add qualification',
                      onPressed: () =>
                          setState(() => drafts.add(_QualificationDraft(null))),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                for (var index = 0; index < drafts.length; index++)
                  _QualificationFields(
                    draft: drafts[index],
                    onRemove: drafts.length == 1
                        ? null
                        : () => setState(() {
                            drafts[index].dispose();
                            drafts.removeAt(index);
                          }),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (fields['full_name']!.text.trim().isEmpty ||
                  fields['name_with_initials']!.text.trim().isEmpty ||
                  fields['registered_date']!.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Full name, initials, and registered date are required.',
                    ),
                  ),
                );
                return;
              }
              final message =
                  AppValidators.nic(fields['nic']!.text) ??
                  AppValidators.phone(fields['phone_number']!.text) ??
                  AppValidators.optionalDate(fields['date_of_birth']!.text) ??
                  AppValidators.date(
                    fields['registered_date']!.text,
                    'Registered date',
                  );
              if (message != null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(message)));
                return;
              }
              Navigator.pop(
                context,
                TeacherEditorValues(
                  details: {
                    ...fields.map(
                      (key, value) => MapEntry(key, value.text.trim()),
                    ),
                    'status': status,
                  },
                  qualifications: drafts.map((draft) => draft.toMap()).toList(),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  for (final controller in fields.values) {
    controller.dispose();
  }
  for (final draft in drafts) {
    draft.dispose();
  }
  return result;
}

class _QualificationFields extends StatelessWidget {
  const _QualificationFields({required this.draft, required this.onRemove});
  final _QualificationDraft draft;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.qualification,
                  decoration: const InputDecoration(labelText: 'Qualification'),
                ),
              ),
              IconButton(
                tooltip: 'Remove qualification',
                onPressed: onRemove,
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
          TextField(
            controller: draft.institution,
            decoration: const InputDecoration(labelText: 'Institution'),
          ),
          TextField(
            controller: draft.year,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Completion year'),
          ),
          TextField(
            controller: draft.notes,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
        ],
      ),
    ),
  );
}

String _label(String key) => key
    .split('_')
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join(' ');
