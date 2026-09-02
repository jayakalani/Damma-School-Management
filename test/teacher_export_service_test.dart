import 'package:flutter_test/flutter_test.dart';

import 'package:damma_school_management_system/core/export/teacher_export_service.dart';

void main() {
  const service = TeacherExportService();
  final teachers = [
    {
      'id': 1,
      'full_name': 'Nimal Perera',
      'name_with_initials': 'N. Perera',
      'registered_date': '2026-01-15',
      'status': 'active',
      'nic': '123456789V',
      'phone_number': '0771234567',
    },
  ];

  test('builds csv with filter summary and teacher columns', () {
    final csv = service.buildCsv(
      teachers,
      filters: TeacherExportFilters(
        searchQuery: 'nimal',
        statusFilter: 'active',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      ),
    );

    expect(csv, contains('# Filters:'));
    expect(csv, contains('Nimal Perera'));
    expect(csv, contains('Active'));
    expect(csv.split('\n').length, greaterThanOrEqualTo(3));
  });

  test('builds pdf bytes for filtered teachers', () async {
    final bytes = await service.buildPdf(
      teachers,
      filters: const TeacherExportFilters(statusFilter: 'active'),
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
