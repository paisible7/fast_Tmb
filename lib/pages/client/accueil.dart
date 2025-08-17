// pages/client/accueil.dart
import 'package:fast_tmb/services/auth_service_v2.dart';
import 'package:flutter/material.dart';
import 'package:fast_tmb/utils/time_format.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fast_tmb/services/firestore_service.dart';
import 'package:fast_tmb/widgets/bouton_principal.dart';
import 'package:fast_tmb/widgets/barre_navigation.dart';
import 'package:fast_tmb/utils/constantes_couleurs.dart';
import 'package:fast_tmb/widgets/role_guard.dart';
import 'package:fast_tmb/services/horaires_service.dart';

import '../connexion_page.dart';

class AccueilPage extends StatefulWidget {
  const AccueilPage({Key? key}) : super(key: key);

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  bool _isProcessing = false;

  String _getServiceLabel(String? queueType) {
    switch (queueType) {
      case 'depot':
        return 'Dépôt';
      case 'retrait':
        return 'Retrait';
      default:
        return 'Non spécifié';
    }
  }

  @override
  void initState() {
    super.initState();
    // Annulation automatique si service fermé, dès l'ouverture de l'accueil
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final cancelled = await firestoreService.annulerMonTicketSiServiceFerme();
      if (!mounted) return;
      if (cancelled) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Service fermé: votre ticket a été annulé automatiquement.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final auth = Provider.of<AuthServiceV2>(context, listen: false);


    if (auth.currentUser == null) {
      Future.microtask(() {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ConnexionPage()),
              (route) => false,
        );
      });
      return const SizedBox.shrink();
    }

    if (auth.currentUser?.role == 'agent') {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/tableau_bord_agent'));
      return const SizedBox.shrink();
    }

    return RoleGuard(
      allowedRoles: const ['client'],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Accueil'),
          backgroundColor: ConstantesCouleurs.orange,
          foregroundColor: Colors.white,
        ),
        bottomNavigationBar: BarreNavigation(),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: StreamBuilder<DocumentSnapshot?>(
              stream: firestore.monTicketStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                final ticket = snapshot.data;

                if (ticket != null && ticket.exists) {
                // L'utilisateur a un ticket actif
                final data = ticket.data() as Map<String, dynamic>;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _BandeauHoraires(),
                    const SizedBox(height: 12),
                    const Text('Votre ticket en cours :',
                        style: TextStyle(fontSize: 22)),
                    const SizedBox(height: 20),
                    Text('Numéro ${data['numero']}',
                        style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: ConstantesCouleurs.orange)),
                    const SizedBox(height: 10),
                    Text('Statut : ${data['status']}',
                        style: const TextStyle(
                            fontSize: 20, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 8),
                    Text('Service: ${_getServiceLabel(data['queueType'])}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    StreamBuilder<Duration>(
                      stream: firestore.tempsAttenteEstimeStream(queueType: data['queueType']),
                      builder: (context, waitSnapshot) {
                        final waitTime = waitSnapshot.data ?? Duration.zero;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, color: Colors.blue.shade600),
                              const SizedBox(width: 8),
                              Text(
                                'Temps d\'attente estimé: ${formatDuration(waitTime)}',
                                style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    const Text(
                        'Veuillez patienter, un agent va bientôt vous appeler.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    if ((data['status'] as String?) == 'en_attente')
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
                          onPressed: () async {
                            try {
                              await firestore.annulerMonTicketActif();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ticket annulé'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erreur : $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                  ],
                );
              } else {
                // L'utilisateur n'a pas de ticket actif
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _BandeauHoraires(),
                    const SizedBox(height: 12),
                    const Text('Bienvenue !',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text('Vous n\'avez aucun ticket en cours.',
                        style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: _InfoFileCard(queueType: 'depot')),
                        const SizedBox(width: 12),
                        Expanded(child: _InfoFileCard(queueType: 'retrait')),
                      ],
                    ),
                    const Spacer(),
                    StreamBuilder(
                      stream: HorairesService().getHorairesStream(),
                      builder: (context, snapHoraire) {
                        final open = snapHoraire.hasData
                            ? (snapHoraire.data as dynamic).isOpenNow(DateTime.now())
                            : true; // par défaut on laisse actif pendant chargement
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BoutonPrincipal(
                              text: 'Prendre un ticket',
                              onPressed: open && !_isProcessing ? () { _prendreTicket(context); } : null,
                            ),
                            if (!open) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Service fermé actuellement. Veuillez consulter les horaires ci-dessus.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ]
                          ],
                        );
                      },
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ),
    ),
    );
  }

  Future<void> _prendreTicket(BuildContext context) async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    // Ouvre un sélecteur de service (dépôt / retrait)
    final queueType = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Choisir un service')),
            Divider(height: 1, color: Colors.grey.withValues(alpha: 0.5)),
            ListTile(
              leading: const Icon(Icons.south_west, color: ConstantesCouleurs.orange),
              title: const Text('Dépôt'),
              onTap: () => Navigator.pop(ctx, 'depot'),
            ),
            ListTile(
              leading: const Icon(Icons.north_east, color: ConstantesCouleurs.orange),
              title: const Text('Retrait'),
              onTap: () => Navigator.pop(ctx, 'retrait'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (queueType == null) return; // annulé
    try {
      if (!mounted) return;
      setState(() { _isProcessing = true; });
      await firestore.ajouterTicketAvecService(queueType);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket ajouté avec succès !'),
          backgroundColor: ConstantesCouleurs.orange,
        ),
      );
      // Redirige automatiquement vers la page "File en cours"
      Navigator.pushReplacementNamed(context, '/file_en_cours');
    } catch (e) {
      // Message clair lors du refus proche fermeture
      final message = e.toString().contains('Service bientôt fermé')
          ? e.toString()
          : 'Impossible de prendre un ticket pour le moment. Veuillez réessayer plus tard.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
      // Désactivation temporaire pour éviter les clics multiples
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      if (mounted) {
        setState(() { _isProcessing = false; });
      }
    }
  }
}

class _BandeauHoraires extends StatefulWidget {
  const _BandeauHoraires({Key? key}) : super(key: key);

  @override
  State<_BandeauHoraires> createState() => _BandeauHorairesState();
}

class _BandeauHorairesState extends State<_BandeauHoraires> {
  final HorairesService _horairesService = HorairesService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _horairesService.getHorairesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Chargement des horaires...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red),
            ),
            child: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Erreur de chargement des horaires', style: TextStyle(color: Colors.red)),
              ],
            ),
          );
        }

        final horaires = snapshot.data;
        if (horaires == null) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now();
        final open = horaires.isOpenNow(now);
        final color = open ? Colors.green.shade600 : Colors.red.shade600;

        return FutureBuilder<String>(
          future: _horairesService.getHorairesDisplayText(),
          builder: (context, textSnapshot) {
            final text = textSnapshot.data ?? (open ? 'Service ouvert' : 'Service fermé');
            
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color),
              ),
              child: Row(
                children: [
                  Icon(open ? Icons.access_time : Icons.lock_clock, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      textAlign: TextAlign.start,
                      text,
                      style: TextStyle(color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _InfoFileCard extends StatelessWidget {
  final String queueType; // 'depot' ou 'retrait'
  const _InfoFileCard({Key? key, required this.queueType}) : super(key: key);

  String get _label => queueType == 'depot' ? 'Dépôt' : 'Retrait';
  IconData get _icon => queueType == 'depot' ? Icons.south_west : Icons.north_east;

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, color: ConstantesCouleurs.orange),
                const SizedBox(width: 8),
                Text(_label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<int>(
              stream: firestore.nombreEnAttenteStream(queueType: queueType),
              builder: (context, snap) {
                final count = snap.data ?? 0;
                return Text('En attente: $count');
              },
            ),
            const SizedBox(height: 6),
            StreamBuilder<Duration>(
              stream: firestore.tempsAttenteEstimeStream(queueType: queueType),
              builder: (context, snap) {
                final d = snap.data ?? Duration.zero;
                return Text('Estimation: ~${formatDuration(d)}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

