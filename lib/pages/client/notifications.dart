// pages/client/notifications.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fast_tmb/services/firestore_service.dart';
import 'package:fast_tmb/utils/constantes_couleurs.dart';
import 'package:flutter/material.dart';
import 'package:fast_tmb/widgets/barre_navigation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fast_tmb/widgets/role_guard.dart';
import 'package:fast_tmb/services/notification_service.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    return RoleGuard(
      allowedRoles: const ['client'],
      child: Scaffold(
        appBar: AppBar(
          title: StreamBuilder<QuerySnapshot>(
            stream: firestoreService.getNotificationsStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Text('Notifications');
              }
              final unreadCount = snapshot.data!.docs
                  .where((doc) => !(((doc.data() as Map<String, dynamic>)['read']) ?? false))
                  .length;
              return Row(
                children: [
                  const Text('Notifications'),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          backgroundColor: ConstantesCouleurs.orange,
          actions: [
            IconButton(
              icon: const Icon(Icons.mark_email_read),
              onPressed: () => _marquerToutesLues(context, firestoreService),
              tooltip: 'Marquer toutes comme lues',
            ),
          ],
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
                final notificationDoc = notifications[index];
                final notification = notificationDoc.data() as Map<String, dynamic>;
                final timestamp = notification['timestamp'] as Timestamp?;
                final date = timestamp?.toDate();
                final formattedDate = date != null
                    ? DateFormat('dd/MM/yyyy à HH:mm').format(date)
                    : 'Date inconnue';
                final isRead = notification['read'] ?? false;
                final notificationType = notification['data']?['type'] as String? ?? 'general';

                return Card(
                  elevation: isRead ? 1 : 3,
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: isRead ? Colors.grey[50] : Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isRead ? Colors.grey[300] : _getNotificationColor(notificationType),
                      child: Icon(
                        _getNotificationIcon(notificationType),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      notification['title'] ?? 'Notification',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        color: isRead ? Colors.grey[600] : Colors.black,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification['body'] ?? '...',
                          style: TextStyle(
                            color: isRead ? Colors.grey[500] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    trailing: !isRead
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: ConstantesCouleurs.orange,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                    onTap: () {
                      if (!isRead) {
                        firestoreService.marquerNotificationLue(notificationDoc.id);
                      }
                      _handleNotificationTap(context, notification);
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'ticket_called':
        return Colors.green;
      case 'queue_update':
        return ConstantesCouleurs.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'ticket_called':
        return Icons.campaign;
      case 'queue_update':
        return Icons.update;
      default:
        return Icons.notifications;
    }
  }

  void _handleNotificationTap(BuildContext context, Map<String, dynamic> notification) {
    final title = notification['title'] as String? ?? 'Notification';
    final body = notification['body'] as String? ?? '';
    final data = notification['data'] as Map<String, dynamic>?;
    // Ouvre toujours en bottom sheet et laisse NotificationService gérer l'action "Ouvrir"
    NotificationService().openNotificationBottomSheet(
      title: title,
      body: body,
      data: data,
    );
  }

  // Plus de boîte de dialogue modale; tout passe par un bottom sheet via NotificationService

  void _marquerToutesLues(BuildContext context, FirestoreService firestoreService) async {
    try {
      final notifications = await firestoreService.getNotificationsStream().first;
      for (final doc in notifications.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (!(data['read'] ?? false)) {
          await firestoreService.marquerNotificationLue(doc.id);
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les notifications ont été marquées comme lues'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
