# Fast TMB

<div align="center">
  <img src="assets/icon/logo.png" alt="Fast TMB Logo" width="120" height="120">
  <h3>Application de gestion de file d'attente bancaire</h3>
  <p>Une solution moderne et intuitive pour optimiser l'expérience client et faciliter le travail des agents bancaires</p>
</div>

## 📋 Vue d'ensemble

**Fast TMB** est une application Flutter complète qui permet :
- Aux **clients** de prendre des tickets virtuels et suivre leur position en temps réel
- Aux **agents** de gérer efficacement les files d'attente
- Aux **superagents** d'administrer le système et consulter les statistiques

### ✨ Fonctionnalités principales
- 🎫 **Gestion de tickets** : Prise, suivi temps réel, notifications
- ⏰ **Horaires dynamiques** : Configuration flexible par les administrateurs
- 📊 **Statistiques avancées** : Performance agents et satisfaction client
- 📄 **Export de données** : Rapports PDF et CSV
- 🔔 **Notifications push** : Alertes temps réel
- 🔐 **Sécurité RBAC** : Gestion des rôles et permissions

## 📚 Documentation

### 📖 Guides disponibles
- **[Documentation complète](DOCUMENTATION_COMPLETE.md)** - Architecture technique, modèles de données, services
- **[Manuel d'utilisation](MANUEL_UTILISATION.md)** - Guide utilisateur pour clients, agents et superagents

### 🏗️ Architecture
- **Framework** : Flutter (SDK ^3.7.2)
- **Backend** : Firebase (Auth, Firestore, FCM)
- **Architecture** : Couches (Présentation/Business/Data)
- **Patterns** : Provider, Repository, Observer, RBAC

## 🚀 Installation et configuration

### Prérequis
- Flutter SDK ^3.7.2
- Compte Firebase configuré
- Android Studio / VS Code

### Installation
```bash
# Cloner le projet
git clone https://github.com/paisible7/fast_Tmb.git
cd fl

# Installer les dépendances
flutter pub get

# Configurer Firebase
# Placer google-services.json dans android/app/
# Placer GoogleService-Info.plist dans ios/Runner/

# Lancer l'application
flutter run
```

## 👥 Rôles utilisateurs

| Rôle | Description | Fonctionnalités |
|------|-------------|----------------|
| **Client** | Utilisateur standard | Prise de ticket, suivi position, évaluation |
| **Agent** | Personnel bancaire | Gestion files d'attente, appel clients |
| **Superagent** | Administrateur | Statistiques, configuration, horaires |

## 🛠️ Technologies utilisées

- **Flutter** - Framework mobile cross-platform
- **Firebase Auth** - Authentification utilisateur
- **Cloud Firestore** - Base de données temps réel
- **Firebase Cloud Messaging** - Notifications push
- **Provider** - Gestion d'état
- **PDF/CSV** - Export de données

## 📱 Captures d'écran

*À ajouter : captures d'écran des interfaces client, agent et superagent*

## 🤝 Contribution

Pour contribuer au projet :
1. Fork le repository
2. Créer une branche feature
3. Commiter les changements
4. Pousser vers la branche
5. Ouvrir une Pull Request

## 📄 Licence

Ce projet est sous licence privée. Tous droits réservés.

---

**Version** : 1.0.0 | **Dernière mise à jour** : Août 2025
