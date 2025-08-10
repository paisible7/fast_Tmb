// pages/agent/tableau_bord_agent.dart
import 'package:fast_tmb/services/auth_service_v2.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:fast_tmb/widgets/barre_navigation.dart';
import 'package:fast_tmb/utils/constantes_couleurs.dart';
import 'package:fast_tmb/services/firestore_service.dart';
import 'package:fast_tmb/utils/time_format.dart';
import 'package:fast_tmb/widgets/role_guard.dart';

import '../connexion_page.dart';

class TableauBordAgentPage extends StatefulWidget {
  const TableauBordAgentPage({Key? key}) : super(key: key);

  @override
  State<TableauBordAgentPage> createState() => _TableauBordAgentPageState();
}

class _TableauBordAgentPageState extends State<TableauBordAgentPage> {
  bool _isLoading = false;
  bool _isLoadingResume = false;
  int _totalTraites = 0;
  int _totalAbsents = 0;
  int _totalAnnules = 0;
  String? _selectedAgentId; // utilisé par superagent
  String? _selectedQueueType; // 'depot' | 'retrait' | null

  @override
  void initState() {
    super.initState();
    _rafraichirResume();
  }

  Future<void> _rafraichirResume() async {
    setState(() => _isLoadingResume = true);
    try {
      final fs = Provider.of<FirestoreService>(context, listen: false);
      final futures = <Future<int>>[
        fs.compterAujourdHuiParStatusEtFile('termine', 'depot'),
        fs.compterAujourdHuiParStatusEtFile('termine', 'retrait'),
        fs.compterAujourdHuiParStatusEtFile('absent', 'depot'),
        fs.compterAujourdHuiParStatusEtFile('absent', 'retrait'),
        fs.compterAujourdHuiParStatusEtFile('annule', 'depot'),
        fs.compterAujourdHuiParStatusEtFile('annule', 'retrait'),
      ];
      final r = await Future.wait(futures);
      setState(() {
        _totalTraites = (r[0] + r[1]);
        _totalAbsents = (r[2] + r[3]);
        _totalAnnules = (r[4] + r[5]);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement stats du jour: $e'), backgroundColor: Colors.red),
        );
        print('Erreur chargement stats du jour: ${e}');

    }
    } finally {
      if (mounted) setState(() => _isLoadingResume = false);
    }
  }

  // Méthode pour appeler le prochain client via FirestoreService
  Future<void> _appellerProchainClient({String? queueType}) async {
    setState(() => _isLoading = true);
    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.appelerProchainClient(queueType: queueType);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client appelé avec succès'), backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint('Erreur appelerProchainClient: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Méthode pour marquer le client en cours comme absent via FirestoreService
  Future<void> _marquerAbsent() async {
    setState(() => _isLoading = true);
    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final role = Provider.of<AuthServiceV2>(context, listen: false).currentUser?.role;
      final isSuperAgent = role == 'superagent';
      await firestoreService.marquerClientAbsent(
        anyAgent: isSuperAgent && _selectedAgentId == null,
        targetAgentId: _selectedAgentId,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client marqué comme absent'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      debugPrint('Erreur marquerClientAbsent: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Affiche une boîte de dialogue de confirmation avant de terminer le service
  Future<void> _confirmerEtTerminerService() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la fin du service'),
        content: const Text('Es-tu sûr de vouloir terminer le service pour ce client ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _terminerService();
    }
  }

  // Méthode pour terminer le service du client actuel via FirestoreService
  Future<void> _terminerService() async {
    setState(() => _isLoading = true);
    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final role = Provider.of<AuthServiceV2>(context, listen: false).currentUser?.role;
      final isSuperAgent = role == 'superagent';
      
      // Terminer le service et récupérer les infos du ticket
      final ticketInfo = await firestoreService.terminerServiceClient(
        anyAgent: isSuperAgent && _selectedAgentId == null,
        targetAgentId: _selectedAgentId,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service terminé pour le client'), backgroundColor: Colors.green),
        );
        
        // Informer simplement l'agent que le client sera invité à évaluer
        if (ticketInfo != null) {
          _proposerSatisfaction(ticketInfo);
        }
      }
    } catch (e) {
      debugPrint('Erreur terminerServiceClient: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _proposerSatisfaction(Map<String, dynamic> ticketInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.star_rate, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('Évaluation du service'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Le service est terminé pour le ticket #${ticketInfo['numero']}.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Le client recevra une invitation pour évaluer son expérience dans son application.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthServiceV2>(context);

    if (authService.currentUser == null) {
      Future.microtask(() {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ConnexionPage()),
              (route) => false,
        );
      });
      return const SizedBox.shrink();
    }

    final role = authService.currentUser?.role;
    final isSuperAgent = role == 'superagent';
    if (role != 'agent' && !isSuperAgent) {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/accueil'));
      return const SizedBox.shrink();
    }
    final firestoreService = Provider.of<FirestoreService>(context);
    
    return RoleGuard(
      allowedRoles: const ['agent'],
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord agent'),
        backgroundColor: ConstantesCouleurs.orange,
        foregroundColor: Colors.white,
        // actions supprimées : pas de bouton déconnexion dans l'AppBar
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _rafraichirResume,
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir les stats',
          ),
        ],
      ),
      bottomNavigationBar: BarreNavigation(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Statistiques en temps réel
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Statistiques',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          StreamBuilder<int>(
                            stream: firestoreService.nombreEnAttenteStream(),
                            builder: (context, snapshot) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        '${snapshot.data ?? 0}',
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: ConstantesCouleurs.orange,
                                        ),
                                      ),
                                      const Text('En attente'),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Stats rapides du jour (toutes files)
                  _buildHeaderResumeDuJour(),
                  const SizedBox(height: 16),
                  // Raccourci vers la page Stats Superagent
                  if (isSuperAgent) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.analytics_outlined),
                        label: const Text('Voir stats globales'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ConstantesCouleurs.orange,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pushNamed(context, '/statistiques_superagent'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Sélecteur d'agent (visible superagent)
                  if (isSuperAgent) ...[
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Filtrer par agent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('utilisateurs')
                                  .where('role', isEqualTo: 'agent')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const CircularProgressIndicator();
                                final items = [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('Tous les agents'),
                                  ),
                                  ...snapshot.data!.docs.map((d) {
                                    final data = d.data() as Map<String, dynamic>;
                                    final name = (data['prenom'] != null && data['nom'] != null)
                                        ? '${data['prenom']} ${data['nom']}'
                                        : (data['email'] ?? d.id);
                                    return DropdownMenuItem<String>(
                                      value: d.id,
                                      child: Text(name),
                                    );
                                  })
                                ];
                                return DropdownButton<String?>(
                                  isExpanded: true,
                                  value: _selectedAgentId,
                                  items: items,
                                  onChanged: (val) => setState(() => _selectedAgentId = val),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Sélecteur de file + appel prochain (superagent)
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Appeler le prochain (filtre file)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('Toutes'),
                                  selected: _selectedQueueType == null,
                                  onSelected: (v) => setState(() => _selectedQueueType = null),
                                ),
                                ChoiceChip(
                                  label: const Text('Dépôt'),
                                  selected: _selectedQueueType == 'depot',
                                  onSelected: (v) => setState(() => _selectedQueueType = 'depot'),
                                ),
                                ChoiceChip(
                                  label: const Text('Retrait'),
                                  selected: _selectedQueueType == 'retrait',
                                  onSelected: (v) => setState(() => _selectedQueueType = 'retrait'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow),
                                style: ElevatedButton.styleFrom(backgroundColor: ConstantesCouleurs.orange, foregroundColor: Colors.white),
                                onPressed: _isLoading ? null : () => _appellerProchainClient(queueType: _selectedQueueType),
                                label: const Text('Appeler le prochain'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Client en cours
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Client en cours',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          StreamBuilder<QuerySnapshot>(
                            stream: (() {
                              final base = FirebaseFirestore.instance
                                  .collection('tickets')
                                  .where('status', isEqualTo: 'en_cours');
                              if (isSuperAgent) {
                                if (_selectedAgentId != null) {
                                  return base
                                      .where('agentId', isEqualTo: _selectedAgentId)
                                      .orderBy('createdAt')
                                      .limit(1)
                                      .snapshots();
                                }
                                return base
                                    .orderBy('createdAt')
                                    .limit(1)
                                    .snapshots();
                              } else {
                                return base
                                    .where('agentId', isEqualTo: authService.currentUser?.uid)
                                    .orderBy('createdAt')
                                    .limit(1)
                                    .snapshots();
                              }
                            })(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                debugPrint('Firestore error (client en cours): ${snapshot.error}');
                                return Column(
                                  children: [
                                    const Icon(Icons.error, color: Colors.red, size: 40),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Erreur Firestore :\n${snapshot.error}\nIl manque probablement un index.\nMerci de contacter l\'administrateur.',
                                      style: const TextStyle(color: Colors.red, fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                );
                              }
                              if (!snapshot.hasData) {
                                return const CircularProgressIndicator();
                              }
                              if (snapshot.data!.docs.isEmpty) {
                                return const Text(
                                  'Aucun client en cours',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                );
                              }
                              final doc = snapshot.data!.docs.first;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ticket #${doc['numero']}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: ConstantesCouleurs.orange,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Client : ${doc['creatorEmail'] ?? doc['creatorId'] ?? 'Inconnu'}'),
                                  const SizedBox(height: 8),
                                  Text('Service: ${(doc.data() as Map<String, dynamic>)['service'] ?? 'Non spécifié'}'),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _isLoading ? null : _confirmerEtTerminerService,
                                          icon: const Icon(Icons.check_circle),
                                          label: const Text('Terminer le service'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _isLoading ? null : _marquerAbsent,
                                          icon: const Icon(Icons.person_off),
                                          label: const Text('Marquer Absent'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Prochain client - Dépôt
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Prochain client - Dépôt',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('tickets')
                                .where('status', isEqualTo: 'en_attente')
                                .where('queueType', isEqualTo: 'depot')
                                .orderBy('createdAt')
                                .limit(1)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                debugPrint('Firestore error (prochain dépôt): ${snapshot.error}');
                                return Column(
                                  children: [
                                    const Icon(Icons.error, color: Colors.red, size: 40),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Erreur Firestore :\n${snapshot.error}\nIl manque probablement un index.\nMerci de contacter l\'administrateur.',
                                      style: const TextStyle(color: Colors.red, fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                );
                              }
                              if (!snapshot.hasData) {
                                return const CircularProgressIndicator();
                              }
                              if (snapshot.data!.docs.isEmpty) {
                                return const Text(
                                  'Aucun client en attente (dépôt)',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                );
                              }
                              final doc = snapshot.data!.docs.first;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ticket #${doc['numero']}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: ConstantesCouleurs.orange,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Service: Dépôt'),
                                  const SizedBox(height: 16),
                                  // Stats rapides dépôt
                                  Row(
                                    children: [
                                      StreamBuilder<int>(
                                        stream: Provider.of<FirestoreService>(context, listen: false)
                                            .nombreEnAttenteStream(queueType: 'depot'),
                                        builder: (context, snap) {
                                          final n = snap.data ?? 0;
                                          return Text('En attente: $n');
                                        },
                                      ),
                                      const SizedBox(width: 16),
                                      StreamBuilder<Duration>(
                                        stream: Provider.of<FirestoreService>(context, listen: false)
                                            .tempsAttenteEstimeStream(queueType: 'depot'),
                                        builder: (context, snap) {
                                          final d = snap.data ?? Duration.zero;
                                          return Text('ETA: ~${formatDuration(d)}');
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isLoading ? null : () => _appellerProchainClient(queueType: 'depot'),
                                      icon: const Icon(Icons.campaign),
                                      label: const Text('Appeler le prochain'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ConstantesCouleurs.orange,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Prochain client - Retrait
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Prochain client - Retrait',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('tickets')
                                .where('status', isEqualTo: 'en_attente')
                                .where('queueType', isEqualTo: 'retrait')
                                .orderBy('createdAt')
                                .limit(1)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                debugPrint('Firestore error (prochain retrait): ${snapshot.error}');
                                return Column(
                                  children: [
                                    const Icon(Icons.error, color: Colors.red, size: 40),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Erreur Firestore :\n${snapshot.error}\nIl manque probablement un index.\nMerci de contacter l\'administrateur.',
                                      style: const TextStyle(color: Colors.red, fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                );
                              }
                              if (!snapshot.hasData) {
                                return const CircularProgressIndicator();
                              }
                              if (snapshot.data!.docs.isEmpty) {
                                return const Text(
                                  'Aucun client en attente (retrait)',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                );
                              }
                              final doc = snapshot.data!.docs.first;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ticket #${doc['numero']}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: ConstantesCouleurs.orange,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Service: Retrait'),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      StreamBuilder<int>(
                                        stream: Provider.of<FirestoreService>(context, listen: false)
                                            .nombreEnAttenteStream(queueType: 'retrait'),
                                        builder: (context, snap) {
                                          final n = snap.data ?? 0;
                                          return Text('En attente: $n');
                                        },
                                      ),
                                      const SizedBox(width: 16),
                                      StreamBuilder<Duration>(
                                        stream: Provider.of<FirestoreService>(context, listen: false)
                                            .tempsAttenteEstimeStream(queueType: 'retrait'),
                                        builder: (context, snap) {
                                          final d = snap.data ?? Duration.zero;
                                          return Text('ETA: ~${formatDuration(d)}');
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isLoading ? null : () => _appellerProchainClient(queueType: 'retrait'),
                                      icon: const Icon(Icons.campaign),
                                      label: const Text('Appeler le prochain'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ConstantesCouleurs.orange,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  

                ],
              ),
            ),
    ),
    );
  }

  Widget _buildHeaderResumeDuJour() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Stats rapides du jour',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                if (_isLoadingResume)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  IconButton(
                    onPressed: _rafraichirResume,
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Rafraîchir',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _smallStat(Icons.check_circle, 'Traités', _totalTraites, Colors.green),
                _smallStat(Icons.block, 'Absents', _totalAbsents, Colors.red),
                _smallStat(Icons.cancel, 'Annulés', _totalAnnules, Colors.grey),
              ],
            ),
          ],
        ),
      ),
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
