// pages/client/file_en_cours.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl/services/firestore_service.dart';
import 'package:fl/utils/constantes_couleurs.dart';

import 'package:fl/services/notification_service.dart';
import 'package:fl/utils/constantes_couleurs.dart';
import 'package:fl/widgets/barre_navigation.dart';
import 'package:fl/services/auth_service.dart';

class FileEnCoursPage extends StatefulWidget {
  const FileEnCoursPage({Key? key}) : super(key: key);

  @override
  State<FileEnCoursPage> createState() => _FileEnCoursPageState();
}

class _FileEnCoursPageState extends State<FileEnCoursPage> {

  int? _monNumero;
  String _statut = 'En attente';
  Duration _estimation = Duration.zero;

  @override
  void initState() {
    super.initState();
    final notif = Provider.of<NotificationService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    // Récupération du dernier ticket utilisateur (à implémenter selon votre auth)
    // firestore.ticketDeLUtilisateur().then((ticket) {
    //   setState(() {
    //     _monNumero = ticket.numero;
    //   });
    // });
    // WebSocket supprimé : ici on pourrait écouter Firestore pour les updates en temps réel si besoin.
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.currentUser?.role == 'agent') {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/tableau_bord_agent'));
      return const SizedBox.shrink();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma place en file'),
        backgroundColor: ConstantesCouleurs.orange,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: BarreNavigation(),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Text(
              _monNumero != null ? 'Mon numéro : $_monNumero' : 'Aucun ticket en cours',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: ConstantesCouleurs.orange,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              color: ConstantesCouleurs.orange.withOpacity(0.07),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      'Statut : $_statut',
                      style: const TextStyle(fontSize: 22, color: ConstantesCouleurs.orange, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Estimation : ${_estimation.inMinutes} min',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
