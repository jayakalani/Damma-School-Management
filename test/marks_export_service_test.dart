import 'package:flutter_test/flutter_test.dart';

import 'package:damma_school_management_system/core/examinations/examination_repository.dart';
import 'package:damma_school_management_system/core/export/marks_export_service.dart';

void main() {
  const service = MarksExportService();
  const meta = MarksExportMeta(
    examinationName: 'second term',
    batchName: 'Grade 1',
    academicYear: 2026,
    grade: '1',
    totalMarks: 100,
  );
  final rows = [
    const MarksExportRow(
      studentId: 2,
      studentName: 'Sample Student',
      entry: '80',
    ),
    const MarksExportRow(
      studentId: 3,
      studentName: 'Absent Student',
      entry: 'Ab',
    ),
  ];
  const analytics = ExaminationAnalytics(
    presentCount: 1,
    absentCount: 1,
    highest: 80,
    lowest: 80,
    average: 80,
    rankings: [],
  );

  test('builds csv with marks and absent entries', () {
    final csv = service.buildCsv(
      meta: meta,
      rows: rows,
      analytics: analytics,
    );

    expect(csv, contains('second term'));
    expect(csv, contains('Sample Student'));
    expect(csv, contains('Present'));
    expect(csv, contains('80'));
    expect(csv, contains('Ab'));
    expect(csv, contains('Absent'));
  });

  test('builds pdf bytes for marks export', () async {
    final bytes = await service.buildPdf(
      meta: meta,
      rows: rows,
      analytics: analytics,
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
