import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Shared authorization checks for repository operations.
class AccessControl {
  const AccessControl._();

  /// Allows active admins and staff (used by operational modules).
  static Future<void> requireActiveAdminOrStaff(
    DatabaseExecutor database,
    int userId, {
    String action = 'perform this action',
  }) async {
    final rows = await database.query(
      'users',
      columns: ['id'],
      where: 'id = ? AND status = ? AND role IN (?, ?)',
      whereArgs: [userId, 'active', 'admin', 'staff'],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError(
        'Only an active admin or staff member can $action.',
      );
    }
  }

  /// Allows active admins only (audit logs, staff management, etc.).
  static Future<void> requireActiveAdmin(
    DatabaseExecutor database,
    int userId, {
    String action = 'perform this action',
  }) async {
    final rows = await database.query(
      'users',
      columns: ['id'],
      where: 'id = ? AND role = ? AND status = ?',
      whereArgs: [userId, 'admin', 'active'],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Only an active admin can $action.');
    }
  }

  /// Allows active staff only (operational create actions).
  static Future<void> requireActiveStaff(
    DatabaseExecutor database,
    int userId, {
    String action = 'perform this action',
  }) async {
    final rows = await database.query(
      'users',
      columns: ['id'],
      where: 'id = ? AND role = ? AND status = ?',
      whereArgs: [userId, 'staff', 'active'],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Only an active staff member can $action.');
    }
  }
}
