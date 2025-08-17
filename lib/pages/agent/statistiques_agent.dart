// pages/agent/statistiques_agent.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fast_tmb/services/auth_service_v2.dart';
import 'package:fast_tmb/services/firestore_service.dart';
import 'package:fast_tmb/utils/constantes_couleurs.dart';
import 'package:fast_tmb/widgets/barre_navigation.dart';
import 'package:fast_tmb/utils/time_format.dart';
import 'package:fast_tmb/widgets/role_guard.dart';

class StatistiquesAgentPage extends StatefulWidget {
  const StatistiquesAgentPage({Key? key}) : super(key: key);

  @override
  State<StatistiquesAgentPage> createState() => _StatistiquesAgentPageState();
}

class _StatistiquesAgentPageState extends State<StatistiquesAgentPage> {
  int _periodeJours = 7; // 1, 7, 30
  bool _loading = false;
  Map<String, dynamic>? _depot;   // { servi, absent, annule, avgTrait, avgWait }
  Map<String, dynamic>? _retrait; // { servi, absent, annule, avgTrait, avgWait }
  double _avgTraitementAgent = 0.0;
  double _avgAttenteAgent = 0.0;
  double _satisfactionMoyenne = 0.0;
  int _satisfactionCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Nettoyage auto des tickets en attente des jours précédents (pas de bouton)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final fs = Provider.of<FirestoreService>(context, listen: false);
      await fs.ensureCompteurTicketsStructure();
      await fs.nettoyerTicketsAnciensEnAttente();
      await _chargerStats();
    });
  }

  Future<void> _chargerStats() async {
    setState(() { _loading = true; _error = null; });
    try {
      final fs = Provider.of<FirestoreService>(context, listen: false);
      final auth = Provider.of<AuthServiceV2>(context, listen: false);
      final agentId = auth.currentUser?.uid;
      // Compteurs du jour
      final depTr = await fs.compterAujourdHuiParStatusEtFile('servi', 'depot');
      final depAb = await fs.compterAujourdHuiParStatusEtFile('absent', 'depot');
      final depAn = await fs.compterAujourdHuiParStatusEtFile('annule', 'depot');
      final retTr = await fs.compterAujourdHuiParStatusEtFile('servi', 'retrait');
      final retAb = await fs.compterAujourdHuiParStatusEtFile('absent', 'retrait');
      final retAn = await fs.compterAujourdHuiParStatusEtFile('annule', 'retrait');

      // Temps moyens (fenêtre choisie)
      final depAvgTrait = await fs.calculerTempsMoyenTraitementParFile('depot', jours: _periodeJours);
      final retAvgTrait = await fs.calculerTempsMoyenTraitementParFile('retrait', jours: _periodeJours);
      final depAvgWait = await fs.calculerTempsMoyenAttenteParFile('depot', jours: _periodeJours);
      final retAvgWait = await fs.calculerTempsMoyenAttenteParFile('retrait', jours: _periodeJours);

      // Moyennes par agent (si connecté)
      if (agentId != null) {
        _avgTraitementAgent = await fs.calculerTempsMoyenTraitementParAgent(agentId, jours: _periodeJours);
        _avgAttenteAgent = await fs.calculerTempsMoyenAttenteParAgent(agentId, jours: _periodeJours);
        _satisfactionMoyenne = await fs.calculerSatisfactionMoyenneAgent(agentId, jours: _periodeJours);
        _satisfactionCount = await fs.compterTicketsAvecSatisfactionAgent(agentId, jours: _periodeJours);
      } else {
        _avgTraitementAgent = 0.0;
        _avgAttenteAgent = 0.0;
        _satisfactionMoyenne = 0.0;
        _satisfactionCount = 0;
      }

      _depot = {
        'servi': depTr,
        'absent': depAb,
        'annule': depAn,
        'avgTrait': depAvgTrait,
        'avgWait': depAvgWait,
      };
      _retrait = {
        'servi': retTr,
        'absent': retAb,
        'annule': retAn,
        'avgTrait': retAvgTrait,
        'avgWait': retAvgWait,
      };
    } catch (e) {
      debugPrint('Erreur chargement stats agent: $e');
      _error = e.toString();
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthServiceV2>(context, listen: false);

    return RoleGuard(
      allowedRoles: const ['agent'],
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Stats Agent'),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Bonjour, ${auth.currentUser?.email ?? 'agent'}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            DropdownButton<int>(
                              value: _periodeJours,
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('Aujourd\'hui')),
                                DropdownMenuItem(value: 7, child: Text('7 jours')),
                                DropdownMenuItem(value: 30, child: Text('30 jours')),
                              ],
                              onChanged: (v) async {
                                if (v == null) return;
                                setState(() => _periodeJours = v);
                                await _chargerStats();
                              },
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildHeaderResume(),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Vos moyennes (période sélectionnée)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Row(children: [
                                  const Icon(Icons.timer, color: ConstantesCouleurs.orange),
                                  const SizedBox(width: 8),
                                  Text('Traitement: ${formatMinutesDouble(_avgTraitementAgent)}'),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.hourglass_bottom, color: Colors.blueGrey),
                                  const SizedBox(width: 8),
                                  Text('Attente: ${formatMinutesDouble(_avgAttenteAgent)}'),
                                ])
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSatisfactionCard(),
                        const SizedBox(height: 12),
                        _buildCard('Dépôt', _depot),
                        const SizedBox(height: 12),
                        _buildCard('Retrait', _retrait),
                        const SizedBox(height: 8),
                        const Text(
                          'Compteurs = journée en cours · Temps moyen = fenêtre sélectionnée',
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

  Widget _buildHeaderResume() {
    final termine = (_depot?['servi'] ?? 0) + (_retrait?['servi'] ?? 0);
    final absent = (_depot?['absent'] ?? 0) + (_retrait?['absent'] ?? 0);
    final annule = (_depot?['annule'] ?? 0) + (_retrait?['annule'] ?? 0);

    return Card(
      color: ConstantesCouleurs.orange.withValues(alpha: 0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _smallStat(Icons.check_circle, 'Servis', termine, Colors.green),
            _smallStat(Icons.block, 'Absents', absent, Colors.red),
            _smallStat(Icons.cancel, 'Annulés', annule, Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSatisfactionCard() {
    final scoreText = _satisfactionMoyenne > 0 
        ? '${_satisfactionMoyenne.toStringAsFixed(1)}/5'
        : 'Aucune';
    
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
                const Text('Satisfaction Client', 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Score moyen',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      scoreText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _satisfactionMoyenne >= 4 ? Colors.green :
                               _satisfactionMoyenne >= 3 ? Colors.orange : Colors.red,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Évaluations',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      '$_satisfactionCount',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ConstantesCouleurs.orange,
                      ),
                    ),
                  ],
                ),
                if (_satisfactionMoyenne > 0)
                  Row(
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

  Widget _buildCard(String titre, Map<String, dynamic>? data) {
    final termine = data?['servi'] ?? 0;
    final absent = data?['absent'] ?? 0;
    final annule = data?['annule'] ?? 0;
    final avgTrait = (data?['avgTrait'] as double?) ?? 0.0;
    final avgWait = (data?['avgWait'] as double?) ?? 0.0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(Icons.check_circle, 'Servis', termine, Colors.green),
                const SizedBox(width: 8),
                _chip(Icons.block, 'Absents', absent, Colors.red),
                const SizedBox(width: 8),
                _chip(Icons.cancel, 'Annulés', annule, Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.timer, color: ConstantesCouleurs.orange),
                const SizedBox(width: 8),
                Text('Traitement: ${formatMinutesDouble(avgTrait)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.hourglass_bottom, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text('Attente: ${formatMinutesDouble(avgWait)}'),
              ],
            )
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

  Widget _smallStat(IconData icon, String label, int value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text('$label: $value', style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
