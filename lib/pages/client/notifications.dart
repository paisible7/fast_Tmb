// pages/client/notifications.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl/services/firestore_service.dart';
import 'package:fl/utils/constantes_couleurs.dart';
import 'package:flutter/material.dart';
import 'package:fl/widgets/barre_navigation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: ConstantesCouleurs.orange,
      ),
      bottomNavigationBar: const BarreNavigation(),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Aucune notification pour le moment.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index].data() as Map<String, dynamic>;
              final timestamp = notification['timestamp'] as Timestamp?;
              final date = timestamp?.toDate();
              final formattedDate = date != null
                  ? DateFormat('dd/MM/yyyy à HH:mm').format(date)
                  : 'Date inconnue';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.notifications, color: ConstantesCouleurs.orange),
                  title: Text(
                    notification['title'] ?? 'Notification',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(notification['body'] ?? '...'),
                  trailing: Text(
                    formattedDate,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
