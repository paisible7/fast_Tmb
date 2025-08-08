// widgets/barre_navigation.dart
import 'package:fast_tmb/services/auth_service_v2.dart';
import 'package:flutter/material.dart';
import 'package:fast_tmb/utils/constantes_couleurs.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

class BarreNavigation extends StatelessWidget {
  const BarreNavigation({Key? key}) : super(key: key);

  static const _labelsAll = ['Accueil', 'En cours', 'Scan', 'Notif', 'Param'];
  static const _iconsAll = [
    Icons.home,
    Icons.format_list_numbered,
    Icons.qr_code_scanner,
    Icons.notifications,
    Icons.settings,
  ];
  static const _routesAll = [
    '/accueil',
    '/file_en_cours',
    '/scan_qr',
    '/notifications',
    '/parametres',
  ];

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthServiceV2>(context, listen: false);
    final userRole = authService.currentUser?.role ?? 'client';

    // Définir les routes pour chaque rôle
    final Map<String, int> agentRoutes = {
      '/tableau_bord_agent': 0,
      '/notifications': 1,
      '/parametres': 2,
    };
    final Map<String, int> clientRoutes = {
      '/': 0,
      '/scan_qr': 1,
      '/notifications': 2,
      '/parametres': 3,
    };

    // Déterminer l'index actuel en fonction de la route
    final String currentRoute = ModalRoute.of(context)!.settings.name ?? '/';
    int currentIndex = 0;
    List<BottomNavigationBarItem> items = [];

    if (userRole == 'agent') {
      items = [
        const BottomNavigationBarItem(icon: Icon(Icons.work_history_outlined), label: 'En cours'),
        const BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: 'Notif'),
        const BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Param'),
      ];
      currentIndex = agentRoutes[currentRoute] ?? 0;
    } else {
      items = [
        const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Accueil'),
        const BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Scan QR'),
        const BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: 'Notif'),
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

