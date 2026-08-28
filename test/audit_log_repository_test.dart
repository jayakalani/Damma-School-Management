import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:damma_school_management_system/core/audit/audit_log_repository.dart';
import 'package:damma_school_management_system/core/database/app_database.dart';

void main() {
  test(
    'filters audit logs by keyword, actor, module, and date range',
    () async {
      sqfliteFfiInit();
      final database = AppDatabase(factory: databaseFactoryFfi);
      final connection = await database.openAt(inMemoryDatabasePath);
      final adminId = (await connection.query('users')).single['id']! as int;
      final staffId = await connection.insert('users', {
        'full_name': 'Audit Staff',
        'username': 'audit.staff',
        'password_hash': 'hash',
        'role': 'staff',
        'status': 'active',
        'created_at': '2026-01-01',
        'updated_at': '2026-01-01',
      });
      await connection.insert('audit_logs', {
        'user_id': adminId,
        'action': 'created',
        'module': 'students',
        'description': 'Created Alice',
        'created_at': '2026-08-01T10:00:00.000Z',
      });
      await connection.insert('audit_logs', {
        'user_id': staffId,
        'action': 'updated',
        'module': 'teachers',
        'description': 'Updated Bob',
        'created_at': '2026-08-15T10:00:00.000Z',
      });
      await connection.insert('audit_logs', {
        'user_id': adminId,
        'action': 'deleted',
        'module': 'students',
        'description': 'Deleted Carol',
        'created_at': '2026-09-01T10:00:00.000Z',
      });
      const repository = AuditLogRepository();

      final all = await repository.listForAdmin(
        database: connection,
        adminId: adminId,
      );
      expect(all, hasLength(3));
      expect(all.first['actor_username'], 'admin');
      expect(
        (await repository.listForAdmin(
          database: connection,
          adminId: adminId,
          query: 'Alice',
        )).single['module'],
        'students',
      );
      expect(
        (await repository.listForAdmin(
          database: connection,
          adminId: adminId,
          userId: staffId,
        )).single['actor_username'],
        'audit.staff',
      );
      expect(
        (await repository.listForAdmin(
          database: connection,
          adminId: adminId,
          module: 'students',
        )),
        hasLength(2),
      );
      expect(
        (await repository.listForAdmin(
          database: connection,
          adminId: adminId,
          startDate: DateTime.utc(2026, 8, 1),
          endDate: DateTime.utc(2026, 8, 31),
        )),
        hasLength(2),
      );
      await repository.logActivity(
        database: connection,
        userId: adminId.toString(),
        action: 'tested',
        module: 'tests',
        description: 'Adapter call',
      );
      expect(
        (await repository.listForAdmin(
          database: connection,
          adminId: adminId,
          module: 'tests',
        )),
        hasLength(1),
      );
      await database.close();
    },
  );

  test('rejects audit log listing for non-admin users', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final adminId = (await connection.query('users')).single['id']! as int;
    final staffId = await connection.insert('users', {
      'full_name': 'Staff',
      'username': 'staff',
      'password_hash': 'hash',
      'role': 'staff',
      'status': 'active',
      'created_at': '2026-01-01',
      'updated_at': '2026-01-01',
    });
    expect(
      () => AuditLogRepository().listForAdmin(
        database: connection,
        adminId: staffId,
      ),
      throwsA(isA<StateError>()),
    );
    await database.close();
  });
}
