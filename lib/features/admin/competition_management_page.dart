import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/widgets/date_picker_field.dart';
import '../../app/widgets/glass_admin_ui.dart';
import '../../core/competitions/competition_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/app_validators.dart';
import '../../core/utils/error_messages.dart';

class CompetitionManagementPage extends StatefulWidget {
  const CompetitionManagementPage({
    super.key,
    required this.database,
    required this.auth,
  });

  final Database database;
  final AuthService auth;

  @override
  State<CompetitionManagementPage> createState() =>
      _CompetitionManagementPageState();
}

class _CompetitionManagementPageState extends State<CompetitionManagementPage> {
  final repository = CompetitionRepository();
  final nameController = TextEditingController();
  final dateController = TextEditingController(
    text: AppDateFormats.storage(DateTime.now()),
  );
  final venueController = TextEditingController();
  final descriptionController = TextEditingController();
  var isSaving = false;
  late Future<List<Map<String, Object?>>> competitions;

  int get adminId => widget.auth.currentSession!.userId;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    nameController.dispose();
    dateController.dispose();
    venueController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void reload() {
    competitions = repository.listCompetitions(
      database: widget.database,
      adminId: adminId,
    );
  }

  void _clearForm() {
    nameController.clear();
    dateController.text = AppDateFormats.storage(DateTime.now());
    venueController.clear();
    descriptionController.clear();
  }

  Future<void> createCompetition() async {
    final name = nameController.text.trim();
    final date = dateController.text.trim();
    final dateError = AppValidators.date(date, 'Competition date');
    if (name.isEmpty || dateError != null) {
      _message(dateError ?? 'Enter a competition name and date.');
      return;
    }

    setState(() => isSaving = true);
    try {
      await repository.createCompetition(
        database: widget.database,
        adminId: adminId,
        name: name,
        date: date,
        venue: venueController.text,
        description: descriptionController.text,
      );
      _clearForm();
      _message('Competition created.');
      setState(reload);
    } catch (error) {
      _message(
        userFacingError(error, fallback: 'Unable to create competition.'),
        error: true,
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.auth.canAccess(role: 'staff')) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return GlassAdminPage(
      title: 'Competitions',
      subtitle: 'Create and view school competitions',
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: competitions,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        userFacingError(
                          snapshot.error!,
                          fallback: 'Unable to load competitions.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : const CircularProgressIndicator(),
            );
          }

          final allCompetitions = snapshot.data!;
          final currentYear = DateTime.now().year;
          final thisYearCount = allCompetitions
              .where(
                (row) =>
                    '${row['competition_date']}'.startsWith('$currentYear'),
              )
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
                      label: 'Total Competitions',
                      value: '${allCompetitions.length}',
                      valueColor: theme.colorScheme.onSurface,
                      accentColor: accent,
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
                        title: 'Create Competition',
                        icon: Icons.emoji_events_outlined,
                        countLabel: 'New entry',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Competition Name *',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      DatePickerField(
                        controller: dateController,
                        label: 'Competition Date',
                        required: true,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: venueController,
                        decoration: const InputDecoration(
                          labelText: 'Venue',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          alignLabelWithHint: true,
                        ),
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: isSaving ? null : createCompetition,
                          icon: isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_rounded),
                          label: Text(
                            isSaving ? 'Saving…' : 'Create Competition',
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
                        title: 'Competition Directory',
                        icon: Icons.list_alt_rounded,
                        countLabel: '${allCompetitions.length} shown',
                      ),
                      const SizedBox(height: 16),
                      if (allCompetitions.isEmpty)
                        const GlassEmptyState(
                          icon: Icons.emoji_events_outlined,
                          message: 'No competitions created yet.',
                        )
                      else ...[
                        const GlassTableHeader(
                          columns: [
                            'ID',
                            'COMPETITION',
                            'DATE',
                            'VENUE',
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final competition in allCompetitions)
                          _CompetitionRow(competition: competition),
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

class _CompetitionRow extends StatelessWidget {
  const _CompetitionRow({required this.competition});

  final Map<String, Object?> competition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venue = competition['venue']?.toString().trim();
    final description = competition['description']?.toString().trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassListRow(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    '#${competition['id']}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    competition['competition_name']! as String,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${competition['competition_date']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    (venue == null || venue.isEmpty) ? '—' : venue,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
