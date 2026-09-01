import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../audit/audit_actions.dart';
import '../audit/audit_log_repository.dart';
import '../utils/app_validators.dart';

class TeacherRepository {
  TeacherRepository({AuditLogRepository? auditLogs})
    : _auditLogs = auditLogs ?? const AuditLogRepository();

  final AuditLogRepository _auditLogs;

  Future<List<Map<String, Object?>>> searchTeachers({
    required Database database,
    required int adminId,
    String query = '',
    String? status,
  }) async {
    await _requireAdmin(database, adminId);
    final conditions = <String>[];
    final arguments = <Object?>[];
    if (query.trim().isNotEmpty) {
      conditions.add(
        '(full_name LIKE ? OR name_with_initials LIKE ? OR nic LIKE ? OR phone_number LIKE ?)',
      );
      final value = '%${query.trim()}%';
      arguments.addAll([value, value, value, value]);
    }
    if (status != null) {
      conditions.add('status = ?');
      arguments.add(status);
    }
    return database.query(
      'teachers',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'full_name COLLATE NOCASE',
    );
  }

  Future<List<Map<String, Object?>>> qualifications({
    required Database database,
    required int adminId,
    required int teacherId,
  }) async {
    await _requireAdmin(database, adminId);
    return database.query(
      'teacher_qualifications',
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
      orderBy: 'id',
    );
  }

  Future<int> createTeacher({
    required Database database,
    required int adminId,
    required Map<String, Object?> details,
    required List<Map<String, Object?>> qualifications,
  }) async {
    _validateDetails(details);
    return database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      final now = DateTime.now().toUtc().toIso8601String();
      final teacherId = await transaction.insert('teachers', {
        ...details,
        'status': details['status'] ?? 'active',
        'created_at': now,
        'updated_at': now,
      });
      await _replaceQualifications(transaction, teacherId, qualifications, now);
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.teacherCreated,
        module: 'teacher_management',
        entityType: 'teacher',
        entityId: teacherId,
        description: 'Admin created teacher ${details['full_name']}.',
      );
      return teacherId;
    });
  }

  Future<void> updateTeacher({
    required Database database,
    required int adminId,
    required int teacherId,
    required Map<String, Object?> details,
    required List<Map<String, Object?>> qualifications,
  }) async {
    _validateDetails(details);
    await database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      await _requireTeacher(transaction, teacherId);
      final now = DateTime.now().toUtc().toIso8601String();
      await transaction.update(
        'teachers',
        {...details, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [teacherId],
      );
      await _replaceQualifications(transaction, teacherId, qualifications, now);
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.teacherUpdated,
        module: 'teacher_management',
        entityType: 'teacher',
        entityId: teacherId,
        description: 'Admin updated teacher ${details['full_name']}.',
      );
    });
  }

  void _validateDetails(Map<String, Object?> details) {
    if (AppValidators.requiredText(details['full_name'], 'Full name') != null ||
        AppValidators.requiredText(
              details['name_with_initials'],
              'Name with initials',
            ) !=
            null ||
        AppValidators.date(details['registered_date'], 'Registered date') !=
            null ||
        AppValidators.nic(details['nic']) != null ||
        AppValidators.phone(details['phone_number']) != null ||
        AppValidators.optionalDate(details['date_of_birth']) != null) {
      throw StateError('Teacher details are invalid.');
    }
  }

  Future<void> setTeacherStatus({
    required Database database,
    required int adminId,
    required int teacherId,
    required bool active,
  }) async {
    await database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      await _requireTeacher(transaction, teacherId);
      await transaction.update(
        'teachers',
        {
          'status': active ? 'active' : 'inactive',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [teacherId],
      );
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.teacherStatusChanged,
        module: 'teacher_management',
        entityType: 'teacher',
        entityId: teacherId,
        description: 'Admin ${active ? 'activated' : 'deactivated'} teacher.',
      );
    });
  }

  Future<void> deleteTeacher({
    required Database database,
    required int adminId,
    required int teacherId,
  }) async {
    await database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      await _requireTeacher(transaction, teacherId);
      final assignments = await transaction.query(
        'batch_teacher_history',
        columns: ['id'],
        where: 'teacher_id = ?',
        whereArgs: [teacherId],
        limit: 1,
      );
      if (assignments.isNotEmpty) throw const TeacherHasAssignmentsException();
      await transaction.delete(
        'teacher_qualifications',
        where: 'teacher_id = ?',
        whereArgs: [teacherId],
      );
      await transaction.delete(
        'teachers',
        where: 'id = ?',
        whereArgs: [teacherId],
      );
    });
  }

  Future<void> _replaceQualifications(
    DatabaseExecutor database,
    int teacherId,
    List<Map<String, Object?>> values,
    String now,
  ) async {
    await database.delete(
      'teacher_qualifications',
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
    );
    for (final value in values) {
      final qualification = value['qualification']?.toString().trim() ?? '';
      if (qualification.isEmpty) continue;
      await database.insert('teacher_qualifications', {
        'teacher_id': teacherId,
        'qualification': qualification,
        'institution': _clean(value['institution']),
        'completion_year': value['completion_year'],
        'notes': _clean(value['notes']),
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  String? _clean(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  Future<void> _requireAdmin(DatabaseExecutor database, int adminId) async {
    final rows = await database.query(
      'users',
      columns: ['id'],
      where: 'id = ? AND role = ? AND status = ?',
      whereArgs: [adminId, 'admin', 'active'],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Only an active admin can manage teachers.');
    }
  }

  Future<void> _requireTeacher(DatabaseExecutor database, int teacherId) async {
    final rows = await database.query(
      'teachers',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [teacherId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Teacher not found.');
  }
}

class TeacherHasAssignmentsException implements Exception {
  const TeacherHasAssignmentsException();
}
