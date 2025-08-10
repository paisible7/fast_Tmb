# Paramétrage des Horaires Dynamique

## Vue d'ensemble

Le système de paramétrage des horaires dynamique permet aux superagents de configurer les horaires d'ouverture du service directement depuis l'application, sans avoir besoin de modifier le code.

## Fonctionnalités

### ✅ Implémenté

1. **Modèle de données flexible** (`models/horaires.dart`)
   - Support de plusieurs créneaux par jour
   - Configuration jour par jour
   - Horaires par défaut automatiques

2. **Service de gestion** (`services/horaires_service.dart`)
   - Lecture/écriture dans Firestore
   - Stream temps réel des horaires
   - Vérification des permissions (superagent uniquement)
   - Fallback sur horaires par défaut en cas d'erreur

3. **Interface d'administration** (`pages/superagent/horaires_admin_page.dart`)
   - Configuration visuelle des horaires
   - Ajout/suppression de créneaux
   - Activation/désactivation par jour
   - Sélecteur d'heure intuitif

4. **Intégration automatique**
   - Mise à jour de `FirestoreService` pour utiliser les horaires dynamiques
   - Mise à jour de `AccueilPage` pour affichage temps réel
   - Bouton d'accès dans le tableau de bord superagent

## Architecture

### Structure Firestore

```
/settings/horaires_ouverture
{
  "jours": {
    "lundi": {
      "ouvert": true,
      "creneaux": [
        {
          "startHour": 8,
          "startMinute": 0,
          "endHour": 15,
          "endMinute": 30
        }
      ]
    },
    "mardi": { ... },
    ...
  },
  "lastUpdated": "2025-01-10T08:00:00Z",
  "updatedBy": "superagent_uid"
}
```

### Flux de données

1. **Lecture** : `HorairesService.getHorairesStream()` → Stream temps réel
2. **Écriture** : `HorairesService.saveHoraires()` → Validation rôle + sauvegarde
3. **Vérification** : `Horaires.isOpenNow()` → Logique de vérification

### Sécurité

- ✅ Seuls les superagents peuvent modifier les horaires
- ✅ Vérification du rôle côté service
- ✅ Fallback automatique en cas d'erreur
- ✅ Validation des données avant sauvegarde

## Utilisation

### Pour les Superagents

1. Aller dans **Statistiques Superagent**
2. Cliquer sur le bouton **"Horaires"**
3. Configurer les horaires jour par jour :
   - Activer/désactiver un jour
   - Ajouter plusieurs créneaux par jour
   - Définir les heures de début/fin
4. Sauvegarder les modifications

### Pour les Développeurs

```dart
// Vérifier si ouvert maintenant
final horairesService = HorairesService();
final isOpen = await horairesService.isOpenNow();

// Écouter les changements d'horaires
StreamBuilder(
  stream: horairesService.getHorairesStream(),
  builder: (context, snapshot) {
    final horaires = snapshot.data;
    final isOpen = horaires?.isOpenNow(DateTime.now()) ?? false;
    // ...
  },
)

// Obtenir le texte d'affichage
final displayText = await horairesService.getHorairesDisplayText();
```

## Horaires par Défaut

Si aucun horaire n'est configuré, le système utilise automatiquement :

- **Lundi à Vendredi** : 08:00 - 15:30
- **Samedi** : 08:00 - 12:00  
- **Dimanche** : Fermé

## Migration

### Avant (horaires codés en dur)
```dart
bool _isWithinIssuanceHours(DateTime now) {
  // Code dur...
}
```

### Après (horaires dynamiques)
```dart
Future<bool> _isWithinIssuanceHours(DateTime now) async {
  final horairesService = HorairesService();
  final horaires = await horairesService.getHoraires();
  return horaires.isOpenNow(now);
}
```

## Tests

### Tests manuels à effectuer

1. **Configuration initiale**
   - [ ] Vérifier que les horaires par défaut s'affichent correctement
   - [ ] Tester l'accès à la page d'administration (superagent uniquement)

2. **Modification des horaires**
   - [ ] Ajouter/supprimer des créneaux
   - [ ] Activer/désactiver des jours
   - [ ] Sauvegarder et vérifier la persistance

3. **Affichage temps réel**
   - [ ] Vérifier que l'accueil se met à jour automatiquement
   - [ ] Tester la vérification d'ouverture lors de la création de tickets

4. **Gestion d'erreurs**
   - [ ] Tester le comportement en cas de problème Firestore
   - [ ] Vérifier le fallback sur horaires par défaut

## Améliorations Futures

- [ ] Interface de gestion des jours fériés
- [ ] Horaires différents par service (dépôt/retrait)
- [ ] Notifications automatiques de changement d'horaires
- [ ] Historique des modifications d'horaires
- [ ] Import/export de configurations d'horaires

## Dépendances

- `cloud_firestore` : Stockage des horaires
- `firebase_auth` : Vérification des permissions
- `flutter/material` : Interface utilisateur
- `provider` : Gestion d'état (optionnel)

## Fichiers Modifiés

- ✅ `lib/models/horaires.dart` (nouveau)
- ✅ `lib/services/horaires_service.dart` (nouveau)  
- ✅ `lib/pages/superagent/horaires_admin_page.dart` (nouveau)
- ✅ `lib/services/firestore_service.dart` (modifié)
- ✅ `lib/pages/client/accueil.dart` (modifié)
- ✅ `lib/pages/superagent/statistiques_superagent.dart` (modifié)
- ✅ `lib/main.dart` (route ajoutée)
