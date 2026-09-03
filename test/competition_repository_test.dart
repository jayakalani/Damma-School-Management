import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:damma_school_management_system/core/batches/batch_repository.dart';
import 'package:damma_school_management_system/core/competitions/competition_repository.dart';
import 'package:damma_school_management_system/core/database/app_database.dart';
import 'package:damma_school_management_system/core/users/user_repository.dart';

void main() {
  test('staff can create and list competitions', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final adminId = (await connection.query('users')).single['id']! as int;
    final staffId = await UserRepository().createStaff(
      database: connection,
      adminId: adminId,
      fullName: 'Staff User',
      username: 'staff.competition.${DateTime.now().microsecondsSinceEpoch}',
      password: 'StaffPassword123!',
    );

    final competitions = CompetitionRepository();
    final id = await competitions.createCompetition(
      database: connection,
      adminId: staffId,
      name: 'Speech Contest',
      date: '2026-09-15',
      venue: 'Main Hall',
      description: 'Annual speech competition',
    );

    final rows = await competitions.listCompetitions(
      database: connection,
      adminId: staffId,
    );

    expect(id, greaterThan(0));
    expect(rows, hasLength(1));
    expect(rows.single['competition_name'], 'Speech Contest');
    expect(rows.single['venue'], 'Main Hall');
    expect(rows.single['description'], 'Annual speech competition');

    await connection.close();
  });

  test('staff can add active batches to a competition', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final adminId = (await connection.query('users')).single['id']! as int;
    final staffId = await UserRepository().createStaff(
      database: connection,
      adminId: adminId,
      fullName: 'Staff User',
      username: 'staff.comp.batches.${DateTime.now().microsecondsSinceEpoch}',
      password: 'StaffPassword123!',
    );

    final batches = BatchRepository();
    await batches.createBatch(
      database: connection,
      adminId: staffId,
      name: 'Grade 5 A',
      startingYear: 2026,
      startingGrade: '5',
    );
    await batches.createBatch(
      database: connection,
      adminId: staffId,
      name: 'Grade 6 B',
      startingYear: 2026,
      startingGrade: '6',
    );
    final activeBatchRows = await connection.query(
      'batches',
      orderBy: 'id ASC',
    );
    final batchIds = activeBatchRows.map((row) => row['id']! as int).toList();

    final competitions = CompetitionRepository();
    final competitionId = await competitions.createCompetition(
      database: connection,
      adminId: staffId,
      name: 'Art Contest',
      date: '2026-09-20',
    );

    await competitions.addBatchesToCompetition(
      database: connection,
      adminId: staffId,
      competitionId: competitionId,
      batchIds: batchIds,
    );

    final linked = await competitions.listCompetitionBatches(
      database: connection,
      adminId: staffId,
      competitionId: competitionId,
    );
    final remaining = await competitions.listActiveBatchesNotInCompetition(
      database: connection,
      adminId: staffId,
      competitionId: competitionId,
    );

    expect(linked, hasLength(2));
    expect(
      linked.map((row) => row['batch_name']).toSet(),
      {'Grade 5 A', 'Grade 6 B'},
    );
    expect(remaining, isEmpty);

    final selection = await competitions.listBatchesForCompetitionSelection(
      database: connection,
      adminId: staffId,
      competitionId: competitionId,
    );
    expect(selection, hasLength(2));
    expect(
      selection.every((row) => (row['already_linked'] as int?) == 1),
      isTrue,
    );

    await expectLater(
      competitions.createCompetitionSection(
        database: connection,
        adminId: staffId,
        competitionId: competitionId,
        sectionName: 'Junior',
      ),
      throwsA(
        isA<InvalidCompetitionException>().having(
          (error) => error.message,
          'message',
          contains('already has batches'),
        ),
      ),
    );

    await connection.close();
  });

  test('staff can add sections when competition has no batches', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final adminId = (await connection.query('users')).single['id']! as int;
    final staffId = await UserRepository().createStaff(
      database: connection,
      adminId: adminId,
      fullName: 'Staff User',
      username: 'staff.comp.sections.${DateTime.now().microsecondsSinceEpoch}',
      password: 'StaffPassword123!',
    );

    final competitions = CompetitionRepository();
    final competitionId = await competitions.createCompetition(
      database: connection,
      adminId: staffId,
      name: 'Speech Contest',
      date: '2026-09-20',
    );

    final sectionId = await competitions.createCompetitionSection(
      database: connection,
      adminId: staffId,
      competitionId: competitionId,
      sectionName: 'Junior',
    );
    final sections = await competitions.listCompetitionSections(
      database: connection,
      adminId: staffId,
      competitionId: competitionId,
    );
    expect(sectionId, greaterThan(0));
    expect(sections, hasLength(1));
    expect(sections.single['section_name'], 'Junior');

    await expectLater(
      competitions.createCompetitionSection(
        database: connection,
        adminId: staffId,
        competitionId: competitionId,
        sectionName: 'junior',
      ),
      throwsA(isA<InvalidCompetitionException>()),
    );

    final batches = BatchRepository();
    await batches.createBatch(
      database: connection,
      adminId: staffId,
      name: 'Grade 5 A',
      startingYear: 2026,
      startingGrade: '5',
    );
    final batchId =
        (await connection.query('batches')).single['id']! as int;

    await expectLater(
      competitions.addBatchesToCompetition(
        database: connection,
        adminId: staffId,
        competitionId: competitionId,
        batchIds: [batchId],
      ),
      throwsA(
        isA<InvalidCompetitionException>().having(
          (error) => error.message,
          'message',
          contains('already has sections'),
        ),
      ),
    );

    await connection.close();
  });
}
