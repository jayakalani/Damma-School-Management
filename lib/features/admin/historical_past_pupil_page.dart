import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/widgets/date_picker_field.dart';
import '../../app/widgets/glass_admin_ui.dart';

import '../../core/past_pupils/past_pupil_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/app_validators.dart';

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
  final search = TextEditingController();
  final yearCompleted = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
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
    yearCompleted.dispose();
    super.dispose();
  }

  void reload() {
    batches = repository.listBatches(
      database: widget.database,
      adminId: adminId,
      query: search.text,
      yearCompleted: int.tryParse(yearCompleted.text.trim()),
      startDate: startDate,
      endDate: endDate,
    );
  }

  void refreshList() => setState(reload);

  void _resetFilters() {
    setState(() {
      search.clear();
      yearCompleted.clear();
      startDate = null;
      endDate = null;
      reload();
    });
  }

  Future<void> chooseStart() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(1950),
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
      firstDate: DateTime(1950),
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
  Widget build(BuildContext context) {
    if (!widget.auth.canAccess(role: 'admin') &&
        !widget.auth.canAccess(role: 'staff')) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final currentYear = DateTime.now().year;

    return GlassAdminPage(
      title: 'Historical Past Pupils',
      subtitle: 'Manage legacy alumni batches and records',
      toolbar: GlassToolbarButton(
        label: 'Create Legacy Batch',
        icon: Icons.add_rounded,
        accent: accent,
        onPressed: addBatch,
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: batches,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.hasError
                  ? const Text('Unable to load legacy batches.')
                  : const CircularProgressIndicator(),
            );
          }

          final allBatches = snapshot.data!;
          final recentCount = allBatches
              .where((b) => b['year_completed'] == currentYear)
              .length;
          final withNotes = allBatches
              .where((b) => (b['notes'] as String?)?.isNotEmpty == true)
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
                      label: 'Completed This Year',
                      value: '$recentCount',
                      valueColor: const Color(0xFF2563EB),
                      accentColor: const Color(0xFF2563EB),
                    ),
                    GlassSummaryStatCard(
                      label: 'With Notes',
                      value: '$withNotes',
                      valueColor: const Color(0xFF7C3AED),
                      accentColor: const Color(0xFF7C3AED),
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
                      final yearWidth = compact ? maxWidth : 160.0;

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
                                hint: 'Search by name...',
                                prefixIcon: Icons.search_rounded,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: yearWidth,
                            child: TextField(
                              controller: yearCompleted,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => refreshList(),
                              decoration: glassInputDecoration(
                                context,
                                hint: 'Year completed',
                                prefixIcon: Icons.calendar_today_outlined,
                              ),
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
                        title: 'Legacy Batch Directory',
                        icon: Icons.history_edu,
                        countLabel: '${allBatches.length} shown',
                      ),
                      const SizedBox(height: 16),
                      if (allBatches.isEmpty)
                        const GlassEmptyState(
                          icon: Icons.history_edu,
                          message: 'No legacy alumni batches found.',
                        )
                      else ...[
                        const GlassTableHeader(
                          columns: [
                            'ID',
                            'BATCH NAME',
                            'YEAR COMPLETED',
                            'ACTIONS',
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final batch in allBatches)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlassListRow(
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
                                    flex: 3,
                                    child: Text(
                                      '${batch['year_completed']}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: GlassActionChipButton(
                                      label: 'Add Pupil',
                                      color: accent,
                                      onPressed: () =>
                                          addPupil(batch['id']! as int),
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

class LegacyBatchEditorValues {
  const LegacyBatchEditorValues(this.name, this.year, this.notes);

  final String name;
  final int year;
  final String notes;
}

Future<LegacyBatchEditorValues?> showLegacyBatchEditor(BuildContext context) async {
  final name = TextEditingController();
  final year = TextEditingController(text: DateTime.now().year.toString());
  final notes = TextEditingController();

  final result = await showDialog<LegacyBatchEditorValues>(
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
            if (name.text.trim().isNotEmpty && value != null) {
              Navigator.pop(
                context,
                LegacyBatchEditorValues(name.text.trim(), value, notes.text.trim()),
              );
            }
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
            if (fields['full_name']!.text.trim().isNotEmpty) {
              final message =
                  AppValidators.nic(fields['nic']!.text) ??
                  AppValidators.phone(fields['phone_number']!.text) ??
                  AppValidators.optionalDate(fields['date_of_birth']!.text);

              if (message != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
                return;
              }

              Navigator.pop(context, {
                for (final entry in fields.entries)
                  entry.key: entry.value.text.trim(),
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Full name is required.')),
              );
            }
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

