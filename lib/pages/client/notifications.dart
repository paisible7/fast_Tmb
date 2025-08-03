// pages/client/notifications.dart
import 'package:fl/pages/connexion_page.dart';
import 'package:fl/services/auth_service_v2.dart';
import 'package:flutter/material.dart';
import 'package:fl/widgets/barre_navigation.dart';
import 'package:provider/provider.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthServiceV2>(context);
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
