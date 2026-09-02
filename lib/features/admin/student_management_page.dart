import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../app/widgets/date_picker_field.dart';
import '../../app/widgets/glass_admin_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/batches/batch_repository.dart';
import '../../core/export/student_export_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/students/student_repository.dart';
import '../../core/utils/app_validators.dart';
import '../../core/utils/error_messages.dart';

class StudentManagementPage extends StatefulWidget {
  const StudentManagementPage({
    super.key,
    required this.database,
    required this.auth,
  });
  final Database database;
  final AuthService auth;
  @override
  State<StudentManagementPage> createState() => _StudentManagementPageState();
}

class _StudentManagementPageState extends State<StudentManagementPage> {
  final search = TextEditingController();
  final repository = StudentRepository();
  final batchRepository = BatchRepository();
  final exportService = const StudentExportService();
  String? status;
  int? batchId;
  DateTime? startDate;
  DateTime? endDate;
  late Future<List<Map<String, Object?>>> students;
  late Future<List<Map<String, Object?>>> batches;
  int get adminId => widget.auth.currentSession!.userId;
  @override
  void initState() {
    super.initState();
    batches = batchRepository.listBatches(
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
    students = repository.searchStudents(
      database: widget.database,
      adminId: adminId,
      query: search.text,
      status: status,
      batchId: batchId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  void refreshList() => setState(reload);

  void _resetFilters() {
    setState(() {
      search.clear();
      status = null;
      batchId = null;
      startDate = null;
      endDate = null;
      reload();
    });
  }

  StudentExportFilters _exportFilters(List<Map<String, Object?>> batchRows) {
    String? batchName;
    if (batchId != null) {
      for (final batch in batchRows) {
        if (batch['id'] == batchId) {
          batchName = batch['batch_name'] as String?;
          break;
        }
      }
    }
    return StudentExportFilters(
      searchQuery: search.text,
      statusFilter: status,
      batchName: batchName,
      startDate: startDate,
      endDate: endDate,
    );
  }

  String _exportTimestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _exportCsv() async {
    try {
      final exportedStudents = await students;
      final batchRows = await batches;
      final location = await getSaveLocation(
        suggestedName: 'students_${_exportTimestamp()}.csv',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null) return;
      await exportService.writeTextFile(
        path: location.path,
        contents: exportService.buildCsv(
          exportedStudents,
          filters: _exportFilters(batchRows),
        ),
      );
      _message(
        'Student CSV exported (${exportedStudents.length} record(s)).',
      );
    } catch (_) {
      _message('Unable to export student CSV.', error: true);
    }
  }

  Future<void> _exportPdf() async {
    try {
      final exportedStudents = await students;
      final batchRows = await batches;
      final location = await getSaveLocation(
        suggestedName: 'students_${_exportTimestamp()}.pdf',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'PDF', extensions: ['pdf']),
        ],
      );
      if (location == null) return;
      final bytes = await exportService.buildPdf(
        exportedStudents,
        filters: _exportFilters(batchRows),
      );
      await exportService.writeBytesFile(path: location.path, bytes: bytes);
      _message(
        'Student PDF exported (${exportedStudents.length} record(s)).',
      );
    } catch (_) {
      _message('Unable to export student PDF.', error: true);
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

  Future<void> toggleStudentStatus(Map<String, Object?> student) async {
    if (student['status'] != 'student') return;
    final active = _isStudentActive(student);
    try {
      await repository.setStudentActive(
        database: widget.database,
        adminId: adminId,
        studentId: student['id']! as int,
        active: !active,
      );
      _message(active ? 'Student deactivated.' : 'Student activated.');
      refreshList();
    } catch (error) {
      _message(
        userFacingError(error, fallback: 'Unable to change student status.'),
        error: true,
      );
    }
  }

  Future<void> addStudent() async {
    final values = await showStudentEditor(context);
    if (values == null || !mounted) return;
    await _perform(
      operation: () async {
        await repository.createStudent(
          database: widget.database,
          adminId: adminId,
          details: values,
        );
        _message('Student registered.');
        refreshList();
      },
      failureMessage: 'Unable to register student.',
    );
  }

  Future<void> viewStudent(Map<String, Object?> student) async {
    await showStudentDetails(context, student: student);
  }

  Future<void> editStudent(Map<String, Object?> student) async {
    final values = await showStudentEditor(context, student: student);
    if (values == null || !mounted) return;
    await _perform(
      operation: () async {
        await repository.updateStudent(
          database: widget.database,
          adminId: adminId,
          studentId: student['id']! as int,
          details: values,
        );
        _message('Student updated.');
        refreshList();
      },
      failureMessage: 'Unable to update student.',
    );
  }

  Future<void> convertStudent(Map<String, Object?> student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert to Past Pupil?'),
        content: Text(
          'Convert ${student['full_name']} without deleting history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _perform(
      operation: () async {
        await repository.convertToPastPupil(
          database: widget.database,
          adminId: adminId,
          studentId: student['id']! as int,
        );
        _message('Student converted to past pupil.');
        refreshList();
      },
      failureMessage: 'Unable to convert student.',
    );
  }

  Future<void> bulkConvert() async {
    final batches = await BatchRepository().listBatches(
      database: widget.database,
      adminId: adminId,
    );
    if (!mounted) return;
    final batchId = await showBatchPicker(context, batches);
    if (batchId == null || !mounted) return;
    await _perform(
      operation: () async {
        final count = await repository.bulkConvertBatchToPastPupils(
          database: widget.database,
          adminId: adminId,
          batchId: batchId,
        );
        _message('$count students converted to past pupils.');
        refreshList();
      },
      failureMessage: 'Unable to complete bulk conversion.',
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

  @override
  Widget build(BuildContext context) {
    if (!widget.auth.canAccess(role: 'staff')) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final canRegister = widget.auth.currentSession!.isStaff;

    return GlassAdminPage(
      title: 'Student Management',
      subtitle: 'Register students and manage past pupil conversions',
      toolbar: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          GlassToolbarButton(
            label: 'Export CSV',
            icon: Icons.table_chart_outlined,
            accent: const Color(0xFF16A34A),
            onPressed: _exportCsv,
          ),
          GlassToolbarButton(
            label: 'Export PDF',
            icon: Icons.picture_as_pdf_outlined,
            accent: const Color(0xFFE11D48),
            onPressed: _exportPdf,
          ),
          GlassToolbarButton(
            label: 'Convert Batch',
            icon: Icons.groups_outlined,
            accent: const Color(0xFF2563EB),
            onPressed: bulkConvert,
          ),
          if (canRegister)
            GlassToolbarButton(
              label: 'Register Student',
              icon: Icons.person_add_outlined,
              accent: accent,
              onPressed: addStudent,
            ),
        ],
      ),
      body: FutureBuilder<List<Object?>>(
        future: Future.wait<Object?>([students, batches]),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  userFacingError(
                    snapshot.error!,
                    fallback: 'Unable to load students.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allStudents =
              (snapshot.data![0] as List).cast<Map<String, Object?>>();
          final allBatches =
              (snapshot.data![1] as List).cast<Map<String, Object?>>();
          final enrolled = allStudents.where((s) => s['status'] == 'student');
          final activeCount =
              enrolled.where((s) => _isStudentActive(s)).length;
          final inactiveCount = enrolled.length - activeCount;

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
                      label: 'Total Records',
                      value: '${allStudents.length}',
                      valueColor: theme.colorScheme.onSurface,
                      accentColor: accent,
                    ),
                    GlassSummaryStatCard(
                      label: 'Active',
                      value: '$activeCount',
                      valueColor: const Color(0xFF16A34A),
                      accentColor: const Color(0xFF16A34A),
                    ),
                    GlassSummaryStatCard(
                      label: 'Inactive',
                      value: '$inactiveCount',
                      valueColor: const Color(0xFFEA580C),
                      accentColor: const Color(0xFFEA580C),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GlassPanel(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      final compact = maxWidth < 720;
                      final searchWidth = compact ? maxWidth : 240.0;
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
                              decoration: glassInputDecoration(
                                context,
                                hint: 'Search students...',
                                prefixIcon: Icons.search_rounded,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: statusWidth,
                            child: DropdownButtonFormField<String?>(
                              key: ValueKey('status-$status'),
                              initialValue: status,
                              isExpanded: true,
                              decoration: glassInputDecoration(
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
                                  value: 'student',
                                  child: Text(
                                    'Students',
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
                                DropdownMenuItem(
                                  value: 'past_pupil',
                                  child: Text(
                                    'Past Pupils',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                status = value;
                                refreshList();
                              },
                            ),
                          ),
                          SizedBox(
                            width: statusWidth,
                            child: DropdownButtonFormField<int?>(
                              key: ValueKey('batch-$batchId'),
                              initialValue: batchId,
                              isExpanded: true,
                              decoration: glassInputDecoration(
                                context,
                                hint: 'All Batches',
                              ),
                              borderRadius: BorderRadius.circular(12),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(
                                    'All Batches',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                for (final batch in allBatches)
                                  DropdownMenuItem<int?>(
                                    value: batch['id']! as int,
                                    child: Text(
                                      batch['batch_name']! as String,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (value) {
                                batchId = value;
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
                        title: 'Student Directory',
                        icon: Icons.school_outlined,
                        countLabel: '${allStudents.length} shown',
                      ),
                      const SizedBox(height: 16),
                      if (allStudents.isEmpty)
                        const GlassEmptyState(
                          icon: Icons.person_outline,
                          message: 'No students found.',
                        )
                      else ...[
                        const GlassTableHeader(
                          columns: [
                            'ID',
                            'FULL NAME',
                            'INITIALS',
                            'JOINED',
                            'STATUS',
                            'ACTIONS',
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final student in allStudents)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlassListRow(
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '#${student['id']}',
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
                                      student['full_name']! as String,
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
                                      student['name_with_initials']! as String,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      student['joined_date']! as String,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: student['status'] == 'student'
                                        ? _StudentActiveToggle(
                                            active: _isStudentActive(student),
                                            onChanged: () =>
                                                toggleStudentStatus(student),
                                          )
                                        : Text(
                                            'Past Pupil',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                              color: const Color(0xFF7C3AED),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        GlassActionChipButton(
                                          label: 'View',
                                          color: const Color(0xFF0891B2),
                                          onPressed: () =>
                                              viewStudent(student),
                                        ),
                                        GlassActionChipButton(
                                          label: 'Edit',
                                          color: const Color(0xFF2563EB),
                                          onPressed: () =>
                                              editStudent(student),
                                        ),
                                        if (student['status'] == 'student')
                                          GlassActionChipButton(
                                            label: 'Convert',
                                            color: accent,
                                            onPressed: () =>
                                                convertStudent(student),
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

bool _isStudentActive(Map<String, Object?> student) =>
    (student['is_active'] ?? 1) == 1;

String _dateLabel(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

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

class _StudentActiveToggle extends StatelessWidget {
  const _StudentActiveToggle({
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

Future<int?> showBatchPicker(
  BuildContext context,
  List<Map<String, Object?>> batches,
) => showDialog<int>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Select Batch'),
    content: SizedBox(
      width: 420,
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final batch in batches)
            ListTile(
              title: Text(batch['batch_name']! as String),
              subtitle: Text(
                '${batch['academic_year'] ?? '-'} | Grade ${batch['grade'] ?? '-'}',
              ),
              onTap: () => Navigator.pop(context, batch['id']! as int),
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

Future<Map<String, Object?>?> showStudentEditor(
  BuildContext context, {
  Map<String, Object?>? student,
}) async {
  final keys = [
    'full_name',
    'name_with_initials',
    'date_of_birth',
    'phone_number',
    'address',
    'joined_date',
  ];
  final fields = {
    for (final key in keys)
      key: TextEditingController(text: student?[key] as String?),
  };
  fields['joined_date']!.text = fields['joined_date']!.text.isEmpty
      ? AppDateFormats.storage(DateTime.now())
      : fields['joined_date']!.text;
  final result = await showDialog<Map<String, Object?>>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(student == null ? 'Register Student' : 'Edit Student'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in fields.entries)
              if (isStorageDateFieldKey(entry.key))
                datePickerForKey(
                  key: entry.key,
                  controller: entry.value,
                  label: _studentLabel(entry.key),
                )
              else
                TextField(
                  controller: entry.value,
                  decoration: InputDecoration(
                    labelText: _studentLabel(entry.key),
                  ),
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
            if (fields['full_name']!.text.trim().isEmpty ||
                fields['name_with_initials']!.text.trim().isEmpty ||
                fields['joined_date']!.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Full name, initials, and joined date are required.',
                  ),
                ),
              );
              return;
            }
            final message =
                AppValidators.phone(fields['phone_number']!.text) ??
                AppValidators.optionalDate(fields['date_of_birth']!.text) ??
                AppValidators.date(fields['joined_date']!.text, 'Joined date');
            if (message != null) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(message)));
              return;
            }
            Navigator.pop(context, {
              for (final entry in fields.entries)
                entry.key: entry.value.text.trim(),
              'nic': null,
            });
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  for (final field in fields.values) {
    field.dispose();
  }
  return result;
}

String _studentLabel(String key) => key
    .split('_')
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join(' ');

String _studentDisplayValue(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '—' : text;
}

String _studentStatusLabel(Map<String, Object?> student) {
  if (student['status'] == 'past_pupil') return 'Past Pupil';
  return _isStudentActive(student) ? 'Active' : 'Inactive';
}

Color _studentStatusColor(Map<String, Object?> student) {
  if (student['status'] == 'past_pupil') return const Color(0xFF7C3AED);
  return _isStudentActive(student)
      ? const Color(0xFF16A34A)
      : Colors.grey.shade600;
}

Future<void> showStudentDetails(
  BuildContext context, {
  required Map<String, Object?> student,
}) {
  final statusLabel = _studentStatusLabel(student);
  final statusColor = _studentStatusColor(student);
  const detailKeys = [
    'full_name',
    'name_with_initials',
    'date_of_birth',
    'nic',
    'phone_number',
    'address',
    'joined_date',
  ];

  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                student['full_name']! as String,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                statusLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StudentDetailSection(
                  title: 'Personal Information',
                  icon: Icons.person_outline,
                  children: [
                    _StudentDetailRow(
                      label: 'Student ID',
                      value: '#${student['id']}',
                    ),
                    for (final key in detailKeys)
                      _StudentDetailRow(
                        label: _studentLabel(key),
                        value: _studentDisplayValue(student[key]),
                      ),
                    _StudentDetailRow(
                      label: 'Enrollment Status',
                      value: student['status'] == 'past_pupil'
                          ? 'Past Pupil'
                          : 'Student',
                    ),
                    if (student['status'] == 'student')
                      _StudentDetailRow(
                        label: 'Active Status',
                        value: _isStudentActive(student)
                            ? 'Active'
                            : 'Inactive',
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _StudentDetailSection(
                  title: 'Record Info',
                  icon: Icons.info_outline,
                  children: [
                    _StudentDetailRow(
                      label: 'Created At',
                      value: _studentDisplayValue(student['created_at']),
                    ),
                    _StudentDetailRow(
                      label: 'Updated At',
                      value: _studentDisplayValue(student['updated_at']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

class _StudentDetailSection extends StatelessWidget {
  const _StudentDetailSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class _StudentDetailRow extends StatelessWidget {
  const _StudentDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
