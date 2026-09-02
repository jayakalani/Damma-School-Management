import 'package:flutter_test/flutter_test.dart';

import 'package:damma_school_management_system/core/export/student_export_service.dart';

void main() {
  const service = StudentExportService();
  final students = [
    {
      'id': 1,
      'full_name': 'Alya Basnayaka',
      'name_with_initials': 'A. Basnayaka',
      'joined_date': '2026-09-02',
      'status': 'student',
      'is_active': 1,
      'batch_name': 'Grade 1',
      'nic': '',
      'phone_number': '0770000000',
    },
  ];

  test('builds csv with filter summary and student columns', () {
    final csv = service.buildCsv(
      students,
      filters: StudentExportFilters(
        searchQuery: 'alya',
        statusFilter: 'student',
        batchName: 'Grade 1',
        startDate: DateTime(2026, 1, 1),
      ),
    );

    expect(csv, contains('# Filters:'));
    expect(csv, contains('Batch: Grade 1'));
    expect(csv, contains('Alya Basnayaka'));
    expect(csv, contains('Active'));
    expect(csv.split('\n').length, greaterThanOrEqualTo(3));
  });

  test('builds pdf bytes for filtered students', () async {
    final bytes = await service.buildPdf(
      students,
      filters: const StudentExportFilters(batchName: 'Grade 1'),
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
