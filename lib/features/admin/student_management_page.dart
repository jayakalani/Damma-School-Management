import 'package:flutter/material.dart';

import '../../app/widgets/date_picker_field.dart';
import '../../app/widgets/glass_admin_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/batches/batch_repository.dart';
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
  String? status;
  DateTime? startDate;
  DateTime? endDate;
  late Future<List<Map<String, Object?>>> students;
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
    students = repository.searchStudents(
      database: widget.database,
      adminId: adminId,
      query: search.text,
      status: status,
      startDate: startDate,
      endDate: endDate,
    );
  }

  void refreshList() => setState(reload);

  void _resetFilters() {
    setState(() {
      search.clear();
      status = null;
      startDate = null;
      endDate = null;
      reload();
    });
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
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: students,
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

          final allStudents = snapshot.data!;
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
                              key: ValueKey(status),
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
