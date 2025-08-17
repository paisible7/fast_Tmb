// pages/client/parametres.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fast_tmb/services/auth_service_v2.dart';
import 'package:fast_tmb/services/firestore_service.dart';
import 'package:fast_tmb/widgets/barre_navigation.dart';
import 'package:fast_tmb/utils/constantes_couleurs.dart';
import 'package:fast_tmb/widgets/role_guard.dart';

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
          if (authService.currentUser?.role != 'superagent')
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
    final fs = Provider.of<FirestoreService>(context, listen: false);
    int selected = 5;
    final controller = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Votre évaluation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(5, (i) {
                      final idx = i + 1;
                      return IconButton(
                        icon: Icon(
                          idx <= selected ? Icons.star : Icons.star_border,
                          color: ConstantesCouleurs.orange,
                        ),
                        onPressed: () {
                          setModalState(() {
                            selected = idx;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Commentaire (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      style: ElevatedButton.styleFrom(backgroundColor: ConstantesCouleurs.orange),
                      label: const Text('Envoyer'),
                      onPressed: () async {
                        try {
                          await fs.ajouterEvaluationService(score: selected, comment: controller.text);
                          if (mounted) Navigator.of(ctx).pop();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Merci pour votre évaluation !')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
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
