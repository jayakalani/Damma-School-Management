import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:damma_school_management_system/core/dashboard/dashboard_stats_repository.dart';
import 'package:damma_school_management_system/core/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads live staff dashboard stats from the database', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(
      'file:staff_dashboard_stats?mode=memory&cache=shared',
    );
    final now = DateTime.now().toUtc().toIso8601String();

    await connection.insert('teachers', {
      'full_name': 'Active Teacher',
      'name_with_initials': 'A. Teacher',
      'registered_date': '2026-01-01',
      'status': 'active',
      'created_at': now,
      'updated_at': now,
    });
    await connection.insert('teachers', {
      'full_name': 'Inactive Teacher',
      'name_with_initials': 'I. Teacher',
      'registered_date': '2026-01-01',
      'status': 'inactive',
      'created_at': now,
      'updated_at': now,
    });
    await connection.insert('batches', {
      'batch_name': 'Grade 1',
      'starting_year': 2026,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    await connection.insert('students', {
      'full_name': 'Active Student',
      'name_with_initials': 'A. Student',
      'joined_date': '2026-01-01',
      'status': 'student',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    await connection.insert('students', {
      'full_name': 'Past Student',
      'name_with_initials': 'P. Student',
      'joined_date': '2020-01-01',
      'status': 'past_pupil',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    await connection.insert('past_pupil_batches', {
      'batch_name': 'Legacy 2018',
      'year_completed': 2018,
      'created_at': now,
      'updated_at': now,
    });
    final legacyBatchId = (await connection.query(
      'past_pupil_batches',
    )).single['id']! as int;
    await connection.insert('historical_past_pupils', {
      'past_pupil_batch_id': legacyBatchId,
      'full_name': 'Legacy Pupil',
      'created_at': now,
      'updated_at': now,
    });

    final stats = await const DashboardStatsRepository().loadStaffStats(
      connection,
    );

    expect(stats.activeTeachers, 1);
    expect(stats.activeBatches, 1);
    expect(stats.enrolledStudents, 1);
    expect(stats.pastPupils, 2);
    expect(stats.legacyBatches, 1);
    expect(stats.historicalPastPupils, 1);
    expect(formatCount(1842), '1,842');
    await database.close();
  });
}
