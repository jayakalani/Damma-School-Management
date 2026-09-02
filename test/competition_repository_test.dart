import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
}
