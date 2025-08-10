import 'package:fast_tmb/services/horaires_service.dart';

/// Utilitaire pour initialiser les horaires par défaut si nécessaire
class HorairesInit {
  static final HorairesService _horairesService = HorairesService();

  /// Initialise les horaires par défaut si ils n'existent pas encore
  static Future<void> initializeDefaultHoraires() async {
    try {
      // Vérifier si les horaires existent déjà
      final horaires = await _horairesService.getHoraires();
      
      // Si les horaires existent déjà, ne rien faire
      if (horaires.id != 'default') {
        print('Horaires déjà configurés');
        return;
      }

      print('Initialisation des horaires par défaut...');
      
      // Les horaires par défaut sont automatiquement créés par getHoraires()
      // si ils n'existent pas, donc pas besoin de faire quoi que ce soit
      
      print('Horaires par défaut initialisés avec succès');
    } catch (e) {
      print('Erreur lors de l\'initialisation des horaires: $e');
      // En cas d'erreur, l'application continuera avec les horaires codés en dur
    }
  }

  /// Affiche les horaires actuels (pour debug)
  static Future<void> printCurrentHoraires() async {
    try {
      final horaires = await _horairesService.getHoraires();
      final displayText = await _horairesService.getHorairesDisplayText();
      
      print('=== HORAIRES ACTUELS ===');
      print('ID: ${horaires.id}');
      print('Dernière mise à jour: ${horaires.lastUpdated}');
      print('Mis à jour par: ${horaires.updatedBy}');
      print('Affichage: $displayText');
      print('========================');
    } catch (e) {
      print('Erreur lors de l\'affichage des horaires: $e');
    }
  }
}
