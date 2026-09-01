import 'dart:convert';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class StaffExportFilters {
  const StaffExportFilters({
    this.searchQuery = '',
    this.statusFilter,
  });

  final String searchQuery;
  final String? statusFilter;

  String get summary {
    final parts = <String>[];
    final query = searchQuery.trim();
    if (query.isNotEmpty) {
      parts.add('Search: "$query"');
    }
    if (statusFilter != null) {
      parts.add(
        'Status: ${statusFilter == 'active' ? 'Active' : 'Disabled'}',
      );
    }
    return parts.isEmpty ? 'All staff' : parts.join(' · ');
  }
}

class StaffExportService {
  const StaffExportService();

  String buildCsv(
    List<Map<String, Object?>> members, {
    StaffExportFilters filters = const StaffExportFilters(),
  }) {
    final buffer = StringBuffer()
      ..writeln('# Filters: ${filters.summary}')
      ..writeln('ID,Full Name,Username,Created,Status');

    for (final member in members) {
      buffer.writeln([
        member['id'],
        _csvCell(member['full_name']! as String),
        _csvCell(member['username']! as String),
        _csvCell(_formatCreatedAt(member['created_at']! as String)),
        _csvCell(_statusLabel(member['status']! as String)),
      ].join(','));
    }

    return buffer.toString();
  }

  Future<List<int>> buildPdf(
    List<Map<String, Object?>> members, {
    StaffExportFilters filters = const StaffExportFilters(),
  }) async {
    final doc = pw.Document();
    final exportedAt = DateTime.now().toLocal();
    final tableData = members
        .map(
          (member) => [
            '#${member['id']}',
            member['full_name']! as String,
            '@${member['username']}',
            _formatCreatedAt(member['created_at']! as String),
            _statusLabel(member['status']! as String),
          ],
        )
        .toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            'Staff Directory Export',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Filters: ${filters.summary}'),
          pw.Text(
            'Exported: ${_formatTimestamp(exportedAt)} · ${members.length} record(s)',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 18),
          if (members.isEmpty)
            pw.Text('No staff records match the current filters.')
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'ID',
                'Full Name',
                'Username',
                'Created',
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
      status == 'active' ? 'Active' : 'Disabled';

  String _formatCreatedAt(String raw) {
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
