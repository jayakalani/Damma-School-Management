import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/widgets/glass_admin_ui.dart';
import '../../core/batches/batch_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/teachers/teacher_repository.dart';
import '../../core/utils/error_messages.dart';

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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Batch Details')),
    body: FutureBuilder<BatchDetails>(
      future: details,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: snapshot.hasError
                ? const Text('Unable to load batch details.')
                : const CircularProgressIndicator(),
          );
        }

        final data = snapshot.data!;
        final current = data.history.lastWhere(
          (row) => row['is_current'] == 1,
          orElse: () => data.history.last,
        );

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.batch['batch_name']! as String,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => promote(data),
                  icon: const Icon(Icons.upgrade),
                  label: const Text('Promote Batch'),
                ),
              ],
            ),
            Text('Starting year: ${data.batch['starting_year']}'),
            Text(
              'Current: ${current['academic_year']} | Grade ${current['grade']}',
            ),
            const SizedBox(height: 24),
            _Section(
              title: 'Batch History',
              children: [
                for (final row in data.history)
                  ListTile(
                    leading: Icon(
                      row['is_current'] == 1
                          ? Icons.radio_button_checked
                          : Icons.history,
                    ),
                    title: Text(
                      'Academic year ${row['academic_year']} - Grade ${row['grade']}',
                    ),
                    subtitle: Text(
                      'Started ${row['started_date']}${row['ended_date'] == null ? '' : ' | Ended ${row['ended_date']}'}',
                    ),
                  ),
              ],
            ),
            _Section(
              title: 'Students',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: addStudent,
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Add Student'),
                    ),
                  ),
                ),
                if (data.students.isEmpty)
                  const ListTile(title: Text('No students assigned.'))
                else
                  for (final row in data.students)
                    ListTile(
                      title: Text(row['full_name']! as String),
                      subtitle: Text(
                        '${row['is_current'] == 1 ? 'Current' : 'Historical'} | Joined ${row['joined_date']}${row['left_date'] == null ? '' : ' | Left ${row['left_date']}'}',
                      ),
                    ),
              ],
            ),
            _Section(
              title: 'Teachers',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => assignTeacher(data),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Assign Class Teacher'),
                    ),
                  ),
                ),
                if (data.teachers.isEmpty)
                  const ListTile(title: Text('No teachers assigned.'))
                else
                  for (final row in data.teachers)
                    ListTile(
                      title: Text(row['full_name']! as String),
                      subtitle: Text(
                        '${row['is_current'] == 1 ? 'Current' : 'Historical'} | Assigned ${row['assigned_date']}${row['removed_date'] == null ? '' : ' | Removed ${row['removed_date']}'}',
                      ),
                    ),
              ],
            ),
            _Section(
              title: 'Examinations',
              children: [
                if (data.examinations.isEmpty)
                  const ListTile(title: Text('No examinations recorded.'))
                else
                  for (final row in data.examinations)
                    ListTile(
                      title: Text(row['examination_name']! as String),
                      subtitle: Text(
                        '${row['examination_date']} | ${row['academic_year']} - Grade ${row['grade']}',
                      ),
                    ),
              ],
            ),
          ],
        );
      },
    ),
  );

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ...children,
      ],
    ),
  );
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

