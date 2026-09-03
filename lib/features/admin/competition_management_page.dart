import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/widgets/date_picker_field.dart';
import '../../app/widgets/glass_admin_ui.dart';
import '../../core/competitions/competition_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/error_messages.dart';

const _competitionCardColors = <Color>[
  Color(0xFFE11D48),
  Color(0xFFEA580C),
  Color(0xFFCA8A04),
  Color(0xFF16A34A),
  Color(0xFF0891B2),
  Color(0xFF2563EB),
  Color(0xFF7C3AED),
  Color(0xFFDB2777),
  Color(0xFF0D9488),
  Color(0xFFF59E0B),
];

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
  late Future<List<Map<String, Object?>>> competitions;

  int get adminId => widget.auth.currentSession!.userId;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    competitions = repository.listCompetitions(
      database: widget.database,
      adminId: adminId,
    );
  }

  Future<void> createCompetition() async {
    final name = await showCreateCompetitionDialog(context);
    if (name == null || !mounted) return;

    try {
      await repository.createCompetition(
        database: widget.database,
        adminId: adminId,
        name: name,
        date: AppDateFormats.storage(DateTime.now()),
      );
      _message('Competition created.');
      setState(reload);
    } catch (error) {
      _message(
        userFacingError(error, fallback: 'Unable to create competition.'),
        error: true,
      );
    }
  }

  Future<void> openCompetitionDetails(int competitionId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompetitionDetailsPage(
          database: widget.database,
          auth: widget.auth,
          competitionId: competitionId,
        ),
      ),
    );
    if (mounted) setState(reload);
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
      toolbar: GlassToolbarButton(
        label: 'Create Competition',
        icon: Icons.add_rounded,
        accent: accent,
        onPressed: createCompetition,
      ),
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

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: GlassPanel(
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
                  else
                    _coloredNameCardGrid(
                      names: [
                        for (final competition in allCompetitions)
                          competition['competition_name']! as String,
                      ],
                      icon: Icons.emoji_events_rounded,
                      colorFor: (i) => _competitionCardColors[
                          i % _competitionCardColors.length],
                      onTap: (i) => openCompetitionDetails(
                        allCompetitions[i]['id']! as int,
                      ),
                    ),
                ],
              ),
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

class _ColoredNameCard extends StatefulWidget {
  const _ColoredNameCard({
    required this.name,
    required this.icon,
    required this.borderColor,
    this.onTap,
  });

  final String name;
  final IconData icon;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  State<_ColoredNameCard> createState() => _ColoredNameCardState();
}

class _ColoredNameCardState extends State<_ColoredNameCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.borderColor;
    final tappable = widget.onTap != null;

    return MouseRegion(
      onEnter: tappable ? (_) => setState(() => _hovered = true) : null,
      onExit: tappable ? (_) => setState(() => _hovered = false) : null,
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _hovered
                    ? Color.alphaBlend(
                        color.withValues(alpha: 0.08),
                        Colors.white,
                      )
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: _hovered ? 0.35 : 0.22),
                    blurRadius: _hovered ? 14 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.icon, color: color, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (tappable)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: color.withValues(alpha: 0.8),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _coloredNameCardGrid({
  required List<String> names,
  required IconData icon,
  required Color Function(int index) colorFor,
  void Function(int index)? onTap,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = width >= 900
          ? 3
          : width >= 560
              ? 2
              : 1;
      final cardWidth = (width - (12.0 * (columns - 1))) / columns;

      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var i = 0; i < names.length; i++)
            SizedBox(
              width: cardWidth,
              child: _ColoredNameCard(
                name: names[i],
                icon: icon,
                borderColor: colorFor(i),
                onTap: onTap == null ? null : () => onTap(i),
              ),
            ),
        ],
      );
    },
  );
}

class CompetitionDetailsPage extends StatefulWidget {
  const CompetitionDetailsPage({
    super.key,
    required this.database,
    required this.auth,
    required this.competitionId,
  });

  final Database database;
  final AuthService auth;
  final int competitionId;

  @override
  State<CompetitionDetailsPage> createState() => _CompetitionDetailsPageState();
}

class _CompetitionDetailsPageState extends State<CompetitionDetailsPage> {
  final repository = CompetitionRepository();
  late Future<_CompetitionDetailsData> details;

  int get adminId => widget.auth.currentSession!.userId;
  bool get canEdit => widget.auth.currentSession!.isStaff;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    details = _load();
  }

  Future<_CompetitionDetailsData> _load() async {
    final competition = await repository.getCompetition(
      database: widget.database,
      adminId: adminId,
      competitionId: widget.competitionId,
    );
    final batches = await repository.listCompetitionBatches(
      database: widget.database,
      adminId: adminId,
      competitionId: widget.competitionId,
    );
    final sections = await repository.listCompetitionSections(
      database: widget.database,
      adminId: adminId,
      competitionId: widget.competitionId,
    );
    return _CompetitionDetailsData(
      competition: competition,
      batches: batches,
      sections: sections,
    );
  }

  Future<void> addBatches() async {
    final current = await details;
    if (!mounted) return;
    if (current.sections.isNotEmpty) {
      _message(
        'This competition uses sections. A competition cannot have batches and sections together.',
        error: true,
      );
      return;
    }

    final batches = await repository.listBatchesForCompetitionSelection(
      database: widget.database,
      adminId: adminId,
      competitionId: widget.competitionId,
    );
    if (!mounted) return;

    if (batches.isEmpty) {
      _message('No batches found to add.');
      return;
    }

    final selectableCount = batches
        .where(
          (row) =>
              (row['is_active'] ?? 1) == 1 && (row['already_linked'] ?? 0) == 0,
        )
        .length;
    if (selectableCount == 0) {
      _message('No more active batches available to add.');
      return;
    }

    final selected = await showAddCompetitionBatchesDialog(
      context,
      batches: batches,
    );
    if (selected == null || selected.isEmpty || !mounted) return;

    try {
      await repository.addBatchesToCompetition(
        database: widget.database,
        adminId: adminId,
        competitionId: widget.competitionId,
        batchIds: selected,
      );
      _message(
        selected.length == 1
            ? 'Batch added to competition.'
            : '${selected.length} batches added to competition.',
      );
      setState(reload);
    } catch (error) {
      _message(
        userFacingError(error, fallback: 'Unable to add batches.'),
        error: true,
      );
    }
  }

  Future<void> addSection() async {
    final current = await details;
    if (!mounted) return;
    if (current.batches.isNotEmpty) {
      _message(
        'This competition uses batches. A competition cannot have batches and sections together.',
        error: true,
      );
      return;
    }

    final name = await showAddCompetitionSectionDialog(context);
    if (name == null || !mounted) return;

    try {
      await repository.createCompetitionSection(
        database: widget.database,
        adminId: adminId,
        competitionId: widget.competitionId,
        sectionName: name,
      );
      _message('Section added.');
      setState(reload);
    } catch (error) {
      _message(
        userFacingError(error, fallback: 'Unable to add section.'),
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.auth.canAccess(role: 'staff')) {
      return const SizedBox.shrink();
    }

    final accent = Theme.of(context).colorScheme.primary;
    const sectionAccent = Color(0xFF7C3AED);

    return FutureBuilder<_CompetitionDetailsData>(
      future: details,
      builder: (context, snapshot) {
        final title = snapshot.data?.competition['competition_name'] as String? ??
            'Competition';

        return GlassAdminPage(
          title: title,
          subtitle: 'Add batches or sections for this competition',
          toolbar: canEdit
              ? Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    GlassToolbarButton(
                      label: 'Add Batch',
                      icon: Icons.add_rounded,
                      accent: accent,
                      onPressed: addBatches,
                    ),
                    GlassToolbarButton(
                      label: 'Add Section',
                      icon: Icons.view_agenda_outlined,
                      accent: sectionAccent,
                      onPressed: addSection,
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
                              fallback: 'Unable to load competition.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : const CircularProgressIndicator(),
                )
              : _CompetitionDetailsBody(data: snapshot.data!),
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

class _CompetitionDetailsData {
  const _CompetitionDetailsData({
    required this.competition,
    required this.batches,
    required this.sections,
  });

  final Map<String, Object?> competition;
  final List<Map<String, Object?>> batches;
  final List<Map<String, Object?>> sections;
}

class _CompetitionDetailsBody extends StatelessWidget {
  const _CompetitionDetailsBody({required this.data});

  final _CompetitionDetailsData data;

  @override
  Widget build(BuildContext context) {
    final batches = data.batches;
    final sections = data.sections;
    final hasBatches = batches.isNotEmpty;
    final hasSections = sections.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasBatches && !hasSections)
            const GlassPanel(
              child: GlassEmptyState(
                icon: Icons.emoji_events_outlined,
                message:
                    'Nothing added yet. Use Add Batch or Add Section — a competition can use one of these, not both.',
              ),
            )
          else ...[
            if (hasSections)
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassDirectoryHeader(
                      title: 'Sections',
                      icon: Icons.view_agenda_outlined,
                      countLabel: '${sections.length} shown',
                    ),
                    const SizedBox(height: 16),
                    _coloredNameCardGrid(
                      names: [
                        for (final section in sections)
                          section['section_name']! as String,
                      ],
                      icon: Icons.view_agenda_outlined,
                      colorFor: (i) => _competitionCardColors[
                          i % _competitionCardColors.length],
                    ),
                  ],
                ),
              ),
            if (hasBatches)
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassDirectoryHeader(
                      title: 'Participating Batches',
                      icon: Icons.groups_outlined,
                      countLabel: '${batches.length} shown',
                    ),
                    const SizedBox(height: 16),
                    _coloredNameCardGrid(
                      names: [
                        for (final batch in batches)
                          batch['batch_name']! as String,
                      ],
                      icon: Icons.groups_outlined,
                      colorFor: (i) => _competitionCardColors[
                          i % _competitionCardColors.length],
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

Future<String?> showCreateCompetitionDialog(BuildContext context) async {
  final nameController = TextEditingController();

  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Create Competition'),
      content: TextField(
        controller: nameController,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Competition Name *',
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          final name = nameController.text.trim();
          if (name.isNotEmpty) {
            Navigator.pop(context, name);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a competition name.')),
              );
              return;
            }
            Navigator.pop(context, name);
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );

  nameController.dispose();
  return result;
}

Future<String?> showAddCompetitionSectionDialog(BuildContext context) async {
  final nameController = TextEditingController();

  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add Section'),
      content: TextField(
        controller: nameController,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Section Name *',
          hintText: 'e.g. Junior, Senior, Open',
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          final name = nameController.text.trim();
          if (name.isNotEmpty) {
            Navigator.pop(context, name);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a section name.')),
              );
              return;
            }
            Navigator.pop(context, name);
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );

  nameController.dispose();
  return result;
}

Future<List<int>?> showAddCompetitionBatchesDialog(
  BuildContext context, {
  required List<Map<String, Object?>> batches,
}) async {
  final selectableIds = batches
      .where(
        (row) =>
            (row['is_active'] ?? 1) == 1 && (row['already_linked'] ?? 0) == 0,
      )
      .map((row) => row['id']! as int)
      .toSet();
  final selected = <int>{};

  return showDialog<List<int>>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final allSelected = selectableIds.isNotEmpty &&
              selectableIds.every(selected.contains);
          final partiallySelected =
              selected.isNotEmpty && !allSelected;

          return AlertDialog(
            title: const Text('Add Batches'),
            content: SizedBox(
              width: 480,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      value: allSelected
                          ? true
                          : partiallySelected
                              ? null
                              : false,
                      tristate: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        'Select all (${selectableIds.length} available)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      onChanged: selectableIds.isEmpty
                          ? null
                          : (_) {
                              setDialogState(() {
                                if (allSelected) {
                                  selected.clear();
                                } else {
                                  selected
                                    ..clear()
                                    ..addAll(selectableIds);
                                }
                              });
                            },
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: batches.length,
                        itemBuilder: (context, index) {
                          final batch = batches[index];
                          final id = batch['id']! as int;
                          final active = (batch['is_active'] ?? 1) == 1;
                          final alreadyLinked =
                              (batch['already_linked'] ?? 0) == 1;
                          final canSelect = active && !alreadyLinked;
                          final checked =
                              alreadyLinked || selected.contains(id);
                          final grade = batch['grade'];
                          final year = batch['academic_year'];
                          final subtitleParts = <String>[
                            if (grade != null) 'Grade $grade',
                            if (year != null) '$year',
                            if (!active) 'Inactive',
                            if (alreadyLinked) 'Already added',
                          ];

                          return CheckboxListTile(
                            value: checked,
                            enabled: canSelect,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(batch['batch_name']! as String),
                            subtitle: Text(subtitleParts.join(' · ')),
                            onChanged: !canSelect
                                ? null
                                : (value) {
                                    setDialogState(() {
                                      if (value == true) {
                                        selected.add(id);
                                      } else {
                                        selected.remove(id);
                                      }
                                    });
                                  },
                          );
                        },
                      ),
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
                  if (selected.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Select at least one batch.'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, selected.toList());
                },
                child: Text(
                  selected.isEmpty
                      ? 'Add'
                      : 'Add (${selected.length})',
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
