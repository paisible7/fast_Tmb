// pages/agent/statistiques_agent.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl/services/firestore_service.dart';
import 'package:fl/widgets/barre_navigation.dart';
import 'package:fl/utils/constantes_couleurs.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:fl/services/auth_service.dart';

import '../../services/export_service.dart';

class StatistiquesAgentPage extends StatelessWidget {
  const StatistiquesAgentPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.currentUser?.role != 'agent') {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/accueil'));
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques')),
      bottomNavigationBar: BarreNavigation(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            FutureBuilder<int>(
              future: _countStatus('termine'),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                final count = snap.data ?? 0;
                return ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text('Tickets traités'),
                  trailing: Text('$count'),
                );
              },
            ),
            FutureBuilder<int>(
              future: _countStatus('absent'),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                final count = snap.data ?? 0;
                return ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: const Text('Clients absents'),
                  trailing: Text('$count'),
                );
              },
            ),
            const Divider(height: 32),
            FutureBuilder<double>(
              future: fs.calculerTempsMoyenAttente(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                final avg = snap.data?.toStringAsFixed(1) ?? '0.0';
                return ListTile(
                  leading: const Icon(Icons.timer, color: Colors.orange),
                  title: const Text('Temps moyen d\'attente'),
                  trailing: Text('$avg min'),
                );
              },
            ),
            const SizedBox(height: 24),
            FutureBuilder<Map<String, int>>(
              future: fs.historiqueQuotidien(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!;
                final labels = data.keys.toList();
                final values = data.values.toList();

                final spots = values
                    .asMap()
                    .entries
                    .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
                    .toList();

                return SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= labels.length) return const SizedBox();
                              final day = labels[index].split('-').last;
                              return Text(day, style: const TextStyle(fontSize: 10));
                            },
                            reservedSize: 28,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) => Text('${value.toInt()}'),
                          ),
                        ),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: ConstantesCouleurs.orange,
                          barWidth: 3,
                          belowBarData: BarAreaData(show: false),
                          dotData: FlDotData(show: true),
                        ),
                      ],
                      minY: 0,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final path = await ExportService().exportTicketsCSV();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Exporté: $path')),
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: ConstantesCouleurs.orange),
              child: const Text('Exporter CSV'),
            ),
          ],
        ),
      ),
    );
  }

  Future<int> _countStatus(String status) {
    return FirebaseFirestore.instance
        .collection('tickets')
        .where('status', isEqualTo: status)
        .get()
        .then((snap) => snap.docs.length);
  }
}
