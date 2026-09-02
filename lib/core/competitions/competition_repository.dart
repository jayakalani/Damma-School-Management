import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../audit/audit_actions.dart';
import '../audit/audit_log_repository.dart';
import '../auth/access_control.dart';
import '../utils/app_validators.dart';

class CompetitionRepository {
  CompetitionRepository({AuditLogRepository? auditLogs})
    : _auditLogs = auditLogs ?? const AuditLogRepository();

  final AuditLogRepository _auditLogs;

  Future<List<Map<String, Object?>>> listCompetitions({
    required Database database,
    required int adminId,
  }) async {
    await AccessControl.requireActiveAdminOrStaff(
      database,
      adminId,
      action: 'manage competitions',
    );
    return database.query(
      'competitions',
      orderBy: 'competition_date DESC, id DESC',
    );
  }

  Future<int> createCompetition({
    required Database database,
    required int adminId,
    required String name,
    required String date,
    String? venue,
    String? description,
  }) async {
    if (name.trim().isEmpty ||
        AppValidators.date(date, 'Competition date') != null) {
      throw const InvalidCompetitionException();
    }
    return database.transaction((transaction) async {
      await AccessControl.requireActiveStaff(
        transaction,
        adminId,
        action: 'create competitions',
      );
      final now = _now();
      final id = await transaction.insert('competitions', {
        'competition_name': name.trim(),
        'competition_date': date.trim(),
        'venue': _clean(venue),
        'description': _clean(description),
        'created_at': now,
        'updated_at': now,
      });
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.competitionCreated,
        module: 'competition_management',
        entityType: 'competition',
        entityId: id,
        description: 'Staff created competition ${name.trim()}.',
      );
      return id;
    });
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String _now() => DateTime.now().toUtc().toIso8601String();
}

class InvalidCompetitionException implements Exception {
  const InvalidCompetitionException();
}
