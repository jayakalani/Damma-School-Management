import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../audit/audit_actions.dart';
import '../audit/audit_log_repository.dart';

class BatchRepository {
  BatchRepository({AuditLogRepository? auditLogs})
    : _auditLogs = auditLogs ?? const AuditLogRepository();

  final AuditLogRepository _auditLogs;

  Future<List<Map<String, Object?>>> listBatches({
    required Database database,
    required int adminId,
    String query = '',
  }) async {
    await _requireAdmin(database, adminId);
    final trimmed = query.trim();
    return database.rawQuery('''
      SELECT batches.*, history.academic_year, history.grade, history.started_date,
        history.is_current
      FROM batches
      LEFT JOIN batch_history history ON history.batch_id = batches.id AND history.is_current = 1
      ${trimmed.isEmpty ? '' : 'WHERE batches.batch_name LIKE ?'}
      ORDER BY batches.batch_name COLLATE NOCASE
    ''', trimmed.isEmpty ? null : ['%$trimmed%']);
  }

  Future<BatchDetails> getBatchDetails({
    required Database database,
    required int adminId,
    required int batchId,
  }) async {
    await _requireAdmin(database, adminId);
    final batches = await database.query(
      'batches',
      where: 'id = ?',
      whereArgs: [batchId],
      limit: 1,
    );
    if (batches.isEmpty) throw StateError('Batch not found.');
    final history = await database.query(
      'batch_history',
      where: 'batch_id = ?',
      whereArgs: [batchId],
      orderBy: 'academic_year, id',
    );
    final students = await database.rawQuery(
      '''
      SELECT students.*, membership.batch_history_id, membership.joined_date,
        membership.left_date, membership.is_current
      FROM student_batch_history membership
      INNER JOIN students ON students.id = membership.student_id
      WHERE membership.batch_id = ?
      ORDER BY students.full_name COLLATE NOCASE
    ''',
      [batchId],
    );
    final teachers = await database.rawQuery(
      '''
      SELECT teachers.*, assignment.batch_history_id, assignment.assigned_date,
        assignment.removed_date, assignment.is_current
      FROM batch_teacher_history assignment
      INNER JOIN teachers ON teachers.id = assignment.teacher_id
      INNER JOIN batch_history history ON history.id = assignment.batch_history_id
      WHERE history.batch_id = ?
      ORDER BY teachers.full_name COLLATE NOCASE
    ''',
      [batchId],
    );
    final examinations = await database.rawQuery(
      '''
      SELECT examinations.*, history.academic_year, history.grade
      FROM examinations
      INNER JOIN batch_history history ON history.id = examinations.batch_history_id
      WHERE history.batch_id = ?
      ORDER BY examinations.examination_date DESC, examinations.id DESC
    ''',
      [batchId],
    );
    return BatchDetails(
      batch: batches.single,
      history: history,
      students: students,
      teachers: teachers,
      examinations: examinations,
    );
  }

  Future<List<Map<String, Object?>>> listStudents({
    required Database database,
    required int adminId,
    String query = '',
  }) async {
    await _requireAdmin(database, adminId);
    final value = query.trim();
    return database.query(
      'students',
      where: value.isEmpty
          ? null
          : '(full_name LIKE ? OR name_with_initials LIKE ? OR nic LIKE ?)',
      whereArgs: value.isEmpty ? null : ['%$value%', '%$value%', '%$value%'],
      orderBy: 'full_name COLLATE NOCASE',
    );
  }

  Future<void> assignClassTeacher({
    required Database database,
    required int adminId,
    required int batchId,
    required int teacherId,
  }) async {
    await database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      final history = await _currentHistory(transaction, batchId);
      final teachers = await transaction.query(
        'teachers',
        columns: ['id'],
        where: 'id = ? AND status = ?',
        whereArgs: [teacherId, 'active'],
        limit: 1,
      );
      if (teachers.isEmpty) throw StateError('An active teacher is required.');
      final now = DateTime.now().toUtc().toIso8601String();
      final current = await transaction.query(
        'batch_teacher_history',
        columns: ['id', 'teacher_id'],
        where: 'batch_history_id = ? AND is_current = 1',
        whereArgs: [history['id']],
        limit: 1,
      );
      if (current.isNotEmpty && current.single['teacher_id'] == teacherId)
        return;
      if (current.isNotEmpty) {
        await transaction.update(
          'batch_teacher_history',
          {'is_current': 0, 'removed_date': now, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [current.single['id']],
        );
      }
      await transaction.insert('batch_teacher_history', {
        'batch_history_id': history['id'],
        'teacher_id': teacherId,
        'assigned_date': now,
        'is_current': 1,
        'created_at': now,
        'updated_at': now,
      });
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.batchTeacherChanged,
        module: 'batch_management',
        entityType: 'batch',
        entityId: batchId,
        description: 'Admin assigned class teacher to batch.',
      );
    });
  }

  Future<void> addStudentToBatch({
    required Database database,
    required int adminId,
    required int batchId,
    required int studentId,
  }) async {
    await database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      final history = await _currentHistory(transaction, batchId);
      final students = await transaction.query(
        'students',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [studentId],
        limit: 1,
      );
      if (students.isEmpty) throw StateError('Student not found.');
      final current = await transaction.query(
        'student_batch_history',
        columns: ['id', 'batch_id', 'batch_history_id'],
        where: 'student_id = ? AND is_current = 1',
        whereArgs: [studentId],
        limit: 1,
      );
      if (current.isNotEmpty &&
          current.single['batch_id'] == batchId &&
          current.single['batch_history_id'] == history['id'])
        throw const StudentAlreadyInBatchException();
      final now = DateTime.now().toUtc().toIso8601String();
      if (current.isNotEmpty) {
        await transaction.update(
          'student_batch_history',
          {'is_current': 0, 'left_date': now, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [current.single['id']],
        );
      }
      await transaction.insert('student_batch_history', {
        'student_id': studentId,
        'batch_id': batchId,
        'batch_history_id': history['id'],
        'joined_date': now,
        'is_current': 1,
        'created_at': now,
        'updated_at': now,
      });
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.studentAdded,
        module: 'batch_management',
        entityType: 'student',
        entityId: studentId,
        description: 'Admin added student to batch.',
      );
    });
  }

  Future<int> createBatch({
    required Database database,
    required int adminId,
    required String name,
    required int startingYear,
    required String startingGrade,
  }) async {
    _validate(name, startingYear, startingGrade);
    return database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      final now = DateTime.now().toUtc().toIso8601String();
      final batchId = await transaction.insert('batches', {
        'batch_name': name.trim(),
        'starting_year': startingYear,
        'created_at': now,
        'updated_at': now,
      });
      final historyId = await transaction.insert('batch_history', {
        'batch_id': batchId,
        'academic_year': startingYear,
        'grade': startingGrade.trim(),
        'started_date': now,
        'is_current': 1,
        'created_at': now,
        'updated_at': now,
      });
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.batchCreated,
        module: 'batch_management',
        entityType: 'batch',
        entityId: batchId,
        description: 'Admin created batch ${name.trim()}.',
      );
      return historyId;
    });
  }

  Future<int> promoteBatch({
    required Database database,
    required int adminId,
    required int batchId,
    required int academicYear,
    required String grade,
  }) async {
    _validate('valid', academicYear, grade);
    return database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      final currentRows = await transaction.query(
        'batch_history',
        where: 'batch_id = ? AND is_current = 1',
        whereArgs: [batchId],
        limit: 1,
      );
      if (currentRows.isEmpty)
        throw StateError('Batch has no current history.');
      final batchRows = await transaction.query(
        'batches',
        columns: ['batch_name'],
        where: 'id = ?',
        whereArgs: [batchId],
        limit: 1,
      );
      if (batchRows.isEmpty) throw StateError('Batch not found.');
      final now = DateTime.now().toUtc().toIso8601String();
      await transaction.update(
        'batch_history',
        {'is_current': 0, 'ended_date': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [currentRows.single['id']],
      );
      final historyId = await transaction.insert('batch_history', {
        'batch_id': batchId,
        'academic_year': academicYear,
        'grade': grade.trim(),
        'started_date': now,
        'is_current': 1,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.update(
        'batches',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [batchId],
      );
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.batchPromoted,
        module: 'batch_management',
        entityType: 'batch',
        entityId: batchId,
        description:
            'Admin promoted batch to $academicYear, grade ${grade.trim()}.',
      );
      return historyId;
    });
  }

  void _validate(String name, int year, String grade) {
    if (name.trim().isEmpty || grade.trim().isEmpty || year < 1)
      throw const InvalidBatchException();
  }

  Future<Map<String, Object?>> _currentHistory(
    DatabaseExecutor database,
    int batchId,
  ) async {
    final rows = await database.query(
      'batch_history',
      where: 'batch_id = ? AND is_current = 1',
      whereArgs: [batchId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Batch has no current history.');
    return rows.single;
  }

  Future<void> _requireAdmin(DatabaseExecutor database, int adminId) async {
    final rows = await database.query(
      'users',
      columns: ['id'],
      where: 'id = ? AND role = ? AND status = ?',
      whereArgs: [adminId, 'admin', 'active'],
      limit: 1,
    );
    if (rows.isEmpty)
      throw StateError('Only an active admin can manage batches.');
  }
}

class BatchDetails {
  const BatchDetails({
    required this.batch,
    required this.history,
    required this.students,
    required this.teachers,
    required this.examinations,
  });
  final Map<String, Object?> batch;
  final List<Map<String, Object?>> history;
  final List<Map<String, Object?>> students;
  final List<Map<String, Object?>> teachers;
  final List<Map<String, Object?>> examinations;
}

class InvalidBatchException implements Exception {
  const InvalidBatchException();
}

class StudentAlreadyInBatchException implements Exception {
  const StudentAlreadyInBatchException();
}
