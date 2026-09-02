import 'dart:convert';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AuditLogExportFilters {
  const AuditLogExportFilters({
    this.searchQuery = '',
    this.userLabel,
    this.module,
    this.startDate,
    this.endDate,
  });

  final String searchQuery;
  final String? userLabel;
  final String? module;
  final DateTime? startDate;
  final DateTime? endDate;

  String get summary {
    final parts = <String>[];
    final query = searchQuery.trim();
    if (query.isNotEmpty) {
      parts.add('Search: "$query"');
    }
    if (userLabel != null) {
      parts.add('User: $userLabel');
    }
    if (module != null && module!.isNotEmpty) {
      parts.add('Module: $module');
    }
    if (startDate != null) {
      parts.add('From: ${_dateLabel(startDate!)}');
    }
    if (endDate != null) {
      parts.add('To: ${_dateLabel(endDate!)}');
    }
    return parts.isEmpty ? 'All logs' : parts.join(' · ');
  }

  static String _dateLabel(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class AuditLogExportService {
  const AuditLogExportService();

  String buildCsv(
    List<Map<String, Object?>> logs, {
    AuditLogExportFilters filters = const AuditLogExportFilters(),
  }) {
    final buffer = StringBuffer()
      ..writeln('# Filters: ${filters.summary}')
      ..writeln('Date/Time,User,Action,Module,Description');

    for (final log in logs) {
      buffer.writeln([
        _csvCell(_formatDateTime(log['created_at']! as String)),
        _csvCell('${log['actor_username'] ?? '-'}'),
        _csvCell(log['action']! as String),
        _csvCell(log['module']! as String),
        _csvCell(log['description']! as String),
      ].join(','));
    }

    return buffer.toString();
  }

  Future<List<int>> buildPdf(
    List<Map<String, Object?>> logs, {
    AuditLogExportFilters filters = const AuditLogExportFilters(),
  }) async {
    final doc = pw.Document();
    final exportedAt = DateTime.now().toLocal();
    final tableData = logs
        .map(
          (log) => [
            _formatDateTime(log['created_at']! as String),
            '${log['actor_username'] ?? '-'}',
            log['action']! as String,
            log['module']! as String,
            log['description']! as String,
          ],
        )
        .toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            'Audit Log Export',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Filters: ${filters.summary}'),
          pw.Text(
            'Exported: ${_formatTimestamp(exportedAt)} · ${logs.length} record(s)',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 18),
          if (logs.isEmpty)
            pw.Text('No audit logs match the current filters.')
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'Date/Time',
                'User',
                'Action',
                'Module',
                'Description',
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

  String _formatDateTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimestamp(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}
