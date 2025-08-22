# Documentation Complète - Fast TMB

## Vue d'ensemble du projet

**Fast TMB** est une application Flutter de gestion de file d'attente bancaire développée pour optimiser l'expérience client et faciliter le travail des agents. L'application permet aux clients de prendre des tickets virtuels, de suivre leur position en temps réel, et aux agents de gérer efficacement les files d'attente.

### Informations générales
- **Nom du projet** : fast_tmb
- **Framework** : Flutter (SDK ^3.7.2)
- **Base de données** : Firebase Firestore
- **Authentification** : Firebase Auth
- **Notifications** : Firebase Cloud Messaging + notifications locales
- **Version** : 1.0.0+1

## Architecture du projet

### Vue d'ensemble architecturale

**Fast TMB** utilise une **architecture Flutter moderne en couches** avec une approche Backend-as-a-Service (BaaS) basée sur Firebase.

#### Architecture générale
```
┌─────────────────────────────────────┐
│           PRESENTATION              │
│    (Pages + Widgets + UI Logic)     │
├─────────────────────────────────────┤
│            BUSINESS                 │
│         (Services + Logic)          │
├─────────────────────────────────────┤
│             DATA                    │
│    (Models + Firebase + Storage)    │
└─────────────────────────────────────┘
```

#### Patterns architecturaux utilisés

1. **Layered Architecture** : Séparation claire en couches Présentation/Business/Data
2. **Provider Pattern** : Gestion d'état réactive avec ChangeNotifier
3. **Repository Pattern** : FirestoreService comme abstraction d'accès aux données
4. **Service Layer Pattern** : Services métier découplés par domaine
5. **Observer Pattern** : Streams pour les données temps réel
6. **Role-Based Access Control (RBAC)** : Sécurité basée sur les rôles utilisateur

#### Gestion d'état
- **Provider** pour l'injection de dépendances
- **ChangeNotifier** pour la réactivité (AuthServiceV2)
- **StreamBuilder** pour les données temps réel Firestore
- **Consumer/Selector** pour optimiser les reconstructions UI

### Structure des dossiers

```
lib/
├── auth/                    # Gestion de l'authentification
│   └── auth_wrapper.dart   # Wrapper d'authentification et routage par rôle
├── models/                 # Modèles de données
│   ├── horaires.dart      # Modèle des horaires d'ouverture
│   ├── ticket.dart        # Modèle des tickets
│   └── utilisateur.dart   # Modèle des utilisateurs
├── pages/                 # Pages de l'application
│   ├── agent/            # Pages spécifiques aux agents
│   ├── client/           # Pages spécifiques aux clients
│   ├── public/           # Pages publiques (sans smartphone)
│   ├── superagent/       # Pages d'administration
│   ├── connexion_page.dart
│   └── inscription_page.dart
├── services/             # Services métier
│   ├── auth_service_v2.dart      # Service d'authentification
│   ├── firestore_service.dart    # Service Firestore principal
│   ├── horaires_service.dart     # Gestion des horaires
│   ├── notification_service.dart # Gestion des notifications
│   ├── export_service.dart       # Export de données
│   └── file_download_service.dart # Téléchargement de fichiers
├── utils/                # Utilitaires
└── main.dart            # Point d'entrée de l'application
```

### Architecture par couches détaillée

#### Couche Présentation (lib/pages/)
```
pages/
├── client/          # Interface utilisateur client
├── agent/           # Interface agent bancaire  
├── superagent/      # Interface administration
├── public/          # Pages publiques (sans compte)
└── auth/            # Pages d'authentification
```

#### Couche Business (lib/services/)
```
services/
├── auth_service_v2.dart      # Authentification & autorisation
├── firestore_service.dart    # Logique métier principale
├── horaires_service.dart     # Gestion des horaires
├── notification_service.dart # Notifications
├── export_service.dart       # Export PDF/CSV
└── file_download_service.dart # Téléchargements
```

#### Couche Data (lib/models/)
```
models/
├── utilisateur.dart  # Modèle utilisateur
├── ticket.dart       # Modèle ticket de file
└── horaires.dart     # Modèle horaires d'ouverture
```

### Rôles utilisateurs et navigation

L'application supporte trois types d'utilisateurs avec routage automatique :

1. **Client** : Utilisateur standard qui peut prendre des tickets et suivre sa position
2. **Agent** : Personnel bancaire qui gère les files d'attente et appelle les clients
3. **Superagent** : Administrateur avec accès aux statistiques et configuration

#### Routage basé sur les rôles
```dart
// Exemple dans auth_wrapper.dart
switch (user.role) {
  case 'superagent': return StatistiquesSuperAgentPage();
  case 'agent': return TableauBordAgentPage();
  default: return AccueilPage(); // client
}
```

## Fonctionnalités principales

### 1. Gestion des tickets

#### Pour les clients
- **Prise de ticket** : Sélection du service (dépôt/retrait) et génération automatique du numéro
- **Suivi en temps réel** : Position dans la file d'attente mise à jour automatiquement
- **Notifications** : Alertes quand c'est le tour du client
- **Annulation** : Possibilité d'annuler son ticket en attente
- **Évaluation** : Système de satisfaction après service (1-5 étoiles + commentaire)

#### Pour les agents
- **Appel du prochain client** : Gestion des files par service (dépôt/retrait)
- **Gestion des statuts** : Marquer les tickets comme servis, absents ou annulés
- **Vue d'ensemble** : Nombre de clients en attente par service
- **Statistiques personnelles** : Performance et satisfaction client

#### Pour les superagents
- **Statistiques globales** : Vue d'ensemble de tous les services
- **Gestion des horaires** : Configuration dynamique des heures d'ouverture
- **Administration des services** : Configuration des types de services disponibles
- **Export de données** : Génération de rapports PDF et CSV

### 2. Système d'horaires dynamiques

Le système permet une configuration flexible des horaires d'ouverture :

- **Configuration par jour** : Horaires différents pour chaque jour de la semaine
- **Créneaux multiples** : Possibilité d'avoir plusieurs créneaux par jour
- **Mise à jour temps réel** : Les changements sont immédiatement visibles
- **Horaires par défaut** : Lun-Ven 08:00-15:30, Sam 08:00-12:00, Dim fermé

### 3. Notifications

#### Types de notifications
- **Ticket appelé** : Notification quand c'est le tour du client
- **Service fermé** : Alerte si le service ferme pendant l'attente
- **Ticket expiré** : Notification d'annulation automatique

#### Canaux de notification
- **Push notifications** : Via Firebase Cloud Messaging
- **Notifications locales** : Alertes système
- **Notifications in-app** : Messages dans l'interface

### 4. Gestion des files d'attente

#### Services disponibles
- **Dépôt** : File pour les opérations de dépôt
- **Retrait** : File pour les opérations de retrait
- **Configuration dynamique** : Interface d'administration complète pour gérer les services
  - Ajout/suppression de services
  - Activation/désactivation par service
  - Renommage des services existants
  - Services par défaut créés automatiquement

#### Logique de gestion
- **FIFO** : Premier arrivé, premier servi
- **Estimation d'attente** : Calcul basé sur le nombre de tickets et durée moyenne
- **Vérification des horaires** : Refus de nouveaux tickets si fermeture imminente
- **Nettoyage automatique** : Annulation des tickets expirés

## Base de données Firestore

### Collections principales

#### `tickets`
```javascript
{
  id: "auto-generated",
  numero: 1,                    // Numéro du ticket (reset quotidien)
  createdAt: Timestamp,         // Date/heure de création
  treatedAt: Timestamp,         // Date/heure de traitement
  startedAt: Timestamp,         // Date/heure d'appel
  status: "en_attente|en_cours|servi|absent|annule",
  uid: "user-id",              // ID du client
  agentId: "agent-id",         // ID de l'agent qui traite
  queueType: "depot|retrait",   // Type de service
  satisfactionScore: 1-5,       // Note de satisfaction
  satisfactionComment: "...",   // Commentaire optionnel
  clientName: "Nom",           // Pour clients sans smartphone
  clientFirstName: "Prénom",   // Pour clients sans smartphone
  guest: true/false            // Ticket créé via page publique
}
```

#### `utilisateurs`
```javascript
{
  id: "user-id",
  email: "user@example.com",
  role: "client|agent|superagent",
  prenom: "Prénom",
  nom: "Nom",
  createdAt: Timestamp
}
```

#### `settings/horaires_ouverture`
```javascript
{
  jours: {
    lundi: {
      ouvert: true,
      creneaux: [
        {
          startHour: 8,
          startMinute: 0,
          endHour: 15,
          endMinute: 30
        }
      ]
    },
    // ... autres jours
  },
  lastUpdated: Timestamp,
  updatedBy: "superagent-id"
}
```

#### `meta/compteur_tickets`
```javascript
{
  last: 42,                    // Dernier numéro attribué
  date: "2025-01-10"          // Date courante (reset quotidien)
}
```

### Sous-collections

#### `utilisateurs/{uid}/notifications`
```javascript
{
  title: "Titre de la notification",
  body: "Corps du message",
  read: false,
  timestamp: Timestamp,
  data: {
    type: "ticket_called|service_closed|...",
    ticketId: "ticket-id",
    // ... autres données contextuelles
  }
}
```

### Patterns spécifiques aux fonctionnalités

#### Gestion des files d'attente
- **Event-driven Architecture** : Événements de tickets (création, appel, traitement)
- **Real-time Updates** : Mise à jour instantanée via Firestore streams
- **FIFO Queue Logic** : Premier arrivé, premier servi avec horodatage
- **State Machine** : Gestion des états de tickets (en_attente → en_cours → servi/absent/annulé)

#### Système de notifications
- **Multi-channel Strategy** :
  - Push notifications (FCM)
  - Local notifications (système)
  - In-app notifications (Firestore subcollection)
- **Observer Pattern** : Écoute des changements d'état pour déclencher les notifications

#### Export de données
- **Strategy Pattern** : Différentes stratégies selon la plateforme (Android SAF, iOS Share, Desktop)
- **Template Method** : Structure commune pour génération PDF/CSV
- **Factory Pattern** : Création de fichiers selon le type et format

#### Injection de dépendances
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthServiceV2()),
    Provider(create: (_) => FirestoreService()),
    Provider(create: (_) => NotificationService()),
  ],
  child: MaterialApp(...)
)
```

## Services techniques

### AuthServiceV2
- **Inscription/Connexion** : Gestion complète de l'authentification
- **Gestion des rôles** : Attribution et vérification des permissions
- **État utilisateur** : Suivi de l'état de connexion avec Provider

### FirestoreService
- **Gestion des tickets** : CRUD complet avec logique métier
- **Vérifications** : Contrôle des horaires et limites
- **Statistiques** : Calculs de performance et satisfaction
- **Notifications** : Envoi de messages aux utilisateurs

### HorairesService
- **Configuration dynamique** : Lecture/écriture des horaires
- **Vérification d'ouverture** : Logique de validation en temps réel
- **Fallback** : Horaires par défaut en cas d'erreur

### NotificationService
- **FCM** : Gestion des push notifications
- **Notifications locales** : Alertes système
- **Navigation** : Redirection automatique selon le contexte

### ExportService
- **Export PDF** : Création de rapports formatés avec statistiques
- **Gestion multi-plateforme** : Adaptation selon la plateforme (Android SAF, iOS Share, Desktop/Web)
- **Templates PDF** : Mise en forme professionnelle des rapports

### FileDownloadService
- **Gestion des permissions** : Demande automatique des permissions de stockage
- **Storage Access Framework** : Intégration native Android pour la sauvegarde
- **Détection MIME** : Inférence automatique du type de fichier

## Sécurité et permissions

### Règles Firestore
- **Clients** : Accès limité à leurs propres tickets et notifications
- **Agents** : Lecture des tickets, modification des statuts
- **Superagents** : Accès complet aux statistiques et configuration

### Validation côté client
- **Horaires** : Vérification avant création de ticket
- **Doublons** : Prévention des tickets multiples
- **Rôles** : Interface adaptée selon les permissions

### Architecture de sécurité
- **Role Guards** : Vérification des permissions au niveau des pages
- **Service-level Security** : Validation des rôles dans les services
- **Firebase Security Rules** : Règles côté serveur pour Firestore
- **Token-based Auth** : Authentification via Firebase Auth tokens

## Configuration et déploiement

### Dépendances principales
```yaml
dependencies:
  flutter: sdk
  firebase_core: ^4.0.0
  cloud_firestore: ^6.0.0
  firebase_auth: ^6.0.0
  firebase_messaging: ^16.0.0
  provider: ^6.0.5
  pdf: ^3.11.0
  csv: ^6.0.0
```

### Configuration Firebase
- **Android** : `android/app/google-services.json`
- **iOS** : `ios/Runner/GoogleService-Info.plist`
- **Web** : Configuration dans `firebase_options.dart`

### Assets
- **Logo** : `assets/icon/logo.png`
- **Splash screen** : `assets/icon/splash.png`

## Maintenance et monitoring

### Nettoyage automatique
- **Tickets expirés** : Annulation automatique des tickets des jours précédents
- **Notifications** : Suppression des notifications anciennes
- **Cache** : Gestion du cache Firestore

### Logs et debugging
- **Debug service** : Service dédié au debugging
- **Logs détaillés** : Traçabilité des actions importantes
- **Gestion d'erreurs** : Capture et logging des exceptions

### Performance
- **Pagination** : Chargement par lot des données
- **Cache** : Utilisation du cache Firestore
- **Optimisation** : Requêtes optimisées et indexation

## Évolutions futures

### Fonctionnalités prévues
- **QR Code** : Scan de QR codes pour services spéciaux (actuellement désactivé)
- **Gestion des jours fériés** : Configuration des fermetures exceptionnelles
- **Horaires par service** : Horaires différents selon le type de service
- **Historique des modifications** : Traçabilité des changements de configuration

### Améliorations techniques
- **WebSocket** : Communication temps réel (préparé mais non activé)
- **Offline support** : Fonctionnement hors ligne
- **Analytics** : Suivi détaillé de l'utilisation
- **Tests automatisés** : Suite de tests complète

---
