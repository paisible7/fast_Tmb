// pages/client/accueil.dart
import 'package:fast_tmb/services/auth_service_v2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fast_tmb/services/firestore_service.dart';
import 'package:fast_tmb/widgets/bouton_principal.dart';
import 'package:fast_tmb/widgets/barre_navigation.dart';
import 'package:fast_tmb/utils/constantes_couleurs.dart';

class AccueilPage extends StatelessWidget {
  const AccueilPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final auth = Provider.of<AuthServiceV2>(context, listen: false);
    if (auth.currentUser?.role == 'agent') {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/tableau_bord_agent'));
      return const SizedBox.shrink();
    }

    return Scaffold(
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
                    const Spacer(),
                    const Text(
                        'Veuillez patienter, un agent va bientôt vous appeler.',
                        textAlign: TextAlign.center),
                  ],
                );
              } else {
                // L'utilisateur n'a pas de ticket actif
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Bienvenue !',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text('Vous n\'avez aucun ticket en cours.',
                        style: TextStyle(fontSize: 18)),
                    const Spacer(),
                    BoutonPrincipal(
                      text: 'Prendre un ticket',
                      onPressed: () async {
                        try {
                          await firestore.ajouterTicket();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ticket ajouté avec succès !'),
                              backgroundColor: ConstantesCouleurs.orange,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur : $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }
}

