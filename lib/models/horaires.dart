import 'package:cloud_firestore/cloud_firestore.dart';

class Horaires {
  final String id;
  final Map<String, HoraireJour> jours;
  final DateTime? lastUpdated;
  final String? updatedBy;

  Horaires({
    required this.id,
    required this.jours,
    this.lastUpdated,
    this.updatedBy,
  });

  factory Horaires.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final joursData = data['jours'] as Map<String, dynamic>? ?? {};
    
    final jours = <String, HoraireJour>{};
    joursData.forEach((key, value) {
      jours[key] = HoraireJour.fromMap(value as Map<String, dynamic>);
    });

    return Horaires(
      id: doc.id,
      jours: jours,
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : null,
      updatedBy: data['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final joursMap = <String, dynamic>{};
    jours.forEach((key, value) {
      joursMap[key] = value.toMap();
    });

    return {
      'jours': joursMap,
      'lastUpdated': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }

  /// Vérifie si le service est ouvert maintenant
  bool isOpenNow(DateTime now) {
    final weekday = _getWeekdayKey(now.weekday);
    final horaireJour = jours[weekday];
    
    if (horaireJour == null || !horaireJour.ouvert) {
      return false;
    }

    final minutes = now.hour * 60 + now.minute;
    
    for (final creneau in horaireJour.creneaux) {
      if (creneau.contains(minutes)) {
        return true;
      }
    }
    
    return false;
  }

  /// Obtient les horaires d'affichage pour un jour donné
  String getHorairesAffichage(int weekday) {
    final key = _getWeekdayKey(weekday);
    final horaireJour = jours[key];
    
    if (horaireJour == null || !horaireJour.ouvert) {
      return 'Fermé';
    }
    
    return horaireJour.creneaux
        .map((c) => '${c.startFormatted}–${c.endFormatted}')
        .join(' • ');
  }

  String _getWeekdayKey(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'lundi';
      case DateTime.tuesday: return 'mardi';
      case DateTime.wednesday: return 'mercredi';
      case DateTime.thursday: return 'jeudi';
      case DateTime.friday: return 'vendredi';
      case DateTime.saturday: return 'samedi';
      case DateTime.sunday: return 'dimanche';
      default: return 'lundi';
    }
  }

  /// Horaires par défaut (actuels)
  static Horaires defaults() {
    return Horaires(
      id: 'default',
      jours: {
        'lundi': HoraireJour(ouvert: true, creneaux: [CreneauHoraire(8, 0, 15, 30)]),
        'mardi': HoraireJour(ouvert: true, creneaux: [CreneauHoraire(8, 0, 15, 30)]),
        'mercredi': HoraireJour(ouvert: true, creneaux: [CreneauHoraire(8, 0, 15, 30)]),
        'jeudi': HoraireJour(ouvert: true, creneaux: [CreneauHoraire(8, 0, 15, 30)]),
        'vendredi': HoraireJour(ouvert: true, creneaux: [CreneauHoraire(8, 0, 15, 30)]),
        'samedi': HoraireJour(ouvert: true, creneaux: [CreneauHoraire(8, 0, 12, 0)]),
        'dimanche': HoraireJour(ouvert: false, creneaux: []),
      },
    );
  }
}

class HoraireJour {
  final bool ouvert;
  final List<CreneauHoraire> creneaux;

  HoraireJour({
    required this.ouvert,
    required this.creneaux,
  });

  factory HoraireJour.fromMap(Map<String, dynamic> map) {
    final creneauxList = map['creneaux'] as List<dynamic>? ?? [];
    final creneaux = creneauxList
        .map((c) => CreneauHoraire.fromMap(c as Map<String, dynamic>))
        .toList();

    return HoraireJour(
      ouvert: map['ouvert'] as bool? ?? false,
      creneaux: creneaux,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ouvert': ouvert,
      'creneaux': creneaux.map((c) => c.toMap()).toList(),
    };
  }
}

class CreneauHoraire {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  CreneauHoraire(this.startHour, this.startMinute, this.endHour, this.endMinute);

  factory CreneauHoraire.fromMap(Map<String, dynamic> map) {
    return CreneauHoraire(
      map['startHour'] as int,
      map['startMinute'] as int,
      map['endHour'] as int,
      map['endMinute'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
    };
  }

  /// Vérifie si les minutes données sont dans ce créneau
  bool contains(int minutes) {
    final start = startHour * 60 + startMinute;
    final end = endHour * 60 + endMinute;
    return minutes >= start && minutes <= end;
  }

  String get startFormatted => '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
  String get endFormatted => '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
}
