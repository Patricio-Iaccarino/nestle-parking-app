// /core/services/export_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;

import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import '../../features/reports/domain/report_models.dart';

class ExportService {
  static final _df = DateFormat('yyyy-MM-dd HH:mm');

  /// ------------------------------------------------------------------------
  /// Punto único de exportación para el **reporte detallado**
  /// format: 'excel' | 'csv' | 'pdf'
  /// ------------------------------------------------------------------------
  static Future<void> exportDetailed(
    String format,
    List<DetailedReportRecord> data,
  ) async {
    switch (format) {
      case 'excel':
        await _exportDetailedToExcel(data);
        break;
      case 'csv':
        await _exportDetailedToCsv(data);
        break;
      case 'pdf':
        await _exportDetailedToPdf(data);
        break;
      default:
        // opcionalmente, podrías lanzar una excepción o ignorar
        break;
    }
  }

  // ------------------------------------------------------------------------
  // CSV
  // ------------------------------------------------------------------------
  static Future<void> _exportDetailedToCsv(List<DetailedReportRecord> data) async {
    final rows = <List<String>>[
      ['Fecha', 'Estado', 'Usuario', 'Departamento', 'Cochera'],
      ...data.map((r) => [
            _df.format(r.releaseDate),
            r.status,
            r.userName ?? '-',
            r.departmentName ?? '-',
            r.spotName ?? '-',
          ]),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    _downloadUtf8(csv, filename: 'reporte_detallado.csv', mime: 'text/csv');
  }

  // ------------------------------------------------------------------------
  // PDF
  // ------------------------------------------------------------------------
  static Future<void> _exportDetailedToPdf(List<DetailedReportRecord> data) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            'Reporte detallado de ocupación',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: const ['Fecha', 'Estado', 'Usuario', 'Departamento', 'Cochera'],
            data: data
                .map((r) => [
                      _df.format(r.releaseDate),
                      r.status,
                      r.userName ?? '-',
                      r.departmentName ?? '-',
                      r.spotName ?? '-',
                    ])
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    _downloadBytes(bytes,
        filename: 'reporte_detallado.pdf', mime: 'application/pdf');
  }

  // ------------------------------------------------------------------------
  // Excel (sin estilos especiales para máxima compatibilidad)
  // ------------------------------------------------------------------------
  static Future<void> _exportDetailedToExcel(List<DetailedReportRecord> data) async {
    final excel = Excel.createExcel();
    final sheet = excel['Reporte detallado'];

    // Encabezados
    sheet.appendRow([
       TextCellValue('Fecha'),
       TextCellValue('Estado'),
       TextCellValue('Usuario'),
       TextCellValue('Departamento'),
       TextCellValue('Cochera'),
    ]);

    // Filas
    for (final r in data) {
      sheet.appendRow([
        TextCellValue(_df.format(r.releaseDate)),
        TextCellValue(r.status),
        TextCellValue(r.userName ?? '-'),
        TextCellValue(r.departmentName ?? '-'),
        TextCellValue(r.spotName ?? '-'),
      ]);
    }

    final bytes = Uint8List.fromList(excel.encode()!);
    _downloadBytes(
      bytes,
      filename: 'reporte_detallado.xlsx',
      mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // ------------------------------------------------------------------------
  // Descargas
  // ------------------------------------------------------------------------
  static void _downloadUtf8(String content,
      {required String filename, required String mime}) {
    final bytes = utf8.encode(content);
    _downloadBytes(bytes, filename: filename, mime: mime);
  }

  static void _downloadBytes(List<int> bytes,
      {required String filename, required String mime}) {
    final blob = html.Blob([Uint8List.fromList(bytes)], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

/// Conversor CSV minimalista
class ListToCsvConverter {
  const ListToCsvConverter();

  String convert(List<List<String>> rows) {
    return rows.map((r) => r.map(_escape).join(',')).join('\n');
  }

  String _escape(String v) {
    final needsQuotes = v.contains(',') || v.contains('"') || v.contains('\n');
    final s = v.replaceAll('"', '""');
    return needsQuotes ? '"$s"' : s;
  }
}
