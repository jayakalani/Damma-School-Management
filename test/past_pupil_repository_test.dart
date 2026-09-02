import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:damma_school_management_system/core/database/app_database.dart';
import 'package:damma_school_management_system/core/past_pupils/past_pupil_repository.dart';

void main() {
  test('from/to dates filter legacy batches by year completed', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final adminId = (await connection.query('users')).single['id']! as int;
    final repository = PastPupilRepository();

    await repository.createBatch(
      database: connection,
      adminId: adminId,
      name: '2018 Darmacharya',
      year: 2018,
    );
    await repository.createBatch(
      database: connection,
      adminId: adminId,
      name: '2022 Alumni',
      year: 2022,
    );

    final filtered = await repository.listBatches(
      database: connection,
      adminId: adminId,
      startDate: DateTime(2020, 9, 2),
      endDate: DateTime(2026, 9, 2),
    );

    expect(filtered, hasLength(1));
    expect(filtered.single['batch_name'], '2022 Alumni');
    expect(filtered.single['year_completed'], 2022);

    await connection.close();
  });
}
