// pages/client/file_en_cours.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl/services/auth_service_v2.dart';
import 'package:fl/services/firestore_service.dart';
import 'package:fl/widgets/barre_navigation.dart';
import 'package:fl/utils/constantes_couleurs.dart';

class FileEnCoursPage extends StatelessWidget {
  const FileEnCoursPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final authService = Provider.of<AuthServiceV2>(context, listen: false);

    if (authService.currentUser == null) {
      return const Center(child: Text('Veuillez vous connecter.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma Place dans la File'),
        backgroundColor: ConstantesCouleurs.bleuNuit,
        elevation: 0,
      ),
      bottomNavigationBar: const BarreNavigation(),
      body: StreamBuilder<DocumentSnapshot?>(
        stream: firestoreService.monTicketStream(),
        builder: (context, snapshotTicket) {
          if (snapshotTicket.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshotTicket.hasData || snapshotTicket.data == null) {
            return _buildNoTicketUI(context);
          }

          final ticket = snapshotTicket.data!;
          final ticketData = ticket.data() as Map<String, dynamic>;

          return StreamBuilder<int>(
            stream: firestoreService.maPositionEnTempsReelStream(ticket),
            builder: (context, snapshotPosition) {
              final position = snapshotPosition.data ?? 0;
              final tempsAttente = Duration(minutes: (position > 0 ? position -1 : 0) * 5); // 5 min par personne

              return _buildTicketUI(context, ticketData, position, tempsAttente);
            },
          );
        },
      ),
    );
  }

  Widget _buildTicketUI(BuildContext context, Map<String, dynamic> ticketData, int position, Duration tempsAttente) {
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
            const SizedBox(height: 40),
            _buildInfoCard(context, 'Position dans la file', position > 0 ? '$position' : 'À vous !'),
            const SizedBox(height: 16),
            _buildInfoCard(context, 'Temps d\'attente estimé', position > 0 ? '~${tempsAttente.inMinutes} minutes' : 'Prêt'),
            const SizedBox(height: 16),
            _buildInfoCard(context, 'Statut', _formatStatus(status), icon: _getIconForStatus(status)),
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
