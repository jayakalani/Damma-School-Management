import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/widgets/glass_ui.dart';
import '../../core/export/staff_export_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/users/user_repository.dart';

class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({
    super.key,
    required this.database,
    required this.auth,
  });

  final Database database;
  final AuthService auth;

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  final search = TextEditingController();
  final repository = UserRepository();
  final exportService = const StaffExportService();
  String? _activeStatusFilter;
  String? _pendingStatusFilter;
  late Future<List<Map<String, Object?>>> _allStaff;

  int get adminId => widget.auth.currentSession!.userId;

  @override
  void initState() {
    super.initState();
    widget.auth.requireRole('admin');
    _reloadAll();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void _reloadAll() {
    _allStaff = repository.listStaff(
      database: widget.database,
      adminId: adminId,
    );
  }

  void refreshList() => setState(_reloadAll);

  void _applyFilters() {
    setState(() {
      _activeStatusFilter = _pendingStatusFilter;
    });
  }

  void _resetFilters() {
    setState(() {
      search.clear();
      _pendingStatusFilter = null;
      _activeStatusFilter = null;
    });
  }

  List<Map<String, Object?>> _filterStaff(List<Map<String, Object?>> members) {
    final query = search.text.trim().toLowerCase();
    return members.where((member) {
      final matchesQuery = query.isEmpty ||
          (member['full_name']! as String).toLowerCase().contains(query) ||
          (member['username']! as String).toLowerCase().contains(query);
      final matchesStatus =
          _activeStatusFilter == null ||
          member['status'] == _activeStatusFilter;
      return matchesQuery && matchesStatus;
    }).toList();
  }

  StaffExportFilters get _exportFilters => StaffExportFilters(
        searchQuery: search.text,
        statusFilter: _activeStatusFilter,
      );

  String _exportTimestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _exportCsv() async {
    if (kIsWeb) {
      _message('Export is available in the desktop app.', error: true);
      return;
    }
    try {
      final members = _filterStaff(await _allStaff);
      final location = await getSaveLocation(
        suggestedName: 'staff_${_exportTimestamp()}.csv',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null || !mounted) return;
      await exportService.writeTextFile(
        path: location.path,
        contents: exportService.buildCsv(members, filters: _exportFilters),
      );
      _message('Staff CSV exported (${members.length} record(s)).');
    } catch (_) {
      _message('Unable to export staff CSV.', error: true);
    }
  }

  Future<void> _exportPdf() async {
    if (kIsWeb) {
      _message('Export is available in the desktop app.', error: true);
      return;
    }
    try {
      final members = _filterStaff(await _allStaff);
      final location = await getSaveLocation(
        suggestedName: 'staff_${_exportTimestamp()}.pdf',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PDF', extensions: ['pdf']),
        ],
      );
      if (location == null || !mounted) return;
      final bytes = await exportService.buildPdf(
        members,
        filters: _exportFilters,
      );
      await exportService.writeBytesFile(path: location.path, bytes: bytes);
      _message('Staff PDF exported (${members.length} record(s)).');
    } catch (_) {
      _message('Unable to export staff PDF.', error: true);
    }
  }

  Future<void> createStaff() async {
    final values = await showStaffEditor(context);
    if (values == null || !mounted) return;
    await _perform(() async {
      await repository.createStaff(
        database: widget.database,
        adminId: adminId,
        fullName: values.fullName,
        username: values.username,
        password: values.password!,
        status: values.status,
      );
      _message('Staff account created.');
      refreshList();
    });
  }

  Future<void> editStaff(Map<String, Object?> member) async {
    final values = await showStaffEditor(context, member: member);
    if (values == null || !mounted) return;
    await _perform(() async {
      await repository.updateStaff(
        database: widget.database,
        adminId: adminId,
        staffId: member['id']! as int,
        fullName: values.fullName,
        username: values.username,
      );
      _message('Staff account updated.');
      refreshList();
    });
  }

  Future<void> changeStatus(Map<String, Object?> member) async {
    final active = member['status'] == 'active';
    final username = member['username']! as String;
    final confirmed = await showConfirmActionDialog(
      context,
      icon: active ? Icons.person_off_outlined : Icons.person_outline,
      iconColor: active
          ? Colors.orange.shade700
          : Theme.of(context).colorScheme.primary,
      title: active ? 'Deactivate staff account?' : 'Activate staff account?',
      message: active
          ? '$username will lose access immediately. You can reactivate the account later.'
          : '$username will be able to sign in and use the system again.',
      confirmLabel: active ? 'Deactivate' : 'Activate',
      confirmColor: active ? Colors.orange.shade700 : null,
    );
    if (!confirmed || !mounted) return;
    await _perform(() async {
      await repository.setStaffStatus(
        database: widget.database,
        adminId: adminId,
        staffId: member['id']! as int,
        active: !active,
      );
      _message('Staff account ${active ? 'deactivated' : 'activated'}.');
      refreshList();
    });
  }

  Future<void> deleteStaff(Map<String, Object?> member) async {
    final username = member['username']! as String;
    final fullName = member['full_name']! as String;
    final confirmed = await showConfirmActionDialog(
      context,
      icon: Icons.delete_forever_outlined,
      iconColor: Theme.of(context).colorScheme.error,
      title: 'Delete staff account?',
      message:
          'Permanently remove $fullName (@$username)? This action cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: Theme.of(context).colorScheme.error,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _perform(() async {
      await repository.deleteStaff(
        database: widget.database,
        adminId: adminId,
        staffId: member['id']! as int,
      );
      _message('Staff account deleted.');
      refreshList();
    });
  }

  Future<void> resetPassword(Map<String, Object?> member) async {
    final username = member['username']! as String;
    final confirmed = await showConfirmActionDialog(
      context,
      icon: Icons.lock_reset_outlined,
      iconColor: Theme.of(context).colorScheme.primary,
      title: 'Reset staff password?',
      message:
          'Set a new password for $username. They will need it on next login.',
      confirmLabel: 'Continue',
    );
    if (!confirmed || !mounted) return;
    final newPassword = await showPasswordReset(context);
    if (newPassword == null || !mounted) return;
    await _perform(() async {
      await repository.resetStaffPassword(
        database: widget.database,
        adminId: adminId,
        staffId: member['id']! as int,
        newPassword: newPassword,
      );
      _message('Staff password reset successfully.');
    });
  }

  Future<void> _perform(Future<void> Function() operation) async {
    try {
      await operation();
    } on UsernameAlreadyInUseException {
      _message('That username is already in use.', error: true);
    } on StateError catch (error) {
      _message(error.message, error: true);
    } catch (_) {
      _message('Unable to complete the staff account operation.', error: true);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    widget.auth.requireRole('admin');
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF4F7),
      body: DashboardBackdrop(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: GlassSurface(
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                opacity: 0.78,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Staff Management',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Manage accounts, access, and permissions',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _BlendedToolbarButton(
                      label: 'Export CSV',
                      icon: Icons.table_chart_outlined,
                      accent: const Color(0xFF16A34A),
                      onPressed: _exportCsv,
                    ),
                    _BlendedToolbarButton(
                      label: 'Export PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      accent: const Color(0xFFE11D48),
                      onPressed: _exportPdf,
                    ),
                    _BlendedToolbarButton(
                      label: 'Add Staff',
                      icon: Icons.person_add_outlined,
                      accent: accent,
                      onPressed: createStaff,
                      emphasized: true,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: _allStaff,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Unable to load staff members.'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allMembers = snapshot.data!;
                  final visibleMembers = _filterStaff(allMembers);
                  final activeCount = allMembers
                      .where((m) => m['status'] == 'active')
                      .length;
                  final disabledCount = allMembers
                      .where((m) => m['status'] == 'inactive')
                      .length;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 900
                                ? 3
                                : constraints.maxWidth >= 560
                                    ? 2
                                    : 1;
                            return GridView.count(
                              crossAxisCount: columns,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: columns == 1 ? 4.8 : 4.2,
                              children: [
                                _SummaryStatCard(
                                  label: 'Total Staff',
                                  value: '${allMembers.length}',
                                  valueColor: theme.colorScheme.onSurface,
                                  accentColor: accent,
                                ),
                                _SummaryStatCard(
                                  label: 'Active',
                                  value: '$activeCount',
                                  valueColor: const Color(0xFF16A34A),
                                  accentColor: const Color(0xFF16A34A),
                                ),
                                _SummaryStatCard(
                                  label: 'Disabled',
                                  value: '$disabledCount',
                                  valueColor: const Color(0xFFEA580C),
                                  accentColor: const Color(0xFFEA580C),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _GlassPanel(
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: 280,
                                child: TextField(
                                  controller: search,
                                  onChanged: (_) => setState(() {}),
                                  decoration: _glassInputDecoration(
                                    context,
                                    hint: 'Search staff...',
                                    prefixIcon: Icons.search_rounded,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 180,
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _pendingStatusFilter,
                                  decoration: _glassInputDecoration(
                                    context,
                                    hint: 'All Status',
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  items: const [
                                    DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('All Status'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'active',
                                      child: Text('Active'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'inactive',
                                      child: Text('Disabled'),
                                    ),
                                  ],
                                  onChanged: (value) => setState(
                                    () => _pendingStatusFilter = value,
                                  ),
                                ),
                              ),
                              _GlassActionButton(
                                label: 'Apply',
                                filled: true,
                                onPressed: _applyFilters,
                              ),
                              _GlassActionButton(
                                label: 'Reset',
                                onPressed: _resetFilters,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _GlassPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.people_alt_outlined,
                                    color: accent,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Staff Directory',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${visibleMembers.length} shown',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (visibleMembers.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 48,
                                  ),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.people_outline,
                                          size: 48,
                                          color: theme.colorScheme.outline,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No staff members found.',
                                          style: theme.textTheme.titleMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else ...[
                                _StaffTableHeader(),
                                const SizedBox(height: 8),
                                for (final member in visibleMembers)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _StaffTableRow(
                                      member: member,
                                      onEdit: () => editStaff(member),
                                      onReset: () => resetPassword(member),
                                      onToggleStatus: () =>
                                          changeStatus(member),
                                      onDelete: () => deleteStaff(member),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _BlendedToolbarButton extends StatefulWidget {
  const _BlendedToolbarButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onPressed,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  State<_BlendedToolbarButton> createState() => _BlendedToolbarButtonState();
}

class _BlendedToolbarButtonState extends State<_BlendedToolbarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = _hovered
        ? Color.alphaBlend(Colors.black.withValues(alpha: 0.08), widget.accent)
        : widget.accent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.03 : 1,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(12),
            splashColor: Colors.white.withValues(alpha: 0.2),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _hovered
                    ? floatingShadow(
                        color: widget.accent,
                        opacity: 0.2,
                        blur: 14,
                        y: 6,
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
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

class _SummaryStatCard extends StatefulWidget {
  const _SummaryStatCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.accentColor,
  });

  final String label;
  final String value;
  final Color valueColor;
  final Color accentColor;

  @override
  State<_SummaryStatCard> createState() => _SummaryStatCardState();
}

class _SummaryStatCardState extends State<_SummaryStatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: GlassSurface(
            borderRadius: BorderRadius.circular(14),
            padding: EdgeInsets.zero,
            opacity: _hovered ? 0.84 : 0.74,
            borderOpacity: _hovered ? 0.72 : 0.55,
            tint: _hovered
                ? Color.alphaBlend(
                    widget.accentColor.withValues(alpha: 0.05),
                    Colors.white,
                  )
                : Colors.white,
            elevated: _hovered,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(height: 3, color: widget.accentColor),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.value,
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: widget.valueColor,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                  letterSpacing: -0.5,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(20),
      opacity: 0.76,
      child: child,
    );
  }
}

class _GlassActionButton extends StatefulWidget {
  const _GlassActionButton({
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  State<_GlassActionButton> createState() => _GlassActionButtonState();
}

class _GlassActionButtonState extends State<_GlassActionButton> {
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
        child: widget.filled
            ? FilledButton(
                onPressed: widget.onPressed,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: _hovered ? 3 : 0,
                ),
                child: Text(widget.label),
              )
            : OutlinedButton(
                onPressed: widget.onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(
                    color: accent.withValues(alpha: _hovered ? 0.6 : 0.35),
                  ),
                  backgroundColor: _hovered
                      ? accent.withValues(alpha: 0.06)
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(widget.label),
              ),
      ),
    );
  }
}

class _StaffTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text('ID', style: style)),
          Expanded(flex: 3, child: Text('FULL NAME', style: style)),
          Expanded(flex: 2, child: Text('USERNAME', style: style)),
          Expanded(flex: 2, child: Text('CREATED', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          Expanded(flex: 5, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }
}

class _StaffTableRow extends StatefulWidget {
  const _StaffTableRow({
    required this.member,
    required this.onEdit,
    required this.onReset,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final Map<String, Object?> member;
  final VoidCallback onEdit;
  final VoidCallback onReset;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  State<_StaffTableRow> createState() => _StaffTableRowState();
}

class _StaffTableRowState extends State<_StaffTableRow> {
  bool _hovered = false;

  String _formatCreatedAt(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final active = widget.member['status'] == 'active';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.005 : 1,
        duration: const Duration(milliseconds: 180),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          opacity: _hovered ? 0.84 : 0.7,
          borderOpacity: _hovered ? 0.7 : 0.5,
          tint: _hovered
              ? Color.alphaBlend(accent.withValues(alpha: 0.04), Colors.white)
              : Colors.white,
          elevated: _hovered,
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Text(
                  '#${widget.member['id']}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  widget.member['full_name']! as String,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '@${widget.member['username']}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _formatCreatedAt(widget.member['created_at']! as String),
                ),
              ),
              Expanded(
                flex: 2,
                child: StaffStatusToggle(
                  active: active,
                  onChanged: widget.onToggleStatus,
                ),
              ),
              Expanded(
                flex: 5,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ActionChipButton(
                      label: 'Edit',
                      color: const Color(0xFF2563EB),
                      onPressed: widget.onEdit,
                    ),
                    _ActionChipButton(
                      label: 'Reset',
                      color: accent,
                      onPressed: widget.onReset,
                    ),
                    _ActionChipButton(
                      label: 'Delete',
                      color: theme.colorScheme.error,
                      onPressed: widget.onDelete,
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

class _ActionChipButton extends StatefulWidget {
  const _ActionChipButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_ActionChipButton> createState() => _ActionChipButtonState();
}

class _ActionChipButtonState extends State<_ActionChipButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.05 : 1,
        duration: const Duration(milliseconds: 160),
        child: OutlinedButton(
          onPressed: widget.onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: widget.color,
            side: BorderSide(
              color: widget.color.withValues(alpha: _hovered ? 0.55 : 0.35),
            ),
            backgroundColor: widget.color.withValues(
              alpha: _hovered ? 0.14 : 0.06,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                ),
          ),
        ),
      ),
    );
  }
}

class StaffStatusToggle extends StatelessWidget {
  const StaffStatusToggle({
    super.key,
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

InputDecoration _glassInputDecoration(
  BuildContext context, {
  required String hint,
  IconData? prefixIcon,
}) {
  final theme = Theme.of(context);
  final accent = theme.colorScheme.primary;
  return InputDecoration(
    hintText: hint,
    prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.45),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: theme.dividerColor.withValues(alpha: 0.35),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: accent, width: 1.5),
    ),
  );
}

Future<bool> showConfirmActionDialog(
  BuildContext context, {
  required IconData icon,
  required Color iconColor,
  required String title,
  required String message,
  required String confirmLabel,
  Color? confirmColor,
  bool destructive = false,
}) async {
  final theme = Theme.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: confirmColor ??
                (destructive ? theme.colorScheme.error : null),
            foregroundColor: destructive ? theme.colorScheme.onError : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

class StaffEditorValues {
  const StaffEditorValues({
    required this.fullName,
    required this.username,
    required this.status,
    this.password,
  });

  final String fullName;
  final String username;
  final String status;
  final String? password;
}

InputDecoration _softInputDecoration(
  BuildContext context, {
  required String label,
  Widget? prefixIcon,
}) {
  final theme = Theme.of(context);
  final accent = theme.colorScheme.primary;
  return InputDecoration(
    labelText: label,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: theme.dividerColor.withValues(alpha: 0.45),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: accent, width: 1.5),
    ),
  );
}

Future<StaffEditorValues?> showStaffEditor(
  BuildContext context, {
  Map<String, Object?>? member,
}) async {
  final fullName = TextEditingController(text: member?['full_name'] as String?);
  final username = TextEditingController(text: member?['username'] as String?);
  final password = TextEditingController();
  final confirm = TextEditingController();
  var status = (member?['status'] as String?) ?? 'active';
  var obscure = true;
  final result = await showDialog<StaffEditorValues>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(member == null ? 'Add Staff' : 'Edit Staff'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fullName,
                decoration: _softInputDecoration(
                  context,
                  label: 'Full Name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: username,
                decoration: _softInputDecoration(
                  context,
                  label: 'Username',
                ),
              ),
              if (member == null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: obscure,
                  decoration: _softInputDecoration(
                    context,
                    label: 'Password',
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirm,
                  obscureText: obscure,
                  decoration: _softInputDecoration(
                    context,
                    label: 'Confirm Password',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: _softInputDecoration(context, label: 'Status'),
                borderRadius: BorderRadius.circular(12),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Disabled')),
                ],
                onChanged: (value) => setState(() => status = value!),
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
              if (fullName.text.trim().isEmpty || username.text.trim().isEmpty) {
                return;
              }
              if (member == null &&
                  (password.text.isEmpty || password.text != confirm.text)) {
                return;
              }
              Navigator.pop(
                context,
                StaffEditorValues(
                  fullName: fullName.text.trim(),
                  username: username.text.trim(),
                  status: status,
                  password: member == null ? password.text : null,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  for (final controller in [fullName, username, password, confirm]) {
    controller.dispose();
  }
  return result;
}

Future<String?> showPasswordReset(BuildContext context) async {
  final password = TextEditingController();
  final confirm = TextEditingController();
  var obscure = true;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: password,
              obscureText: obscure,
              decoration: _softInputDecoration(
                context,
                label: 'New Password',
              ).copyWith(
                suffixIcon: IconButton(
                  onPressed: () => setState(() => obscure = !obscure),
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              obscureText: obscure,
              decoration: _softInputDecoration(
                context,
                label: 'Confirm New Password',
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
              if (password.text.isNotEmpty && password.text == confirm.text) {
                Navigator.pop(context, password.text);
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    ),
  );
  password.dispose();
  confirm.dispose();
  return result;
}
