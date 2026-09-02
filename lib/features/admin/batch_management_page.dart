import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/widgets/glass_admin_ui.dart';
import '../../core/batches/batch_repository.dart';
import '../../core/export/batch_export_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/teachers/teacher_repository.dart';
import '../../core/utils/error_messages.dart';
import 'examination_management_page.dart';

class BatchManagementPage extends StatefulWidget {
  const BatchManagementPage({
    super.key,
    required this.database,
    required this.auth,
  });

  final Database database;
  final AuthService auth;

  @override
  State<BatchManagementPage> createState() => _BatchManagementPageState();
}

class _BatchManagementPageState extends State<BatchManagementPage> {
  final search = TextEditingController();
  final repository = BatchRepository();
  late Future<List<Map<String, Object?>>> batches;

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
    batches = repository.listBatches(
      database: widget.database,
      adminId: adminId,
      query: search.text,
    );
  }

  void refreshList() => setState(reload);

  void _resetFilters() {
    setState(() {
      search.clear();
      reload();
    });
  }

  Future<void> addBatch() async {
    final values = await showBatchEditor(context);
    if (values == null || !mounted) return;

    try {
      await repository.createBatch(
        database: widget.database,
        adminId: adminId,
        name: values.name,
        startingYear: values.year,
        startingGrade: values.grade,
      );
      _message('Batch created.');
      refreshList();
    } catch (error) {
      _message(
        userFacingError(error, fallback: 'Unable to create the batch.'),
        error: true,
      );
    }
  }

  Future<void> editBatch(Map<String, Object?> batch) async {
    final values = await showBatchEditor(context, batch: batch);
    if (values == null || !mounted) return;

    try {
      await repository.updateBatch(
        database: widget.database,
        adminId: adminId,
        batchId: batch['id']! as int,
        name: values.name,
        startingYear: values.year,
        grade: values.grade,
      );
      _message('Batch updated.');
      refreshList();
    } catch (error) {
      _message(
        userFacingError(error, fallback: 'Unable to update the batch.'),
        error: true,
      );
    }
  }

  Future<void> toggleBatchStatus(Map<String, Object?> batch) async {
    final active = _isBatchActive(batch);
    try {
      await repository.setBatchActive(
        database: widget.database,
        adminId: adminId,
        batchId: batch['id']! as int,
        active: !active,
      );
      _message(active ? 'Batch deactivated.' : 'Batch activated.');
      refreshList();
    } catch (error) {
      _message(
        userFacingError(error, fallback: 'Unable to change batch status.'),
        error: true,
      );
    }
  }

  Future<void> openBatchDetails(int batchId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BatchDetailsPage(
          database: widget.database,
          auth: widget.auth,
          batchId: batchId,
        ),
      ),
    );
    refreshList();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.auth.canAccess(role: 'staff')) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final canCreate = widget.auth.currentSession!.isStaff;
    final currentYear = DateTime.now().year;

    return GlassAdminPage(
      title: 'Batch Management',
      subtitle: 'Manage academic batches and promotions',
      toolbar: canCreate
          ? GlassToolbarButton(
              label: 'Create Batch',
              icon: Icons.add_rounded,
              accent: accent,
              onPressed: addBatch,
            )
          : null,
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: batches,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                userFacingError(
                  snapshot.error!,
                  fallback: 'Unable to load batches.',
                ),
                textAlign: TextAlign.center,
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allBatches = snapshot.data!;
          final withCurrentYear = allBatches
              .where((b) => b['academic_year'] != null)
              .length;
          final startedThisYear = allBatches
              .where((b) => b['starting_year'] == currentYear)
              .length;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                glassSummaryGrid(
                  context: context,
                  accent: accent,
                  cards: [
                    GlassSummaryStatCard(
                      label: 'Total Batches',
                      value: '${allBatches.length}',
                      valueColor: theme.colorScheme.onSurface,
                      accentColor: accent,
                    ),
                    GlassSummaryStatCard(
                      label: 'Active Years',
                      value: '$withCurrentYear',
                      valueColor: const Color(0xFF2563EB),
                      accentColor: const Color(0xFF2563EB),
                    ),
                    GlassSummaryStatCard(
                      label: 'Started This Year',
                      value: '$startedThisYear',
                      valueColor: const Color(0xFF16A34A),
                      accentColor: const Color(0xFF16A34A),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GlassPanel(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      final compact = maxWidth < 720;
                      final searchWidth = compact ? maxWidth : 280.0;

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
                              decoration: glassInputDecoration(
                                context,
                                hint: 'Search batches...',
                                prefixIcon: Icons.search_rounded,
                              ),
                            ),
                          ),
                          GlassActionButton(
                            label: 'Apply',
                            filled: true,
                            onPressed: refreshList,
                          ),
                          GlassActionButton(
                            label: 'Reset',
                            onPressed: _resetFilters,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GlassDirectoryHeader(
                        title: 'Batch Directory',
                        icon: Icons.groups_outlined,
                        countLabel: '${allBatches.length} shown',
                      ),
                      const SizedBox(height: 16),
                      if (allBatches.isEmpty)
                        const GlassEmptyState(
                          icon: Icons.groups_outlined,
                          message: 'No batches found.',
                        )
                      else ...[
                        const GlassTableHeader(
                          columns: [
                            'ID',
                            'BATCH NAME',
                            'STARTING YEAR',
                            'CURRENT',
                            'STATUS',
                            'ACTIONS',
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final batch in allBatches)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlassListRow(
                              onTap: () =>
                                  openBatchDetails(batch['id']! as int),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '#${batch['id']}',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      batch['batch_name']! as String,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${batch['starting_year']}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      '${batch['academic_year'] ?? '-'} · Grade ${batch['grade'] ?? '-'}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _BatchActiveToggle(
                                      active: _isBatchActive(batch),
                                      onChanged: () =>
                                          toggleBatchStatus(batch),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (canCreate)
                                          GlassActionChipButton(
                                            label: 'Edit',
                                            color: const Color(0xFF2563EB),
                                            onPressed: () =>
                                                editBatch(batch),
                                          ),
                                        GlassActionChipButton(
                                          label: 'Open',
                                          color: accent,
                                          onPressed: () => openBatchDetails(
                                            batch['id']! as int,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
    );
  }

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
}

bool _isBatchActive(Map<String, Object?> batch) =>
    (batch['is_active'] ?? 1) == 1;

class _BatchActiveToggle extends StatelessWidget {
  const _BatchActiveToggle({
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

class BatchDetailsPage extends StatefulWidget {
  const BatchDetailsPage({
    super.key,
    required this.database,
    required this.auth,
    required this.batchId,
  });

  final Database database;
  final AuthService auth;
  final int batchId;

  @override
  State<BatchDetailsPage> createState() => _BatchDetailsPageState();
}

class _BatchDetailsPageState extends State<BatchDetailsPage> {
  final repository = BatchRepository();
  final teacherRepository = TeacherRepository();
  final exportService = const BatchExportService();
  late Future<BatchDetails> details;

  int get adminId => widget.auth.currentSession!.userId;

  @override
  void initState() {
    super.initState();
    details = repository.getBatchDetails(
      database: widget.database,
      adminId: adminId,
      batchId: widget.batchId,
    );
  }

  void reload() => setState(() {
    details = repository.getBatchDetails(
      database: widget.database,
      adminId: adminId,
      batchId: widget.batchId,
    );
  });

  Future<void> promote(BatchDetails data) async {
    final current = data.history.lastWhere(
      (row) => row['is_current'] == 1,
      orElse: () => data.history.last,
    );
    final values = await showPromotionEditor(
      context,
      year: (current['academic_year']! as int) + 1,
      grade: current['grade']! as String,
    );
    if (values == null || !mounted) return;

    try {
      await repository.promoteBatch(
        database: widget.database,
        adminId: adminId,
        batchId: widget.batchId,
        academicYear: values.year,
        grade: values.grade,
      );
      _message('Batch promoted.');
      reload();
    } catch (_) {
      _message('Unable to promote the batch.', error: true);
    }
  }

  Future<void> assignTeacher(BatchDetails data) async {
    final teachers = await teacherRepository.searchTeachers(
      database: widget.database,
      adminId: adminId,
      status: 'active',
    );
    if (!mounted) return;

    final teacherId = await showTeacherPicker(context, teachers);
    if (teacherId == null || !mounted) return;

    try {
      await repository.assignClassTeacher(
        database: widget.database,
        adminId: adminId,
        batchId: widget.batchId,
        teacherId: teacherId,
      );
      _message('Class teacher assigned.');
      reload();
    } catch (_) {
      _message('Unable to assign the class teacher.', error: true);
    }
  }

  Future<void> addStudent() async {
    final students = await repository.listStudents(
      database: widget.database,
      adminId: adminId,
    );
    if (!mounted) return;

    final studentId = await showStudentPicker(context, students);
    if (studentId == null || !mounted) return;

    try {
      await repository.addStudentToBatch(
        database: widget.database,
        adminId: adminId,
        batchId: widget.batchId,
        studentId: studentId,
      );
      _message('Student added to the batch.');
      reload();
    } on StudentAlreadyInBatchException {
      _message('That student is already in this batch.', error: true);
    } catch (_) {
      _message('Unable to add the student.', error: true);
    }
  }

  Future<void> openExamination(int examinationId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarksEntryPage(
          database: widget.database,
          auth: widget.auth,
          examinationId: examinationId,
          batchId: widget.batchId,
        ),
      ),
    );
    if (mounted) reload();
  }

  String _exportTimestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  String _exportFileStem(BatchDetails data) {
    final name = (data.batch['batch_name']! as String)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'batch_${name.isEmpty ? widget.batchId : name}_${_exportTimestamp()}';
  }

  Future<void> _exportCsv(BatchDetails data) async {
    if (kIsWeb) {
      _message('Export is available in the desktop app.', error: true);
      return;
    }
    try {
      final location = await getSaveLocation(
        suggestedName: '${_exportFileStem(data)}.csv',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null || !mounted) return;
      await exportService.writeTextFile(
        path: location.path,
        contents: exportService.buildCsv(data),
      );
      _message('Batch CSV exported.');
    } catch (_) {
      _message('Unable to export batch CSV.', error: true);
    }
  }

  Future<void> _exportPdf(BatchDetails data) async {
    if (kIsWeb) {
      _message('Export is available in the desktop app.', error: true);
      return;
    }
    try {
      final location = await getSaveLocation(
        suggestedName: '${_exportFileStem(data)}.pdf',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PDF', extensions: ['pdf']),
        ],
      );
      if (location == null || !mounted) return;
      final bytes = await exportService.buildPdf(data);
      await exportService.writeBytesFile(path: location.path, bytes: bytes);
      _message('Batch PDF exported.');
    } catch (_) {
      _message('Unable to export batch PDF.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return FutureBuilder<BatchDetails>(
      future: details,
      builder: (context, snapshot) {
        final batchName =
            snapshot.data?.batch['batch_name'] as String? ?? 'Batch Details';
        String subtitle = 'Batch overview and membership';
        if (snapshot.hasData) {
          final data = snapshot.data!;
          if (data.history.isNotEmpty) {
            final current = data.history.lastWhere(
              (row) => row['is_current'] == 1,
              orElse: () => data.history.last,
            );
            subtitle =
                'Started ${data.batch['starting_year']} · '
                '${current['academic_year']} · Grade ${current['grade']}';
          } else {
            subtitle = 'Started ${data.batch['starting_year']}';
          }
        }

        return GlassAdminPage(
          title: batchName,
          subtitle: subtitle,
          toolbar: snapshot.hasData
              ? Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    GlassToolbarButton(
                      label: 'Export CSV',
                      icon: Icons.table_chart_outlined,
                      accent: const Color(0xFF16A34A),
                      onPressed: () => _exportCsv(snapshot.data!),
                    ),
                    GlassToolbarButton(
                      label: 'Export PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      accent: const Color(0xFFE11D48),
                      onPressed: () => _exportPdf(snapshot.data!),
                    ),
                    GlassToolbarButton(
                      label: 'Promote Batch',
                      icon: Icons.upgrade_rounded,
                      accent: accent,
                      onPressed: () => promote(snapshot.data!),
                    ),
                  ],
                )
              : null,
          body: !snapshot.hasData
              ? Center(
                  child: snapshot.hasError
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            userFacingError(
                              snapshot.error!,
                              fallback: 'Unable to load batch details.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : const CircularProgressIndicator(),
                )
              : _BatchDetailsBody(
                  data: snapshot.data!,
                  accent: accent,
                  onAddStudent: addStudent,
                  onAssignTeacher: () => assignTeacher(snapshot.data!),
                  onOpenExamination: openExamination,
                ),
        );
      },
    );
  }

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
}

class _BatchDetailsBody extends StatelessWidget {
  const _BatchDetailsBody({
    required this.data,
    required this.accent,
    required this.onAddStudent,
    required this.onAssignTeacher,
    required this.onOpenExamination,
  });

  final BatchDetails data;
  final Color accent;
  final VoidCallback onAddStudent;
  final VoidCallback onAssignTeacher;
  final ValueChanged<int> onOpenExamination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentStudents =
        data.students.where((row) => row['is_current'] == 1).length;
    final currentTeachers =
        data.teachers.where((row) => row['is_current'] == 1).length;
    final isActive = (data.batch['is_active'] ?? 1) == 1;

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
                label: 'Students',
                value: '$currentStudents',
                valueColor: const Color(0xFF2563EB),
                accentColor: const Color(0xFF2563EB),
                dense: true,
              ),
              GlassSummaryStatCard(
                label: 'Teachers',
                value: '$currentTeachers',
                valueColor: const Color(0xFF16A34A),
                accentColor: const Color(0xFF16A34A),
                dense: true,
              ),
              GlassSummaryStatCard(
                label: 'History Years',
                value: '${data.history.length}',
                valueColor: const Color(0xFF7C3AED),
                accentColor: const Color(0xFF7C3AED),
                dense: true,
              ),
              GlassSummaryStatCard(
                label: 'Examinations',
                value: '${data.examinations.length}',
                valueColor: theme.colorScheme.onSurface,
                accentColor: accent,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.groups_rounded, color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.batch['batch_name']! as String,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Starting year ${data.batch['starting_year']}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(
                  label: isActive ? 'Active' : 'Inactive',
                  color: isActive
                      ? const Color(0xFF16A34A)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassDirectoryHeader(
                  title: 'Batch History',
                  icon: Icons.timeline_rounded,
                  countLabel: '${data.history.length} year(s)',
                ),
                const SizedBox(height: 16),
                if (data.history.isEmpty)
                  const GlassEmptyState(
                    icon: Icons.timeline_outlined,
                    message: 'No academic history recorded.',
                  )
                else
                  for (final row in data.history)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassListRow(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: row['is_current'] == 1
                                    ? accent.withValues(alpha: 0.12)
                                    : theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                row['is_current'] == 1
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.history_rounded,
                                size: 18,
                                color: row['is_current'] == 1
                                    ? accent
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Academic year ${row['academic_year']} · Grade ${row['grade']}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      'Started ${_formatDisplayDate(row['started_date'] as String?)}',
                                      if (row['ended_date'] != null)
                                        'Ended ${_formatDisplayDate(row['ended_date'] as String?)}',
                                    ].join(' · '),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (row['is_current'] == 1)
                              const _StatusBadge(
                                label: 'Current',
                                color: Color(0xFF16A34A),
                              ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionToolbar(
                  title: 'Students',
                  icon: Icons.school_outlined,
                  countLabel: '${data.students.length} total',
                  action: GlassActionChipButton(
                    label: 'Add Student',
                    color: accent,
                    onPressed: onAddStudent,
                  ),
                ),
                const SizedBox(height: 16),
                if (data.students.isEmpty)
                  const GlassEmptyState(
                    icon: Icons.school_outlined,
                    message: 'No students assigned.',
                  )
                else
                  for (final row in data.students)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassListRow(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row['full_name']! as String,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      'Joined ${_formatDisplayDate(row['joined_date'] as String?)}',
                                      if (row['left_date'] != null)
                                        'Left ${_formatDisplayDate(row['left_date'] as String?)}',
                                    ].join(' · '),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _StatusBadge(
                              label: row['is_current'] == 1
                                  ? 'Current'
                                  : 'Historical',
                              color: row['is_current'] == 1
                                  ? const Color(0xFF16A34A)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionToolbar(
                  title: 'Teachers',
                  icon: Icons.person_outline_rounded,
                  countLabel: '${data.teachers.length} total',
                  action: GlassActionChipButton(
                    label: 'Assign Teacher',
                    color: accent,
                    onPressed: onAssignTeacher,
                  ),
                ),
                const SizedBox(height: 16),
                if (data.teachers.isEmpty)
                  const GlassEmptyState(
                    icon: Icons.person_outline_rounded,
                    message: 'No teachers assigned.',
                  )
                else
                  for (final row in data.teachers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassListRow(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row['full_name']! as String,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      'Assigned ${_formatDisplayDate(row['assigned_date'] as String?)}',
                                      if (row['removed_date'] != null)
                                        'Removed ${_formatDisplayDate(row['removed_date'] as String?)}',
                                    ].join(' · '),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _StatusBadge(
                              label: row['is_current'] == 1
                                  ? 'Current'
                                  : 'Historical',
                              color: row['is_current'] == 1
                                  ? const Color(0xFF16A34A)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassDirectoryHeader(
                  title: 'Examinations',
                  icon: Icons.quiz_outlined,
                  countLabel: '${data.examinations.length} recorded',
                ),
                const SizedBox(height: 16),
                if (data.examinations.isEmpty)
                  const GlassEmptyState(
                    icon: Icons.quiz_outlined,
                    message: 'No examinations recorded.',
                  )
                else
                  for (final row in data.examinations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassListRow(
                        onTap: () => onOpenExamination(row['id']! as int),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row['examination_name']! as String,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDisplayDate(
                                      row['examination_date'] as String?,
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${row['total_marks']} marks',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
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
}

class _SectionToolbar extends StatelessWidget {
  const _SectionToolbar({
    required this.title,
    required this.icon,
    required this.countLabel,
    required this.action,
  });

  final String title;
  final IconData icon;
  final String countLabel;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Row(
      children: [
        Icon(icon, color: accent, size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          countLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        action,
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

String _formatDisplayDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '-';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

class BatchEditorValues {
  const BatchEditorValues(this.name, this.year, this.grade);

  final String name;
  final int year;
  final String grade;
}

Future<BatchEditorValues?> showBatchEditor(
  BuildContext context, {
  Map<String, Object?>? batch,
}) async {
  final isEdit = batch != null;
  final name = TextEditingController(text: batch?['batch_name'] as String?);
  final year = TextEditingController(
    text: batch == null
        ? DateTime.now().year.toString()
        : '${batch['starting_year']}',
  );
  final grade = TextEditingController(text: batch?['grade'] as String?);

  final result = await showDialog<BatchEditorValues>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(isEdit ? 'Edit Batch' : 'Create Batch'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Batch Name'),
          ),
          TextField(
            controller: year,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Starting Year'),
          ),
          TextField(
            controller: grade,
            decoration: InputDecoration(
              labelText: isEdit ? 'Current Grade' : 'Starting Grade',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = int.tryParse(year.text);
            if (name.text.trim().isNotEmpty &&
                value != null &&
                grade.text.trim().isNotEmpty) {
              Navigator.pop(
                context,
                BatchEditorValues(name.text.trim(), value, grade.text.trim()),
              );
            }
          },
          child: Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    ),
  );

  name.dispose();
  year.dispose();
  grade.dispose();
  return result;
}

Future<BatchEditorValues?> showPromotionEditor(
  BuildContext context, {
  required int year,
  required String grade,
}) async {
  final yearController = TextEditingController(text: year.toString());
  final gradeController = TextEditingController(text: grade);

  final result = await showDialog<BatchEditorValues>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Promote Batch'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: yearController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'New Academic Year'),
          ),
          TextField(
            controller: gradeController,
            decoration: const InputDecoration(labelText: 'New Grade'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = int.tryParse(yearController.text);
            if (value != null && gradeController.text.trim().isNotEmpty) {
              Navigator.pop(
                context,
                BatchEditorValues('', value, gradeController.text.trim()),
              );
            }
          },
          child: const Text('Promote'),
        ),
      ],
    ),
  );

  yearController.dispose();
  gradeController.dispose();
  return result;
}

Future<int?> showTeacherPicker(
  BuildContext context,
  List<Map<String, Object?>> teachers,
) async {
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Assign Class Teacher'),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final teacher in teachers)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(teacher['full_name']! as String),
                subtitle: Text(teacher['name_with_initials']! as String),
                onTap: () => Navigator.pop(context, teacher['id']! as int),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

Future<int?> showStudentPicker(
  BuildContext context,
  List<Map<String, Object?>> students,
) async {
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add Student'),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final student in students)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(student['full_name']! as String),
                subtitle: Text(student['name_with_initials']! as String),
                onTap: () => Navigator.pop(context, student['id']! as int),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

