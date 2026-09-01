import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../audit/audit_actions.dart';
import '../audit/audit_log_repository.dart';

class BackupService {
  BackupService({required this.database, AuditLogRepository? auditLogs})
    : _auditLogs = auditLogs ?? const AuditLogRepository();
  final Database database;
  final AuditLogRepository _auditLogs;

  Future<String?> databasePath() async {
    final directory = await getApplicationSupportDirectory();
    return path.join(directory.path, 'damma_school.db');
  }

  Future<String> createBackup({
    required int adminId,
    required String destinationFolder,
  }) async {
    await _requireActiveUser(adminId);
    final source = await databasePath();
    if (source == null || !File(source).existsSync()) {
      throw const InvalidBackupException(
        'The live database file was not found.',
      );
    }
    await database.rawQuery('PRAGMA wal_checkpoint(FULL)');
    final destination = Directory(destinationFolder);
    if (!destination.existsSync()) await destination.create(recursive: true);
    final target = path.join(
      destination.path,
      'damma_school_${_stamp(DateTime.now().toUtc())}.db',
    );
    await File(source).copy(target);
    await _auditLogs.record(
      database: database,
      userId: adminId,
      action: AuditActions.backupCreated,
      module: 'backup_management',
      entityType: 'database',
      description: 'User created a database backup.',
    );
    return target;
  }

  Future<void> validateBackup(String sourcePath) async {
    final file = File(sourcePath);
    if (!file.existsSync()) {
      throw const InvalidBackupException(
        'The selected backup file does not exist.',
      );
    }
    final candidate = await databaseFactoryFfi.openDatabase(
      sourcePath,
      options: OpenDatabaseOptions(readOnly: true),
    );
    try {
      final integrity = await candidate.rawQuery('PRAGMA integrity_check');
      if (integrity.single.values.single != 'ok') {
        throw const InvalidBackupException('SQLite integrity check failed.');
      }
      final tables = await candidate.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = tables.map((row) => row['name']).toSet();
      const required = [
        'users',
        'audit_logs',
        'teachers',
        'batches',
        'batch_history',
        'students',
        'student_batch_history',
        'examinations',
        'exam_results',
      ];
      if (!required.every(names.contains)) {
        throw const InvalidBackupException(
          'The backup is missing required application tables.',
        );
      }
      final admin = await candidate.query(
        'users',
        where: 'role = ?',
        whereArgs: ['admin'],
        limit: 1,
      );
      if (admin.isEmpty) {
        throw const InvalidBackupException(
          'The backup contains no administrator account.',
        );
      }
    } finally {
      await candidate.close();
    }
  }

  Future<String> restoreDatabase({
    required int adminId,
    required String sourcePath,
  }) async {
    await _requireActiveAdmin(adminId);
    await validateBackup(sourcePath);
    final livePath = await databasePath();
    if (livePath == null) {
      throw const InvalidBackupException(
        'The live database path is unavailable.',
      );
    }
    final safetyPath =
        '${livePath.substring(0, livePath.length - 3)}pre_restore_${_stamp(DateTime.now().toUtc())}.db';
    await database.rawQuery('PRAGMA wal_checkpoint(FULL)');
    await database.close();
    try {
      await File(livePath).copy(safetyPath);
      final temporary = '$livePath.restore_tmp';
      await File(sourcePath).copy(temporary);
      await File(temporary).rename(livePath);
      return safetyPath;
    } catch (_) {
      final safety = File(safetyPath);
      if (safety.existsSync()) await safety.copy(livePath);
      rethrow;
    }
  }

  Future<void> _requireActiveUser(int userId) async {
    final rows = await database.query(
      'users',
      columns: ['id'],
      where: 'id = ? AND status = ?',
      whereArgs: [userId, 'active'],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Only an active user can create backups.');
    }
  }

  Future<void> _requireActiveAdmin(int userId) async {
    final rows = await database.query(
      'users',
      columns: ['id'],
      where: 'id = ? AND role = ? AND status = ?',
      whereArgs: [userId, 'admin', 'active'],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Only an active admin can restore the database.');
    }
  }

  String _stamp(DateTime value) => value
      .toIso8601String()
      .replaceAll(RegExp(r'[^0-9]'), '')
      .substring(0, 14);
}

class BackupUnsupportedException implements Exception {
  const BackupUnsupportedException();
}

class InvalidBackupException implements Exception {
  const InvalidBackupException(this.message);
  final String message;
}
