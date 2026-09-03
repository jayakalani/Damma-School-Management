import 'package:flutter_test/flutter_test.dart';

import 'package:damma_school_management_system/core/export/tabular_report_export_service.dart';
import 'package:damma_school_management_system/core/reports/report_catalog.dart';

void main() {
  const service = TabularReportExportService();

  final columns = ReportCatalog.teachers.fields
      .where((field) => field.selectedByDefault)
      .toList();

  final rows = [
    {
      'full_name': 'Nimal Perera',
      'name_with_initials': 'N. Perera',
      'nic': '123456789V',
      'phone_number': '0771234567',
      'address': 'Colombo',
      'date_of_birth': '1980-01-01',
      'registered_date': '2026-01-15',
      'status': 'Active',
      'bank_name': 'Test Bank',
      'bank_branch': 'Main',
      'bank_account_number': '123456',
    },
  ];

  test('builds csv with only the selected field headers', () {
    final csv = service.buildCsv(
      definition: ReportCatalog.teachers,
      columns: columns,
      rows: rows,
      filterSummary: 'Status: Active',
    );

    expect(csv, contains('# Filters: Status: Active'));
    expect(
      csv,
      contains('Full name,Initials,NIC,Phone,Registered date,Status'),
    );
    expect(csv, isNot(contains('Address')));
    expect(csv, isNot(contains('Colombo')));
    expect(csv, contains('Nimal Perera'));
    expect(csv, contains('123456789V'));
  });

  test('builds pdf bytes for selected columns', () async {
    final bytes = await service.buildPdf(
      definition: ReportCatalog.teachers,
      columns: columns,
      rows: rows,
      filterSummary: 'Status: Active',
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('builds pdf bytes when there are no matching rows', () async {
    final bytes = await service.buildPdf(
      definition: ReportCatalog.teachers,
      columns: columns,
      rows: const [],
      filterSummary: 'All teachers',
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
