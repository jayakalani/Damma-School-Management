import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:damma_school_management_system/core/batches/batch_repository.dart';
import 'package:damma_school_management_system/core/database/app_database.dart';

void main() {
  test('creates batch details and promotes without losing history', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final adminId = (await connection.query('users')).single['id']! as int;
    final repository = BatchRepository();

    await repository.createBatch(
      database: connection,
      adminId: adminId,
      name: 'Class of 2026',
      startingYear: 2026,
      startingGrade: 'Grade 1',
    );

    final created = await connection.query('batches');
    final batchId = created.single['id']! as int;
    final initialHistory = await connection.query('batch_history');
    expect(initialHistory, hasLength(1));
    expect(initialHistory.single['academic_year'], 2026);
    expect(initialHistory.single['grade'], 'Grade 1');

    final details = await repository.getBatchDetails(
      database: connection,
      adminId: adminId,
      batchId: batchId,
    );
    expect(details.batch['batch_name'], 'Class of 2026');
    expect(details.history, hasLength(1));

    await repository.promoteBatch(
      database: connection,
      adminId: adminId,
      batchId: batchId,
      academicYear: 2027,
      grade: 'Grade 2',
    );

    final history = await connection.query(
      'batch_history',
      where: 'batch_id = ?',
      whereArgs: [batchId],
      orderBy: 'id',
    );
    expect(history, hasLength(2));
    expect(history[0]['academic_year'], 2026);
    expect(history[0]['grade'], 'Grade 1');
    expect(history[0]['is_current'], 0);
    expect(history[1]['academic_year'], 2027);
    expect(history[1]['grade'], 'Grade 2');
    expect(history[1]['is_current'], 1);

    final current = await connection.query(
      'batch_history',
      where: 'batch_id = ? AND is_current = 1',
      whereArgs: [batchId],
    );
    expect(current, hasLength(1));
    await database.close();
  });
}
