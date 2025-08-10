// pages/client/file_en_cours.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fast_tmb/services/auth_service_v2.dart';
import 'package:fast_tmb/services/firestore_service.dart';
import 'package:fast_tmb/widgets/barre_navigation.dart';
import 'package:fast_tmb/utils/constantes_couleurs.dart';
import 'package:fast_tmb/utils/time_format.dart';
import 'package:fast_tmb/widgets/role_guard.dart';

class FileEnCoursPage extends StatefulWidget {
  const FileEnCoursPage({Key? key}) : super(key: key);

  @override
  State<FileEnCoursPage> createState() => _FileEnCoursPageState();
}

class _FileEnCoursPageState extends State<FileEnCoursPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final authService = Provider.of<AuthServiceV2>(context, listen: false);

    if (authService.currentUser == null) {
      return const Center(child: Text('Veuillez vous connecter.'));
    }

    return RoleGuard(
      allowedRoles: const ['client'],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('File d\'Attente'),
          backgroundColor: ConstantesCouleurs.orange,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(icon: Icon(Icons.person), text: 'Ma Position'),
              Tab(icon: Icon(Icons.queue), text: 'File Complète'),
            ],
          ),
        ),
        bottomNavigationBar: const BarreNavigation(),
        body: StreamBuilder<DocumentSnapshot?>(
          stream: firestoreService.monTicketStream(),
          builder: (context, snapshotTicket) {
            if (snapshotTicket.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final hasTicket = snapshotTicket.hasData && snapshotTicket.data != null;
            
            if (!hasTicket) {
              return _buildNoTicketUI(context);
            }

            final ticket = snapshotTicket.data!;
            final ticketData = ticket.data() as Map<String, dynamic>;
            final ticketId = ticket.id;
            final status = (ticketData['status'] as String?) ?? 'en_attente';
            final queueType = (ticketData['queueType'] as String?) ?? 'depot';

            return TabBarView(
              controller: _tabController,
              children: [
                // Onglet 1: Ma Position
                _buildMyPositionTab(context, firestoreService, ticket, ticketData, ticketId, status, queueType),
                // Onglet 2: File Complète
                _buildQueueTab(context, firestoreService, queueType, ticketId),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMyPositionTab(BuildContext context, FirestoreService firestoreService, 
      DocumentSnapshot ticket, Map<String, dynamic> ticketData, String ticketId, String status, String queueType) {
    
    // Position en temps réel dans la file spécifique
    final positionStream = FirebaseFirestore.instance
        .collection('tickets')
        .where('status', isEqualTo: 'en_attente')
        .where('queueType', isEqualTo: queueType)
        .orderBy('createdAt')
        .snapshots()
        .map((qs) {
      if (status == 'en_cours') return 0;
      final index = qs.docs.indexWhere((d) => d.id == ticketId);
      return index == -1 ? 0 : index + 1;
    });

    return StreamBuilder<int>(
      stream: positionStream,
      builder: (context, posSnap) {
        final position = posSnap.data ?? 0;
        return StreamBuilder<Duration>(
          stream: firestoreService.tempsAttenteEstimeStream(queueType: queueType),
          builder: (context, etaSnap) {
            final eta = etaSnap.data ?? Duration(minutes: (position > 0 ? (position - 1) * 5 : 0));
            return _buildTicketUI(context, ticketData, position, eta, queueType: queueType, onCancel: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Annuler le ticket ?'),
                  content: const Text('Cette action est définitive.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui, annuler')),
                  ],
                ),
              );
              if (confirm != true) return;
              try {
                await firestoreService.annulerMonTicketActif();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ticket annulé'), backgroundColor: Colors.redAccent),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
                  );
                }
              }
            });
          },
        );
      },
    );
  }

  Widget _buildQueueTab(BuildContext context, FirestoreService firestoreService, String queueType, String myTicketId) {
    return Column(
      children: [
        // En-tête avec informations de la file
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ConstantesCouleurs.orange.withValues(alpha: 0.1),
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            children: [
              Text(
                'File ${queueType == 'depot' ? 'Dépôt' : 'Retrait'}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ConstantesCouleurs.orange,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<Duration>(
                stream: firestoreService.tempsAttenteEstimeStream(queueType: queueType),
                builder: (context, etaSnap) {
                  final eta = etaSnap.data ?? const Duration(minutes: 0);
                  return Text(
                    'Temps d\'attente moyen: ${formatDuration(eta)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  );
                },
              ),
            ],
          ),
        ),
        // Liste des tickets en attente
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tickets')
                .where('status', isEqualTo: 'en_attente')
                .where('queueType', isEqualTo: queueType)
                .orderBy('createdAt')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.queue, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Aucun ticket en attente',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final tickets = snapshot.data!.docs;
              
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tickets.length,
                itemBuilder: (context, index) {
                  final ticketDoc = tickets[index];
                  final ticketData = ticketDoc.data() as Map<String, dynamic>;
                  final isMyTicket = ticketDoc.id == myTicketId;
                  final numero = ticketData['numero']?.toString() ?? '-';
                  final createdAt = ticketData['createdAt'] as Timestamp?;
                  final clientName = ticketData['clientName'] as String?;
                  final clientFirstName = ticketData['clientFirstName'] as String?;
                  final isGuest = ticketData['guest'] == true;
                  
                  String displayName = 'Client';
                  if (isGuest && clientName != null && clientFirstName != null) {
                    displayName = '$clientFirstName ${clientName.substring(0, 1).toUpperCase()}.';
                  } else if (isMyTicket) {
                    displayName = 'Vous';
                  }
                  
                  return Card(
                    elevation: isMyTicket ? 4 : 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isMyTicket 
                          ? BorderSide(color: ConstantesCouleurs.orange, width: 2)
                          : BorderSide.none,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: isMyTicket 
                            ? ConstantesCouleurs.orange 
                            : Colors.grey.shade300,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isMyTicket ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            'Ticket #$numero',
                            style: TextStyle(
                              fontWeight: isMyTicket ? FontWeight.bold : FontWeight.normal,
                              color: isMyTicket ? ConstantesCouleurs.orange : null,
                            ),
                          ),
                          if (isMyTicket) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: ConstantesCouleurs.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'VOUS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName),
                          if (createdAt != null)
                            Text(
                              'Créé à ${createdAt.toDate().hour.toString().padLeft(2, '0')}:${createdAt.toDate().minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                      trailing: isGuest 
                          ? const Icon(Icons.smartphone_outlined, color: Colors.grey)
                          : const Icon(Icons.phone_android, color: Colors.green),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTicketUI(
    BuildContext context,
    Map<String, dynamic> ticketData,
    int position,
    Duration tempsAttente, {
    required String queueType,
    required Future<void> Function() onCancel,
  }) {
    final status = ticketData['status'] ?? 'Indisponible';
    final numero = ticketData['numero']?.toString() ?? '-';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Votre numéro de ticket', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(numero, style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold, color: ConstantesCouleurs.orange)),
            const SizedBox(height: 8),
            Text('File: ${queueType == 'depot' ? 'Dépôt' : 'Retrait'}'),
            const SizedBox(height: 32),
            _buildInfoCard(context, 'Position dans la file', position > 0 ? '$position' : 'À vous !'),
            const SizedBox(height: 16),
            _buildInfoCard(context, 'Temps d\'attente estimé', position > 0 ? '~${formatDuration(tempsAttente)}' : 'Prêt'),
            const SizedBox(height: 16),
            _buildInfoCard(context, 'Statut', _formatStatus(status), icon: _getIconForStatus(status)),
            const SizedBox(height: 24),
            if (status == 'en_attente')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.cancel),
                  label: const Text('Annuler mon ticket'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: onCancel,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String value, {IconData? icon}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: icon != null ? Icon(icon, color: ConstantesCouleurs.orange) : null,
        title: Text(title, style: const TextStyle(color: Colors.grey)),
        trailing: Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildNoTicketUI(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.confirmation_number_outlined, size: 100, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            'Vous n\'avez pas de ticket actif.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ConstantesCouleurs.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            onPressed: () {
              // Naviguer vers la page d'accueil pour prendre un ticket
              Navigator.pushNamedAndRemoveUntil(context, '/accueil', (route) => false);
            },
            child: const Text('Prendre un ticket', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'en_attente':
        return 'En attente';
      case 'en_cours':
        return 'En cours de traitement';
      default:
        return 'Terminé';
    }
  }

  IconData _getIconForStatus(String status) {
    switch (status) {
      case 'en_attente':
        return Icons.hourglass_top;
      case 'en_cours':
        return Icons.person_pin;
      default:
        return Icons.check_circle;
    }
  }
}
