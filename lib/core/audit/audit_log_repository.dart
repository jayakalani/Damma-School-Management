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
  }) async {
    await _requireAdmin(database, adminId);
    return database.rawQuery('''
      SELECT audit_logs.*, users.username AS actor_username,
        users.full_name AS actor_full_name
      FROM audit_logs
      INNER JOIN users ON users.id = audit_logs.user_id
      ORDER BY audit_logs.created_at DESC, audit_logs.id DESC
    ''');
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