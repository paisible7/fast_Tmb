import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:printing/printing.dart' as printing;
import 'package:share_plus/share_plus.dart' as share;
import 'package:cross_file/cross_file.dart' as cf;
import 'file_download_service.dart';

class ExportService {
  Future<String> exportTicketsCSV() async {
    final snap = await FirebaseFirestore.instance
        .collection('tickets')
        .orderBy('createdAt')
        .get();

    final rows = <List<String>>[
      ['numero','status','createdAt','treatedAt']
    ];
    for (final doc in snap.docs) {
      final d = doc.data();
      rows.add([
        d['numero'].toString(),
        d['status'] as String,
        (d['createdAt'] as Timestamp).toDate().toIso8601String(),
        (d['treatedAt'] as Timestamp?)?.toDate().toIso8601String() ?? ''
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);

    // Suggest a save location via native dialog (desktop/web). On mobile, open share/save sheet.
    try {
      final isDesktopOrWeb = kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS;
      if (isDesktopOrWeb) {
        final location = await getSaveLocation(
          suggestedName: 'tickets_export.csv',
          acceptedTypeGroups: const [
            XTypeGroup(label: 'CSV', extensions: ['csv'])
          ],
        );
        if (location != null) {
          final data = Uint8List.fromList(utf8.encode(csv));
          final xfile = XFile.fromData(data,
              name: 'tickets_export.csv', mimeType: 'text/csv');
          await xfile.saveTo(location.path);
          return location.path;
        }
      } else if (Platform.isAndroid) {
        // Android: Let user pick exact location via SAF (Save As)
        final downloadService = FileDownloadService();
        final uri = await downloadService.pickAndSaveWithDialog(
          Uint8List.fromList(utf8.encode(csv)),
          'tickets_export.csv',
          mimeType: 'text/csv',
        );
        if (uri != null) return uri;
        return 'cancelled';
      } else if (Platform.isIOS) {
        // iOS: use native share sheet
        final tmp = await getTemporaryDirectory();
        final tmpFile = File('${tmp.path}/tickets_export.csv');
        await tmpFile.writeAsBytes(Uint8List.fromList(utf8.encode(csv)));
        await share.Share.shareXFiles([
          cf.XFile(tmpFile.path, mimeType: 'text/csv', name: 'tickets_export.csv')
        ], text: 'Export CSV');
        return 'shared:tickets_export.csv';
      }
    } catch (_) {
      // getSaveLocation not implemented => fallback below
    }

    // Fallback to app documents directory if user cancels
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/tickets_export.csv');
    await file.writeAsString(csv);
    return file.path;

  }

  Future<String> exportStatsPDF({
    required String title,
    Map<String, dynamic>? summary, // ex: {'servi': 12, 'absent': 2, 'annule': 1, 'avgWait': '05:32', 'avgTrait': '03:10'}
    List<Map<String, dynamic>>? perService, // ex: [{'service': 'Dépôt','servi':10,'absent':1,'annule':1,'avgWait':'05:00','avgTrait':'03:00'}]
    DateTime? from,
    DateTime? to,
  }) async {
    // Default built-in font (limited Unicode). We keep ASCII to avoid missing glyphs.
    final doc = pw.Document();
    final df = DateFormat('dd/MM/yyyy');
    final now = DateTime.now();
    final period = from != null && to != null
        ? '${df.format(from)} - ${df.format(to)}'
        : df.format(now);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('FAST - TMB', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Rapport statistiques', style: const pw.TextStyle(fontSize: 12)),
                ]),
                pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Periode: $period', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Date: ${df.format(now)}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 16),

            if (summary != null) ...[
              pw.Text('Synthese', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(width: 0.4, color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1),
                },
                children: [
                  _row(['Termines', (summary['servi'] ?? 0).toString()], header: true),
                  _row(['Absents', (summary['absent'] ?? 0).toString()]),
                  _row(['Annules', (summary['annule'] ?? 0).toString()]),
                  _row(['Attente moyenne', (summary['avgWait'] ?? '-').toString()]),
                  _row(['Traitement moyen', (summary['avgTrait'] ?? '-').toString()]),
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            if (perService != null && perService.isNotEmpty) ...[
              pw.Text('Details par service', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(width: 0.4, color: PdfColors.grey400),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1),
                  4: pw.FlexColumnWidth(1.2),
                  5: pw.FlexColumnWidth(1.2),
                },
                children: [
                  _row(['Service','Termines','Absents','Annules','Attente moy.','Traitement moy.'], header: true),
                  ...perService.map((e) => _row([
                    (e['service'] ?? '').toString(),
                    (e['servi'] ?? 0).toString(),
                    (e['absent'] ?? 0).toString(),
                    (e['annule'] ?? 0).toString(),
                    (e['avgWait'] ?? '-').toString(),
                    (e['avgTrait'] ?? '-').toString(),
                  ])).toList(),
                ],
              ),
            ],
          ];
        },
      ),
    );

    final bytes = await doc.save();
    final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');

    // Desktop/Web: show native Save dialog. Mobile: show Share/Save sheet.
    try {
      final isDesktopOrWeb = kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS;
      if (isDesktopOrWeb) {
        final location = await getSaveLocation(
          suggestedName: 'stats_$safeTitle.pdf',
          acceptedTypeGroups: const [
            XTypeGroup(label: 'PDF', extensions: ['pdf'])
          ],
        );
        if (location != null) {
          final xfile = XFile.fromData(bytes,
              name: 'stats_$safeTitle.pdf', mimeType: 'application/pdf');
          await xfile.saveTo(location.path);
          return location.path;
        }
      } else if (Platform.isAndroid) {
        // Android: open SAF Save As dialog to let user choose location
        final downloadService = FileDownloadService();
        final uri = await downloadService.pickAndSaveWithDialog(
          bytes,
          'stats_$safeTitle.pdf',
          mimeType: 'application/pdf',
        );
        if (uri != null) return uri;
        return 'cancelled';
      } else if (Platform.isIOS) {
        // iOS: Share sheet
        await printing.Printing.sharePdf(bytes: bytes, filename: 'stats_$safeTitle.pdf');
        return 'shared:stats_$safeTitle.pdf';
      }
    } catch (_) {
      // fall through to fallback
    }

    // Fallback if dialog cancelled or any error
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/stats_$safeTitle.pdf');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}

pw.TableRow _row(List<String> cells, {bool header = false}) {
  final style = pw.TextStyle(
    fontSize: 10,
    fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  return pw.TableRow(
    decoration: header ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFEFEF)) : null,
    children: cells.map((c) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Text(c, style: style),
    )).toList(),
  );
}
