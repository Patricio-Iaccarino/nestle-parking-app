import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'dart:html' as html;
import 'package:excel/excel.dart'; 
import '../../features/reports/domain/report_models.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class ExportService {
  static String _formatDay(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// ------------------------------------------------------------------------
  /// 🔹 Exportador unificado según tipo de reporte y formato (CSV, PDF, XLSX)
  /// ------------------------------------------------------------------------
  static Future<void> export({
    required String format, // 'csv' | 'pdf' | 'excel'
    required ReportKind kind,
    required List<DailyOccupancyPoint> daily,
    required Map<String, int> byDepartment,
    required int substituteCount,
    required Map<String, int> releasesStats,
  }) async {
    switch (kind) {
      // ----------------------------------------------------------------------
      // 📊 Ocupación diaria
      // ----------------------------------------------------------------------
      case ReportKind.occupancyDaily:
        if (format == 'csv') {
          await exportDailyToCsv(daily);
        } else if (format == 'pdf') {
          await exportDailyToPdf(daily);
        } else if (format == 'excel') {
          await exportDailyToExcel(daily);
        }
        break;

      // ----------------------------------------------------------------------
      // 🏢 Uso por departamento
      // ----------------------------------------------------------------------
      case ReportKind.byDepartment:
        if (format == 'csv') {
          await exportByDepartmentToCsv(byDepartment);
        } else if (format == 'pdf') {
          await exportByDepartmentToPdf(byDepartment);
        } else if (format == 'excel') {
          await exportByDepartmentToExcel(byDepartment);
        }
        break;

      // ----------------------------------------------------------------------
      // 👥 Reservas de suplentes
      // ----------------------------------------------------------------------
      case ReportKind.substitutes:
        if (format == 'csv') {
          await exportSubstitutesToCsv(substituteCount);
        } else if (format == 'pdf') {
          await exportSubstitutesToPdf(substituteCount);
        } else if (format == 'excel') {
          await exportSubstitutesToExcel(substituteCount);
        }
        break;

      // ----------------------------------------------------------------------
      // 🚗 Liberaciones de titulares
      // ----------------------------------------------------------------------
      case ReportKind.titularReleases:
        if (format == 'csv') {
          await exportReleasesToCsv(releasesStats);
        } else if (format == 'pdf') {
          await exportReleasesToPdf(releasesStats);
        } else if (format == 'excel') {
          await exportReleasesToExcel(releasesStats);
        }
        break;
    }
  }

  // ------------------------------------------------------------------------
  // 📊 Ocupación diaria
  // ------------------------------------------------------------------------
  static Future<void> exportDailyToCsv(List<DailyOccupancyPoint> data) async {
    final rows = <List<String>>[
      ['Día', 'Ocupadas', 'Reservadas (Supl.)', 'Disponibles (Supl.)'],
      ...data.map((e) => [
            _formatDay(e.day),
            e.occupied.toString(),
            e.reservedBySubstitutes.toString(),
            e.availableForSubstitutes.toString(),
          ]),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    _downloadUtf8(csv, filename: 'ocupacion_diaria.csv', mime: 'text/csv');
  }

  static Future<void> exportDailyToPdf(List<DailyOccupancyPoint> data) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Reporte: Ocupación diaria',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: [
                'Día',
                'Ocupadas',
                'Reservadas (Supl.)',
                'Disponibles (Supl.)'
              ],
              data: data
                  .map((e) => [
                        _formatDay(e.day),
                        e.occupied,
                        e.reservedBySubstitutes,
                        e.availableForSubstitutes,
                      ])
                  .toList(),
            ),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();
    _downloadBytes(bytes,
        filename: 'ocupacion_diaria.pdf', mime: 'application/pdf');
  }

  static Future<void> exportDailyToExcel(List<DailyOccupancyPoint> data) async {
    final excel = Excel.createExcel();
    final sheet = excel['Ocupación diaria'];
    sheet.appendRow([
      TextCellValue('Día'),
      TextCellValue('Ocupadas'),
      TextCellValue('Reservadas (Supl.)'),
      TextCellValue('Disponibles (Supl.)'),
    ]);

    for (final e in data) {
      sheet.appendRow([
        TextCellValue(_formatDay(e.day)),
        TextCellValue(e.occupied.toString()),
        TextCellValue(e.reservedBySubstitutes.toString()),
        TextCellValue(e.availableForSubstitutes.toString()),
      ]);
    }

    final bytes = Uint8List.fromList(excel.encode()!);
    _downloadBytes(
      bytes,
      filename: 'ocupacion_diaria.xlsx',
      mime:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // ------------------------------------------------------------------------
  // 🏢 Uso por departamento
  // ------------------------------------------------------------------------
  static Future<void> exportByDepartmentToCsv(
      Map<String, int> byDepartment) async {
    final rows = <List<String>>[
      ['Departamento', 'Reservas'],
      ...byDepartment.entries.map((e) => [e.key, e.value.toString()]),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    _downloadUtf8(csv,
        filename: 'uso_por_departamento.csv', mime: 'text/csv');
  }

  static Future<void> exportByDepartmentToPdf(
      Map<String, int> byDepartment) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Reporte: Uso por departamento',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: ['Departamento', 'Reservas'],
              data: byDepartment.entries.map((e) => [e.key, e.value]).toList(),
            ),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();
    _downloadBytes(bytes,
        filename: 'uso_por_departamento.pdf', mime: 'application/pdf');
  }

  static Future<void> exportByDepartmentToExcel(
      Map<String, int> byDepartment) async {
    final excel = Excel.createExcel();
    final sheet = excel['Uso por departamento'];
    sheet.appendRow([
      TextCellValue('Departamento'),
      TextCellValue('Reservas'),
    ]);

    for (final e in byDepartment.entries) {
      sheet.appendRow([
        TextCellValue(e.key),
        TextCellValue(e.value.toString()),
      ]);
    }

    final bytes = Uint8List.fromList(excel.encode()!);
    _downloadBytes(
      bytes,
      filename: 'uso_por_departamento.xlsx',
      mime:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // ------------------------------------------------------------------------
  // 👥 Reservas de suplentes
  // ------------------------------------------------------------------------
  static Future<void> exportSubstitutesToCsv(int count) async {
    final csv = 'Tipo,Total\nReservas de suplentes,$count';
    _downloadUtf8(csv,
        filename: 'reservas_suplentes.csv', mime: 'text/csv');
  }

  static Future<void> exportSubstitutesToPdf(int count) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (_) => pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'Reporte: Reservas de suplentes',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Total: $count reservas',
                  style: const pw.TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );

    final bytes = await pdf.save();
    _downloadBytes(bytes,
        filename: 'reservas_suplentes.pdf', mime: 'application/pdf');
  }

  static Future<void> exportSubstitutesToExcel(int count) async {
    final excel = Excel.createExcel();
    final sheet = excel['Reservas de suplentes'];
    sheet.appendRow([
      TextCellValue('Tipo'),
      TextCellValue('Total'),
    ]);
    sheet.appendRow([
      TextCellValue('Reservas de suplentes'),
      TextCellValue(count.toString()),
    ]);

    final bytes = Uint8List.fromList(excel.encode()!);
    _downloadBytes(
      bytes,
      filename: 'reservas_suplentes.xlsx',
      mime:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // ------------------------------------------------------------------------
  // 🚗 Liberaciones de titulares
  // ------------------------------------------------------------------------
  static Future<void> exportReleasesToCsv(Map<String, int> stats) async {
    final csv = const ListToCsvConverter().convert([
      ['Tipo', 'Cantidad'],
      ['Disponibles', '${stats['available'] ?? 0}'],
      ['Reservadas', '${stats['booked'] ?? 0}'],
      ['Total', '${stats['total'] ?? 0}'],
    ]);
    _downloadUtf8(csv,
        filename: 'liberaciones_titulares.csv', mime: 'text/csv');
  }

  static Future<void> exportReleasesToPdf(Map<String, int> stats) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (_) => pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'Reporte: Liberaciones de titulares',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: ['Tipo', 'Cantidad'],
                data: [
                  ['Disponibles', stats['available'] ?? 0],
                  ['Reservadas', stats['booked'] ?? 0],
                  ['Total', stats['total'] ?? 0],
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final bytes = await pdf.save();
    _downloadBytes(bytes,
        filename: 'liberaciones_titulares.pdf', mime: 'application/pdf');
  }

  static Future<void> exportReleasesToExcel(Map<String, int> stats) async {
    final excel = Excel.createExcel();
    final sheet = excel['Liberaciones de titulares'];
    sheet.appendRow([
      TextCellValue('Tipo'),
      TextCellValue('Cantidad'),
    ]);
    sheet.appendRow([
      TextCellValue('Disponibles'),
      TextCellValue((stats['available'] ?? 0).toString()),
    ]);
    sheet.appendRow([
      TextCellValue('Reservadas'),
      TextCellValue((stats['booked'] ?? 0).toString()),
    ]);
    sheet.appendRow([
      TextCellValue('Total'),
      TextCellValue((stats['total'] ?? 0).toString()),
    ]);

    final bytes = Uint8List.fromList(excel.encode()!);
    _downloadBytes(
      bytes,
      filename: 'liberaciones_titulares.xlsx',
      mime:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // ------------------------------------------------------------------------
  // 💾 Métodos de descarga
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

/// --------------------------------------------------------------------------
/// CSV converter minimalista (sin dependencias externas)
/// --------------------------------------------------------------------------
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
