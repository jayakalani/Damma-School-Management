import 'dart:convert';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../examinations/examination_repository.dart';

class MarksExportMeta {
  const MarksExportMeta({
    required this.examinationName,
    required this.batchName,
    required this.academicYear,
    required this.grade,
    required this.totalMarks,
  });

  final String examinationName;
  final String batchName;
  final Object academicYear;
  final Object grade;
  final Object totalMarks;

  String get summary =>
      '$examinationName · $batchName · $academicYear · Grade $grade · Total: $totalMarks';
}

class MarksExportRow {
  const MarksExportRow({
    required this.studentId,
    required this.studentName,
    required this.entry,
  });

  final int studentId;
  final String studentName;
  final String entry;

  String get status {
    final parsed = ExaminationRepository.parseMarkEntry(entry);
    if (parsed == null) return 'Pending';
    return parsed.absent ? 'Absent' : 'Present';
  }

  String get marksLabel {
    final parsed = ExaminationRepository.parseMarkEntry(entry);
    if (parsed == null) return '';
    if (parsed.absent) return 'Ab';
    return '${parsed.marks}';
  }
}

class MarksExportService {
  const MarksExportService();

  String buildCsv({
    required MarksExportMeta meta,
    required List<MarksExportRow> rows,
    ExaminationAnalytics? analytics,
  }) {
    final buffer = StringBuffer()
      ..writeln('# ${meta.summary}')
      ..writeln(
        '# Present: ${analytics?.presentCount ?? '-'} · Absent: ${analytics?.absentCount ?? '-'} · '
        'Highest: ${analytics?.highest ?? '-'} · Lowest: ${analytics?.lowest ?? '-'} · '
        'Average: ${analytics?.average?.toStringAsFixed(2) ?? '-'}',
      )
      ..writeln('ID,Student,Status,Marks');

    for (final row in rows) {
      buffer.writeln([
        row.studentId,
        _csvCell(row.studentName),
        _csvCell(row.status),
        _csvCell(row.marksLabel),
      ].join(','));
    }

    return buffer.toString();
  }

  Future<List<int>> buildPdf({
    required MarksExportMeta meta,
    required List<MarksExportRow> rows,
    ExaminationAnalytics? analytics,
  }) async {
    final doc = pw.Document();
    final exportedAt = DateTime.now().toLocal();
    final tableData = rows
        .map(
          (row) => [
            '#${row.studentId}',
            row.studentName,
            row.status,
            row.marksLabel.isEmpty ? '-' : row.marksLabel,
          ],
        )
        .toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            'Marks Entry Export',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(meta.summary),
          pw.Text(
            'Exported: ${_formatTimestamp(exportedAt)} · ${rows.length} student(s)',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          if (analytics != null) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Present: ${analytics.presentCount} · Absent: ${analytics.absentCount} · '
              'Highest: ${analytics.highest ?? '-'} · Lowest: ${analytics.lowest ?? '-'} · '
              'Average: ${analytics.average?.toStringAsFixed(2) ?? '-'}',
            ),
          ],
          pw.SizedBox(height: 18),
          if (rows.isEmpty)
            pw.Text('No students available for this batch.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['ID', 'Student', 'Status', 'Marks'],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF145C63),
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 10),
              data: tableData,
            ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> writeTextFile({
    required String path,
    required String contents,
  }) async {
    await File(path).writeAsString(contents, encoding: utf8);
  }

  Future<void> writeBytesFile({
    required String path,
    required List<int> bytes,
  }) async {
    await File(path).writeAsBytes(bytes, flush: true);
  }

  String _csvCell(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _formatTimestamp(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}
