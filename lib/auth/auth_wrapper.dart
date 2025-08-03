import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl/pages/connexion_page.dart';
import 'package:fl/pages/agent/tableau_bord_agent.dart';
import 'package:fl/pages/client/accueil.dart';
import 'package:fl/services/auth_service_v2.dart';


class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // On utilise un Consumer pour écouter les changements de l'AuthService.
    // C'est la méthode la plus fiable pour reconstruire l'UI lors d'un changement d'état.
    return Consumer<AuthServiceV2>(
      builder: (context, authService, _) {
        print('AuthWrapper: 🔄 Reconstruction - Initializing: ${authService.isInitializing}, User: ${authService.currentUser?.email ?? "null"}');

        // Timeout pour éviter de rester bloqué en mode initializing
        if (authService.isInitializing) {
          // Après 3 secondes, forcer l'affichage de la page de connexion
          Future.delayed(const Duration(seconds: 3), () {
            if (authService.isInitializing && authService.currentUser == null) {
              print('AuthWrapper: ⚠️ Timeout initialisation - Force connexion page');
              // Cette ligne va forcer une reconstruction
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/connexion', (route) => false);
              }
            }
          });
          
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initialisation...'),
                ],
              ),
            ),
          );
        }

        final user = authService.currentUser;
        print('AuthWrapper: 👤 Utilisateur: ${user?.email ?? "null"}, Rôle: ${user?.role ?? "null"}');

        if (user == null) {
          print('AuthWrapper: ❌ Aucun utilisateur connecté -> Page de connexion');
          return const ConnexionPage();
        }

        // Utilisateur connecté -> redirection selon le rôle
        if (user.role == 'agent') {
          print('AuthWrapper: 👨‍💼 Utilisateur agent détecté -> Tableau de bord');
          return const TableauBordAgentPage();
        } else {
          print('AuthWrapper: 👤 Utilisateur client détecté -> Accueil');
          return const AccueilPage();
        }
      },
    );
  }
}
