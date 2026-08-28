import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/services/auth_service.dart';
import '../../core/teachers/teacher_repository.dart';
import '../../core/utils/app_validators.dart';

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
  String? statusFilter;
  late Future<List<Map<String, Object?>>> teachers;

  int get adminId => widget.auth.currentSession!.userId;

  @override
  void initState() {
    super.initState();
    widget.auth.requireRole('admin');
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
    );
  }

  void refreshList() => setState(reload);

  Future<void> addTeacher() async {
    final values = await showTeacherEditor(context);
    if (values == null || !mounted) return;
    await _perform(() async {
      await repository.createTeacher(
        database: widget.database,
        adminId: adminId,
        details: values.details,
        qualifications: values.qualifications,
      );
      _message('Teacher added.');
      refreshList();
    });
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
    await _perform(() async {
      await repository.updateTeacher(
        database: widget.database,
        adminId: adminId,
        teacherId: teacher['id']! as int,
        details: values.details,
        qualifications: values.qualifications,
      );
      _message('Teacher updated.');
      refreshList();
    });
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
    await _perform(() async {
      await repository.setTeacherStatus(
        database: widget.database,
        adminId: adminId,
        teacherId: teacher['id']! as int,
        active: !active,
      );
      _message(active ? 'Teacher deactivated.' : 'Teacher activated.');
      refreshList();
    });
  }

  Future<void> _perform(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      _message('Unable to complete the teacher operation.', error: true);
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
    widget.auth.requireRole('admin');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teachers'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        labelText: 'Search teachers',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String?>(
                    value: statusFilter,
                    hint: const Text('All statuses'),
                    items: const [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All statuses'),
                      ),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive'),
                      ),
                    ],
                    onChanged: (value) {
                      statusFilter = value;
                      refreshList();
                    },
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: refreshList,
                    icon: const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: addTeacher,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Teacher'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: teachers,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return const Center(
                      child: Text('Unable to load teachers.'),
                    );
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.data!.isEmpty)
                    return const Center(child: Text('No teachers found.'));
                  return Card(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: snapshot.data!.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final teacher = snapshot.data![index];
                        final active = teacher['status'] == 'active';
                        return ListTile(
                          leading: Icon(
                            active
                                ? Icons.check_circle_outline
                                : Icons.pause_circle_outline,
                            color: active ? Colors.green : Colors.grey,
                          ),
                          title: Text(teacher['full_name']! as String),
                          subtitle: Text(
                            '${teacher['name_with_initials']} | Registered ${teacher['registered_date']}',
                          ),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => editTeacher(teacher),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: active ? 'Deactivate' : 'Activate',
                                onPressed: () => toggleStatus(teacher),
                                icon: Icon(
                                  active
                                      ? Icons.person_off_outlined
                                      : Icons.person_outline,
                                ),
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
}

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
      ? DateTime.now().toIso8601String().split('T').first
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
  for (final controller in fields.values) controller.dispose();
  for (final draft in drafts) draft.dispose();
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
