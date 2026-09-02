import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/widgets/date_picker_field.dart';
import '../../app/widgets/glass_admin_ui.dart';

import '../../core/examinations/examination_repository.dart';
import '../../core/export/marks_export_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/app_validators.dart';
import '../../core/utils/error_messages.dart';

class ExaminationManagementPage extends StatefulWidget {
  const ExaminationManagementPage({
    super.key,
    required this.database,
    required this.auth,
  });

  final Database database;
  final AuthService auth;

  @override
  State<ExaminationManagementPage> createState() =>
      _ExaminationManagementPageState();
}

class _ExaminationManagementPageState extends State<ExaminationManagementPage> {
  final repository = ExaminationRepository();
  late Future<List<Map<String, Object?>>> examinations;
  late Future<List<Map<String, Object?>>> activeBatches;
  final expandedExamIds = <int>{};

  int get adminId => widget.auth.currentSession!.userId;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    examinations = repository.listExaminations(
      database: widget.database,
      adminId: adminId,
    );
    activeBatches = repository.listActiveBatches(
      database: widget.database,
      adminId: adminId,
    );
  }

  Future<void> createExam() async {
    final value = await showExamEditor(context);
    if (value == null || !mounted) return;

    try {
      await repository.createExamination(
        database: widget.database,
        adminId: adminId,
        name: value.name,
        date: value.date,
        totalMarks: value.totalMarks,
      );
      _message('Examination created.');
      setState(reload);
    } catch (error) {
      _message(
        userFacingError(error, fallback: 'Unable to create examination.'),
        error: true,
      );
    }
  }

  void toggleExpanded(int examId) {
    setState(() {
      if (expandedExamIds.contains(examId)) {
        expandedExamIds.remove(examId);
      } else {
        expandedExamIds.add(examId);
      }
    });
  }

  void openMarksEntry({
    required int examinationId,
    required int batchId,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarksEntryPage(
          database: widget.database,
          auth: widget.auth,
          examinationId: examinationId,
          batchId: batchId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.auth.canAccess(role: 'staff')) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final canCreate = widget.auth.currentSession!.isStaff;

    return GlassAdminPage(
      title: 'Examinations',
      subtitle: 'Define examinations and manage student marks',
      toolbar: canCreate
          ? GlassToolbarButton(
              label: 'Define Examination',
              icon: Icons.add_rounded,
              accent: accent,
              onPressed: createExam,
            )
          : null,
      body: FutureBuilder<List<Object?>>(
        future: Future.wait<Object?>([examinations, activeBatches]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        userFacingError(
                          snapshot.error!,
                          fallback: 'Unable to load examinations.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : const CircularProgressIndicator(),
            );
          }

          final allExams =
              (snapshot.data![0] as List).cast<Map<String, Object?>>();
          final batches =
              (snapshot.data![1] as List).cast<Map<String, Object?>>();
          final currentYear = DateTime.now().year;
          final thisYearCount = allExams
              .where((e) => '${e['examination_date']}'.startsWith('$currentYear'))
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
                      label: 'Total Examinations',
                      value: '${allExams.length}',
                      valueColor: theme.colorScheme.onSurface,
                      accentColor: accent,
                    ),
                    GlassSummaryStatCard(
                      label: 'Active Batches',
                      value: '${batches.length}',
                      valueColor: const Color(0xFF2563EB),
                      accentColor: const Color(0xFF2563EB),
                    ),
                    GlassSummaryStatCard(
                      label: 'This Year',
                      value: '$thisYearCount',
                      valueColor: const Color(0xFF16A34A),
                      accentColor: const Color(0xFF16A34A),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GlassDirectoryHeader(
                        title: 'Examination Directory',
                        icon: Icons.assignment_outlined,
                        countLabel: '${allExams.length} shown',
                      ),
                      const SizedBox(height: 16),
                      if (allExams.isEmpty)
                        const GlassEmptyState(
                          icon: Icons.assignment_outlined,
                          message: 'No examinations defined.',
                        )
                      else ...[
                        const GlassTableHeader(
                          columns: [
                            'ID',
                            'EXAMINATION',
                            'DATE',
                            'DETAILS',
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final exam in allExams)
                          _ExaminationExpandableRow(
                            exam: exam,
                            batches: batches,
                            expanded: expandedExamIds.contains(
                              exam['id']! as int,
                            ),
                            accent: accent,
                            onToggle: () =>
                                toggleExpanded(exam['id']! as int),
                            onBatchSelected: (batchId) => openMarksEntry(
                              examinationId: exam['id']! as int,
                              batchId: batchId,
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

class _ExaminationExpandableRow extends StatelessWidget {
  const _ExaminationExpandableRow({
    required this.exam,
    required this.batches,
    required this.expanded,
    required this.accent,
    required this.onToggle,
    required this.onBatchSelected,
  });

  final Map<String, Object?> exam;
  final List<Map<String, Object?>> batches;
  final bool expanded;
  final Color accent;
  final VoidCallback onToggle;
  final ValueChanged<int> onBatchSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          GlassListRow(
            onTap: onToggle,
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    '#${exam['id']}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    exam['examination_name']! as String,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${exam['examination_date']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${exam['total_marks']} marks',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: accent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Material(
                color: accent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                child: batches.isEmpty
                    ? const ListTile(
                        dense: true,
                        title: Text('No active batches available.'),
                      )
                    : Column(
                        children: [
                          for (final batch in batches)
                            ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.groups_outlined,
                                color: accent,
                              ),
                              title: Text(batch['batch_name']! as String),
                              subtitle: Text(
                                '${batch['academic_year']} · Grade ${batch['grade']}',
                              ),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: accent,
                              ),
                              onTap: () =>
                                  onBatchSelected(batch['id']! as int),
                            ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class MarksEntryPage extends StatefulWidget {
  const MarksEntryPage({
    super.key,
    required this.database,
    required this.auth,
    required this.examinationId,
    required this.batchId,
  });

  final Database database;
  final AuthService auth;
  final int examinationId;
  final int batchId;

  @override
  State<MarksEntryPage> createState() => _MarksEntryPageState();
}

class _MarksEntryPageState extends State<MarksEntryPage> {
  final repository = ExaminationRepository();
  final exportService = const MarksExportService();
  late Future<ExaminationDetails> details;
  final marks = <int, TextEditingController>{};

  int get adminId => widget.auth.currentSession!.userId;

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    details = repository
        .getDetails(
          database: widget.database,
          adminId: adminId,
          examinationId: widget.examinationId,
          batchId: widget.batchId,
        )
        .then((value) {
          for (final controller in marks.values) {
            controller.dispose();
          }
          marks.clear();
          for (final student in value.students) {
            final id = student['id']! as int;
            final text = student['attendance_status'] == 'absent'
                ? 'Ab'
                : student['marks']?.toString() ?? '';
            final controller = TextEditingController(text: text);
            controller.addListener(() {
              if (mounted) setState(() {});
            });
            marks[id] = controller;
          }
          return value;
        });
  }

  @override
  void dispose() {
    for (final controller in marks.values) {
      controller.dispose();
    }
    super.dispose();
  }

  ExaminationAnalytics _liveAnalytics(ExaminationDetails data) {
    return repository.analyticsFromRows([
      for (final student in data.students)
        {
          'id': student['id'],
          'full_name': student['full_name'],
          'entry': marks[student['id']! as int]?.text ?? '',
        },
    ]);
  }

  MarksExportMeta _exportMeta(ExaminationDetails data) {
    final exam = data.examination;
    return MarksExportMeta(
      examinationName: exam['examination_name']! as String,
      batchName: exam['batch_name']! as String,
      academicYear: exam['academic_year']!,
      grade: exam['grade']!,
      totalMarks: exam['total_marks']!,
    );
  }

  List<MarksExportRow> _exportRows(ExaminationDetails data) {
    return [
      for (final student in data.students)
        MarksExportRow(
          studentId: student['id']! as int,
          studentName: student['full_name']! as String,
          entry: marks[student['id']! as int]?.text ?? '',
        ),
    ];
  }

  String _exportTimestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _exportCsv(ExaminationDetails data) async {
    try {
      final location = await getSaveLocation(
        suggestedName: 'marks_${_exportTimestamp()}.csv',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null) return;
      await exportService.writeTextFile(
        path: location.path,
        contents: exportService.buildCsv(
          meta: _exportMeta(data),
          rows: _exportRows(data),
          analytics: _liveAnalytics(data),
        ),
      );
      _message('Marks CSV exported (${data.students.length} student(s)).');
    } catch (_) {
      _message('Unable to export marks CSV.', error: true);
    }
  }

  Future<void> _exportPdf(ExaminationDetails data) async {
    try {
      final location = await getSaveLocation(
        suggestedName: 'marks_${_exportTimestamp()}.pdf',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'PDF', extensions: ['pdf']),
        ],
      );
      if (location == null) return;
      final bytes = await exportService.buildPdf(
        meta: _exportMeta(data),
        rows: _exportRows(data),
        analytics: _liveAnalytics(data),
      );
      await exportService.writeBytesFile(path: location.path, bytes: bytes);
      _message('Marks PDF exported (${data.students.length} student(s)).');
    } catch (_) {
      _message('Unable to export marks PDF.', error: true);
    }
  }

  Future<void> save(ExaminationDetails data) async {
    try {
      final totalMarks = data.examination['total_marks']! as num;
      final results = <ExamMarkInput>[];
      for (final student in data.students) {
        final id = student['id']! as int;
        final parsed = ExaminationRepository.parseMarkEntry(
          marks[id]?.text ?? '',
        );
        if (parsed == null) {
          throw const InvalidExamResultException();
        }
        if (parsed.absent) {
          results.add(
            ExamMarkInput(studentId: id, attendanceStatus: 'absent'),
          );
        } else {
          final mark = parsed.marks!;
          if (mark < 0 || mark > totalMarks) {
            throw const InvalidExamResultException();
          }
          results.add(
            ExamMarkInput(
              studentId: id,
              attendanceStatus: 'present',
              marks: mark,
            ),
          );
        }
      }

      await repository.saveResults(
        database: widget.database,
        adminId: adminId,
        examinationId: widget.examinationId,
        batchId: widget.batchId,
        results: results,
      );
      _message('Marks saved.');
      setState(load);
    } on InvalidExamResultException {
      _message(
        'Enter a mark within the total for each student, or type Ab if absent.',
        error: true,
      );
    } catch (error) {
      _message(
        userFacingError(error, fallback: 'Unable to save marks.'),
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return FutureBuilder<ExaminationDetails>(
      future: details,
      builder: (context, snapshot) {
        final examName = snapshot.data?.examination['examination_name']
                as String? ??
            'Marks Entry';
        final subtitle = snapshot.hasData
            ? '${snapshot.data!.examination['batch_name']} · ${snapshot.data!.examination['academic_year']} · Grade ${snapshot.data!.examination['grade']}'
            : 'Enter marks or Ab for each student';

        return GlassAdminPage(
          title: examName,
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
                    if (snapshot.data!.students.isNotEmpty)
                      GlassToolbarButton(
                        label: 'Save Marks',
                        icon: Icons.save_rounded,
                        accent: accent,
                        onPressed: () => save(snapshot.data!),
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
                              fallback: 'Unable to load examination.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : const CircularProgressIndicator(),
                )
              : _MarksEntryBody(
                  data: snapshot.data!,
                  marks: marks,
                  analytics: _liveAnalytics(snapshot.data!),
                  accent: accent,
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

class _MarksEntryBody extends StatefulWidget {
  const _MarksEntryBody({
    required this.data,
    required this.marks,
    required this.analytics,
    required this.accent,
  });

  final ExaminationDetails data;
  final Map<int, TextEditingController> marks;
  final ExaminationAnalytics analytics;
  final Color accent;

  @override
  State<_MarksEntryBody> createState() => _MarksEntryBodyState();
}

class _MarksEntryBodyState extends State<_MarksEntryBody> {
  final nameFilter = TextEditingController();

  @override
  void dispose() {
    nameFilter.dispose();
    super.dispose();
  }

  List<Map<String, Object?>> get _visibleStudents {
    final query = nameFilter.text.trim().toLowerCase();
    if (query.isEmpty) return widget.data.students;
    return widget.data.students.where((student) {
      final fullName = (student['full_name'] as String? ?? '').toLowerCase();
      final initials =
          (student['name_with_initials'] as String? ?? '').toLowerCase();
      return fullName.contains(query) || initials.contains(query);
    }).toList();
  }

  void _resetNameFilter() {
    setState(() => nameFilter.clear());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMarks = widget.data.examination['total_marks'];
    final visibleStudents = _visibleStudents;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          glassSummaryGrid(
            context: context,
            accent: widget.accent,
            columns: 4,
            cards: [
              GlassSummaryStatCard(
                label: 'Present',
                value: '${widget.analytics.presentCount}',
                valueColor: const Color(0xFF16A34A),
                accentColor: const Color(0xFF16A34A),
                dense: true,
              ),
              GlassSummaryStatCard(
                label: 'Absent',
                value: '${widget.analytics.absentCount}',
                valueColor: const Color(0xFFDC2626),
                accentColor: const Color(0xFFDC2626),
                dense: true,
              ),
              GlassSummaryStatCard(
                label: 'Average',
                value: widget.analytics.average?.toStringAsFixed(1) ?? '-',
                valueColor: const Color(0xFF2563EB),
                accentColor: const Color(0xFF2563EB),
                dense: true,
              ),
              GlassSummaryStatCard(
                label: 'Total Marks',
                value: '$totalMarks',
                valueColor: theme.colorScheme.onSurface,
                accentColor: widget.accent,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassDirectoryHeader(
                  title: 'Student Marks',
                  icon: Icons.edit_note_rounded,
                  countLabel:
                      '${visibleStudents.length} of ${widget.data.students.length} students',
                ),
                const SizedBox(height: 8),
                Text(
                  'Type a mark or Ab for absent',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 720;
                    final searchWidth =
                        compact ? constraints.maxWidth : 280.0;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: searchWidth,
                          child: TextField(
                            controller: nameFilter,
                            onChanged: (_) => setState(() {}),
                            decoration: glassInputDecoration(
                              context,
                              hint: 'Filter by name...',
                              prefixIcon: Icons.search_rounded,
                            ),
                          ),
                        ),
                        GlassActionButton(
                          label: 'Reset',
                          onPressed: _resetNameFilter,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (widget.data.students.isEmpty)
                  const GlassEmptyState(
                    icon: Icons.groups_outlined,
                    message: 'No students found in this active batch.',
                  )
                else if (visibleStudents.isEmpty)
                  const GlassEmptyState(
                    icon: Icons.person_search_outlined,
                    message: 'No students match this name filter.',
                  )
                else ...[
                  const GlassTableHeader(
                    columns: ['#', 'STUDENT', 'STATUS', 'MARKS / AB'],
                  ),
                  const SizedBox(height: 8),
                  for (var index = 0; index < visibleStudents.length; index++) ...[
                    if (index > 0) const SizedBox(height: 8),
                    _MarkRow(
                      index: index + 1,
                      student: visibleStudents[index],
                      controller:
                          widget.marks[visibleStudents[index]['id']! as int]!,
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          AnalyticsPanel(analytics: widget.analytics),
        ],
      ),
    );
  }
}

class _MarkRow extends StatelessWidget {
  const _MarkRow({
    required this.index,
    required this.student,
    required this.controller,
  });

  final int index;
  final Map<String, Object?> student;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = ExaminationRepository.parseMarkEntry(controller.text);
    final isAbsent = parsed?.absent == true;
    final hasMark = parsed != null && !isAbsent;
    final statusLabel = isAbsent
        ? 'Absent'
        : hasMark
            ? 'Present'
            : 'Pending';
    final statusColor = isAbsent
        ? const Color(0xFFDC2626)
        : hasMark
            ? const Color(0xFF16A34A)
            : theme.colorScheme.onSurfaceVariant;

    return GlassListRow(
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '$index',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              student['full_name']! as String,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              statusLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 150,
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isAbsent ? const Color(0xFFDC2626) : null,
                  ),
                  decoration: glassInputDecoration(
                    context,
                    hint: 'e.g. 85 or Ab',
                  ).copyWith(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    suffixIcon: isAbsent
                        ? const Icon(
                            Icons.person_off_outlined,
                            color: Color(0xFFDC2626),
                            size: 20,
                          )
                        : hasMark
                            ? const Icon(
                                Icons.check_circle_outline,
                                color: Color(0xFF16A34A),
                                size: 20,
                              )
                            : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnalyticsPanel extends StatelessWidget {
  const AnalyticsPanel({
    super.key,
    required this.analytics,
  });

  final ExaminationAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassDirectoryHeader(
            title: 'Analytics',
            icon: Icons.insights_rounded,
            countLabel: analytics.rankings.isEmpty
                ? 'No rankings yet'
                : 'Top ${analytics.rankings.length}',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _AnalyticsChip(
                label: 'Highest',
                value: '${analytics.highest ?? '-'}',
                color: const Color(0xFF16A34A),
              ),
              _AnalyticsChip(
                label: 'Lowest',
                value: '${analytics.lowest ?? '-'}',
                color: const Color(0xFFEA580C),
              ),
              _AnalyticsChip(
                label: 'Average',
                value: analytics.average?.toStringAsFixed(2) ?? '-',
                color: const Color(0xFF2563EB),
              ),
            ],
          ),
          if (analytics.rankings.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final ranking in analytics.rankings)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GlassListRow(
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${ranking.rank}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ranking.studentName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${ranking.marks} marks',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AnalyticsChip extends StatelessWidget {
  const _AnalyticsChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class ExamEditorValues {
  const ExamEditorValues({
    required this.name,
    required this.date,
    required this.totalMarks,
  });

  final String name;
  final String date;
  final num totalMarks;
}

Future<ExamEditorValues?> showExamEditor(BuildContext context) async {
  final name = TextEditingController();
  final date = TextEditingController(
    text: AppDateFormats.storage(DateTime.now()),
  );
  final total = TextEditingController(text: '100');

  final result = await showDialog<ExamEditorValues>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Define Examination'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Examination Name',
              ),
            ),
            DatePickerField(
              controller: date,
              label: 'Examination Date',
              required: true,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            ),
            TextField(
              controller: total,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total Marks'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = num.tryParse(total.text);
            final dateError = AppValidators.date(date.text, 'Examination date');
            if (name.text.trim().isNotEmpty &&
                dateError == null &&
                value != null) {
              Navigator.pop(
                context,
                ExamEditorValues(
                  name: name.text.trim(),
                  date: date.text.trim(),
                  totalMarks: value,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    dateError ??
                        'Enter an examination name and valid total marks.',
                  ),
                ),
              );
            }
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );

  name.dispose();
  date.dispose();
  total.dispose();
  return result;
}

