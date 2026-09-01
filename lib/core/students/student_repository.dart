import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../audit/audit_actions.dart';
import '../audit/audit_log_repository.dart';
import '../utils/app_validators.dart';

class StudentRepository {
  StudentRepository({AuditLogRepository? auditLogs})
    : _auditLogs = auditLogs ?? const AuditLogRepository();

  final AuditLogRepository _auditLogs;

  Future<List<Map<String, Object?>>> searchStudents({
    required Database database,
    required int adminId,
    String query = '',
    String? status,
  }) async {
    await _requireAdmin(database, adminId);
    final conditions = <String>[];
    final arguments = <Object?>[];
    final value = query.trim();
    if (value.isNotEmpty) {
      conditions.add(
        '(full_name LIKE ? OR name_with_initials LIKE ? OR nic LIKE ? OR phone_number LIKE ?)',
      );
      final pattern = '%$value%';
      arguments.addAll([pattern, pattern, pattern, pattern]);
    }
    if (status != null) {
      conditions.add('status = ?');
      arguments.add(status);
    }
    return database.query(
      'students',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'full_name COLLATE NOCASE',
    );
  }

  Future<int> createStudent({
    required Database database,
    required int adminId,
    required Map<String, Object?> details,
  }) async {
    _validate(details);
    return database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      final now = DateTime.now().toUtc().toIso8601String();
      final id = await transaction.insert('students', {
        ..._studentDetails(details),
        'status': 'student',
        'created_at': now,
        'updated_at': now,
      });
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.studentAdded,
        module: 'student_management',
        entityType: 'student',
        entityId: id,
        description: 'Admin registered student ${details['full_name']}.',
      );
      return id;
    });
  }

  Future<void> updateStudent({
    required Database database,
    required int adminId,
    required int studentId,
    required Map<String, Object?> details,
  }) async {
    _validate(details);
    await database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      await _requireStudent(transaction, studentId);
      await transaction.update(
        'students',
        {
          ..._studentDetails(details),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [studentId],
      );
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.studentUpdated,
        module: 'student_management',
        entityType: 'student',
        entityId: studentId,
        description: 'Admin updated student ${details['full_name']}.',
      );
    });
  }

  Future<void> convertToPastPupil({
    required Database database,
    required int adminId,
    required int studentId,
  }) async {
    await database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      await _requireStudent(transaction, studentId);
      final now = DateTime.now().toUtc().toIso8601String();
      await transaction.update(
        'students',
        {'status': 'past_pupil', 'updated_at': now},
        where: 'id = ?',
        whereArgs: [studentId],
      );
      await _closeCurrentMembership(transaction, studentId, now);
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.studentPastPupil,
        module: 'student_management',
        entityType: 'student',
        entityId: studentId,
        description: 'Admin converted student to past pupil.',
      );
    });
  }

  Future<int> bulkConvertBatchToPastPupils({
    required Database database,
    required int adminId,
    required int batchId,
  }) async {
    return database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      final rows = await transaction.rawQuery(
        'SELECT membership.student_id FROM student_batch_history membership INNER JOIN students ON students.id = membership.student_id WHERE membership.batch_id = ? AND membership.is_current = 1 AND students.status = ?',
        [batchId, 'student'],
      );
      final now = DateTime.now().toUtc().toIso8601String();
      var count = 0;
      for (final row in rows) {
        final id = row['student_id']! as int;
        await transaction.update(
          'students',
          {'status': 'past_pupil', 'updated_at': now},
          where: 'id = ? AND status = ?',
          whereArgs: [id, 'student'],
        );
        await _closeCurrentMembership(transaction, id, now);
        count++;
      }
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.studentsBulkPastPupil,
        module: 'student_management',
        entityType: 'batch',
        entityId: batchId,
        description:
            'Admin converted $count current batch students to past pupils.',
      );
      return count;
    });
  }

  Future<void> _closeCurrentMembership(
    DatabaseExecutor database,
    int studentId,
    String now,
  ) async {
    await database.update(
      'student_batch_history',
      {'is_current': 0, 'left_date': now, 'updated_at': now},
      where: 'student_id = ? AND is_current = 1',
      whereArgs: [studentId],
    );
  }

  Map<String, Object?> _cleanDetails(Map<String, Object?> details) => {
    for (final entry in details.entries) entry.key: _clean(entry.value),
  };
  Object? _clean(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  void _validate(Map<String, Object?> details) {
    if ((details['full_name']?.toString().trim() ?? '').isEmpty ||
        (details['name_with_initials']?.toString().trim() ?? '').isEmpty ||
        (details['joined_date']?.toString().trim() ?? '').isEmpty) {
      throw const InvalidStudentException();
    }
    if (AppValidators.phone(details['phone_number']) != null ||
        AppValidators.optionalDate(details['date_of_birth']) != null ||
        AppValidators.date(details['joined_date'], 'Joined date') != null) {
      throw const InvalidStudentException();
    }
  }

  Map<String, Object?> _studentDetails(Map<String, Object?> details) => {
    ..._cleanDetails(details),
    'nic': null,
  };

  Future<void> _requireAdmin(DatabaseExecutor database, int adminId) async {
    final rows = await database.query(
      'users',
      columns: ['id'],
      where: 'id = ? AND role = ? AND status = ?',
      whereArgs: [adminId, 'admin', 'active'],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Only an active admin can manage students.');
    }
  }

  Future<void> _requireStudent(DatabaseExecutor database, int studentId) async {
    final rows = await database.query(
      'students',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [studentId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Student not found.');
  }
}

class InvalidStudentException implements Exception {
  const InvalidStudentException();
}
