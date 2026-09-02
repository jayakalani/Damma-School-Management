import 'dart:convert';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class StudentExportFilters {
  const StudentExportFilters({
    this.searchQuery = '',
    this.statusFilter,
    this.batchName,
    this.startDate,
    this.endDate,
  });

  final String searchQuery;
  final String? statusFilter;
  final String? batchName;
  final DateTime? startDate;
  final DateTime? endDate;

  String get summary {
    final parts = <String>[];
    final query = searchQuery.trim();
    if (query.isNotEmpty) {
      parts.add('Search: "$query"');
    }
    if (statusFilter != null) {
      parts.add('Status: ${_statusFilterLabel(statusFilter!)}');
    }
    if (batchName != null && batchName!.trim().isNotEmpty) {
      parts.add('Batch: ${batchName!.trim()}');
    }
    if (startDate != null) {
      parts.add('From: ${_dateLabel(startDate!)}');
    }
    if (endDate != null) {
      parts.add('To: ${_dateLabel(endDate!)}');
    }
    return parts.isEmpty ? 'All students' : parts.join(' · ');
  }

  static String _dateLabel(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String _statusFilterLabel(String value) => switch (value) {
        'student' => 'Students',
        'active' => 'Active',
        'inactive' => 'Inactive',
        'past_pupil' => 'Past Pupils',
        _ => value,
      };
}

class StudentExportService {
  const StudentExportService();

  String buildCsv(
    List<Map<String, Object?>> students, {
    StudentExportFilters filters = const StudentExportFilters(),
  }) {
    final buffer = StringBuffer()
      ..writeln('# Filters: ${filters.summary}')
      ..writeln(
        'ID,Full Name,Initials,Joined,Status,Active,Batch,NIC,Phone',
      );

    for (final student in students) {
      buffer.writeln([
        student['id'],
        _csvCell(student['full_name']! as String),
        _csvCell(student['name_with_initials']! as String),
        _csvCell(student['joined_date']! as String),
        _csvCell(_statusLabel(student)),
        _csvCell(_activeLabel(student)),
        _csvCell('${student['batch_name'] ?? ''}'),
        _csvCell('${student['nic'] ?? ''}'),
        _csvCell('${student['phone_number'] ?? ''}'),
      ].join(','));
    }

    return buffer.toString();
  }

  Future<List<int>> buildPdf(
    List<Map<String, Object?>> students, {
    StudentExportFilters filters = const StudentExportFilters(),
  }) async {
    final doc = pw.Document();
    final exportedAt = DateTime.now().toLocal();
    final tableData = students
        .map(
          (student) => [
            '#${student['id']}',
            student['full_name']! as String,
            student['name_with_initials']! as String,
            student['joined_date']! as String,
            _statusLabel(student),
            '${student['batch_name'] ?? '-'}',
          ],
        )
        .toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            'Student Directory Export',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Filters: ${filters.summary}'),
          pw.Text(
            'Exported: ${_formatTimestamp(exportedAt)} · ${students.length} record(s)',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 18),
          if (students.isEmpty)
            pw.Text('No students match the current filters.')
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'ID',
                'Full Name',
                'Initials',
                'Joined',
                'Status',
                'Batch',
              ],
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

  String _statusLabel(Map<String, Object?> student) {
    if (student['status'] == 'past_pupil') return 'Past Pupil';
    return (student['is_active'] ?? 1) == 1 ? 'Active' : 'Inactive';
  }

  String _activeLabel(Map<String, Object?> student) {
    if (student['status'] == 'past_pupil') return '-';
    return (student['is_active'] ?? 1) == 1 ? 'Yes' : 'No';
  }

  String _formatTimestamp(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}
