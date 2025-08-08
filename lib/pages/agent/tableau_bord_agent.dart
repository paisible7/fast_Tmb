// pages/agent/tableau_bord_agent.dart
import 'package:fast_tmb/services/auth_service_v2.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:fast_tmb/widgets/barre_navigation.dart';
import 'package:fast_tmb/utils/constantes_couleurs.dart';
import 'package:fast_tmb/services/firestore_service.dart';

import '../connexion_page.dart';

class TableauBordAgentPage extends StatefulWidget {
  const TableauBordAgentPage({Key? key}) : super(key: key);

  @override
  State<TableauBordAgentPage> createState() => _TableauBordAgentPageState();
}

class _TableauBordAgentPageState extends State<TableauBordAgentPage> {
  bool _isLoading = false;

  // Méthode pour appeler le prochain client via FirestoreService
  Future<void> _appellerProchainClient() async {
    setState(() => _isLoading = true);
    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.appelerProchainClient();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client appelé avec succès'), backgroundColor: Colors.green),
      );
    } catch (e) {
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
      await firestoreService.marquerClientAbsent();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client marqué comme absent'), backgroundColor: Colors.orange),
      );
    } catch (e) {
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
      await firestoreService.terminerServiceClient();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service terminé pour le client'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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

    if (authService.currentUser?.role != 'agent') {
      Future.microtask(() {
        Navigator.pushReplacementNamed(context, '/accueil');
      });
      return const SizedBox.shrink();
    }

    if (authService.currentUser?.role != 'agent') {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/accueil'));
      return const SizedBox.shrink();
    }
    final firestoreService = Provider.of<FirestoreService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord Agent'),
        backgroundColor: ConstantesCouleurs.orange,
        foregroundColor: Colors.white,
        // actions supprimées : pas de bouton déconnexion dans l'AppBar
        actions: [],
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
                            stream: FirebaseFirestore.instance
                                .collection('tickets')
                                .where('status', isEqualTo: 'en_cours')
                                .where('agentId', isEqualTo: authService.currentUser?.uid)
                                .orderBy('createdAt')
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
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
                  
                  // Prochain client
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Prochain client',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('tickets')
                                .where('status', isEqualTo: 'en_attente')
                                .orderBy('createdAt')
                                .limit(1)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
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
                                  'Aucun client en attente',
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
                                  Text('Service: ${(doc.data() as Map<String, dynamic>)['service'] ?? 'Non spécifié'}'),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isLoading ? null : _appellerProchainClient,
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
                  const SizedBox(height: 24),
                  

                ],
              ),
            ),
    );
  }
}
