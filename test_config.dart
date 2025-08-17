import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Script de test pour configurer Firestore avec les bonnes données de test
void main() async {
  // Initialiser Firebase
  await Firebase.initializeApp();
  
  final db = FirebaseFirestore.instance;
  
  print('Configuration de test Firestore...');
  
  // 1. Configuration des horaires de test
  await configureHoraires(db);
  
  // 2. Configuration de la marge avant fermeture
  await configureMarge(db);
  
  print('Configuration terminée !');
}

Future<void> configureHoraires(FirebaseFirestore db) async {
  print('Configuration des horaires...');
  
  // Horaires de test : fermeture dans 30 minutes pour tester le refus
  final now = DateTime.now();
  final fermetureDans30Min = now.add(Duration(minutes: 30));
  
  final horaires = {
    'jours': {
      'lundi': {
        'ouvert': true,
        'creneaux': [
          {
            'startHour': 8,
            'startMinute': 0,
            'endHour': fermetureDans30Min.hour,
            'endMinute': fermetureDans30Min.minute,
          }
        ]
      },
      'mardi': {
        'ouvert': true,
        'creneaux': [
          {
            'startHour': 8,
            'startMinute': 0,
            'endHour': fermetureDans30Min.hour,
            'endMinute': fermetureDans30Min.minute,
          }
        ]
      },
      'mercredi': {
        'ouvert': true,
        'creneaux': [
          {
            'startHour': 8,
            'startMinute': 0,
            'endHour': fermetureDans30Min.hour,
            'endMinute': fermetureDans30Min.minute,
          }
        ]
      },
      'jeudi': {
        'ouvert': true,
        'creneaux': [
          {
            'startHour': 8,
            'startMinute': 0,
            'endHour': fermetureDans30Min.hour,
            'endMinute': fermetureDans30Min.minute,
          }
        ]
      },
      'vendredi': {
        'ouvert': true,
        'creneaux': [
          {
            'startHour': 8,
            'startMinute': 0,
            'endHour': fermetureDans30Min.hour,
            'endMinute': fermetureDans30Min.minute,
          }
        ]
      },
      'samedi': {
        'ouvert': true,
        'creneaux': [
          {
            'startHour': 8,
            'startMinute': 0,
            'endHour': fermetureDans30Min.hour,
            'endMinute': fermetureDans30Min.minute,
          }
        ]
      },
      'dimanche': {
        'ouvert': false,
        'creneaux': []
      }
    }
  };
  
  await db.collection('settings').doc('horaires').set(horaires);
  print('Horaires configurés - fermeture à ${fermetureDans30Min.hour}:${fermetureDans30Min.minute.toString().padLeft(2, '0')}');
}

Future<void> configureMarge(FirebaseFirestore db) async {
  print('Configuration de la marge avant fermeture...');
  
  // Marge de 15 minutes avant fermeture
  final config = {
    'margeMinutes': 15,
  };
  
  await db.collection('settings').doc('app_config').set(config);
  print('Marge configurée : 15 minutes');
}
