import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/widgets/date_picker_field.dart';
import '../../app/widgets/glass_admin_ui.dart';
import '../../core/export/tabular_report_export_service.dart';
import '../../core/reports/report_catalog.dart';
import '../../core/reports/report_query_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/error_messages.dart';

enum _ExportFormat { csv, pdf }

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    super.key,
    required this.database,
    required this.auth,
  });

  final Database database;
  final AuthService auth;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _queryService = ReportQueryService();
  final _exportService = const TabularReportExportService();

  ReportId _reportId = ReportId.teachers;
  String? _status;
  int? _batchId;
  int? _alumniBatchId;
  DateTime? _startDate;
  DateTime? _endDate;
  late Set<String> _selectedFields;
  _ExportFormat _format = _ExportFormat.csv;
  bool _generating = false;
  late Future<ReportLookupOptions> _lookups;

  int get _userId => widget.auth.currentSession!.userId;

  ReportDefinition get _definition => ReportCatalog.byId(_reportId);

  @override
  void initState() {
    super.initState();
    _selectedFields = {..._definition.defaultFieldKeys};
    _lookups = _queryService.loadLookups(
      database: widget.database,
      userId: _userId,
    );
  }

  void _selectReport(ReportId id) {
    setState(() {
      _reportId = id;
      _status = null;
      _batchId = null;
      _alumniBatchId = null;
      _startDate = null;
      _endDate = null;
      _selectedFields = {...ReportCatalog.byId(id).defaultFieldKeys};
    });
  }

  ReportQuery get _query => ReportQuery(
        reportId: _reportId,
        status: _status,
        batchId: _batchId,
        alumniBatchId: _alumniBatchId,
        startDate: _startDate,
        endDate: _endDate,
      );

  Future<void> _generate() async {
    if (_generating) return;
    if (_selectedFields.isEmpty) {
      _message('Select at least one field.', error: true);
      return;
    }
    if (_startDate != null &&
        _endDate != null &&
        _startDate!.isAfter(_endDate!)) {
      _message('From date cannot be after To date.', error: true);
      return;
    }
    if (kIsWeb) {
      _message('Export is available in the desktop app.', error: true);
      return;
    }

    setState(() => _generating = true);
    try {
      final definition = _definition;
      final columns = definition.fields
          .where((field) => _selectedFields.contains(field.key))
          .toList();
      final result = await _queryService.loadReport(
        database: widget.database,
        userId: _userId,
        query: _query,
      );
      final extension = _format == _ExportFormat.csv ? 'csv' : 'pdf';
      final location = await getSaveLocation(
        suggestedName: '${definition.fileStem}_${_exportTimestamp()}.$extension',
        acceptedTypeGroups: [
          XTypeGroup(
            label: extension.toUpperCase(),
            extensions: [extension],
          ),
        ],
      );
      if (location == null || !mounted) return;

      if (_format == _ExportFormat.csv) {
        await _exportService.writeTextFile(
          path: location.path,
          contents: _exportService.buildCsv(
            definition: definition,
            columns: columns,
            rows: result.rows,
            filterSummary: result.filterSummary,
          ),
        );
      } else {
        final bytes = await _exportService.buildPdf(
          definition: definition,
          columns: columns,
          rows: result.rows,
          filterSummary: result.filterSummary,
        );
        await _exportService.writeBytesFile(path: location.path, bytes: bytes);
      }

      _message(
        '${definition.title} ${extension.toUpperCase()} exported '
        '(${result.rows.length} record(s)).',
      );
    } catch (error) {
      _message(
        userFacingError(error, fallback: 'Unable to generate report.'),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _exportTimestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.auth.canAccess(role: 'staff')) {
      return const SizedBox.shrink();
    }

    final accent = Theme.of(context).colorScheme.primary;
    final filters = _definition.filters;

    return GlassAdminPage(
      title: 'Reports',
      subtitle: 'Choose a dataset, apply filters, and export CSV or PDF',
      body: FutureBuilder<ReportLookupOptions>(
        future: _lookups,
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  userFacingError(
                    snapshot.error!,
                    fallback: 'Unable to load report options.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final lookups = snapshot.data ?? const ReportLookupOptions();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassPanel(
                  child: _WizardSection(
                    step: 1,
                    title: 'Select report',
                    subtitle: 'Pick the dataset you want to export',
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 640 ? 2 : 1;
                        final gap = 12.0;
                        final width = columns == 1
                            ? constraints.maxWidth
                            : (constraints.maxWidth - gap) / 2;
                        return RadioGroup<ReportId>(
                          groupValue: _reportId,
                          onChanged: (id) {
                            if (id != null) _selectReport(id);
                          },
                          child: Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final report in ReportCatalog.all)
                                SizedBox(
                                  width: width,
                                  child: _ReportChoiceCard(
                                    report: report,
                                    selected: report.id == _reportId,
                                    onTap: () => _selectReport(report.id),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GlassPanel(
                  child: _WizardSection(
                    step: 2,
                    title: 'Apply filters',
                    subtitle: 'Narrow the dataset before download',
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final fieldWidth = constraints.maxWidth >= 720
                            ? (constraints.maxWidth - 24) / 3
                            : constraints.maxWidth >= 520
                                ? (constraints.maxWidth - 12) / 2
                                : constraints.maxWidth;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 16,
                          children: [
                            if (filters.contains(ReportFilter.teacherStatus) ||
                                filters.contains(ReportFilter.batchStatus))
                              SizedBox(
                                width: fieldWidth,
                                child: _FilterDropdown<String?>(
                                  label: 'Status',
                                  value: _status,
                                  items: const [
                                    (null, 'All'),
                                    ('active', 'Active'),
                                    ('inactive', 'Inactive'),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _status = value),
                                ),
                              ),
                            if (filters.contains(ReportFilter.studentStatus))
                              SizedBox(
                                width: fieldWidth,
                                child: _FilterDropdown<String?>(
                                  label: 'Status',
                                  value: _status,
                                  items: const [
                                    (null, 'All'),
                                    ('active', 'Active'),
                                    ('inactive', 'Inactive'),
                                    ('past_pupil', 'Past pupil'),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _status = value),
                                ),
                              ),
                            if (filters.contains(ReportFilter.currentBatch))
                              SizedBox(
                                width: fieldWidth,
                                child: _FilterDropdown<int?>(
                                  label: 'Batch',
                                  value: _batchId,
                                  items: [
                                    (null, 'All'),
                                    for (final batch in lookups.batches)
                                      (
                                        batch['id']! as int,
                                        '${batch['batch_name']}',
                                      ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _batchId = value),
                                ),
                              ),
                            if (filters.contains(ReportFilter.alumniBatch))
                              SizedBox(
                                width: fieldWidth,
                                child: _FilterDropdown<int?>(
                                  label: 'Alumni batch',
                                  value: _alumniBatchId,
                                  items: [
                                    (null, 'All'),
                                    for (final batch in lookups.alumniBatches)
                                      (
                                        batch['id']! as int,
                                        '${batch['batch_name']} (${batch['year_completed']})',
                                      ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _alumniBatchId = value),
                                ),
                              ),
                            if (filters.contains(ReportFilter.dateRange)) ...[
                              SizedBox(
                                width: fieldWidth,
                                child: _FilterDateField(
                                  label: 'From',
                                  value: _startDate,
                                  onChanged: (value) =>
                                      setState(() => _startDate = value),
                                ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child: _FilterDateField(
                                  label: 'To',
                                  value: _endDate,
                                  onChanged: (value) =>
                                      setState(() => _endDate = value),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GlassPanel(
                  child: _WizardSection(
                    step: 3,
                    title: 'Select fields',
                    subtitle: 'Choose the columns included in the export',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => setState(
                            () => _selectedFields = {
                              for (final field in _definition.fields) field.key,
                            },
                          ),
                          child: const Text('Select all'),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _selectedFields = {}),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 900
                            ? 3
                            : constraints.maxWidth >= 560
                                ? 2
                                : 1;
                        final gap = 8.0;
                        final width = columns == 1
                            ? constraints.maxWidth
                            : (constraints.maxWidth - gap * (columns - 1)) /
                                columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: 4,
                          children: [
                            for (final field in _definition.fields)
                              SizedBox(
                                width: width,
                                child: CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(field.label),
                                  value: _selectedFields.contains(field.key),
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked ?? false) {
                                        _selectedFields.add(field.key);
                                      } else {
                                        _selectedFields.remove(field.key);
                                      }
                                    });
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GlassPanel(
                  child: _WizardSection(
                    step: 4,
                    title: 'Export options',
                    subtitle: 'Choose a file format and generate the report',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth >= 520
                                ? (constraints.maxWidth - 12) / 2
                                : constraints.maxWidth;
                            return RadioGroup<_ExportFormat>(
                              groupValue: _format,
                              onChanged: (format) {
                                if (format != null) {
                                  setState(() => _format = format);
                                }
                              },
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: width,
                                    child: _FormatChoiceCard(
                                      label: 'CSV',
                                      description:
                                          'Spreadsheet-friendly table',
                                      value: _ExportFormat.csv,
                                      selected: _format == _ExportFormat.csv,
                                      onTap: () => setState(
                                        () => _format = _ExportFormat.csv,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: width,
                                    child: _FormatChoiceCard(
                                      label: 'PDF',
                                      description: 'Printable document',
                                      value: _ExportFormat.pdf,
                                      selected: _format == _ExportFormat.pdf,
                                      onTap: () => setState(
                                        () => _format = _ExportFormat.pdf,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GlassToolbarButton(
                            label: _generating
                                ? 'Generating…'
                                : 'Generate report',
                            icon: Icons.download_rounded,
                            accent: accent,
                            onPressed: _generating ? () {} : _generate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WizardSection extends StatelessWidget {
  const _WizardSection({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final int step;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$step. $title',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _ReportChoiceCard extends StatelessWidget {
  const _ReportChoiceCard({
    required this.report,
    required this.selected,
    required this.onTap,
  });

  final ReportDefinition report;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? accent
                  : theme.dividerColor.withValues(alpha: 0.45),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Radio<ReportId>(value: report.id),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormatChoiceCard extends StatelessWidget {
  const _FormatChoiceCard({
    required this.label,
    required this.description,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final _ExportFormat value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? accent
                  : theme.dividerColor.withValues(alpha: 0.45),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Radio<_ExportFormat>(value: value),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: glassInputDecoration(context, hint: label).copyWith(
        labelText: label,
        hintText: null,
      ),
      borderRadius: BorderRadius.circular(12),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(
            value: item.$1,
            child: Text(item.$2, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (selected) {
        if (selected != null || items.any((item) => item.$1 == null)) {
          onChanged(selected as T);
        }
      },
    );
  }
}

class _FilterDateField extends StatefulWidget {
  const _FilterDateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  State<_FilterDateField> createState() => _FilterDateFieldState();
}

class _FilterDateFieldState extends State<_FilterDateField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _label(widget.value));
  }

  @override
  void didUpdateWidget(covariant _FilterDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _label(widget.value);
    if (_controller.text != next) {
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _label(DateTime? value) =>
      value == null ? '' : AppDateFormats.storage(value);

  Future<void> _pick() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
      initialDate: widget.value ?? DateTime(now.year, now.month, now.day),
      helpText: 'Select ${widget.label}',
    );
    if (picked != null) widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      controller: _controller,
      onTap: _pick,
      decoration: glassInputDecoration(context, hint: 'Tap to choose a date')
          .copyWith(
        labelText: widget.label,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.value != null)
              IconButton(
                tooltip: 'Clear',
                onPressed: () => widget.onChanged(null),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            IconButton(
              tooltip: 'Choose date',
              onPressed: _pick,
              icon: const Icon(Icons.calendar_month_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
