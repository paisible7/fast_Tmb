// pages/client/parametres.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fl/services/auth_service_v2.dart';
import 'package:fl/widgets/barre_navigation.dart';
import 'package:fl/utils/constantes_couleurs.dart';

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
    return Scaffold(
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
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            title: const Text('Déconnexion'),
            onTap: () {
              _showLogoutConfirmationDialog();
            },
          ),
        ],
      ),
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
