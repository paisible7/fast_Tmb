// pages/client/parametres.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fast_tmb/services/auth_service_v2.dart';
import 'package:fast_tmb/widgets/barre_navigation.dart';
import 'package:fast_tmb/utils/constantes_couleurs.dart';
import 'package:fast_tmb/widgets/role_guard.dart';
import 'package:fast_tmb/pages/client/satisfaction_page.dart';
import 'package:fast_tmb/services/notification_service.dart';

import '../connexion_page.dart';

class ParametresPage extends StatefulWidget {
  const ParametresPage({Key? key}) : super(key: key);

  @override
  State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthServiceV2>(context, listen: false);

    if(authService.currentUser == null){
      Future.microtask(() => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => const ConnexionPage()),
            (route) => false,
      ));
      return const SizedBox.shrink();
    }
    return RoleGuard(
      allowedRoles: const ['client', 'agent', 'superagent'],
      child: Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      bottomNavigationBar: BarreNavigation(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Notifications push'),
            value: _notificationsEnabled,
            activeColor: ConstantesCouleurs.orange,
            onChanged: (val) async {
              setState(() => _notificationsEnabled = val);
              if (val) {
                await FirebaseMessaging.instance.requestPermission();
              } else {
                await FirebaseMessaging.instance.deleteToken();
              }
            },
          ),
          const Divider(),
          // Option d'évaluation pour les clients uniquement
          if (authService.currentUser?.role == 'client') ...[
            ListTile(
              leading: const Icon(Icons.star_rate, color: ConstantesCouleurs.orange),
              title: const Text('Évaluer mon dernier service'),
              subtitle: const Text('Donnez votre avis sur votre dernière expérience'),
              onTap: () => _showEvaluationOption(context),
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            title: const Text('Déconnexion'),
            onTap: () {
              _showLogoutConfirmationDialog();
            },
          ),
        ],
      ),
    ));
  }

  void _showEvaluationOption(BuildContext context) async {
    try {
      // Chercher le dernier ticket "servi" de l'utilisateur
      final user = Provider.of<AuthServiceV2>(context, listen: false).currentUser;
      if (user == null) return;
      
      final snap = await FirebaseFirestore.instance
          .collection('tickets')
          .where('creatorId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'servi')
          .orderBy('treatedAt', descending: true)
          .limit(1)
          .get();
      
      if (snap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun service terminé à évaluer'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      final Map<String, dynamic> ticketData = snap.docs.first.data();
      final ticketId = snap.docs.first.id;
      
      // Vérifier si ce ticket a déjà été évalué
      if (ticketData['satisfaction'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ce service a déjà été évalué'),
            backgroundColor: Colors.blue,
          ),
        );
        return;
      }
      
      // Ouvrir l'évaluation en Bottom Sheet
      final numero = ticketData['numero']?.toString() ?? 'N/A';
      final queueType = ticketData['queueType'] ?? 'depot';
      NotificationService().openEvaluationBottomSheet(
        ticketId: ticketId,
        numero: numero,
        queueType: queueType,
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la recherche du service: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showLogoutConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Déconnexion',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Annuler',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Confirmer', style: TextStyle(fontSize: 16, color: Colors.white)),
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Ferme la dialog
                await Provider.of<AuthServiceV2>(context, listen: false).signOut();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const ConnexionPage()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
