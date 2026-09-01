import 'package:flutter/material.dart';

import '../../app/widgets/date_picker_field.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/batches/batch_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/students/student_repository.dart';
import '../../core/utils/app_validators.dart';

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
    );
  }

  void refreshList() => setState(reload);

  Future<void> addStudent() async {
    final values = await showStudentEditor(context);
    if (values == null || !mounted) return;
    try {
      await repository.createStudent(
        database: widget.database,
        adminId: adminId,
        details: values,
      );
      _message('Student registered.');
      refreshList();
    } catch (_) {
      _message('Unable to register student.', error: true);
    }
  }

  Future<void> editStudent(Map<String, Object?> student) async {
    final values = await showStudentEditor(context, student: student);
    if (values == null || !mounted) return;
    try {
      await repository.updateStudent(
        database: widget.database,
        adminId: adminId,
        studentId: student['id']! as int,
        details: values,
      );
      _message('Student updated.');
      refreshList();
    } catch (_) {
      _message('Unable to update student.', error: true);
    }
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
    try {
      await repository.convertToPastPupil(
        database: widget.database,
        adminId: adminId,
        studentId: student['id']! as int,
      );
      _message('Student converted to past pupil.');
      refreshList();
    } catch (_) {
      _message('Unable to convert student.', error: true);
    }
  }

  Future<void> bulkConvert() async {
    final batches = await BatchRepository().listBatches(
      database: widget.database,
      adminId: adminId,
    );
    if (!mounted) return;
    final batchId = await showBatchPicker(context, batches);
    if (batchId == null || !mounted) return;
    try {
      final count = await repository.bulkConvertBatchToPastPupils(
        database: widget.database,
        adminId: adminId,
        batchId: batchId,
      );
      _message('$count students converted to past pupils.');
      refreshList();
    } catch (_) {
      _message('Unable to complete bulk conversion.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.auth.canAccess(role: 'admin') && !widget.auth.canAccess(role: 'staff')) {
      return const SizedBox.shrink();
    }
    return Scaffold(
      appBar: AppBar(
      title: const Text('Student Management'),
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: constraints.maxWidth < 720
                      ? constraints.maxWidth
                      : 320,
                  child: TextField(
                    controller: search,
                    onChanged: (_) => refreshList(),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Search students',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String?>(
                  value: status,
                  hint: const Text('All statuses'),
                  items: const [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All statuses'),
                    ),
                    DropdownMenuItem(value: 'student', child: Text('Students')),
                    DropdownMenuItem(
                      value: 'past_pupil',
                      child: Text('Past Pupils'),
                    ),
                  ],
                  onChanged: (value) {
                    status = value;
                    refreshList();
                  },
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: refreshList,
                  icon: const Icon(Icons.refresh),
                ),
                FilledButton.icon(
                  onPressed: bulkConvert,
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Convert Batch'),
                ),
                FilledButton.icon(
                  onPressed: addStudent,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Register Student'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: students,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Unable to load students.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.isEmpty) {
                  return const Center(child: Text('No students found.'));
                }
                return Card(
                  child: ListView.separated(
                    itemCount: snapshot.data!.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final student = snapshot.data![index];
                      final live = student['status'] == 'student';
                      return ListTile(
                        leading: Icon(
                          live ? Icons.person_outline : Icons.school_outlined,
                        ),
                        title: Text(student['full_name']! as String),
                        subtitle: Text(
                          '${student['name_with_initials']} | ${live ? 'Student' : 'Past Pupil'}',
                        ),
                        trailing: Wrap(
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () => editStudent(student),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            if (live)
                              IconButton(
                                tooltip: 'Convert to past pupil',
                                onPressed: () => convertStudent(student),
                                icon: const Icon(Icons.school_outlined),
                              ),
                          ],
                        ),
                      );
                    },
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

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
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
