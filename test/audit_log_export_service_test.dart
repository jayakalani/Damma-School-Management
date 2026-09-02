import 'package:flutter_test/flutter_test.dart';

import 'package:damma_school_management_system/core/export/audit_log_export_service.dart';

void main() {
  const service = AuditLogExportService();
  final logs = [
    {
      'created_at': '2026-09-01T17:12:24.382536Z',
      'actor_username': 'admin',
      'action': 'staff_created',
      'module': 'staff_management',
      'description': 'Admin created staff member amila.',
    },
    {
      'created_at': '2026-09-01T17:10:00.000Z',
      'actor_username': 'Jayakalani',
      'action': 'password_changed',
      'module': 'user_profile',
      'description': 'User changed password.',
    },
  ];

  test('builds csv with filter summary and escaped values', () {
    final csv = service.buildCsv(
      logs,
      filters: const AuditLogExportFilters(
        searchQuery: 'staff',
        module: 'staff_management',
      ),
    );

    expect(
      csv,
      contains('# Filters: Search: "staff" · Module: staff_management'),
    );
    expect(csv, contains('staff_created'));
    expect(csv, contains('Admin created staff member amila.'));
    expect(csv.split('\n').length, greaterThanOrEqualTo(3));
  });

  test('builds pdf bytes for filtered audit logs', () async {
    final bytes = await service.buildPdf(
      logs,
      filters: const AuditLogExportFilters(userLabel: 'admin'),
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
