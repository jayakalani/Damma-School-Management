import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../audit/audit_actions.dart';
import '../audit/audit_log_repository.dart';
import '../auth/access_control.dart';
import '../utils/app_validators.dart';

class PastPupilRepository {
  PastPupilRepository({AuditLogRepository? auditLogs})
    : _auditLogs = auditLogs ?? const AuditLogRepository();
  final AuditLogRepository _auditLogs;

  Future<List<Map<String, Object?>>> listBatches({
    required Database database,
    required int adminId,
    String query = '',
    int? yearCompleted,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await _requireAdmin(database, adminId);
    final conditions = <String>[];
    final arguments = <Object?>[];
    final value = query.trim();
    if (value.isNotEmpty) {
      conditions.add('batch_name LIKE ?');
      arguments.add('%$value%');
    }
    if (yearCompleted != null) {
      conditions.add('year_completed = ?');
      arguments.add(yearCompleted);
    }
    if (startDate != null) {
      conditions.add('year_completed >= ?');
      arguments.add(startDate.year);
    }
    if (endDate != null) {
      conditions.add('year_completed <= ?');
      arguments.add(endDate.year);
    }
    return database.query(
      'past_pupil_batches',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'year_completed DESC, batch_name COLLATE NOCASE',
    );
  }

  Future<List<Map<String, Object?>>> listPupils({
    required Database database,
    required int adminId,
    required int batchId,
  }) async {
    await _requireAdmin(database, adminId);
    return database.query(
      'historical_past_pupils',
      where: 'past_pupil_batch_id = ?',
      whereArgs: [batchId],
      orderBy: 'full_name COLLATE NOCASE',
    );
  }

  Future<int> createBatch({
    required Database database,
    required int adminId,
    required String name,
    required int year,
    String? notes,
  }) async {
    if (name.trim().isEmpty || year < 1) {
      throw const InvalidPastPupilBatchException();
    }
    return database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      final now = DateTime.now().toUtc().toIso8601String();
      final id = await transaction.insert('past_pupil_batches', {
        'batch_name': name.trim(),
        'year_completed': year,
        'notes': _clean(notes),
        'created_at': now,
        'updated_at': now,
      });
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.pastPupilBatchCreated,
        module: 'past_pupil_management',
        entityType: 'past_pupil_batch',
        entityId: id,
        description: 'Admin created legacy past pupil batch ${name.trim()}.',
      );
      return id;
    });
  }

  Future<int> addPupil({
    required Database database,
    required int adminId,
    required int batchId,
    required Map<String, Object?> details,
  }) async {
    if ((details['full_name']?.toString().trim() ?? '').isEmpty) {
      throw const InvalidPastPupilException();
    }
    if (AppValidators.nic(details['nic']) != null ||
        AppValidators.phone(details['phone_number']) != null ||
        AppValidators.optionalDate(details['date_of_birth']) != null) {
      throw const InvalidPastPupilException();
    }
    return database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      final batches = await transaction.query(
        'past_pupil_batches',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [batchId],
        limit: 1,
      );
      if (batches.isEmpty) throw StateError('Past pupil batch not found.');
      final now = DateTime.now().toUtc().toIso8601String();
      return transaction.insert('historical_past_pupils', {
        'past_pupil_batch_id': batchId,
        'full_name': details['full_name'].toString().trim(),
        'name_with_initials': _clean(details['name_with_initials']),
        'date_of_birth': _clean(details['date_of_birth']),
        'nic': _clean(details['nic']),
        'phone_number': _clean(details['phone_number']),
        'address': _clean(details['address']),
        'notes': _clean(details['notes']),
        'created_at': now,
        'updated_at': now,
      });
    });
  }

  String? _clean(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  Future<void> _requireAdmin(DatabaseExecutor database, int adminId) async {
    await AccessControl.requireActiveAdminOrStaff(
      database,
      adminId,
      action: 'manage past pupils',
    );
  }
}

class InvalidPastPupilBatchException implements Exception {
  const InvalidPastPupilBatchException();
}

class InvalidPastPupilException implements Exception {
  const InvalidPastPupilException();
}
