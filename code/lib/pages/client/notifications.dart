// pages/client/notifications.dart
import 'package:flutter/material.dart';
import 'package:fast_tmb/widgets/barre_navigation.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      bottomNavigationBar: BarreNavigation(),
      body: const Center(
        child: Text(
          'Aucune notification pour le moment',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
