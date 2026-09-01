import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/widgets/glass_ui.dart';
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
  String? statusFilter;
  late Future<List<Map<String, Object?>>> staff;

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
    staff = repository.searchStaff(
      database: widget.database,
      adminId: adminId,
      query: search.text,
      status: statusFilter,
    );
  }

  void refreshList() => setState(reload);

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
      iconColor: active ? Colors.orange.shade700 : Theme.of(context).colorScheme.primary,
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
      message: 'Set a new password for $username. They will need it on next login.',
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
      appBar: AppBar(
        title: const Text('Staff Management'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            elevation: 0,
            color: theme.colorScheme.surface,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.35),
                  ),
                ),
                boxShadow: floatingShadow(opacity: 0.06, blur: 12, y: 4),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage staff accounts and access.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 720;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: stacked ? constraints.maxWidth : 300,
                            child: TextField(
                              controller: search,
                              onChanged: (_) => refreshList(),
                              decoration: _softInputDecoration(
                                context,
                                label: 'Search staff',
                                prefixIcon: Icon(Icons.search, color: accent),
                              ),
                            ),
                          ),
                          _SoftDropdown<String?>(
                            value: statusFilter,
                            hint: 'All statuses',
                            width: stacked ? constraints.maxWidth : 180,
                            items: const [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All statuses'),
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
                            onChanged: (value) {
                              setState(() {
                                statusFilter = value;
                                reload();
                              });
                            },
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Refresh',
                            onPressed: refreshList,
                            icon: const Icon(Icons.refresh),
                            style: IconButton.styleFrom(
                              foregroundColor: accent,
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: createStaff,
                            icon: const Icon(Icons.person_add_outlined),
                            label: const Text('Add Staff'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: staff,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Unable to load staff members.'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                    );
                  }
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.4),
                      ),
                    ),
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: floatingShadow(opacity: 0.05, blur: 16, y: 6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: snapshot.data!.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: theme.dividerColor.withValues(alpha: 0.35),
                          ),
                          itemBuilder: (context, index) {
                            final member = snapshot.data![index];
                            return _StaffListTile(
                              member: member,
                              onEdit: () => editStaff(member),
                              onResetPassword: () => resetPassword(member),
                              onToggleStatus: () => changeStatus(member),
                              onDelete: () => deleteStaff(member),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffListTile extends StatelessWidget {
  const _StaffListTile({
    required this.member,
    required this.onEdit,
    required this.onResetPassword,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final Map<String, Object?> member;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final status = member['status']! as String;
    final active = status == 'active';
    final createdAt = _formatCreatedAt(member['created_at']! as String);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Row(
        children: [
          Expanded(
            child: Text(
              member['full_name']! as String,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          StaffStatusBadge(status: status),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          '@${member['username']}  ·  Created $createdAt',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: Icon(Icons.edit_outlined, color: accent),
          ),
          IconButton(
            tooltip: 'Reset password',
            onPressed: onResetPassword,
            icon: Icon(Icons.lock_reset_outlined, color: accent),
          ),
          IconButton(
            tooltip: active ? 'Deactivate' : 'Activate',
            onPressed: onToggleStatus,
            icon: Icon(
              active ? Icons.person_off_outlined : Icons.person_outline,
              color: active ? Colors.orange.shade700 : accent,
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline,
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCreatedAt(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class StaffStatusBadge extends StatelessWidget {
  const StaffStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (status) {
      'active' => (
          'Active',
          Colors.green.withValues(alpha: 0.14),
          Colors.green.shade800,
        ),
      'inactive' => (
          'Disabled',
          Colors.red.withValues(alpha: 0.14),
          Colors.red.shade800,
        ),
      'pending' => (
          'Pending',
          Colors.amber.withValues(alpha: 0.18),
          Colors.amber.shade900,
        ),
      _ => (
          status,
          Colors.grey.withValues(alpha: 0.14),
          Colors.grey.shade800,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}

class _SoftDropdown<T> extends StatelessWidget {
  const _SoftDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.width,
  });

  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.45),
        ),
        boxShadow: floatingShadow(opacity: 0.04, blur: 10, y: 3),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(hint),
          items: items,
          onChanged: onChanged,
          borderRadius: BorderRadius.circular(12),
          icon: Icon(Icons.expand_more, color: theme.colorScheme.primary),
        ),
      ),
    );
  }
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
