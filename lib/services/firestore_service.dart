  import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fast_tmb/services/horaires_service.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ---- LOGGING ERREURS ----
  void _logError(String context, Object e, StackTrace st) {
    if (e is FirebaseException) {
      print('[FirestoreService][ERROR][' + context + '] code=' + e.code + ' message=' + (e.message ?? ''));
    } else {
      print('[FirestoreService][ERROR][' + context + '] ' + e.toString());
    }
    print(st.toString());
  }

  late final CollectionReference _ticketsCollection = _db.collection('tickets');
  late final CollectionReference _servicesCol = _db.collection('services');
  late final CollectionReference _guichetsCol = _db.collection('guichets');
  late final CollectionReference _provisioningCol = _db.collection('provisioning_requests');

  static const Duration _dureeMoyenneTraitement = Duration(minutes: 5);
  // Marge par défaut si aucune configuration Firestore n'est disponible
  static const Duration _margeParDefaut = Duration(minutes: 10);

  /// Calcule l'heure de fermeture du créneau courant à partir des horaires Firestore.
  /// Retourne null si aucun créneau en cours n'est trouvé (ex: fermé maintenant).
  Future<DateTime?> _heureFermetureAujourdHui(DateTime now) async {
    try {
      final horaires = await HorairesService().getHoraires();
      final weekday = now.weekday;
      final key = () {
        switch (weekday) {
          case DateTime.monday:
            return 'lundi';
          case DateTime.tuesday:
            return 'mardi';
          case DateTime.wednesday:
            return 'mercredi';
          case DateTime.thursday:
            return 'jeudi';
          case DateTime.friday:
            return 'vendredi';
          case DateTime.saturday:
            return 'samedi';
          case DateTime.sunday:
            return 'dimanche';
          default:
            return 'lundi';
        }
      }();

      final jour = horaires.jours[key];
      if (jour == null || !jour.ouvert) return null;

      final minutesNow = now.hour * 60 + now.minute;
      // Trouver le créneau qui contient l'heure actuelle
      for (final c in jour.creneaux) {
        final start = c.startHour * 60 + c.startMinute;
        final end = c.endHour * 60 + c.endMinute;
        if (minutesNow >= start && minutesNow <= end) {
          return DateTime(now.year, now.month, now.day, c.endHour, c.endMinute);
        }
      }
      return null;
    } catch (e) {
      // Fallback sur anciens horaires codés en dur si erreur en lecture Firestore
      final wd = now.weekday;
      if (wd == DateTime.sunday) return null;
      if (wd >= DateTime.monday && wd <= DateTime.friday) {
        return DateTime(now.year, now.month, now.day, 15, 30);
      }
      if (wd == DateTime.saturday) {
        return DateTime(now.year, now.month, now.day, 12, 0);
      }
      return null;
    }
  }

  /// Lit la marge (en minutes) depuis settings/app_config.margeMinutes avec fallback 10 min
  Future<Duration> _getMargeAvantFermeture() async {
    try {
      final doc = await _db.collection('settings').doc('app_config').get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final m = (data['margeMinutes'] as num?)?.toInt();
        if (m != null && m >= 0 && m <= 120) {
          return Duration(minutes: m);
        }
      }
    } catch (_) {}
    return _margeParDefaut;
  }

  /// Vérifie que l'utilisateur peut prendre un ticket sans dépasser la fermeture.
  /// Refuse si l'estimation du temps (tous les tickets en attente + le sien + marge) dépasse l'heure de fermeture.
  Future<void> _verifierAvantFermeture(String queueType) async {
    final now = DateTime.now();
    debugPrint('[FirestoreService] Vérification avant fermeture pour queueType: $queueType à ${now.toString()}');
    
    // D'abord, s'assurer que l'émission est autorisée à cet instant
    final ouvertMaintenant = await _isWithinIssuanceHours(now);
    debugPrint('[FirestoreService] Service ouvert maintenant: $ouvertMaintenant');
    if (!ouvertMaintenant) {
      throw Exception('Service fermé: la prise de tickets est indisponible.');
    }
    
    // Heure de fermeture basée sur les horaires Firestore (fallback intégré si erreur)
    final fermeture = await _heureFermetureAujourdHui(now);
    debugPrint('[FirestoreService] Heure de fermeture aujourd\'hui: ${fermeture?.toString() ?? 'null'}');
    if (fermeture == null) {
      debugPrint('[FirestoreService] Pas d\'heure de fermeture définie, autorisation par défaut');
      return; // pas de contrôle possible, on laisse passer
    }
    
    final restant = fermeture.difference(now);
    debugPrint('[FirestoreService] Temps restant avant fermeture: ${restant.inMinutes} minutes');
    if (restant.isNegative) {
      throw Exception('Service fermé: la prise de tickets est indisponible.');
    }
    
    // Nombre de tickets déjà en attente dans cette file
    final enAttenteSnap = await _ticketsCollection
        .where('status', isEqualTo: 'en_attente')
        .where('queueType', isEqualTo: queueType)
        .get();
    final count = enAttenteSnap.docs.length;
    debugPrint('[FirestoreService] Tickets en attente dans la file $queueType: $count');
    
    // Temps nécessaire pour servir tous ceux en attente + le nouveau ticket
    final attenteAvantMoi = Duration(minutes: count * _dureeMoyenneTraitement.inMinutes);
    final tempsPourMonService = _dureeMoyenneTraitement;
    final marge = await _getMargeAvantFermeture();
    final besoinTotal = attenteAvantMoi + tempsPourMonService + marge;
    
    debugPrint('[FirestoreService] Temps nécessaire: attente=${attenteAvantMoi.inMinutes}min + service=${tempsPourMonService.inMinutes}min + marge=${marge.inMinutes}min = ${besoinTotal.inMinutes}min');
    debugPrint('[FirestoreService] Temps disponible: ${restant.inMinutes}min');
    
    if (besoinTotal > restant) {
      final mins = restant.inMinutes;
      debugPrint('[FirestoreService] REFUS: Temps insuffisant (besoin ${besoinTotal.inMinutes}min > disponible ${mins}min)');
      throw Exception('Service bientôt fermé: prise de ticket refusée. Temps restant: ~${mins} min.');
    }
    
    debugPrint('[FirestoreService] AUTORISATION: Temps suffisant pour traiter le ticket');
  }
  
  /// Nombre de tickets en file d'attente (optionnellement par file)
  Stream<int> nombreEnAttenteStream({String? queueType}) {
    Query q = _ticketsCollection.where('status', isEqualTo: 'en_attente');
    if (queueType != null) {
      q = q.where('queueType', isEqualTo: queueType);
    }
    return q.snapshots().map((snap) => snap.docs.length);
  }

  /// S'assure que le document meta/compteur_tickets existe et contient les champs requis.
  /// Ne modifie pas la valeur du compteur existant; ajoute simplement la date si manquante.
  Future<void> ensureCompteurTicketsStructure() async {
    try {
      final metaRef = _db.collection('meta').doc('compteur_tickets');
      final snap = await metaRef.get();
      final todayStr = '${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      if (!snap.exists) {
        await metaRef.set({'last': 0, 'date': todayStr});
        debugPrint('[FirestoreService] meta/compteur_tickets créé automatiquement');
        return;
      }
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) {
        await metaRef.set({'last': 0, 'date': todayStr});
        return;
      }
      if (!data.containsKey('date')) {
        await metaRef.update({'date': todayStr});
        debugPrint('[FirestoreService] Ajout du champ date sur meta/compteur_tickets');
      }
      if (!data.containsKey('last')) {
        await metaRef.update({'last': 0});
        debugPrint('[FirestoreService] Ajout du champ last sur meta/compteur_tickets');
      }
    } catch (e) {
      debugPrint('[FirestoreService] ensureCompteurTicketsStructure erreur: $e');
    }
  }

  /// Nettoie automatiquement les tickets encore en attente des jours précédents
  /// en les marquant comme annulés. À appeler au démarrage des écrans agent/superagent.
  Future<int> nettoyerTicketsAnciensEnAttente() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      // Traiter jusqu'à 500 docs par exécution pour rester sous la limite batch
      final snap = await _ticketsCollection
          .where('status', isEqualTo: 'en_attente')
          .where('createdAt', isLessThan: Timestamp.fromDate(todayStart))
          .limit(500)
          .get();
      if (snap.docs.isEmpty) return 0;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.update(d.reference, {
          'status': 'annule',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledReason': 'expiration_jour',
        });
      }
      await batch.commit();
      debugPrint('[FirestoreService] Nettoyage effectué: ${snap.docs.length} tickets en_attente anciens annulés');
      return snap.docs.length;
    } catch (e) {
      debugPrint('[FirestoreService] Nettoyage tickets anciens échoué: $e');
      return 0;
    }
  }

  /// Estimation du temps d'attente (optionnellement par file)
  Stream<Duration> tempsAttenteEstimeStream({String? queueType}) {
    return nombreEnAttenteStream(queueType: queueType).map((count) =>
        Duration(minutes: count * _dureeMoyenneTraitement.inMinutes));
  }

  Future<bool> _isWithinIssuanceHours(DateTime now) async {
    try {
      final horairesService = HorairesService();
      final horaires = await horairesService.getHoraires();
      return horaires.isOpenNow(now);
    } catch (e) {
      // Fallback sur les horaires par défaut en cas d'erreur
      print('Erreur lors de la vérification des horaires: $e');
      // Horaires par défaut: Lun-Ven 08:00-15:30, Sam 08:00-12:00, fermé Dim
      final wd = now.weekday;
      if (wd == DateTime.sunday) return false;
      final minutes = now.hour * 60 + now.minute;
      bool inRange(int sh, int sm, int eh, int em) {
        final s = sh * 60 + sm;
        final e = eh * 60 + em;
        return minutes >= s && minutes <= e;
      }
      if (wd >= DateTime.monday && wd <= DateTime.friday) {
        return inRange(8, 0, 15, 30);
      }
      if (wd == DateTime.saturday) {
        return inRange(8, 0, 12, 0);
      }
      return false;
    }
  }

  /// Ajoute un nouveau ticket (par défaut file dépôt pour rétro-compatibilité)
  Future<void> ajouterTicket() async {
    return ajouterTicketAvecService('depot');
  }

  /// Ajoute un nouveau ticket avec sélection de file (dépôt/retrait) et vérification des horaires
  Future<void> ajouterTicketAvecService(String queueType) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');
    // Validation stricte du type de file
    final qt = queueType.trim().toLowerCase();
    if (qt.isEmpty || (qt != 'depot' && qt != 'retrait')) {
      throw Exception("Type de service invalide. Veuillez choisir 'depot' ou 'retrait'.");
    }
    // Vérification: ne pas dépasser l'heure de fermeture (inclut la vérification des horaires d'ouverture)
    await _verifierAvantFermeture(qt);
    // Vérifier si l'utilisateur a déjà un ticket actif (en_attente ou en_cours)
    final existing = await _ticketsCollection
        .where('uid', isEqualTo: user.uid)
        .where('status', whereIn: ['en_attente', 'en_cours'])
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('Vous avez déjà un ticket actif.');
    }

    final metaRef = _db.collection('meta').doc('compteur_tickets');

    await _db.runTransaction((transaction) async {
      final metaSnap = await transaction.get(metaRef);
      int lastNum = 0;
      final todayStr = '${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}' ;
      if (metaSnap.exists) {
        final data = metaSnap.data() as Map<String, dynamic>?;
        final savedDate = data?['date'] as String?;
        // Reset if date changed
        if (savedDate == todayStr) {
          lastNum = (data?['last'] ?? 0) as int;
        } else {
          lastNum = 0;
        }
      }
      final newNum = lastNum + 1;
      transaction.set(metaRef, {
        'last': newNum,
        'date': todayStr,
      });
      transaction.set(_ticketsCollection.doc(), {
        'uid': user.uid,
        'creatorEmail': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'en_attente',
        'numero': newNum,
        'queueType': qt, // 'depot' ou 'retrait'
      });
    });
  }

  /// Ajoute un nouveau ticket avec informations d'enregistrement (pour clients sans smartphone)
  Future<void> ajouterTicketAvecEnregistrement({
    required String queueType,
    required String clientName,
    required String clientFirstName,
    required bool guest,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');
    
    // Validation stricte du type de file
    final qt = queueType.trim().toLowerCase();
    if (qt.isEmpty || (qt != 'depot' && qt != 'retrait')) {
      throw Exception("Type de service invalide. Veuillez choisir 'depot' ou 'retrait'.");
    }
    
    // Validation des champs obligatoires
    if (clientName.trim().isEmpty || clientFirstName.trim().isEmpty) {
      throw Exception('Le nom et le prénom sont obligatoires.');
    }
    
    // Vérification: ne pas dépasser l'heure de fermeture (inclut la vérification des horaires d'ouverture)
    await _verifierAvantFermeture(qt);

    // Vérifier si l'utilisateur a déjà un ticket actif
    final existing = await _ticketsCollection
        .where('uid', isEqualTo: user.uid)
        .where('status', whereIn: ['en_attente', 'en_cours'])
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('Un ticket est déjà en cours pour cette session.');
    }

    final metaRef = _db.collection('meta').doc('compteur_tickets');

    await _db.runTransaction((transaction) async {
      final metaSnap = await transaction.get(metaRef);
      int lastNum = 0;
      final todayStr = '${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}' ;
      if (metaSnap.exists) {
        final data = metaSnap.data() as Map<String, dynamic>?;
        final savedDate = data?['date'] as String?;
        if (savedDate == todayStr) {
          lastNum = (data?['last'] ?? 0) as int;
        } else {
          lastNum = 0;
        }
      }
      final newNum = lastNum + 1;
      transaction.set(metaRef, {
        'last': newNum,
        'date': todayStr,
      });
      transaction.set(_ticketsCollection.doc(), {
        'uid': user.uid,
        'creatorEmail': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'en_attente',
        'numero': newNum,
        'queueType': qt,
        'clientName': clientName.trim(),
        'clientFirstName': clientFirstName.trim(),
        'guest': guest,
      });
    });
  }

  /// Annule le ticket actif (en_attente) de l'utilisateur
  Future<void> annulerMonTicketActif() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');
    final snap = await _ticketsCollection
        .where('uid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'en_attente')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      throw Exception("Aucun ticket en attente à annuler");
    }
    await snap.docs.first.reference.update({
      'status': 'annule',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  /// Annule automatiquement le ticket en attente de l'utilisateur si le service est fermé
  /// ou si le ticket est d'un jour précédent.
  /// Ne lève pas d'exception si aucun ticket n'est présent; retourne true si une annulation a eu lieu.
  Future<bool> annulerMonTicketSiServiceFerme({String? raison}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    // Rechercher un ticket en attente
    final snap = await _ticketsCollection
        .where('uid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'en_attente')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return false;
    
    final ticketDoc = snap.docs.first;
    final ticketData = ticketDoc.data() as Map<String, dynamic>;
    final createdAt = (ticketData['createdAt'] as Timestamp?)?.toDate();
    
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    bool shouldCancel = false;
    String cancelReason = 'service_ferme';
    
    // Vérifier si le ticket est d'un jour précédent
    if (createdAt != null && createdAt.isBefore(todayStart)) {
      shouldCancel = true;
      cancelReason = 'expiration_jour';
    } else {
      // Vérifier si le service est actuellement fermé
      final ouvert = await _isWithinIssuanceHours(now);
      if (!ouvert) {
        shouldCancel = true;
        cancelReason = 'service_ferme';
      }
    }
    
    if (shouldCancel) {
      await ticketDoc.reference.update({
        'status': 'annule',
        'cancelledAt': FieldValue.serverTimestamp(),
        // NOTE: ne pas écrire cancelledReason côté client pour respecter les règles
      });
      debugPrint('[FirestoreService] Ticket auto-annulé: $cancelReason');
      return true;
    }
    
    return false;
  }

  /// Récupère le ticket actif (en attente ou en cours) de l'utilisateur connecté
  /// Donne la position de l'utilisateur dans la file d'attente en temps réel.
  Stream<int> maPositionEnTempsReelStream(DocumentSnapshot? monTicket) {
    if (monTicket == null || !monTicket.exists) {
      return Stream.value(0);
    }

    final ticketData = monTicket.data() as Map<String, dynamic>?;
    if (ticketData == null) return Stream.value(0);

    final ticketStatus = ticketData['status'];
    final ticketCreatedAt = ticketData['createdAt'];

    // Si l'utilisateur n'est plus en attente, sa position est 0.
    if (ticketStatus != 'en_attente' || ticketCreatedAt == null) {
      return Stream.value(0);
    }

    // On écoute le nombre de tickets créés avant celui de l'utilisateur.
    return _ticketsCollection
        .where('status', isEqualTo: 'en_attente')
        .where('createdAt', isLessThan: ticketCreatedAt)
        .snapshots()
        .map((snap) => snap.docs.length + 1); // +1 pour une position 1-based
  }

  /// Ajoute une évaluation générale du service bancaire et de l'application
  Future<void> ajouterEvaluationService({
    required int score,
    String? comment,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');
    
    // Seuls les clients peuvent évaluer
    // Si le rôle n'est pas présent (null), on accepte par défaut (assume client)
    final userDoc = await _db.collection('utilisateurs').doc(user.uid).get();
    final userRole = (userDoc.data() as Map<String, dynamic>?)?['role'] as String?;
    if (userRole != null && userRole != 'client') {
      throw Exception('Seuls les clients peuvent effectuer une évaluation');
    }
    
    // Validation du score
    if (score < 1 || score > 5) {
      throw Exception('Le score doit être entre 1 et 5');
    }
    
    // Vérifier s'il y a déjà une évaluation récente (dans les 24h) pour éviter le spam
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));
    
    final recentEvaluations = await _db
        .collection('evaluations_service')
        .where('clientId', isEqualTo: user.uid)
        .where('dateEvaluation', isGreaterThan: Timestamp.fromDate(yesterday))
        .limit(1)
        .get();
    
    if (recentEvaluations.docs.isNotEmpty) {
      throw Exception('Vous avez déjà donné votre avis récemment. Merci !');
    }
    
    // Créer une évaluation générale du service
    await _db.collection('evaluations_service').add({
      'clientId': user.uid,
      'clientEmail': user.email,
      'score': score,
      'commentaire': comment?.trim() ?? '',
      'dateEvaluation': FieldValue.serverTimestamp(),
      'typeEvaluation': 'service_bancaire_et_app',
      'version': '1.0', // Version de l'app pour tracking
    });
    
    debugPrint('[FirestoreService] Évaluation générale du service enregistrée pour ${user.uid}');
  }

  /// Calcule le score moyen des évaluations de service sur une période
  Future<double> calculerSatisfactionMoyenneAgent(String? agentId, {int jours = 7}) async {
    if (agentId == null) return calculerSatisfactionMoyenneGlobale(jours: jours);
    final now = DateTime.now();
    final from = now.subtract(Duration(days: jours));
    // On calcule la moyenne sur les tickets servis par cet agent avec une satisfaction renseignée
    try {
      var q = _ticketsCollection
          .where('agentId', isEqualTo: agentId)
          .where('treatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('satisfactionScore', isGreaterThan: 0);
      // Compatibilité: certains environnements utilisent encore 'termine'
      // Firestore ne supporte pas deux where sur le même champ avec whereIn ET autre filtre,
      // on filtre le status après coup si nécessaire
      final snap = await q.get();
      if (snap.docs.isEmpty) return 0.0;
      int total = 0;
      int count = 0;
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final status = data['status'] as String?;
        if (status == 'servi' || status == 'termine') {
          final score = data['satisfactionScore'] as int? ?? 0;
          if (score > 0) {
            total += score;
            count++;
          }
        }
      }
      if (count == 0) return 0.0;
      return total / count;
    } catch (e, st) {
      _logError('calculerSatisfactionMoyenneAgent', e, st);
      rethrow;
    }
  }

  /// Compte le nombre d'évaluations de service sur une période
  Future<int> compterTicketsAvecSatisfactionAgent(String? agentId, {int jours = 7}) async {
    if (agentId == null) return compterTicketsAvecSatisfactionGlobal(jours: jours);
    final now = DateTime.now();
    final from = now.subtract(Duration(days: jours));
    try {
      var q = _ticketsCollection
          .where('agentId', isEqualTo: agentId)
          .where('treatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('satisfactionScore', isGreaterThan: 0);
      final snap = await q.get();
      if (snap.docs.isEmpty) return 0;
      int count = 0;
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final status = data['status'] as String?;
        if ((status == 'servi' || status == 'termine') && (data['satisfactionScore'] as int? ?? 0) > 0) {
          count++;
        }
      }
      return count;
    } catch (e, st) {
      _logError('compterTicketsAvecSatisfactionAgent', e, st);
      rethrow;
    }
  }

  /// Calcule le score moyen global à partir des tickets (satisfactionScore) sur une période
  Future<double> calculerSatisfactionMoyenneGlobale({int jours = 7}) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: jours));
    try {
      final snap = await _ticketsCollection
          .where('treatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('satisfactionScore', isGreaterThan: 0)
          .get();
      if (snap.docs.isEmpty) return 0.0;
      int total = 0;
      int count = 0;
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final status = data['status'] as String?;
        if (status == 'servi' || status == 'termine') {
          final score = data['satisfactionScore'] as int? ?? 0;
          if (score > 0) {
            total += score;
            count++;
          }
        }
      }
      if (count == 0) return 0.0;
      return total / count;
    } catch (e, st) {
      _logError('calculerSatisfactionMoyenneGlobale', e, st);
      rethrow;
    }
  }

  /// Compte le nombre de tickets avec satisfaction (>0) sur la période
  Future<int> compterTicketsAvecSatisfactionGlobal({int jours = 7}) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: jours));
    try {
      final snap = await _ticketsCollection
          .where('treatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('satisfactionScore', isGreaterThan: 0)
          .get();
      if (snap.docs.isEmpty) return 0;
      int count = 0;
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final status = data['status'] as String?;
        final score = data['satisfactionScore'] as int? ?? 0;
        if ((status == 'servi' || status == 'termine') && score > 0) {
          count++;
        }
      }
      return count;
    } catch (e, st) {
      _logError('compterTicketsAvecSatisfactionGlobal', e, st);
      rethrow;
    }
  }

  /// Calcule la distribution des scores d'évaluation de service (1-5 étoiles)
  /// Optionnellement filtrée par agent, sur les tickets traités sur la période.
  Future<Map<int, int>> getDistributionScoresSatisfaction({int jours = 7, String? agentId}) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: jours));
    var q = _ticketsCollection
        .where('treatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('satisfactionScore', isGreaterThan: 0);
    if (agentId != null) {
      q = q.where('agentId', isEqualTo: agentId);
    }
    final snap = await q.get();
    final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String?;
      if (status != 'servi' && status != 'termine') continue;
      final score = data['satisfactionScore'] as int? ?? 0;
      if (score >= 1 && score <= 5) {
        distribution[score] = (distribution[score] ?? 0) + 1;
      }
    }
    return distribution;
  }

  /// Récupère le ticket actif (en attente ou en cours) de l'utilisateur connecté
  Stream<DocumentSnapshot?> monTicketStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _ticketsCollection
        .where('uid', isEqualTo: user.uid)
        .where('status', whereIn: ['en_attente', 'en_cours'])
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty ? snap.docs.first : null);
  }

  /// Pagination des tickets en attente
  Future<List<QueryDocumentSnapshot>> fetchTicketsPage({
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    Query query = _ticketsCollection
        .where('status', isEqualTo: 'en_attente')
        .orderBy('createdAt')
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snap = await query.get();
    return snap.docs;
  }

  /// Temps moyen d'attente (min)
  Future<double> calculerTempsMoyenAttente() async {
    final snap = await _ticketsCollection
        .where('status', isEqualTo: 'servi')
        .get();
    if (snap.docs.isEmpty) return 0.0;
    final total = snap.docs.fold<int>(0, (sum, doc) {
      final data = doc.data() as Map<String, dynamic>;
      final created = (data['createdAt'] as Timestamp?)?.toDate();
      final started = (data['startedAt'] as Timestamp?)?.toDate();
      if (created == null || started == null) return sum;
      return sum + started.difference(created).inMinutes;
    });
    return total / snap.docs.length;
  }

  /// Récupère le flux de notifications pour l'utilisateur connecté (agent ou client)
  Stream<QuerySnapshot> getNotificationsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _db
        .collection('utilisateurs')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Marque une notification comme lue
  Future<void> marquerNotificationLue(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _db
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      debugPrint('Erreur marquage notification lue: $e');
    }
  }

  /// Envoie une notification Firestore à un utilisateur donné
  Future<void> envoyerNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('[FirestoreService] envoyerNotification: userId=$userId, type=${data?['type']}, title=$title');
      await _db
          .collection('utilisateurs')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'data': data ?? <String, dynamic>{},
      });
      debugPrint('[FirestoreService] Notification ajoutée avec succès dans Firestore');
    } catch (e) {
      debugPrint('[FirestoreService] ERREUR envoi notification: $e');
      rethrow;
    }
  }

  /// Historique quotidien des tickets traités (7 jours par défaut)
  Future<Map<String, int>> historiqueQuotidien({int jours = 7}) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: jours));
    final snap = await _ticketsCollection
        .where('treatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .get();
    final Map<String, int> counts = {};
    for (final doc in snap.docs) {
      final date = (doc['treatedAt'] as Timestamp).toDate();
      final key = '${date.year}-${date.month}-${date.day}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// Passe le prochain ticket en attente à 'en_cours' et l'assigne à l'agent connecté
  /// Si [queueType] est fourni, ne considère que cette file (ex: 'depot' ou 'retrait').
  Future<void> appelerProchainClient({String? queueType}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');
    // Chercher le prochain ticket en attente
    Query query = _ticketsCollection
        .where('status', isEqualTo: 'en_attente')
        .orderBy('createdAt')
        .limit(1);
    if (queueType != null) {
      query = _ticketsCollection
          .where('status', isEqualTo: 'en_attente')
          .where('queueType', isEqualTo: queueType)
          .orderBy('createdAt')
          .limit(1);
    }
    final snap = await query.get();
    if (snap.docs.isEmpty) {
      throw Exception('Aucun client en attente');
    }
    
    final ticketDoc = snap.docs.first;
    final ticketData = ticketDoc.data() as Map<String, dynamic>;
    final ticketId = ticketDoc.id;
    final clientUid = ticketData['uid'] as String?;
    final numero = ticketData['numero']?.toString() ?? 'N/A';
    final queueTypeStr = ticketData['queueType'] as String? ?? 'depot';
    
    // Mettre à jour le ticket
    await ticketDoc.reference.update({
      'status': 'en_cours',
      'agentId': user.uid,
      'agentEmail': user.email,
      'startedAt': FieldValue.serverTimestamp(),
    });
    
    // Envoyer une notification au client appelé
    if (clientUid != null) {
      debugPrint('[FirestoreService] Envoi notification ticket_called à $clientUid pour ticket #$numero');
      await envoyerNotification(
        userId: clientUid,
        title: '🔔 C\'est à votre tour !',
        body: 'Votre ticket #$numero est maintenant appelé. Rendez-vous au guichet.',
        data: {
          'type': 'ticket_called',
          'ticketId': ticketId,
          'numero': numero,
          'queueType': queueTypeStr,
        },
      );
      debugPrint('[FirestoreService] Notification ticket_called envoyée avec succès');
    } else {
      debugPrint('[FirestoreService] ERREUR: clientUid est null, impossible d\'envoyer la notification');
    }
  }

  /// Marque le ticket en cours comme 'absent'.
  /// Si [targetAgentId] est fourni, cible le ticket en cours de cet agent (utilisé par le superagent).
  /// Sinon, si [anyAgent] est true, cible n'importe quel ticket en cours.
  /// Par défaut, cible le ticket en cours de l'agent connecté.
  Future<void> marquerClientAbsent({String? targetAgentId, bool anyAgent = false}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');
    // Chercher le ticket en cours selon la stratégie
    Query q = _ticketsCollection.where('status', isEqualTo: 'en_cours');
    if (targetAgentId != null) {
      q = q.where('agentId', isEqualTo: targetAgentId);
    } else if (!anyAgent) {
      q = q.where('agentId', isEqualTo: user.uid);
    }
    q = q.limit(1);
    final snap = await q.get();
    if (snap.docs.isEmpty) {
      throw Exception('Aucun client en cours à marquer absent');
    }
    final first = snap.docs.first;
    final doc = first.reference;
    final data = first.data() as Map<String, dynamic>;
    await doc.update({
      'status': 'absent',
      'absentAt': FieldValue.serverTimestamp(),
    });
    // Notifier le client qu'il a été marqué absent
    final clientId = data['uid'] as String?;
    final numero = data['numero'];
    final queueType = data['queueType'];
    if (clientId != null && clientId.isNotEmpty) {
      try {
        await envoyerNotification(
          userId: clientId,
          title: '⏰ Vous avez été marqué absent',
          body: 'Votre ticket #$numero a été marqué absent. Vous pouvez reprendre un nouveau ticket si nécessaire.',
          data: {
            'type': 'ticket_absent',
            'ticketId': first.id,
            'numero': numero,
            'queueType': queueType,
          },
        );
      } catch (e) {
        debugPrint('Erreur envoi notification absent: $e');
      }
    }
  }

  /// Termine le ticket en cours (status 'servi').
  /// Si [targetAgentId] est fourni, cible le ticket en cours de cet agent (utilisé par le superagent).
  /// Sinon, si [anyAgent] est true, cible n'importe quel ticket en cours.
  /// Par défaut, cible le ticket en cours de l'agent connecté.
  /// Retourne les informations du ticket terminé pour permettre la redirection vers la satisfaction.
  Future<Map<String, dynamic>?> terminerServiceClient({String? targetAgentId, bool anyAgent = false}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');
    // Chercher le ticket en cours selon la stratégie
    Query q = _ticketsCollection.where('status', isEqualTo: 'en_cours');
    if (targetAgentId != null) {
      q = q.where('agentId', isEqualTo: targetAgentId);
    } else if (!anyAgent) {
      q = q.where('agentId', isEqualTo: user.uid);
    }
    q = q.limit(1);
    final snap = await q.get();
    if (snap.docs.isEmpty) {
      throw Exception('Aucun client en cours à terminer');
    }
    
    final ticketDoc = snap.docs.first;
    final ticketData = ticketDoc.data() as Map<String, dynamic>;
    final doc = ticketDoc.reference;
    
    await doc.update({
      'status': 'servi', // Changé de 'termine' à 'servi' pour correspondre au modèle
      'treatedAt': FieldValue.serverTimestamp(),
    });
    try {
      // Remercier le client (information), l'évaluation sera déclenchée automatiquement côté client
      final clientId = ticketData['uid'] as String?;
      if (clientId != null && clientId.isNotEmpty) {
        await envoyerNotification(
          userId: clientId,
          title: '✅ Service terminé',
          body: 'Merci pour votre visite au guichet.',
          data: {
            'type': 'service_termine',
            'ticketId': ticketDoc.id,
            'numero': ticketData['numero'],
            'queueType': ticketData['queueType'],
          },
        );
        debugPrint('Notification de remerciement envoyée au client $clientId');
      }
    } catch (e) {
      debugPrint('Erreur envoi notification remerciement: $e');
    }
  
    // Retourner les informations du ticket pour la satisfaction
    return {
      'ticketId': ticketDoc.id,
      'numero': ticketData['numero'],
      'uid': ticketData['uid'],
      'queueType': ticketData['queueType'],
    };
  }


  /// Compte les tickets d'un [status] pour une [queueType] donnés sur la journée en cours (heure locale serveur)
  Future<int> compterAujourdHuiParStatusEtFile(String status, String queueType) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    // Champ de date de référence selon le statut
    String dateField;
    switch (status) {
      case 'servi':
        dateField = 'treatedAt';
        break;
      case 'termine': // compatibilité legacy
        dateField = 'treatedAt';
        break;
      case 'absent':
        dateField = 'absentAt';
        break;
      case 'annule':
        dateField = 'cancelledAt';
        break;
      default:
        dateField = 'createdAt';
    }
    final snap = await _ticketsCollection
        .where('status', isEqualTo: status)
        .where('queueType', isEqualTo: queueType)
        .where(dateField, isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();
    return snap.docs.length;
  }

  /// Calcule le temps moyen de traitement (en minutes) pour une file donnée ('depot'/'retrait') sur une fenêtre récente
  Future<double> calculerTempsMoyenTraitementParFile(String queueType, {int jours = 7}) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: jours));
    final snap = await _ticketsCollection
        .where('status', isEqualTo: 'servi')
        .where('queueType', isEqualTo: queueType)
        .where('treatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .get();
    if (snap.docs.isEmpty) return 0.0;
    int totalMinutes = 0;
    int count = 0;
    for (final d in snap.docs) {
      final data = d.data() as Map<String, dynamic>;
      final started = (data['startedAt'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate();
      final treated = (data['treatedAt'] as Timestamp?)?.toDate();
      if (started != null && treated != null) {
        totalMinutes += treated.difference(started).inMinutes;
        count++;
      }
    }
    if (count == 0) return 0.0;
    return totalMinutes / count;
  }

  // =============================
  // Administration Superagent
  // =============================

  // Services
  Stream<QuerySnapshot> streamServices() {
    // On s'appuie sur createdAt (horodatage client) pour l'ordre immédiat,
    // createdAtServer est conservé pour la précision côté serveur
    return _servicesCol.orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> ajouterService(String nom) async {
    await _servicesCol.add({
      'nom': nom,
      'actif': true,
      // Horodatage client pour rendre l'élément visible et ordonnable immédiatement
      'createdAt': Timestamp.now(),
      // Horodatage serveur pour la précision et l'audit
      'createdAtServer': FieldValue.serverTimestamp(),
    });
  }

  Future<void> basculerServiceActif(String serviceId, bool actif) async {
    await _servicesCol.doc(serviceId).update({'actif': actif});
  }

  Future<void> renommerService(String serviceId, String nouveauNom) async {
    try {
      await _servicesCol.doc(serviceId).update({'nom': nouveauNom});
    } catch (e, st) {
      _logError('renommerService('+serviceId+')', e, st);
      rethrow;
    }
  }

  Future<void> supprimerService(String serviceId) async {
    try {
      await _servicesCol.doc(serviceId).delete();
    } catch (e, st) {
      _logError('supprimerService('+serviceId+')', e, st);
      rethrow;
    }
  }

  Future<void> ensureBuiltinServicesIfMissing() async {
    try {
      final ids = ['depot', 'retrait'];
      for (final id in ids) {
        final doc = await _servicesCol.doc(id).get();
        if (!doc.exists) {
          final nom = id == 'depot' ? 'Dépôt' : 'Retrait';
          await _servicesCol.doc(id).set({
            'nom': nom,
            'actif': true,
            'createdAt': DateTime.now(),
            'createdAtServer': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e, st) {
      _logError('ensureBuiltinServicesIfMissing', e, st);
      rethrow;
    }
  }

  // Guichets
  Stream<QuerySnapshot> streamGuichets({String? serviceId}) {
    Query q = _guichetsCol;
    if (serviceId != null) q = q.where('serviceId', isEqualTo: serviceId);
    return q.orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> ajouterGuichet({required String libelle, required String serviceId}) async {
    await _guichetsCol.add({
      'libelle': libelle,
      'serviceId': serviceId,
      'actif': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> basculerGuichetActif(String guichetId, bool actif) async {
    await _guichetsCol.doc(guichetId).update({'actif': actif});
  }

  // Agents
  Stream<QuerySnapshot> streamAgents() {
    return _db.collection('utilisateurs').where('role', isEqualTo: 'agent').snapshots();
  }

  Stream<QuerySnapshot> streamAgentsEtSuperagents() {
    return _db
        .collection('utilisateurs')
        .where('role', whereIn: ['agent', 'superagent'])
        .snapshots();
  }

  Future<void> creerDemandeProvisionAgent({required String email, String? prenom, String? nom}) async {
    // Une Cloud Function écoutera cette collection et créera l'utilisateur Auth + doc utilisateur avec rôle agent
    await _provisioningCol.add({
      'type': 'create_agent',
      'email': email,
      'prenom': prenom,
      'nom': nom,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'by': _auth.currentUser?.uid,
    });
  }

  // =============================
  // Outils pour statistiques avancées (superagent)
  // =============================

  /// Liste les agents (id + email)
  Future<List<Map<String, String?>>> listerAgents() async {
    final snap = await _db.collection('utilisateurs').where('role', isEqualTo: 'agent').get();
    return snap.docs
        .map((d) => {
              'id': d.id,
              'email': (d.data()['email'] as String?) ?? (d.data()['uid'] as String?)
            })
        .toList();
  }

  /// Liste les agents ET superagents (id + email)
  Future<List<Map<String, String?>>> listerAgentsEtSuperagents() async {
    final snap = await _db
        .collection('utilisateurs')
        .where('role', whereIn: ['agent', 'superagent'])
        .get();
    return snap.docs
        .map((d) => {
              'id': d.id,
              'email': (d.data()['email'] as String?) ?? (d.data()['uid'] as String?),
              'role': d.data()['role'] as String?
            })
        .toList();
  }

  /// Compte les tickets par période avec filtres optionnels
  Future<int> compterParPeriode({
    required String status,
    required DateTime from,
    required DateTime to,
    String? queueType,
    String? agentId,
  }) async {
    try {
      String dateField;
      switch (status) {
        case 'servi':
          dateField = 'treatedAt';
          break;
        case 'termine':
          dateField = 'treatedAt';
          break;
        case 'absent':
          dateField = 'absentAt';
          break;
        case 'annule':
          dateField = 'cancelledAt';
          break;
        default:
          dateField = 'createdAt';
      }
      Query q = _ticketsCollection
          .where('status', isEqualTo: status)
          .where(dateField, isGreaterThanOrEqualTo: Timestamp.fromDate(from));
      q = q.where(dateField, isLessThanOrEqualTo: Timestamp.fromDate(to));
      if (queueType != null) q = q.where('queueType', isEqualTo: queueType);
      if (agentId != null) q = q.where('agentId', isEqualTo: agentId);
      final snap = await q.get();
      return snap.docs.length;
    } catch (e, st) {
      _logError('compterParPeriode(status='+status+', queueType='+ (queueType??'null') +', agentId='+ (agentId??'null') +')', e, st);
      rethrow;
    }
  }

  /// Temps moyen de traitement (en minutes) avec filtres optionnels
  Future<double> calculerTempsMoyenTraitementParFiltres({
    required DateTime from,
    required DateTime to,
    String? queueType,
    String? agentId,
  }) async {
    Query q = _ticketsCollection
        .where('status', isEqualTo: 'servi')
        .where('treatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('treatedAt', isLessThanOrEqualTo: Timestamp.fromDate(to));
    if (queueType != null) q = q.where('queueType', isEqualTo: queueType);
    if (agentId != null) q = q.where('agentId', isEqualTo: agentId);
    final snap = await q.get();
    if (snap.docs.isEmpty) return 0.0;
    int totalMinutes = 0;
    int count = 0;
    for (final d in snap.docs) {
      final data = d.data() as Map<String, dynamic>;
      final started = (data['startedAt'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate();
      final treated = (data['treatedAt'] as Timestamp?)?.toDate();
      if (started != null && treated != null) {
        totalMinutes += treated.difference(started).inMinutes;
        count++;
      }
    }
    if (count == 0) return 0.0;
    return totalMinutes / count;
  }

  /// Temps moyen d'attente (en minutes) avec filtres optionnels
  Future<double> calculerTempsMoyenAttenteParFiltres({
    required DateTime from,
    required DateTime to,
    String? queueType,
    String? agentId,
  }) async {
    Query q = _ticketsCollection
        .where('status', isEqualTo: 'servi')
        .where('treatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('treatedAt', isLessThanOrEqualTo: Timestamp.fromDate(to));
    if (queueType != null) q = q.where('queueType', isEqualTo: queueType);
    if (agentId != null) q = q.where('agentId', isEqualTo: agentId);
    final snap = await q.get();
    if (snap.docs.isEmpty) return 0.0;
    int totalMinutes = 0;
    int count = 0;
    for (final d in snap.docs) {
      final data = d.data() as Map<String, dynamic>;
      final created = (data['createdAt'] as Timestamp?)?.toDate();
      final started = (data['startedAt'] as Timestamp?)?.toDate();
      if (created != null && started != null) {
        totalMinutes += started.difference(created).inMinutes;
        count++;
      }
    }
    if (count == 0) return 0.0;
    return totalMinutes / count;
  }

  /// Calcule le temps moyen de traitement (en minutes) pour une file donnée entre [from] et [to]
  Future<double> calculerTempsMoyenTraitementParFileEtPeriode(String queueType, {required DateTime from, required DateTime to}) async {
    final snap = await _ticketsCollection
        .where('status', isEqualTo: 'servi')
        .where('queueType', isEqualTo: queueType)
        .where('treatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('treatedAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .get();
    if (snap.docs.isEmpty) return 0.0;
    int totalMinutes = 0;
    int count = 0;
    for (final d in snap.docs) {
      final data = d.data() as Map<String, dynamic>;
      final started = (data['startedAt'] as Timestamp?)?.toDate();
      final treated = (data['treatedAt'] as Timestamp?)?.toDate();
      // Si pas de startedAt, fallback sur createdAt
      final created = (data['createdAt'] as Timestamp?)?.toDate();
      final start = started ?? created;
      if (start != null && treated != null) {
        totalMinutes += treated.difference(start).inMinutes;
        count++;
      }
    }
    if (count == 0) return 0.0;
    return totalMinutes / count;
  }

  /// Calcule le temps moyen de traitement (en minutes) par agent sur une fenêtre récente
  Future<double> calculerTempsMoyenTraitementParAgent(String agentId, {int jours = 7}) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: jours));
    final snap = await _ticketsCollection
        .where('status', isEqualTo: 'servi')
        .where('agentId', isEqualTo: agentId)
        .where('treatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .get();
    if (snap.docs.isEmpty) return 0.0;
    int totalMinutes = 0;
    int count = 0;
    for (final d in snap.docs) {
      final data = d.data() as Map<String, dynamic>;
      final started = (data['startedAt'] as Timestamp?)?.toDate();
      final treated = (data['treatedAt'] as Timestamp?)?.toDate();
      final created = (data['createdAt'] as Timestamp?)?.toDate();
      final start = started ?? created;
      if (start != null && treated != null) {
        totalMinutes += treated.difference(start).inMinutes;
        count++;
      }
    }
    if (count == 0) return 0.0;
    return totalMinutes / count;
  }

  /// Temps moyen d'attente (en minutes) avant prise en charge, par file, sur une fenêtre récente
  /// Calculé avec startedAt - createdAt (tickets terminés)
  Future<double> calculerTempsMoyenAttenteParFile(String queueType, {int jours = 7}) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: jours));
    final snap = await _ticketsCollection
        .where('status', isEqualTo: 'servi')
        .where('queueType', isEqualTo: queueType)
        .where('treatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .get();
    if (snap.docs.isEmpty) return 0.0;
    int totalMinutes = 0;
    int count = 0;
    for (final d in snap.docs) {
      final data = d.data() as Map<String, dynamic>;
      final created = (data['createdAt'] as Timestamp?)?.toDate();
      final started = (data['startedAt'] as Timestamp?)?.toDate();
      if (created != null && started != null) {
        totalMinutes += started.difference(created).inMinutes;
        count++;
      }
    }
    if (count == 0) return 0.0;
    return totalMinutes / count;
  }

  /// Temps moyen d'attente (en minutes) avant prise en charge, par agent, sur une fenêtre récente
  Future<double> calculerTempsMoyenAttenteParAgent(String agentId, {int jours = 7}) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: jours));
    final snap = await _ticketsCollection
        .where('status', isEqualTo: 'servi')
        .where('agentId', isEqualTo: agentId)
        .where('treatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .get();
    if (snap.docs.isEmpty) return 0.0;
    int totalMinutes = 0;
    int count = 0;
    for (final d in snap.docs) {
      final data = d.data() as Map<String, dynamic>;
      final created = (data['createdAt'] as Timestamp?)?.toDate();
      final started = (data['startedAt'] as Timestamp?)?.toDate();
      if (created != null && started != null) {
        totalMinutes += started.difference(created).inMinutes;
        count++;
      }
    }
    if (count == 0) return 0.0;
    return totalMinutes / count;
  }
}
