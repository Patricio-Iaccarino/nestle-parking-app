import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../features/reports/domain/report_models.dart';

class ExportService {
  static final _df = DateFormat('yyyy-MM-dd HH:mm');

  /// ------------------------------------------------------------------------
  /// Punto único de exportación para el reporte detallado
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
    }
  }

  // ------------------------------------------------------------------------
  // CSV 
  // ------------------------------------------------------------------------
  static Future<void> _exportDetailedToCsv(
      List<DetailedReportRecord> data) async {
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

    await Printing.sharePdf(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      filename: "reporte_detallado.csv",
    );
  }

  // ------------------------------------------------------------------------
  // PDF 
  // ------------------------------------------------------------------------
  static Future<void> _exportDetailedToPdf(
      List<DetailedReportRecord> data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            "Reporte detallado de ocupación",
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),

          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  for (final h in [
                    'Fecha',
                    'Estado',
                    'Usuario',
                    'Departamento',
                    'Cochera'
                  ])
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        h,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                ],
              ),
              ...data.map(
                (r) => pw.TableRow(
                  children: [
                    _pdfCell(_df.format(r.releaseDate)),
                    _pdfCell(r.status),
                    _pdfCell(r.userName ?? '-'),
                    _pdfCell(r.departmentName ?? '-'),
                    _pdfCell(r.spotName ?? '-'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    await Printing.sharePdf(
      bytes: bytes,
      filename: "reporte_detallado.pdf",
    );
  }

  static pw.Widget _pdfCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text),
    );
  }

  // ------------------------------------------------------------------------
  // EXCEL
  // ------------------------------------------------------------------------
  static Future<void> _exportDetailedToExcel(
      List<DetailedReportRecord> data) async {
    final excel = Excel.createExcel();
    final sheet = excel['Reporte detallado'];

    sheet.appendRow([
      TextCellValue('Fecha'),
      TextCellValue('Estado'),
      TextCellValue('Usuario'),
      TextCellValue('Departamento'),
      TextCellValue('Cochera'),
    ]);

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

    await Printing.sharePdf(
      bytes: bytes,
      filename: "reporte_detallado.xlsx",
    );
  }
}

/// Conversor CSV 
class ListToCsvConverter {
  const ListToCsvConverter();

  String convert(List<List<String>> rows) {
    return rows.map((r) => r.map(_escape).join(',')).join('\n');
  }

  String _escape(String v) {
    final needsQuotes =
        v.contains(',') || v.contains('"') || v.contains('\n');
    final s = v.replaceAll('"', '""');
    return needsQuotes ? '"$s"' : s;
  }
}
