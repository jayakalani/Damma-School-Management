import 'package:flutter_test/flutter_test.dart';

import 'package:damma_school_management_system/core/export/staff_export_service.dart';

void main() {
  const service = StaffExportService();
  final members = [
    {
      'id': 2,
      'full_name': 'Jayakalani Liyanage',
      'username': 'jayakalani',
      'created_at': '2026-09-01T00:00:00.000Z',
      'status': 'active',
    },
    {
      'id': 3,
      'full_name': 'Amila Eranga',
      'username': 'amila',
      'created_at': '2026-09-01T00:00:00.000Z',
      'status': 'inactive',
    },
  ];

  test('builds csv with filter summary and escaped values', () {
    final csv = service.buildCsv(
      members,
      filters: const StaffExportFilters(
        searchQuery: 'amila',
        statusFilter: 'inactive',
      ),
    );

    expect(csv, contains('# Filters: Search: "amila" · Status: Disabled'));
    expect(csv, contains('Amila Eranga'));
    expect(csv, contains('Disabled'));
    expect(csv.split('\n').length, greaterThanOrEqualTo(3));
  });

  test('builds pdf bytes for filtered staff list', () async {
    final bytes = await service.buildPdf(
      members,
      filters: const StaffExportFilters(statusFilter: 'active'),
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
