# Manuel d'utilisation - Fast TMB

## Table des matières

1. [Introduction](#introduction)
2. [Installation et première utilisation](#installation-et-première-utilisation)
3. [Guide utilisateur Client](#guide-utilisateur-client)
4. [Guide utilisateur Agent](#guide-utilisateur-agent)
5. [Guide utilisateur Superagent](#guide-utilisateur-superagent)
6. [Fonctionnalités spéciales](#fonctionnalités-spéciales)
7. [Dépannage](#dépannage)


## Introduction

Fast TMB est une application mobile de gestion de file d'attente bancaire qui permet :
- Aux **clients** de prendre des tickets virtuels et suivre leur position
- Aux **agents** de gérer efficacement les files d'attente
- Aux **superagents** d'administrer le système et consulter les statistiques

### Prérequis
- Smartphone Android ou iOS
- Connexion internet
- Compte utilisateur créé par l'administration (pour agents/superagents)

## Installation et première utilisation

### 1. Installation de l'application
- Téléchargez l'application depuis le store interne de votre banque
- Installez l'application sur votre appareil
- Ouvrez l'application

### 2. Première connexion

#### Pour les clients
1. Appuyez sur **"Créer un compte"**
2. Saisissez vos informations :
   - Adresse email
   - Prénom et nom
   - Mot de passe (minimum 6 caractères)
3. Appuyez sur **"S'inscrire"**
4. Vous êtes automatiquement connecté

#### Pour les agents/superagents
1. Utilisez les identifiants fournis par votre administration
2. Appuyez sur **"Se connecter"**
3. Saisissez votre email et mot de passe
4. Appuyez sur **"Connexion"**

## Guide utilisateur Client

### Page d'accueil

La page d'accueil affiche :
- **Horaires d'ouverture** actuels du service
- **État du service** (ouvert/fermé)
- **Nombre de clients en attente** par service
- **Temps d'attente estimé**

### Prendre un ticket

1. **Vérifiez que le service est ouvert**
   - L'indicateur doit être vert avec "Service ouvert"
   - Si fermé, les horaires d'ouverture sont affichés

2. **Choisissez votre service**
   - **Dépôt** : Pour les opérations de dépôt d'argent, chèques, etc.
   - **Retrait** : Pour les retraits d'argent, consultations, etc.

3. **Prenez votre ticket**
   - Appuyez sur le bouton du service souhaité
   - Votre numéro de ticket s'affiche immédiatement
   - Une notification confirme la prise de ticket

### Suivre votre position

Une fois votre ticket pris :
- **Numéro de ticket** : Affiché en grand
- **Position dans la file** : "Vous êtes 3ème"
- **Temps d'attente estimé** : Basé sur la durée moyenne de service
- **Mise à jour automatique** : La position se met à jour en temps réel

### Notifications

Vous recevrez des notifications pour :
- **Votre tour approche** : Quand vous êtes dans les 2 prochains
- **C'est votre tour** : Notification avec son pour vous rendre au guichet
- **Service fermé** : Si le service ferme pendant votre attente

### Annuler votre ticket

Pour annuler votre ticket en attente :
1. Appuyez sur **"Annuler mon ticket"**
2. Confirmez l'annulation
3. Vous retournez à la page d'accueil

### Évaluation du service

Après avoir été servi :
1. Une notification vous invite à évaluer le service
2. Donnez une note de 1 à 5 étoiles
3. Ajoutez un commentaire (optionnel)
4. Appuyez sur **"Envoyer"**

### Menu client

Accédez au menu via l'icône ☰ :
- **Accueil** : Retour à la page principale
- **File en cours** : Voir votre ticket actuel
- **Notifications** : Historique des notifications
- **Paramètres** : Gestion du compte
- **Se déconnecter** : Quitter l'application

## Guide utilisateur Agent

### Tableau de bord agent

Le tableau de bord affiche :
- **Clients en attente** par service (dépôt/retrait)
- **Prochain client** à appeler
- **Statistiques du jour** : Tickets traités, temps moyen
- **Boutons d'action** pour gérer les files

### Appeler un client

1. **Choisissez le service** (dépôt ou retrait)
2. **Appuyez sur "Appeler prochain client"**
3. Le système :
   - Passe le ticket en statut "en cours"
   - Envoie une notification au client
   - Affiche les informations du client

### Gérer un ticket en cours

Une fois un client appelé, vous pouvez :

#### Marquer comme servi
1. Appuyez sur **"Marquer comme servi"**
2. Le ticket passe en statut "servi"
3. Le client reçoit une invitation à évaluer le service

#### Marquer comme absent
1. Si le client ne se présente pas
2. Appuyez sur **"Marquer comme absent"**
3. Le ticket est retiré de la file

#### Annuler le ticket
1. En cas de problème ou d'erreur
2. Appuyez sur **"Annuler"**
3. Le ticket est annulé

### Statistiques personnelles

Accédez à vos statistiques via le menu :
- **Tickets traités** : Nombre par jour/semaine
- **Temps moyen de service** : Performance personnelle
- **Satisfaction client** : Note moyenne reçue
- **Graphiques** : Évolution de vos performances

### Gestion des files multiples

Pour gérer plusieurs services :
1. **Alternez entre les services** avec les onglets
2. **Priorisez** selon l'affluence
3. **Surveillez les temps d'attente** pour équilibrer

## Guide utilisateur Superagent

### Tableau de bord superagent

Vue d'ensemble complète :
- **Statistiques globales** : Tous services confondus
- **Performance des agents** : Comparaison et suivi
- **Satisfaction client** : Moyennes et tendances
- **Accès aux outils d'administration**

### Gestion des horaires

1. **Accédez à "Horaires"** depuis le tableau de bord
2. **Configuration par jour** :
   - Activez/désactivez chaque jour
   - Définissez les créneaux horaires
   - Ajoutez plusieurs créneaux par jour si nécessaire

3. **Modification des horaires** :
   - Sélectionnez le jour à modifier
   - Ajustez les heures de début/fin
   - Sauvegardez les modifications

4. **Horaires par défaut** :
   - Lundi-Vendredi : 08:00-15:30
   - Samedi : 08:00-12:00
   - Dimanche : Fermé

### Administration des services

1. **Accédez à "Services"** depuis le tableau de bord
2. **Interface complète de gestion** :
   - **Ajouter un service** : Saisissez le nom et appuyez sur "Ajouter"
   - **Activer/désactiver** : Utilisez le commutateur pour chaque service
   - **Renommer** : Cliquez sur l'icône d'édition pour modifier le nom
   - **Supprimer** : Cliquez sur l'icône de suppression (avec confirmation)
   - **Services par défaut** : Dépôt et Retrait créés automatiquement au premier accès

### Statistiques avancées

#### Vue d'ensemble
- **Tickets du jour** : Total et par service
- **Temps d'attente moyen** : Performance globale
- **Satisfaction client** : Note moyenne et distribution
- **Agents actifs** : Qui est connecté

#### Rapports détaillés
- **Graphiques temporels** : Évolution sur 7/30 jours
- **Comparaison agents** : Performance individuelle
- **Analyse par service** : Dépôt vs Retrait
- **Heures de pointe** : Identification des pics d'affluence

### Export de données

1. **Sélectionnez la période** d'export depuis les statistiques
2. **Choisissez le format** :
   - **PDF** : Rapport formaté avec graphiques et tableaux
   - **CSV** : Données brutes pour analyse dans un tableur

3. **Processus de sauvegarde** :
   - **Desktop/Web** : Dialogue natif pour choisir l'emplacement
   - **Android** : Storage Access Framework pour sélectionner le dossier
   - **iOS** : Partage via le système natif

4. **Contenu des exports** :
   - **PDF** : Synthèse, détails par service, graphiques temporels
   - **CSV** : Numéro, statut, dates de création/traitement de chaque ticket

### Gestion des utilisateurs

#### Création d'agents
1. Les agents doivent être créés manuellement dans Firestore
2. Structure requise dans `utilisateurs/{uid}` :
```json
{
  "email": "agent@banque.com",
  "role": "agent",
  "prenom": "Prénom",
  "nom": "Nom",
  "createdAt": "timestamp"
}
```

#### Gestion des rôles
- **client** : Accès standard aux services
- **agent** : Gestion des files d'attente
- **superagent** : Administration complète

## Fonctionnalités spéciales

### Mode sans smartphone

Pour les clients sans smartphone :
1. **Accédez à la page publique** via l'URL dédiée
2. **Saisissez les informations client** :
   - Nom et prénom
   - Type de service souhaité
3. **Générez le ticket** pour le client
4. **Remettez le numéro** au client

### Notifications push

Configuration automatique :
- **Permissions** : Demandées au premier lancement
- **Types de notifications** :
  - Ticket appelé
  - Service fermé
  - Rappels importants

### Gestion hors ligne

Fonctionnalités limitées sans internet :
- **Consultation** du dernier état connu
- **Notifications locales** continuent de fonctionner
- **Synchronisation** automatique au retour de connexion

## Dépannage

### Problèmes courants

#### "Service fermé" alors qu'il devrait être ouvert
1. Vérifiez l'heure système de votre appareil
2. Contactez un superagent pour vérifier les horaires configurés dans l'interface d'administration
3. Redémarrez l'application
4. Les horaires peuvent avoir été modifiés récemment par un superagent

#### Notifications non reçues
1. Vérifiez les permissions de notification dans les paramètres
2. Assurez-vous que l'application n'est pas en mode économie d'énergie
3. Redémarrez l'application

#### Position dans la file incorrecte
1. Fermez et rouvrez l'application
2. Vérifiez votre connexion internet
3. Si le problème persiste, annulez et reprenez un ticket

#### Impossible de prendre un ticket
1. Vérifiez que vous n'avez pas déjà un ticket actif
2. Vérifiez les horaires d'ouverture
3. Assurez-vous d'être connecté à internet

### Messages d'erreur

#### "Vous avez déjà un ticket actif"
- Un seul ticket par utilisateur à la fois
- Annulez votre ticket actuel ou attendez qu'il soit traité

#### "Service bientôt fermé"
- Il n'y a plus assez de temps pour traiter votre demande
- Revenez pendant les heures d'ouverture

#### "Utilisateur non connecté"
- Votre session a expiré
- Reconnectez-vous à l'application
