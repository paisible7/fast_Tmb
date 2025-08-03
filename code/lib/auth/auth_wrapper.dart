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
        print('AuthWrapper: Reconstruction du widget - Initializing: ${authService.isInitializing}');

        if (authService.isInitializing) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = authService.currentUser;
        print('AuthWrapper: Utilisateur: ${user?.email ?? "null"}, Rôle: ${user?.role ?? "null"}');

        if (user == null) {
          print('AuthWrapper: Aucun utilisateur connecté -> Page de connexion');
          return const ConnexionPage();
        }

        // Utilisateur connecté -> redirection selon le rôle
        if (user.role == 'agent') {
          print('AuthWrapper: Utilisateur agent détecté -> Tableau de bord');
          return const TableauBordAgentPage();
        } else {
          print('AuthWrapper: Utilisateur client détecté -> Accueil');
          return const AccueilPage();
        }
      },
    );
  }
}
