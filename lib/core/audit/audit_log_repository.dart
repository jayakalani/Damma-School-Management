import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AuditLogRepository {
  const AuditLogRepository();

  Future<int> record({
    required DatabaseExecutor database,
    required int userId,
    required String action,
    required String module,
    required String description,
    String? entityType,
    int? entityId,
  }) async {
    final actor = await database.query(
      'users',
      columns: ['id'],
      where: 'id = ? AND status = ?',
      whereArgs: [userId, 'active'],
      limit: 1,
    );
    if (actor.isEmpty) {
      throw StateError('Only an active user can create an audit log.');
    }

    return database.insert('audit_logs', {
      'user_id': userId,
      'action': action,
      'module': module,
      'entity_type': entityType,
      'entity_id': entityId,
      'description': description,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> listForAdmin({
    required DatabaseExecutor database,
    required int adminId,
    String query = '',
    int? userId,
    String? module,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await _requireAdmin(database, adminId);
    final conditions = <String>[];
    final arguments = <Object?>[];
    final value = query.trim();
    if (value.isNotEmpty) {
      conditions.add(
        '(users.username LIKE ? OR users.full_name LIKE ? OR audit_logs.action LIKE ? OR audit_logs.module LIKE ? OR audit_logs.description LIKE ?)',
      );
      final pattern = '%$value%';
      arguments.addAll([pattern, pattern, pattern, pattern, pattern]);
    }
    if (userId != null) {
      conditions.add('audit_logs.user_id = ?');
      arguments.add(userId);
    }
    if (module != null && module.isNotEmpty) {
      conditions.add('audit_logs.module = ?');
      arguments.add(module);
    }
    if (startDate != null) {
      conditions.add('audit_logs.created_at >= ?');
      arguments.add(startDate.toUtc().toIso8601String());
    }
    if (endDate != null) {
      conditions.add('audit_logs.created_at < ?');
      arguments.add(
        endDate.toUtc().add(const Duration(days: 1)).toIso8601String(),
      );
    }
    return database.rawQuery('''
      SELECT audit_logs.*, users.username AS actor_username,
        users.full_name AS actor_full_name
      FROM audit_logs
      INNER JOIN users ON users.id = audit_logs.user_id
      ${conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}'}
      ORDER BY audit_logs.created_at DESC, audit_logs.id DESC
    ''', arguments);
  }

  Future<List<Map<String, Object?>>> listUsersForFilter({
    required DatabaseExecutor database,
    required int adminId,
  }) async {
    await _requireAdmin(database, adminId);
    return database.query(
      'users',
      columns: ['id', 'username', 'full_name'],
      orderBy: 'full_name COLLATE NOCASE',
    );
  }

  Future<List<String>> listModulesForFilter({
    required DatabaseExecutor database,
    required int adminId,
  }) async {
    await _requireAdmin(database, adminId);
    final rows = await database.rawQuery(
      'SELECT DISTINCT module FROM audit_logs ORDER BY module COLLATE NOCASE',
    );
    return rows.map((row) => row['module']! as String).toList();
  }

  Future<int> logActivity({
    required DatabaseExecutor database,
    required String userId,
    required String action,
    required String module,
    String? description,
  }) async {
    final parsedUserId = int.tryParse(userId.trim());
    if (parsedUserId == null) throw const InvalidAuditUserIdException();
    return record(
      database: database,
      userId: parsedUserId,
      action: action,
      module: module,
      description: description ?? '',
    );
  }

  Future<void> _requireAdmin(DatabaseExecutor database, int userId) async {
    final admins = await database.query(
      'users',
      columns: ['id'],
      where: 'id = ? AND role = ? AND status = ?',
      whereArgs: [userId, 'admin', 'active'],
      limit: 1,
    );
    if (admins.isEmpty) {
      throw StateError('Only an active admin can view audit logs.');
    }
  }
}

class InvalidAuditUserIdException implements Exception {
  const InvalidAuditUserIdException();
}
