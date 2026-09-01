import 'dart:developer' as developer;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Abstract base class for all repositories in the application.
/// 
/// This defines the contract that all repositories should follow:
/// - Standardized error handling
/// - Audit logging capability
/// - Common utility methods
/// - Consistent method naming
/// 
/// All concrete repositories should extend this class.
abstract class BaseRepository {
  /// Log an activity to the audit trail
  /// 
  /// Parameters:
  /// - `db`: Database connection
  /// - `userId`: User performing the action
  /// - `action`: What action was performed (created, updated, deleted, etc.)
  /// - `module`: Which module was affected (students, teachers, batches, etc.)
  /// - `description`: Detailed description of what happened
  /// 
  /// Example:
  /// ```dart
  /// await logActivity(
  ///   db: database,
  ///   userId: userId,
  ///   action: 'created',
  ///   module: 'students',
  ///   description: 'Created student: John Doe',
  /// );
  /// ```
  Future<void> logActivity({
    required Database db,
    required String userId,
    required String action,
    required String module,
    required String description,
  }) async {
    try {
      final auditLog = {
        'user_id': int.parse(userId),
        'action': action,
        'module': module,
        'description': description,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      
      await db.insert('audit_logs', auditLog);
    } catch (e) {
      // Audit log failures should not break the main operation
      developer.log('Failed to log activity: $e', name: 'BaseRepository');
    }
  }
  
  /// Validate that a required value is not empty
  /// 
  /// Throws ArgumentError if value is null or empty
  void validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      throw ArgumentError('$fieldName is required');
    }
  }
  
  /// Validate that a value is not negative
  /// 
  /// Throws ArgumentError if value is negative
  void validateNonNegative(int value, String fieldName) {
    if (value < 0) {
      throw ArgumentError('$fieldName cannot be negative');
    }
  }
  
  /// Check if a record with given ID exists in a table
  /// 
  /// Returns true if found, false otherwise
  Future<bool> recordExists(
    Database db,
    String tableName,
    int id,
  ) async {
    final result = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty;
  }
  
  /// Get count of records matching a condition
  /// 
  /// Example:
  /// ```dart
  /// final count = await countWhere(
  ///   db: database,
  ///   table: 'students',
  ///   where: 'batch = ?',
  ///   whereArgs: ['2024A'],
  /// );
  /// ```
  Future<int> countWhere(
    Database db,
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $table${where != null ? ' WHERE $where' : ''}',
      whereArgs ?? [],
    );
    return Intl.parseInt(result.first['count'] as String);
  }
}

class Intl {
  static int parseInt(String value) => int.parse(value);
}
