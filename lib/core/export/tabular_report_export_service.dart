import 'dart:convert';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../reports/report_catalog.dart';

class TabularReportExportService {
  const TabularReportExportService();

  String buildCsv({
    required ReportDefinition definition,
    required List<ReportField> columns,
    required List<Map<String, String>> rows,
    required String filterSummary,
  }) {
    final buffer = StringBuffer()
      ..writeln('# Filters: $filterSummary')
      ..writeln(columns.map((column) => _csvCell(column.label)).join(','));

    for (final row in rows) {
      buffer.writeln(
        columns.map((column) => _csvCell(row[column.key] ?? '')).join(','),
      );
    }

    return buffer.toString();
  }

  Future<List<int>> buildPdf({
    required ReportDefinition definition,
    required List<ReportField> columns,
    required List<Map<String, String>> rows,
    required String filterSummary,
  }) async {
    final doc = pw.Document();
    final exportedAt = DateTime.now().toLocal();
    final tableData = rows
        .map(
          (row) => columns.map((column) => row[column.key] ?? '').toList(),
        )
        .toList();
    final fontSize = columns.length > 8 ? 8.0 : 10.0;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            '${definition.title} Export',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Filters: $filterSummary'),
          pw.Text(
            'Exported: ${_formatTimestamp(exportedAt)} · ${rows.length} record(s)',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 18),
          if (rows.isEmpty)
            pw.Text('No records match the current filters.')
          else
            pw.TableHelper.fromTextArray(
              headers: columns.map((column) => column.label).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: fontSize,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF145C63),
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: pw.TextStyle(fontSize: fontSize),
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
