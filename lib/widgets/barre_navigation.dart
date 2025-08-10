// widgets/barre_navigation.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fast_tmb/services/auth_service_v2.dart';
import 'package:fast_tmb/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:fast_tmb/utils/constantes_couleurs.dart';
import 'package:provider/provider.dart';

// import '../services/auth_service.dart';

class BarreNavigation extends StatelessWidget {
  const BarreNavigation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthServiceV2>(context, listen: false);
    final userRole = authService.currentUser?.role ?? 'client';

    // Définir les routes pour chaque rôle
    final Map<String, int> agentRoutes = const {
      '/tableau_bord_agent': 0,
      '/notifications_agent': 1,
      '/parametres': 2,
    };
    final Map<String, int> clientRoutes = const {
      '/accueil': 0,
      // TODO(QR): Route scan désactivée -> '/scan_qr'
      '/notifications': 1,
      '/parametres': 2,
    };

    // Déterminer l'index actuel en fonction de la route
    final String currentRoute = ModalRoute.of(context)?.settings.name ?? '/accueil';
    int currentIndex = 0;
    List<BottomNavigationBarItem> items = [];

    if (userRole == 'superagent') {
      final Map<String, int> superAgentRoutes = const {
        '/statistiques_superagent': 0,
        '/admin_services': 1,
        '/admin_agents': 2,
        '/parametres': 3,
      };
      items = const [
        BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'Stats'),
        BottomNavigationBarItem(icon: Icon(Icons.home_repair_service_outlined), label: 'Services'),
        BottomNavigationBarItem(icon: Icon(Icons.group_outlined), label: 'Agents'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Param'),
      ];
      // Si la page a été poussée directement (sans nom de route), on considère l'onglet Stats comme sélectionné
      currentIndex = superAgentRoutes[currentRoute] ?? 0;
      return BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: ConstantesCouleurs.orange,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == currentIndex) return;
          final routeName = superAgentRoutes.keys.elementAt(index);
          Navigator.pushReplacementNamed(context, routeName);
        },
        items: items,
      );
    } else if (userRole == 'agent') {
      items = [
        const BottomNavigationBarItem(icon: Icon(Icons.work_history_outlined), label: 'En cours'),
        const BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: 'Notif'),
        const BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Param'),
      ];
      currentIndex = agentRoutes[currentRoute] ?? 0;
    } else {
      // Pour les clients, ajouter un badge de notification
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      items = [
        const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Accueil'),
        // TODO(QR): Item Scan désactivé
        // const BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Scan QR'),
        BottomNavigationBarItem(
          icon: StreamBuilder<QuerySnapshot>(
            stream: firestoreService.getNotificationsStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Icon(Icons.notifications_outlined);
              }
              final unreadCount = snapshot.data!.docs
                  .where((doc) => !(((doc.data() as Map<String, dynamic>)['read']) ?? false))
                  .length;
              return Stack(
                children: [
                  const Icon(Icons.notifications_outlined),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          label: 'Notif',
        ),
        const BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Param'),
      ];
      currentIndex = clientRoutes[currentRoute] ?? 0;
    }

    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: ConstantesCouleurs.orange,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        if (index == currentIndex) return; // Ne rien faire si on clique sur l'onglet actif

        String routeName;
        if (userRole == 'agent') {
          routeName = agentRoutes.keys.elementAt(index);
        } else {
          routeName = clientRoutes.keys.elementAt(index);
        }
        Navigator.pushReplacementNamed(context, routeName);
      },
      items: items,
    );
  }
}

