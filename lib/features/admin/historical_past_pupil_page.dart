import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/past_pupils/past_pupil_repository.dart';
import '../../core/services/auth_service.dart';

class HistoricalPastPupilPage extends StatefulWidget {
  const HistoricalPastPupilPage({
    super.key,
    required this.database,
    required this.auth,
  });
  final Database database;
  final AuthService auth;
  @override
  State<HistoricalPastPupilPage> createState() =>
      _HistoricalPastPupilPageState();
}

class _HistoricalPastPupilPageState extends State<HistoricalPastPupilPage> {
  final repository = PastPupilRepository();
  late Future<List<Map<String, Object?>>> batches;
  int get adminId => widget.auth.currentSession!.userId;
  @override
  void initState() {
    super.initState();
    widget.auth.requireRole('admin');
    reload();
  }

  void reload() {
    batches = repository.listBatches(
      database: widget.database,
      adminId: adminId,
    );
  }

  Future<void> addBatch() async {
    final value = await showLegacyBatchEditor(context);
    if (value == null || !mounted) return;
    try {
      await repository.createBatch(
        database: widget.database,
        adminId: adminId,
        name: value.name,
        year: value.year,
        notes: value.notes,
      );
      _message('Legacy alumni batch created.');
      setState(reload);
    } catch (_) {
      _message('Unable to create alumni batch.', error: true);
    }
  }

  Future<void> addPupil(int batchId) async {
    final value = await showLegacyPupilEditor(context);
    if (value == null || !mounted) return;
    try {
      await repository.addPupil(
        database: widget.database,
        adminId: adminId,
        batchId: batchId,
        details: value,
      );
      _message('Historical past pupil added.');
      setState(reload);
    } catch (_) {
      _message('Unable to add past pupil.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Historical Past Pupils'),
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
              onPressed: addBatch,
              icon: const Icon(Icons.add),
              label: const Text('Create Legacy Batch'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: batches,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(
                    child: snapshot.hasError
                        ? const Text('Unable to load legacy batches.')
                        : const CircularProgressIndicator(),
                  );
                if (snapshot.data!.isEmpty)
                  return const Center(
                    child: Text('No legacy alumni batches found.'),
                  );
                return ListView(
                  children: [
                    for (final batch in snapshot.data!)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.history_edu),
                          title: Text(batch['batch_name']! as String),
                          subtitle: Text(
                            'Year completed: ${batch['year_completed']}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Add past pupil',
                            onPressed: () => addPupil(batch['id']! as int),
                            icon: const Icon(Icons.person_add_outlined),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
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

class _LegacyBatchValue {
  const _LegacyBatchValue(this.name, this.year, this.notes);
  final String name, notes;
  final int year;
}

Future<_LegacyBatchValue?> showLegacyBatchEditor(BuildContext context) async {
  final name = TextEditingController();
  final year = TextEditingController(text: DateTime.now().year.toString());
  final notes = TextEditingController();
  final result = await showDialog<_LegacyBatchValue>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Create Legacy Batch'),
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
            decoration: const InputDecoration(labelText: 'Year Completed'),
          ),
          TextField(
            controller: notes,
            decoration: const InputDecoration(labelText: 'Notes'),
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
            if (name.text.trim().isNotEmpty && value != null)
              Navigator.pop(
                context,
                _LegacyBatchValue(name.text.trim(), value, notes.text.trim()),
              );
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
  name.dispose();
  year.dispose();
  notes.dispose();
  return result;
}

Future<Map<String, Object?>?> showLegacyPupilEditor(
  BuildContext context,
) async {
  final keys = [
    'full_name',
    'name_with_initials',
    'date_of_birth',
    'nic',
    'phone_number',
    'address',
    'notes',
  ];
  final fields = {for (final key in keys) key: TextEditingController()};
  final result = await showDialog<Map<String, Object?>>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add Historical Past Pupil'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in fields.entries)
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
            if (fields['full_name']!.text.trim().isNotEmpty)
              Navigator.pop(context, {
                for (final entry in fields.entries)
                  entry.key: entry.value.text.trim(),
              });
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  for (final field in fields.values) field.dispose();
  return result;
}

String _studentLabel(String key) => key
    .split('_')
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join(' ');
