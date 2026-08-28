import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/audit/audit_log_repository.dart';
import '../../core/services/auth_service.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key, required this.database, required this.auth});
  final Database database;
  final AuthService auth;
  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  final repository = const AuditLogRepository();
  final search = TextEditingController();
  late Future<List<Map<String, Object?>>> logs;
  late Future<List<Map<String, Object?>>> users;
  late Future<List<String>> modules;
  int? userId;
  String? module;
  DateTime? startDate;
  DateTime? endDate;
  int get adminId => widget.auth.currentSession!.userId;

  @override
  void initState() {
    super.initState();
    widget.auth.requireRole('admin');
    users = repository.listUsersForFilter(
      database: widget.database,
      adminId: adminId,
    );
    modules = repository.listModulesForFilter(
      database: widget.database,
      adminId: adminId,
    );
    reload();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void reload() {
    logs = repository.listForAdmin(
      database: widget.database,
      adminId: adminId,
      query: search.text,
      userId: userId,
      module: module,
      startDate: startDate,
      endDate: endDate,
    );
  }

  void clearFilters() {
    search.clear();
    setState(() {
      userId = null;
      module = null;
      startDate = null;
      endDate = null;
      reload();
    });
  }

  Future<void> chooseStart() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
      initialDate: startDate ?? DateTime.now(),
    );
    if (value != null)
      setState(() {
        startDate = value;
        reload();
      });
  }

  Future<void> chooseEnd() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
      initialDate: endDate ?? DateTime.now(),
    );
    if (value != null)
      setState(() {
        endDate = value;
        reload();
      });
  }

  @override
  Widget build(BuildContext context) {
    widget.auth.requireRole('admin');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Review system activity and administrative changes.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: constraints.maxWidth < 720
                        ? constraints.maxWidth
                        : 280,
                    child: TextField(
                      controller: search,
                      onChanged: (_) => setState(reload),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search logs',
                      ),
                    ),
                  ),
                  FutureBuilder<List<Map<String, Object?>>>(
                    future: users,
                    builder: (context, snapshot) => DropdownButton<int?>(
                      value: userId,
                      hint: const Text('All users'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All users'),
                        ),
                        if (snapshot.hasData)
                          for (final user in snapshot.data!)
                            DropdownMenuItem(
                              value: user['id']! as int,
                              child: Text(user['username']! as String),
                            ),
                      ],
                      onChanged: (value) => setState(() {
                        userId = value;
                        reload();
                      }),
                    ),
                  ),
                  FutureBuilder<List<String>>(
                    future: modules,
                    builder: (context, snapshot) => DropdownButton<String?>(
                      value: module,
                      hint: const Text('All modules'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All modules'),
                        ),
                        if (snapshot.hasData)
                          for (final value in snapshot.data!)
                            DropdownMenuItem(value: value, child: Text(value)),
                      ],
                      onChanged: (value) => setState(() {
                        module = value;
                        reload();
                      }),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: chooseStart,
                    icon: const Icon(Icons.event),
                    label: Text(
                      startDate == null ? 'From date' : _dateLabel(startDate!),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: chooseEnd,
                    icon: const Icon(Icons.event),
                    label: Text(
                      endDate == null ? 'To date' : _dateLabel(endDate!),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: clearFilters,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear filters'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: logs,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return _StateMessage(
                      icon: Icons.error_outline,
                      text: 'Unable to load audit logs.',
                      action: TextButton.icon(
                        onPressed: () => setState(reload),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    );
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.data!.isEmpty)
                    return const _StateMessage(
                      icon: Icons.fact_check_outlined,
                      text: 'No audit logs match the current filters.',
                    );
                  return Card(
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Date/Time')),
                            DataColumn(label: Text('User')),
                            DataColumn(label: Text('Action')),
                            DataColumn(label: Text('Module')),
                            DataColumn(label: Text('Description')),
                          ],
                          rows: [
                            for (final log in snapshot.data!)
                              DataRow(
                                cells: [
                                  DataCell(Text(log['created_at']! as String)),
                                  DataCell(
                                    Text('${log['actor_username'] ?? '-'}'),
                                  ),
                                  DataCell(Text(log['action']! as String)),
                                  DataCell(Text(log['module']! as String)),
                                  DataCell(
                                    SizedBox(
                                      width: 360,
                                      child: Text(
                                        log['description']! as String,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
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

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        Text(text),
        if (action != null) action!,
      ],
    ),
  );
}

String _dateLabel(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
