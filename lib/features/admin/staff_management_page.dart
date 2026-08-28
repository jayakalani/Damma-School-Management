import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          active ? 'Deactivate staff account?' : 'Activate staff account?',
        ),
        content: Text(
          'Are you sure you want to ${active ? 'deactivate' : 'activate'} ${member['username']}?',
        ),
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

  Future<void> resetPassword(Map<String, Object?> member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset staff password?'),
        content: Text('Reset the password for ${member['username']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Manage staff accounts and access.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
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
                        labelText: 'Search staff',
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
                    onPressed: createStaff,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Staff'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: staff,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return const Center(
                      child: Text('Unable to load staff members.'),
                    );
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.data!.isEmpty)
                    return const Center(child: Text('No staff members found.'));
                  return Card(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: snapshot.data!.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final member = snapshot.data![index];
                        final active = member['status'] == 'active';
                        return ListTile(
                          title: Text(member['full_name']! as String),
                          subtitle: Text(
                            '@${member['username']} | Created ${member['created_at']}',
                          ),
                          leading: Icon(
                            active
                                ? Icons.check_circle_outline
                                : Icons.pause_circle_outline,
                            color: active ? Colors.green : Colors.grey,
                          ),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => editStaff(member),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Reset password',
                                onPressed: () => resetPassword(member),
                                icon: const Icon(Icons.password_outlined),
                              ),
                              IconButton(
                                tooltip: active ? 'Deactivate' : 'Activate',
                                onPressed: () => changeStatus(member),
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
        title: Text(member == null ? 'Add Staff' : 'Edit Staff'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fullName,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              TextField(
                controller: username,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              if (member == null) ...[
                TextField(
                  controller: password,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                TextField(
                  controller: confirm,
                  obscureText: obscure,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                  ),
                ),
              ],
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
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
              if (fullName.text.trim().isEmpty || username.text.trim().isEmpty)
                return;
              if (member == null &&
                  (password.text.isEmpty || password.text != confirm.text))
                return;
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
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: password,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: 'New Password',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => obscure = !obscure),
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            TextField(
              controller: confirm,
              obscureText: obscure,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
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
              if (password.text.isNotEmpty && password.text == confirm.text)
                Navigator.pop(context, password.text);
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
