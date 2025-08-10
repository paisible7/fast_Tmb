import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fast_tmb/services/auth_service_v2.dart';

/// RoleGuard
/// Utilisation: Encapsuler n'importe quelle page destinées à certains rôles
/// RoleGuard(allowedRoles: const ['client'], child: Scaffold(...))
class RoleGuard extends StatelessWidget {
  final List<String> allowedRoles;
  final Widget child;
  final Widget? fallback;

  const RoleGuard({Key? key, required this.allowedRoles, required this.child, this.fallback}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthServiceV2>(context, listen: true);
    final role = auth.currentUser?.role;

    if (role == null || role == 'unknown') {
      // En attente de résolution du profil
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!allowedRoles.contains(role)) {
      // Redirection douce vers la page appropriée selon le rôle courant
      Future.microtask(() {
        if (!context.mounted) return;
        switch (role) {
          case 'superagent':
            Navigator.pushNamedAndRemoveUntil(context, '/statistiques_superagent', (r) => false);
            break;
          case 'agent':
            Navigator.pushNamedAndRemoveUntil(context, '/tableau_bord_agent', (r) => false);
            break;
          default:
            Navigator.pushNamedAndRemoveUntil(context, '/accueil', (r) => false);
        }
      });
      return fallback ?? const SizedBox.shrink();
    }

    return child;
  }
}
