// pages/superagent/statistiques_superagent.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fast_tmb/services/firestore_service.dart';
import 'package:fast_tmb/widgets/barre_navigation.dart';
import 'package:fast_tmb/utils/constantes_couleurs.dart';
import 'package:fast_tmb/utils/time_format.dart';
import 'package:fast_tmb/widgets/role_guard.dart';

class StatistiquesSuperAgentPage extends StatefulWidget {
  const StatistiquesSuperAgentPage({Key? key}) : super(key: key);

  @override
  State<StatistiquesSuperAgentPage> createState() => _StatistiquesSuperAgentPageState();
}

class _StatistiquesSuperAgentPageState extends State<StatistiquesSuperAgentPage> {
  int _periodeJours = 7; // 1/7/30
  String? _agentId; // null = tous
  String? _queueType; // null = tous | 'depot' | 'retrait'

  bool _loading = false;
  String? _error;

  // Données
  List<Map<String, String?>> _agents = [];
  int _termine = 0;
  int _absent = 0;
  int _annule = 0;
  double _avgTraitement = 0.0;
  double _avgAttente = 0.0;
  double _satisfactionMoyenne = 0.0;
  int _satisfactionCount = 0;

  @override
  void initState() {
    super.initState();
    _chargerAgentsEtStats();
  }

  Future<void> _chargerAgentsEtStats() async {
    setState(() { _loading = true; _error = null; });
    try {
      final fs = Provider.of<FirestoreService>(context, listen: false);
      // Charger la liste des agents au premier chargement
      if (_agents.isEmpty) {
        _agents = await fs.listerAgents();
      }
      await _chargerStats();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _chargerStats() async {
    setState(() { _loading = true; _error = null; });
    try {
      final fs = Provider.of<FirestoreService>(context, listen: false);
      final now = DateTime.now();
      final from = now.subtract(Duration(days: _periodeJours));

      // Compteurs
      _termine = await fs.compterParPeriode(status: 'termine', from: from, to: now, queueType: _queueType, agentId: _agentId);
      _absent = await fs.compterParPeriode(status: 'absent', from: from, to: now, queueType: _queueType, agentId: _agentId);
      _annule = await fs.compterParPeriode(status: 'annule', from: from, to: now, queueType: _queueType, agentId: _agentId);

      // Moyennes
      _avgTraitement = await fs.calculerTempsMoyenTraitementParFiltres(from: from, to: now, queueType: _queueType, agentId: _agentId);
      _avgAttente = await fs.calculerTempsMoyenAttenteParFiltres(from: from, to: now, queueType: _queueType, agentId: _agentId);
      
      // Satisfaction
      if (_agentId != null) {
        _satisfactionMoyenne = await fs.calculerSatisfactionMoyenneAgent(_agentId!, jours: _periodeJours);
        _satisfactionCount = await fs.compterTicketsAvecSatisfactionAgent(_agentId!, jours: _periodeJours);
      } else {
        _satisfactionMoyenne = await fs.calculerSatisfactionMoyenneGlobale(jours: _periodeJours);
        _satisfactionCount = await fs.compterTicketsAvecSatisfactionGlobal(jours: _periodeJours);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['superagent'],
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Stats Superagent'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _loading ? null : _chargerStats,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      bottomNavigationBar: BarreNavigation(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Erreur: $_error'))
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Vue globale', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                // Période
                                DropdownButton<int>(
                                  value: _periodeJours,
                                  items: const [
                                    DropdownMenuItem(value: 1, child: Text("Aujourd'hui")),
                                    DropdownMenuItem(value: 7, child: Text('7 jours')),
                                    DropdownMenuItem(value: 30, child: Text('30 jours')),
                                  ],
                                  onChanged: (v) async {
                                    if (v == null) return;
                                    setState(() => _periodeJours = v);
                                    await _chargerStats();
                                  },
                                ),
                                // Service
                                DropdownButton<String?>(
                                  value: _queueType,
                                  items: const [
                                    DropdownMenuItem(value: null, child: Text('Tous services')),
                                    DropdownMenuItem(value: 'depot', child: Text('Dépôt')),
                                    DropdownMenuItem(value: 'retrait', child: Text('Retrait')),
                                  ],
                                  onChanged: (v) async {
                                    setState(() => _queueType = v);
                                    await _chargerStats();
                                  },
                                ),
                                // Agent
                                DropdownButton<String?>(
                                  value: _agentId,
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('Tous agents')),
                                    ..._agents.map((a) => DropdownMenuItem(
                                          value: a['id'],
                                          child: Text(a['email'] ?? a['id'] ?? ''),
                                        ))
                                  ],
                                  onChanged: (v) async {
                                    setState(() => _agentId = v);
                                    await _chargerStats();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _resumeCard(),
                        const SizedBox(height: 12),
                        _satisfactionCard(),
                        const SizedBox(height: 12),
                        _moyennesCard(),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/admin_services'),
                            icon: const Icon(Icons.home_repair_service_outlined),
                            label: const Text('Services'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/admin_agents'),
                            icon: const Icon(Icons.group_outlined),
                            label: const Text('Agents'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/admin_horaires'),
                            icon: const Icon(Icons.access_time),
                            label: const Text('Horaires'),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        const Text(
                          'Filtres appliqués sur la période sélectionnée',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
      ),
    ),
    );
  }

  Widget _resumeCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Compteurs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              _chip(Icons.check_circle, 'Traités', _termine, Colors.green),
              const SizedBox(width: 8),
              _chip(Icons.block, 'Absents', _absent, Colors.red),
              const SizedBox(width: 8),
              _chip(Icons.cancel, 'Annulés', _annule, Colors.grey),
            ])
          ],
        ),
      ),
    );
  }

  Widget _satisfactionCard() {
    final scoreText = _satisfactionMoyenne > 0 
        ? '${_satisfactionMoyenne.toStringAsFixed(1)}/5'
        : 'Aucune';
    
    final scope = _agentId != null ? 'Agent sélectionné' : 'Global';
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rate, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text('Satisfaction Client ($scope)', 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Score moyen',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        scoreText,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _satisfactionMoyenne >= 4 ? Colors.green :
                                 _satisfactionMoyenne >= 3 ? Colors.orange : 
                                 _satisfactionMoyenne > 0 ? Colors.red : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Évaluations',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        '$_satisfactionCount',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ConstantesCouleurs.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_satisfactionMoyenne > 0)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Qualité',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: List.generate(5, (index) {
                            return Icon(
                              index < _satisfactionMoyenne.round() ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (_satisfactionCount == 0) ...[
              const SizedBox(height: 8),
              Text(
                'Aucune évaluation reçue sur cette période',
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _moyennesCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Moyennes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.timer, color: ConstantesCouleurs.orange),
              const SizedBox(width: 8),
              Text('Traitement: ${formatMinutesDouble(_avgTraitement)}'),
              const SizedBox(width: 16),
              const Icon(Icons.hourglass_bottom, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Text('Attente: ${formatMinutesDouble(_avgAttente)}'),
            ])
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, int value, Color color) {
    return Chip(
      avatar: Icon(icon, size: 18, color: Colors.white),
      label: Text('$label: $value'),
      backgroundColor: color.withValues(alpha: 0.8),
      labelStyle: const TextStyle(color: Colors.white),
    );
  }
}
