import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../audit/audit_actions.dart';
import '../audit/audit_log_repository.dart';
import '../security/password_hasher.dart';
import '../utils/validators.dart';
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

  Future<void> deleteStaff({
    required Database database,
    required int adminId,
    required int staffId,
  }) async {
    await database.transaction((transaction) async {
      await _requireAdmin(transaction, adminId);
      if (staffId == adminId) {
        throw StateError('You cannot delete your own account.');
      }
      final rows = await transaction.query(
        'users',
        columns: ['username'],
        where: 'id = ? AND role = ?',
        whereArgs: [staffId, 'staff'],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('The target user is not a staff account.');
      }
      final username = rows.single['username']! as String;
      await transaction.update(
        'audit_logs',
        {'user_id': adminId},
        where: 'user_id = ?',
        whereArgs: [staffId],
      );
      await transaction.delete(
        'users',
        where: 'id = ?',
        whereArgs: [staffId],
      );
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.staffDeleted,
        module: 'staff_management',
        entityType: 'user',
        entityId: staffId,
        description: 'Admin permanently deleted staff member $username.',
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

  Future<void> updateUserProfile({
    required Database database,
    required int userId,
    required String fullName,
    required String username,
  }) async {
    final trimmedName = fullName.trim();
    final trimmedUsername = username.trim();
    if (trimmedName.isEmpty) {
      throw const InvalidProfileDataException('Full name is required.');
    }
    if (trimmedName.length < 2 || trimmedName.length > 150) {
      throw const InvalidProfileDataException(
        'Full name must be between 2 and 150 characters.',
      );
    }
    final usernameError = InputValidator.username(trimmedUsername);
    if (usernameError != null) {
      throw InvalidProfileDataException(usernameError);
    }

    await database.transaction((transaction) async {
      final user = await _requireActiveUser(transaction, userId);
      await _ensureUsernameAvailable(
        transaction,
        trimmedUsername,
        excludingId: userId,
      );
      await transaction.update(
        'users',
        {
          'full_name': trimmedName,
          'username': trimmedUsername,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [userId],
      );
      final usernameChanged = user.username != trimmedUsername;
      await _auditLogs.record(
        database: transaction,
        userId: userId,
        action: AuditActions.profileUpdated,
        module: 'user_profile',
        entityType: 'user',
        entityId: userId,
        description: usernameChanged
            ? '${user.username} updated their profile (name and username).'
            : '${user.username} updated their profile name.',
      );
    });
  }

  Future<void> updateUserPassword({
    required Database database,
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    await database.transaction((transaction) async {
      final user = await _requireActiveUser(transaction, userId);
      if (!_passwordHasher.verify(currentPassword, user.passwordHash)) {
        throw const InvalidCurrentPasswordException();
      }
      if (currentPassword == newPassword) {
        throw const InvalidProfileDataException(
          'New password must be different from the current password.',
        );
      }

      await transaction.update(
        'users',
        {
          'password_hash': _passwordHasher.hash(newPassword),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [userId],
      );
      await _auditLogs.record(
        database: transaction,
        userId: userId,
        action: AuditActions.passwordChanged,
        module: 'user_profile',
        entityType: 'user',
        entityId: userId,
        description: '${user.username} changed their account password.',
      );
    });
  }

  Future<User> _requireActiveUser(DatabaseExecutor database, int userId) async {
    final rows = await database.query(
      'users',
      where: 'id = ? AND status = ?',
      whereArgs: [userId, 'active'],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Only an active user can update their profile.');
    }
    return User.fromMap(rows.single);
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

class InvalidProfileDataException implements Exception {
  const InvalidProfileDataException(this.message);
  final String message;
}

class InvalidCurrentPasswordException implements Exception {
  const InvalidCurrentPasswordException();
}