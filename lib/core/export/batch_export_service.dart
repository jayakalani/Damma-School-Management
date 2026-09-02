import 'dart:convert';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../batches/batch_repository.dart';

class BatchExportService {
  const BatchExportService();

  String buildCsv(BatchDetails details) {
    final batch = details.batch;
    final buffer = StringBuffer()
      ..writeln('# Batch Details Export')
      ..writeln('# Batch: ${batch['batch_name']}')
      ..writeln('# Starting Year: ${batch['starting_year']}')
      ..writeln(
        '# Status: ${(batch['is_active'] ?? 1) == 1 ? 'Active' : 'Inactive'}',
      )
      ..writeln()
      ..writeln('## History')
      ..writeln('Academic Year,Grade,Started,Ended,Current')
      ..writeln(
        details.history
            .map(
              (row) => [
                row['academic_year'],
                _csvCell('${row['grade']}'),
                _csvCell(_formatDate(row['started_date'] as String?)),
                _csvCell(_formatDate(row['ended_date'] as String?)),
                row['is_current'] == 1 ? 'Yes' : 'No',
              ].join(','),
            )
            .join('\n'),
      )
      ..writeln()
      ..writeln('## Students')
      ..writeln('ID,Full Name,Joined,Left,Current')
      ..writeln(
        details.students
            .map(
              (row) => [
                row['id'],
                _csvCell(row['full_name']! as String),
                _csvCell(_formatDate(row['joined_date'] as String?)),
                _csvCell(_formatDate(row['left_date'] as String?)),
                row['is_current'] == 1 ? 'Yes' : 'No',
              ].join(','),
            )
            .join('\n'),
      )
      ..writeln()
      ..writeln('## Teachers')
      ..writeln('ID,Full Name,Assigned,Removed,Current')
      ..writeln(
        details.teachers
            .map(
              (row) => [
                row['id'],
                _csvCell(row['full_name']! as String),
                _csvCell(_formatDate(row['assigned_date'] as String?)),
                _csvCell(_formatDate(row['removed_date'] as String?)),
                row['is_current'] == 1 ? 'Yes' : 'No',
              ].join(','),
            )
            .join('\n'),
      )
      ..writeln()
      ..writeln('## Examinations')
      ..writeln('ID,Name,Date,Total Marks')
      ..writeln(
        details.examinations
            .map(
              (row) => [
                row['id'],
                _csvCell(row['examination_name']! as String),
                _csvCell(_formatDate(row['examination_date'] as String?)),
                row['total_marks'],
              ].join(','),
            )
            .join('\n'),
      );

    return buffer.toString();
  }

  Future<List<int>> buildPdf(BatchDetails details) async {
    final batch = details.batch;
    final exportedAt = DateTime.now().toLocal();
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            'Batch Details Export',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '${batch['batch_name']} · Starting year ${batch['starting_year']} · '
            '${(batch['is_active'] ?? 1) == 1 ? 'Active' : 'Inactive'}',
          ),
          pw.Text(
            'Exported: ${_formatTimestamp(exportedAt)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 18),
          _sectionTitle('Batch History'),
          if (details.history.isEmpty)
            pw.Text('No academic history recorded.')
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'Academic Year',
                'Grade',
                'Started',
                'Ended',
                'Current',
              ],
              headerStyle: _headerStyle,
              headerDecoration: _headerDecoration,
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 10),
              data: details.history
                  .map(
                    (row) => [
                      '${row['academic_year']}',
                      '${row['grade']}',
                      _formatDate(row['started_date'] as String?),
                      _formatDate(row['ended_date'] as String?),
                      row['is_current'] == 1 ? 'Yes' : 'No',
                    ],
                  )
                  .toList(),
            ),
          pw.SizedBox(height: 16),
          _sectionTitle('Students (${details.students.length})'),
          if (details.students.isEmpty)
            pw.Text('No students assigned.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['ID', 'Full Name', 'Joined', 'Left', 'Current'],
              headerStyle: _headerStyle,
              headerDecoration: _headerDecoration,
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 10),
              data: details.students
                  .map(
                    (row) => [
                      '#${row['id']}',
                      row['full_name']! as String,
                      _formatDate(row['joined_date'] as String?),
                      _formatDate(row['left_date'] as String?),
                      row['is_current'] == 1 ? 'Yes' : 'No',
                    ],
                  )
                  .toList(),
            ),
          pw.SizedBox(height: 16),
          _sectionTitle('Teachers (${details.teachers.length})'),
          if (details.teachers.isEmpty)
            pw.Text('No teachers assigned.')
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'ID',
                'Full Name',
                'Assigned',
                'Removed',
                'Current',
              ],
              headerStyle: _headerStyle,
              headerDecoration: _headerDecoration,
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 10),
              data: details.teachers
                  .map(
                    (row) => [
                      '#${row['id']}',
                      row['full_name']! as String,
                      _formatDate(row['assigned_date'] as String?),
                      _formatDate(row['removed_date'] as String?),
                      row['is_current'] == 1 ? 'Yes' : 'No',
                    ],
                  )
                  .toList(),
            ),
          pw.SizedBox(height: 16),
          _sectionTitle('Examinations (${details.examinations.length})'),
          if (details.examinations.isEmpty)
            pw.Text('No examinations recorded.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['ID', 'Name', 'Date', 'Total Marks'],
              headerStyle: _headerStyle,
              headerDecoration: _headerDecoration,
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 10),
              data: details.examinations
                  .map(
                    (row) => [
                      '#${row['id']}',
                      row['examination_name']! as String,
                      _formatDate(row['examination_date'] as String?),
                      '${row['total_marks']}',
                    ],
                  )
                  .toList(),
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

  pw.Widget _sectionTitle(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(
          title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      );

  pw.TextStyle get _headerStyle => pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      );

  pw.BoxDecoration get _headerDecoration => const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFF145C63),
      );

  String _csvCell(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  String _formatTimestamp(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}
