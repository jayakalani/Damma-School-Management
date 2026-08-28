import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/backup/backup_service.dart';
import '../../core/services/auth_service.dart';

class BackupManagementPage extends StatefulWidget {
  const BackupManagementPage({
    super.key,
    required this.database,
    required this.auth,
    this.onRestore,
  });
  final Database database;
  final AuthService auth;
  final Future<void> Function()? onRestore;
  @override
  State<BackupManagementPage> createState() => _BackupManagementPageState();
}

class _BackupManagementPageState extends State<BackupManagementPage> {
  late final BackupService service;
  bool busy = false;
  int get userId => widget.auth.currentSession!.userId;
  bool get isAdmin => widget.auth.currentSession?.isAdmin == true;
  @override
  void initState() {
    super.initState();
    service = BackupService(database: widget.database);
    widget.auth.requireRole(widget.auth.currentSession!.role);
  }

  Future<void> createBackup() async {
    if (kIsWeb) {
      _message('Backups are available in the desktop app.', error: true);
      return;
    }
    final folder = await getDirectoryPath(
      confirmButtonText: 'Save Backup Here',
    );
    if (folder == null || !mounted) return;
    setState(() => busy = true);
    try {
      final file = await service.createBackup(
        adminId: userId,
        destinationFolder: folder,
      );
      _message('Backup created: $file');
    } catch (_) {
      _message('Unable to create backup.', error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restore() async {
    if (!isAdmin) {
      _message('Only an administrator can restore the database.', error: true);
      return;
    }
    if (kIsWeb) {
      _message('Restore is available in the desktop app.', error: true);
      return;
    }
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'SQLite database',
          extensions: ['db', 'sqlite', 'sqlite3'],
        ),
      ],
    );
    if (file == null || !mounted) return;
    setState(() => busy = true);
    try {
      await service.validateBackup(file.path);
      if (!mounted) return;
      if (await _confirm(
                'Restore this database?',
                'The selected backup passed validation. The current database will first be saved as a safety copy.',
              ) !=
              true ||
          !mounted)
        return;
      if (await _confirm(
                'Final confirmation',
                'This will replace the current database and restart the application. Continue?',
              ) !=
              true ||
          !mounted)
        return;
      await service.restoreDatabase(adminId: userId, sourcePath: file.path);
      await widget.onRestore?.call();
    } on InvalidBackupException catch (error) {
      _message(error.message, error: true);
    } catch (_) {
      _message(
        'Restore failed. The original database was preserved when possible.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool?> _confirm(String title, String message) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
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
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Backup & Restore'),
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Database Safety',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a timestamped copy of the application database or restore a validated copy.',
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: busy ? null : createBackup,
                    icon: const Icon(Icons.backup_outlined),
                    label: const Text('Create Backup'),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: busy ? null : restore,
                      icon: const Icon(Icons.restore),
                      label: const Text('Restore Database'),
                    ),
                  ],
                  if (busy) ...[
                    const SizedBox(height: 20),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ),
        ),
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
