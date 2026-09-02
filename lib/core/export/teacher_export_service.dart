import 'dart:convert';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class TeacherExportFilters {
  const TeacherExportFilters({
    this.searchQuery = '',
    this.statusFilter,
    this.startDate,
    this.endDate,
  });

  final String searchQuery;
  final String? statusFilter;
  final DateTime? startDate;
  final DateTime? endDate;

  String get summary {
    final parts = <String>[];
    final query = searchQuery.trim();
    if (query.isNotEmpty) {
      parts.add('Search: "$query"');
    }
    if (statusFilter != null) {
      parts.add(
        'Status: ${statusFilter == 'active' ? 'Active' : 'Inactive'}',
      );
    }
    if (startDate != null) {
      parts.add('From: ${_dateLabel(startDate!)}');
    }
    if (endDate != null) {
      parts.add('To: ${_dateLabel(endDate!)}');
    }
    return parts.isEmpty ? 'All teachers' : parts.join(' · ');
  }

  static String _dateLabel(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class TeacherExportService {
  const TeacherExportService();

  String buildCsv(
    List<Map<String, Object?>> teachers, {
    TeacherExportFilters filters = const TeacherExportFilters(),
  }) {
    final buffer = StringBuffer()
      ..writeln('# Filters: ${filters.summary}')
      ..writeln('ID,Full Name,Initials,Registered,Status,NIC,Phone');

    for (final teacher in teachers) {
      buffer.writeln([
        teacher['id'],
        _csvCell(teacher['full_name']! as String),
        _csvCell(teacher['name_with_initials']! as String),
        _csvCell(teacher['registered_date']! as String),
        _csvCell(_statusLabel(teacher['status']! as String)),
        _csvCell('${teacher['nic'] ?? ''}'),
        _csvCell('${teacher['phone_number'] ?? ''}'),
      ].join(','));
    }

    return buffer.toString();
  }

  Future<List<int>> buildPdf(
    List<Map<String, Object?>> teachers, {
    TeacherExportFilters filters = const TeacherExportFilters(),
  }) async {
    final doc = pw.Document();
    final exportedAt = DateTime.now().toLocal();
    final tableData = teachers
        .map(
          (teacher) => [
            '#${teacher['id']}',
            teacher['full_name']! as String,
            teacher['name_with_initials']! as String,
            teacher['registered_date']! as String,
            _statusLabel(teacher['status']! as String),
          ],
        )
        .toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            'Teacher Directory Export',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Filters: ${filters.summary}'),
          pw.Text(
            'Exported: ${_formatTimestamp(exportedAt)} · ${teachers.length} record(s)',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 18),
          if (teachers.isEmpty)
            pw.Text('No teachers match the current filters.')
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'ID',
                'Full Name',
                'Initials',
                'Registered',
                'Status',
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

  String _statusLabel(String status) =>
      status == 'active' ? 'Active' : 'Inactive';

  String _formatTimestamp(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}
