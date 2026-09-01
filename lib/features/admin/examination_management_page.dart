import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/examinations/examination_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/app_validators.dart';

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
  }

  Future<void> createExam() async {
    final histories = await repository.listBatchYears(
      database: widget.database,
      adminId: adminId,
    );
    if (!mounted) return;

    final value = await showExamEditor(context, histories);
    if (value == null || !mounted) return;

    try {
      await repository.createExamination(
        database: widget.database,
        adminId: adminId,
        batchHistoryId: value.historyId,
        name: value.name,
        date: value.date,
        totalMarks: value.totalMarks,
      );
      _message('Examination created.');
      setState(reload);
    } catch (_) {
      _message('Unable to create examination.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.auth.canAccess(role: 'admin') &&
        !widget.auth.canAccess(role: 'staff')) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Examinations'),
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
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: createExam,
                icon: const Icon(Icons.add),
                label: const Text('Define Examination'),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: examinations,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: snapshot.hasError
                          ? const Text('Unable to load examinations.')
                          : const CircularProgressIndicator(),
                    );
                  }
                  if (snapshot.data!.isEmpty) {
                    return const Center(child: Text('No examinations defined.'));
                  }

                  return Card(
                    child: ListView.separated(
                      itemCount: snapshot.data!.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final exam = snapshot.data![index];
                        return ListTile(
                          leading: const Icon(Icons.assignment_outlined),
                          title: Text(exam['examination_name']! as String),
                          subtitle: Text(
                            '${exam['batch_name']} | ${exam['academic_year']} - ${exam['grade']} | Total ${exam['total_marks']}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MarksEntryPage(
                                database: widget.database,
                                auth: widget.auth,
                                examinationId: exam['id']! as int,
                              ),
                            ),
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

class MarksEntryPage extends StatefulWidget {
  const MarksEntryPage({
    super.key,
    required this.database,
    required this.auth,
    required this.examinationId,
  });

  final Database database;
  final AuthService auth;
  final int examinationId;

  @override
  State<MarksEntryPage> createState() => _MarksEntryPageState();
}

class _MarksEntryPageState extends State<MarksEntryPage> {
  final repository = ExaminationRepository();
  late Future<ExaminationDetails> details;
  final marks = <int, TextEditingController>{};
  final attendance = <int, bool>{};

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
        )
        .then((value) {
          for (final student in value.students) {
            final id = student['id']! as int;
            marks[id] = TextEditingController(
              text: student['marks']?.toString() ?? '',
            );
            attendance[id] = student['attendance_status'] != 'absent';
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

  Future<void> save(ExaminationDetails data) async {
    try {
      final results = [
        for (final student in data.students)
          ExamMarkInput(
            studentId: student['id']! as int,
            attendanceStatus: attendance[student['id']! as int] == true
                ? 'present'
                : 'absent',
            marks: num.tryParse(marks[student['id']! as int]!.text.trim()),
          ),
      ];

      await repository.saveResults(
        database: widget.database,
        adminId: adminId,
        examinationId: widget.examinationId,
        results: results,
      );
      _message('Marks saved.');
      setState(load);
    } on InvalidExamResultException {
      _message(
        'Present students need valid marks within the total.',
        error: true,
      );
    } catch (_) {
      _message('Unable to save marks.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Marks Entry')),
    body: FutureBuilder<ExaminationDetails>(
      future: details,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: snapshot.hasError
                ? const Text('Unable to load examination.')
                : const CircularProgressIndicator(),
          );
        }

        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              data.examination['examination_name']! as String,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              '${data.examination['batch_name']} | ${data.examination['academic_year']} - ${data.examination['grade']} | Total marks: ${data.examination['total_marks']}',
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  for (final student in data.students)
                    _MarkRow(
                      student: student,
                      mark: marks[student['id']! as int]!,
                      present: attendance[student['id']! as int] == true,
                      onAttendance: (value) => setState(
                        () => attendance[student['id']! as int] = value,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => save(data),
              icon: const Icon(Icons.save),
              label: const Text('Save Marks'),
            ),
            const SizedBox(height: 24),
            AnalyticsPanel(analytics: data.analytics),
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

class _MarkRow extends StatelessWidget {
  const _MarkRow({
    required this.student,
    required this.mark,
    required this.present,
    required this.onAttendance,
  });

  final Map<String, Object?> student;
  final TextEditingController mark;
  final bool present;
  final ValueChanged<bool> onAttendance;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(student['full_name']! as String)),
        Switch(value: present, onChanged: onAttendance),
        Text(present ? 'Present' : 'Absent'),
        const SizedBox(width: 16),
        SizedBox(
          width: 120,
          child: TextField(
            controller: mark,
            enabled: present,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Marks'),
          ),
        ),
      ],
    ),
  );
}

class AnalyticsPanel extends StatelessWidget {
  const AnalyticsPanel({
    super.key,
    required this.analytics,
  });

  final ExaminationAnalytics analytics;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Analytics', style: Theme.of(context).textTheme.titleLarge),
          Text(
            'Present: ${analytics.presentCount} | Absent: ${analytics.absentCount}',
          ),
          Text(
            'Highest: ${analytics.highest ?? '-'} | Lowest: ${analytics.lowest ?? '-'} | Average: ${analytics.average?.toStringAsFixed(2) ?? '-'}',
          ),
          const SizedBox(height: 8),
          for (final ranking in analytics.rankings)
            ListTile(
              dense: true,
              leading: Text('${ranking.rank}.'),
              title: Text(ranking.studentName),
              trailing: Text('${ranking.marks} marks'),
            ),
        ],
      ),
    ),
  );
}

class ExamEditorValues {
  const ExamEditorValues({
    required this.historyId,
    required this.name,
    required this.date,
    required this.totalMarks,
  });

  final int historyId;
  final String name;
  final String date;
  final num totalMarks;
}

Future<ExamEditorValues?> showExamEditor(
  BuildContext context,
  List<Map<String, Object?>> histories,
) async {
  final name = TextEditingController();
  final date = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );
  final total = TextEditingController(text: '100');
  int? historyId = histories.isEmpty ? null : histories.first['id']! as int;

  final result = await showDialog<ExamEditorValues>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Define Examination'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: historyId,
                decoration: const InputDecoration(
                  labelText: 'Batch and Academic Year',
                ),
                items: [
                  for (final history in histories)
                    DropdownMenuItem(
                      value: history['id']! as int,
                      child: Text(
                        '${history['batch_name']} | ${history['academic_year']} - ${history['grade']}',
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => historyId = value),
              ),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Examination Name',
                ),
              ),
              TextField(
                controller: date,
                decoration: const InputDecoration(
                  labelText: 'Examination Date',
                ),
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
              final selectedHistoryId = historyId;
              if (selectedHistoryId != null &&
                  name.text.trim().isNotEmpty &&
                  dateError == null &&
                  value != null) {
                Navigator.pop(
                  context,
                  ExamEditorValues(
                    historyId: selectedHistoryId,
                    name: name.text.trim(),
                    date: date.text.trim(),
                    totalMarks: value,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      dateError ?? 'Enter an examination name and valid total marks.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );

  name.dispose();
  date.dispose();
  total.dispose();
  return result;
}

