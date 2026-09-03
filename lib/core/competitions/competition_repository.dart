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

  Future<Map<String, Object?>> getCompetition({
    required Database database,
    required int adminId,
    required int competitionId,
  }) async {
    await AccessControl.requireActiveAdminOrStaff(
      database,
      adminId,
      action: 'manage competitions',
    );
    final rows = await database.query(
      'competitions',
      where: 'id = ?',
      whereArgs: [competitionId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Competition not found.');
    }
    return rows.single;
  }

  Future<List<Map<String, Object?>>> listCompetitionBatches({
    required Database database,
    required int adminId,
    required int competitionId,
  }) async {
    await AccessControl.requireActiveAdminOrStaff(
      database,
      adminId,
      action: 'manage competitions',
    );
    return database.rawQuery(
      '''
      SELECT batches.id, batches.batch_name, batches.starting_year,
        history.id AS batch_history_id, history.academic_year, history.grade,
        competition_batches.added_at
      FROM competition_batches
      INNER JOIN batches ON batches.id = competition_batches.batch_id
      INNER JOIN batch_history history
        ON history.batch_id = batches.id AND history.is_current = 1
      WHERE competition_batches.competition_id = ?
      ORDER BY batches.batch_name COLLATE NOCASE
      ''',
      [competitionId],
    );
  }

  Future<List<Map<String, Object?>>> listActiveBatchesNotInCompetition({
    required Database database,
    required int adminId,
    required int competitionId,
  }) async {
    await AccessControl.requireActiveAdminOrStaff(
      database,
      adminId,
      action: 'manage competitions',
    );
    return database.rawQuery(
      '''
      SELECT batches.id, batches.batch_name, batches.starting_year,
        history.id AS batch_history_id, history.academic_year, history.grade
      FROM batches
      INNER JOIN batch_history history
        ON history.batch_id = batches.id AND history.is_current = 1
      WHERE batches.is_active = 1
        AND batches.id NOT IN (
          SELECT batch_id FROM competition_batches
          WHERE competition_id = ?
        )
      ORDER BY batches.batch_name COLLATE NOCASE
      ''',
      [competitionId],
    );
  }

  Future<List<Map<String, Object?>>> listBatchesForCompetitionSelection({
    required Database database,
    required int adminId,
    required int competitionId,
  }) async {
    await AccessControl.requireActiveAdminOrStaff(
      database,
      adminId,
      action: 'manage competitions',
    );
    return database.rawQuery(
      '''
      SELECT batches.id, batches.batch_name, batches.starting_year,
        batches.is_active,
        history.academic_year, history.grade,
        CASE
          WHEN linked.id IS NULL THEN 0
          ELSE 1
        END AS already_linked
      FROM batches
      LEFT JOIN batch_history history
        ON history.batch_id = batches.id AND history.is_current = 1
      LEFT JOIN competition_batches linked
        ON linked.batch_id = batches.id AND linked.competition_id = ?
      ORDER BY batches.batch_name COLLATE NOCASE
      ''',
      [competitionId],
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

  Future<void> addBatchesToCompetition({
    required Database database,
    required int adminId,
    required int competitionId,
    required List<int> batchIds,
  }) async {
    final uniqueIds = batchIds.toSet().toList();
    if (uniqueIds.isEmpty) {
      throw const InvalidCompetitionException(
        message: 'Select at least one active batch.',
      );
    }

    await database.transaction((transaction) async {
      await AccessControl.requireActiveStaff(
        transaction,
        adminId,
        action: 'add batches to competitions',
      );

      final competition = await transaction.query(
        'competitions',
        columns: ['id', 'competition_name'],
        where: 'id = ?',
        whereArgs: [competitionId],
        limit: 1,
      );
      if (competition.isEmpty) {
        throw StateError('Competition not found.');
      }

      final sectionRows = await transaction.rawQuery(
        'SELECT COUNT(*) AS count FROM competition_sections WHERE competition_id = ?',
        [competitionId],
      );
      final sectionCount = (sectionRows.single['count'] as int?) ?? 0;
      if (sectionCount > 0) {
        throw const InvalidCompetitionException(
          message:
              'This competition already has sections. Remove them before adding batches.',
        );
      }

      final now = _now();
      final addedNames = <String>[];

      for (final batchId in uniqueIds) {
        final batches = await transaction.rawQuery(
          '''
          SELECT batches.id, batches.batch_name
          FROM batches
          INNER JOIN batch_history history
            ON history.batch_id = batches.id AND history.is_current = 1
          WHERE batches.id = ? AND batches.is_active = 1
          LIMIT 1
          ''',
          [batchId],
        );
        if (batches.isEmpty) {
          throw StateError(
            'Batch #$batchId is not an active batch and cannot be added.',
          );
        }

        final existing = await transaction.query(
          'competition_batches',
          columns: ['id'],
          where: 'competition_id = ? AND batch_id = ?',
          whereArgs: [competitionId, batchId],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;

        await transaction.insert('competition_batches', {
          'competition_id': competitionId,
          'batch_id': batchId,
          'added_at': now,
          'created_at': now,
          'updated_at': now,
        });
        addedNames.add(batches.single['batch_name']! as String);
      }

      if (addedNames.isEmpty) {
        throw const InvalidCompetitionException(
          message: 'Selected batches are already linked to this competition.',
        );
      }

      final name = competition.single['competition_name']! as String;
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.competitionBatchesAdded,
        module: 'competition_management',
        entityType: 'competition',
        entityId: competitionId,
        description:
            'Staff added ${addedNames.length} batch(es) to competition $name: '
            '${addedNames.join(', ')}.',
      );
    });
  }

  Future<List<Map<String, Object?>>> listCompetitionSections({
    required Database database,
    required int adminId,
    required int competitionId,
  }) async {
    await AccessControl.requireActiveAdminOrStaff(
      database,
      adminId,
      action: 'manage competitions',
    );
    return database.query(
      'competition_sections',
      where: 'competition_id = ?',
      whereArgs: [competitionId],
      orderBy: 'section_name COLLATE NOCASE',
    );
  }

  Future<int> createCompetitionSection({
    required Database database,
    required int adminId,
    required int competitionId,
    required String sectionName,
  }) async {
    final name = sectionName.trim();
    if (name.isEmpty) {
      throw const InvalidCompetitionException(
        message: 'Enter a section name.',
      );
    }

    return database.transaction((transaction) async {
      await AccessControl.requireActiveStaff(
        transaction,
        adminId,
        action: 'create competition sections',
      );

      final competition = await transaction.query(
        'competitions',
        columns: ['id', 'competition_name'],
        where: 'id = ?',
        whereArgs: [competitionId],
        limit: 1,
      );
      if (competition.isEmpty) {
        throw StateError('Competition not found.');
      }

      final batchRows = await transaction.rawQuery(
        'SELECT COUNT(*) AS count FROM competition_batches WHERE competition_id = ?',
        [competitionId],
      );
      final batchCount = (batchRows.single['count'] as int?) ?? 0;
      if (batchCount > 0) {
        throw const InvalidCompetitionException(
          message:
              'This competition already has batches. Remove them before adding sections.',
        );
      }

      final existing = await transaction.query(
        'competition_sections',
        columns: ['id'],
        where: 'competition_id = ? AND section_name = ? COLLATE NOCASE',
        whereArgs: [competitionId, name],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw const InvalidCompetitionException(
          message: 'That section already exists for this competition.',
        );
      }

      final now = _now();
      final id = await transaction.insert('competition_sections', {
        'competition_id': competitionId,
        'section_name': name,
        'created_at': now,
        'updated_at': now,
      });

      final competitionName = competition.single['competition_name']! as String;
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.competitionSectionCreated,
        module: 'competition_management',
        entityType: 'competition_section',
        entityId: id,
        description:
            'Staff added section $name to competition $competitionName.',
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
  const InvalidCompetitionException({
    this.message = 'Competition details are invalid.',
  });

  final String message;
}
