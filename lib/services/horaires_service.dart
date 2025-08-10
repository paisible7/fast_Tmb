import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fast_tmb/models/horaires.dart';

class HorairesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _collectionName = 'settings';
  static const String _horaireDocId = 'horaires_ouverture';

  /// Stream des horaires en temps réel
  Stream<Horaires> getHorairesStream() {
    return _db
        .collection(_collectionName)
        .doc(_horaireDocId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return Horaires.fromDocument(doc);
      } else {
        // Retourner les horaires par défaut si pas encore configurés
        return Horaires.defaults();
      }
    });
  }

  /// Récupère les horaires actuels (une seule fois)
  Future<Horaires> getHoraires() async {
    try {
      final doc = await _db
          .collection(_collectionName)
          .doc(_horaireDocId)
          .get();
      
      if (doc.exists) {
        return Horaires.fromDocument(doc);
      } else {
        // Créer les horaires par défaut s'ils n'existent pas
        final defaultHoraires = Horaires.defaults();
        await _saveHoraires(defaultHoraires);
        return defaultHoraires;
      }
    } catch (e) {
      print('Erreur lors de la récupération des horaires: $e');
      // Fallback sur les horaires par défaut
      return Horaires.defaults();
    }
  }

  /// Sauvegarde les horaires (réservé aux superagents)
  Future<void> saveHoraires(Horaires horaires) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté');
    }

    // Vérifier le rôle superagent
    final userDoc = await _db.collection('utilisateurs').doc(user.uid).get();
    final role = userDoc.data()?['role'] as String?;
    
    if (role != 'superagent') {
      throw Exception('Accès refusé : seuls les superagents peuvent modifier les horaires');
    }

    await _saveHoraires(horaires.copyWith(updatedBy: user.uid));
  }

  /// Sauvegarde interne des horaires
  Future<void> _saveHoraires(Horaires horaires) async {
    await _db
        .collection(_collectionName)
        .doc(_horaireDocId)
        .set(horaires.toMap());
  }

  /// Vérifie si le service est ouvert maintenant
  Future<bool> isOpenNow() async {
    final horaires = await getHoraires();
    return horaires.isOpenNow(DateTime.now());
  }

  /// Obtient le texte d'affichage des horaires pour tous les jours
  Future<String> getHorairesDisplayText() async {
    final horaires = await getHoraires();
    final now = DateTime.now();
    final isOpen = horaires.isOpenNow(now);
    
    final buffer = StringBuffer();
    
    if (isOpen) {
      buffer.write('Service ouvert :\n');
    } else {
      buffer.write('Service fermé :\n');
    }
    
    // Grouper les jours avec les mêmes horaires
    final groupedDays = <String, List<String>>{};
    
    final daysOrder = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
    final daysDisplay = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    
    for (int i = 0; i < daysOrder.length; i++) {
      final day = daysOrder[i];
      final displayDay = daysDisplay[i];
      final horaireJour = horaires.jours[day];
      
      String horaireText;
      if (horaireJour == null || !horaireJour.ouvert) {
        horaireText = 'Fermé';
      } else {
        horaireText = horaireJour.creneaux
            .map((c) => '${c.startFormatted}–${c.endFormatted}')
            .join(' • ');
      }
      
      if (groupedDays.containsKey(horaireText)) {
        groupedDays[horaireText]!.add(displayDay);
      } else {
        groupedDays[horaireText] = [displayDay];
      }
    }
    
    // Construire le texte d'affichage
    final entries = groupedDays.entries.toList();
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final days = entry.value;
      final horaire = entry.key;
      
      if (days.length == 1) {
        buffer.write('${days[0]} $horaire');
      } else if (days.length == 2) {
        buffer.write('${days[0]} – ${days[1]} $horaire');
      } else {
        // Grouper les jours consécutifs
        final ranges = <String>[];
        int start = 0;
        
        for (int j = 1; j <= days.length; j++) {
          if (j == days.length || !_areConsecutive(days, start, j)) {
            if (j - start == 1) {
              ranges.add(days[start]);
            } else {
              ranges.add('${days[start]} – ${days[j - 1]}');
            }
            start = j;
          }
        }
        
        buffer.write('${ranges.join(', ')} $horaire');
      }
      
      if (i < entries.length - 1) {
        buffer.write('\n');
      }
    }
    
    return buffer.toString();
  }

  bool _areConsecutive(List<String> days, int start, int end) {
    final daysOrder = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    
    for (int i = start; i < end - 1; i++) {
      final currentIndex = daysOrder.indexOf(days[i]);
      final nextIndex = daysOrder.indexOf(days[i + 1]);
      
      if (nextIndex != currentIndex + 1) {
        return false;
      }
    }
    
    return true;
  }
}

extension HorairesExtension on Horaires {
  Horaires copyWith({
    String? id,
    Map<String, HoraireJour>? jours,
    DateTime? lastUpdated,
    String? updatedBy,
  }) {
    return Horaires(
      id: id ?? this.id,
      jours: jours ?? this.jours,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
