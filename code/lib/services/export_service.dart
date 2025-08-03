import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';

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
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/tickets_export.csv');
    await file.writeAsString(csv);
    return file.path;

  }
}
