import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../audit/audit_actions.dart';
import '../audit/audit_log_repository.dart';
import '../security/password_hasher.dart';
import '../../models/database_models.dart';

class UserRepository {
  UserRepository({
    PasswordHasher? passwordHasher,
    AuditLogRepository? auditLogs,
  })  : _passwordHasher = passwordHasher ?? const PasswordHasher(),
        _auditLogs = auditLogs ?? const AuditLogRepository();

  final PasswordHasher _passwordHasher;
  final AuditLogRepository _auditLogs;

  Future<User?> findByUsername({
    required Database database,
    required String username,
  }) async {
    final rows = await database.query(
      'users',
      where: 'username = ?',
      whereArgs: [username.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : User.fromMap(rows.single);
  }

  Future<User?> findById({required Database database, required int id}) async {
    final rows = await database.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : User.fromMap(rows.single);
  }

  Future<List<Map<String, Object?>>> listStaff({
    required Database database,
    required int adminId,
  }) async {
    await _requireAdmin(database, adminId);
    return database.query(
      'users',
      where: 'role = ?',
      whereArgs: ['staff'],
      orderBy: 'full_name COLLATE NOCASE',
    );
  }

  Future<List<Map<String, Object?>>> searchStaff({
    required Database database,
    required int adminId,
    String query = '',
    String? status,
  }) async {
    await _requireAdmin(database, adminId);
    final conditions = <String>['role = ?'];
    final arguments = <Object?>['staff'];
    if (query.trim().isNotEmpty) {
      conditions.add('(full_name LIKE ? OR username LIKE ?)');
      final value = '%${query.trim()}%';
      arguments.addAll([value, value]);
    }
    if (status != null) {
      conditions.add('status = ?');
      arguments.add(status);
    }
    return database.query(
      'users',
      where: conditions.join(' AND '),
      whereArgs: arguments,
      orderBy: 'full_name COLLATE NOCASE',
    );
  }

  Future<int> createStaff({
    required Database database,
    required int adminId,
    required String fullName,
    required String username,
    required String password,
    String status = 'active',
  }) async {
    if (status != 'active' && status != 'inactive') {
      throw const InvalidStaffStatusException();
    }
    return database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      await _ensureUsernameAvailable(transaction, username);
      final now = DateTime.now().toUtc().toIso8601String();
      final staffId = await transaction.insert('users', {
        'full_name': fullName.trim(),
        'username': username.trim(),
        'password_hash': _passwordHasher.hash(password),
        'role': 'staff',
        'status': status,
        'created_at': now,
        'updated_at': now,
      });
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.staffCreated,
        module: 'staff_management',
        entityType: 'user',
        entityId: staffId,
        description: 'Admin created staff member ${username.trim()}.',
      );
      return staffId;
    });
  }

  Future<void> updateStaff({
    required Database database,
    required int adminId,
    required int staffId,
    required String fullName,
    required String username,
  }) async {
    await database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      await _requireStaff(transaction, staffId);
      await _ensureUsernameAvailable(transaction, username, excludingId: staffId);
      await transaction.update(
        'users',
        {
          'full_name': fullName.trim(),
          'username': username.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [staffId],
      );
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.staffUpdated,
        module: 'staff_management',
        entityType: 'user',
        entityId: staffId,
        description: 'Admin updated staff member ${username.trim()}.',
      );
    });
  }

  Future<void> setStaffStatus({
    required Database database,
    required int adminId,
    required int staffId,
    required bool active,
  }) async {
    await database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      await _requireStaff(transaction, staffId);
      await transaction.update(
        'users',
        {
          'status': active ? 'active' : 'inactive',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [staffId],
      );
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.staffStatusChanged,
        module: 'staff_management',
        entityType: 'user',
        entityId: staffId,
        description: 'Admin ${active ? 'activated' : 'deactivated'} staff member.',
      );
    });
  }

  Future<void> resetStaffPassword({
    required Database database,
    required int adminId,
    required int staffId,
    required String newPassword,
  }) async {
    await database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      await _requireStaff(transaction, staffId);
      await transaction.update(
        'users',
        {
          'password_hash': _passwordHasher.hash(newPassword),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [staffId],
      );
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: 'staff_password_reset',
        module: 'staff_management',
        entityType: 'user',
        entityId: staffId,
        description: 'Admin reset a staff member password.',
      );
    });
  }

  Future<void> _requireAdmin(DatabaseExecutor database, int adminId) async {
    final admins = await database.query(
      'users',
      columns: ['id'],
      where: 'id = ? AND role = ? AND status = ?',
      whereArgs: [adminId, 'admin', 'active'],
      limit: 1,
    );
    if (admins.isEmpty) {
      throw StateError('Only an active admin can manage staff accounts.');
    }
  }

  Future<void> _requireStaff(DatabaseExecutor database, int staffId) async {
    final staff = await database.query(
      'users',
      columns: ['id'],
      where: 'id = ? AND role = ?',
      whereArgs: [staffId, 'staff'],
      limit: 1,
    );
    if (staff.isEmpty) {
      throw StateError('The target user is not a staff account.');
    }
  }

  Future<void> _ensureUsernameAvailable(
    DatabaseExecutor database,
    String username, {
    int? excludingId,
  }) async {
    final conditions = <String>['username = ?'];
    final arguments = <Object?>[username.trim()];
    if (excludingId != null) {
      conditions.add('id != ?');
      arguments.add(excludingId);
    }
    final matches = await database.query(
      'users',
      columns: ['id'],
      where: conditions.join(' AND '),
      whereArgs: arguments,
      limit: 1,
    );
    if (matches.isNotEmpty) throw const UsernameAlreadyInUseException();
  }
}

class UsernameAlreadyInUseException implements Exception {
  const UsernameAlreadyInUseException();
}

class InvalidStaffStatusException implements Exception {
  const InvalidStaffStatusException();
}