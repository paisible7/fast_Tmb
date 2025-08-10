import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fast_tmb/services/horaires_service.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final CollectionReference _ticketsCollection = _db.collection('tickets');
  late final CollectionReference _servicesCol = _db.collection('services');
  late final CollectionReference _guichetsCol = _db.collection('guichets');
  late final CollectionReference _provisioningCol = _db.collection('provisioning_requests');

  static const Duration _dureeMoyenneTraitement = Duration(minutes: 5);

  /// Nombre de tickets en file d'attente (optionnellement par file)
  Stream<int> nombreEnAttenteStream({String? queueType}) {
    Query q = _ticketsCollection.where('status', isEqualTo: 'en_attente');
    if (queueType != null) {
      q = q.where('queueType', isEqualTo: queueType);
    }
    return q.snapshots().map((snap) => snap.docs.length);
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
    if (!await _isWithinIssuanceHours(DateTime.now())) {
      throw Exception('La délivrance des tickets est fermée pour le moment.');
    }

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
      int lastNum = metaSnap.exists ? (metaSnap.data()?['last'] ?? 0) as int : 0;
      int newNum = lastNum + 1;
      transaction.set(metaRef, {'last': newNum});
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
    
    if (!await _isWithinIssuanceHours(DateTime.now())) {
      throw Exception('La délivrance des tickets est fermée pour le moment.');
    }

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
      int lastNum = metaSnap.exists ? (metaSnap.data()?['last'] ?? 0) as int : 0;
      int newNum = lastNum + 1;
      transaction.set(metaRef, {'last': newNum});
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

  /// Ajoute une évaluation de satisfaction à un ticket
  Future<void> ajouterSatisfaction({
    required String ticketId,
    required int score,
    String? comment,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');
    // Seuls les clients peuvent évaluer
    final userDoc = await _db.collection('utilisateurs').doc(user.uid).get();
    final userRole = (userDoc.data() as Map<String, dynamic>?)?['role'] as String?;
    if (userRole != 'client') {
      throw Exception('Seuls les clients peuvent effectuer une évaluation');
    }
    
    // Validation du score
    if (score < 1 || score > 5) {
      throw Exception('Le score doit être entre 1 et 5');
    }
    
    // Vérifier que le ticket existe et appartient à l'utilisateur
    final ticketDoc = await _ticketsCollection.doc(ticketId).get();
    if (!ticketDoc.exists) {
      throw Exception('Ticket introuvable');
    }
    
    final ticketData = ticketDoc.data() as Map<String, dynamic>;
    if (ticketData['uid'] != user.uid) {
      throw Exception('Vous n\'avez pas l\'autorisation d\'évaluer ce ticket');
    }
    
    // Vérifier que le ticket est terminé
    final status = ticketData['status'] as String?;
    if (status != 'servi') {
      throw Exception('Seuls les tickets terminés peuvent être évalués');
    }
    
    // Vérifier qu'il n'y a pas déjà une évaluation
    if (ticketData.containsKey('satisfactionScore')) {
      throw Exception('Ce ticket a déjà été évalué');
    }
    
    // Ajouter l'évaluation
    await _ticketsCollection.doc(ticketId).update({
      'satisfactionScore': score,
      'satisfactionComment': comment?.trim() ?? '',
      'satisfactionAt': FieldValue.serverTimestamp(),
    });
  }

  /// Calcule le score moyen de satisfaction pour un agent sur une période
  Future<double> calculerSatisfactionMoyenneAgent(String agentId, {int jours = 7}) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: jours));
    
    final snap = await _ticketsCollection
        .where('status', isEqualTo: 'servi')
        .where('agentId', isEqualTo: agentId)
        .where('satisfactionAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('satisfactionScore', isGreaterThan: 0)
        .get();
    
    if (snap.docs.isEmpty) return 0.0;
    
    int totalScore = 0;
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalScore += (data['satisfactionScore'] as int? ?? 0);
    }
    
    return totalScore / snap.docs.length;
  }

  /// Compte le nombre de tickets avec évaluation de satisfaction pour un agent
  Future<int> compterTicketsAvecSatisfactionAgent(String agentId, {int jours = 7}) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: jours));
    
    final snap = await _ticketsCollection
        .where('status', isEqualTo: 'servi')
        .where('agentId', isEqualTo: agentId)
        .where('satisfactionAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('satisfactionScore', isGreaterThan: 0)
        .get();
    
    return snap.docs.length;
  }

  /// Calcule le score moyen de satisfaction global sur une période
  Future<double> calculerSatisfactionMoyenneGlobale({int jours = 7}) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: jours));
    
    final snap = await _ticketsCollection
        .where('status', isEqualTo: 'servi')
        .where('satisfactionAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('satisfactionScore', isGreaterThan: 0)
        .get();
    
    if (snap.docs.isEmpty) return 0.0;
    
    int totalScore = 0;
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalScore += (data['satisfactionScore'] as int? ?? 0);
    }
    
    return totalScore / snap.docs.length;
  }

  /// Compte le nombre total de tickets avec évaluation de satisfaction
  Future<int> compterTicketsAvecSatisfactionGlobal({int jours = 7}) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: jours));
    
    final snap = await _ticketsCollection
        .where('status', isEqualTo: 'servi')
        .where('satisfactionAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('satisfactionScore', isGreaterThan: 0)
        .get();
    
    return snap.docs.length;
  }

  /// Calcule la distribution des scores de satisfaction (1-5 étoiles)
  Future<Map<int, int>> getDistributionScoresSatisfaction({int jours = 7, String? agentId}) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: jours));
    
    Query query = _ticketsCollection
        .where('status', isEqualTo: 'servi')
        .where('satisfactionAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('satisfactionScore', isGreaterThan: 0);
    
    if (agentId != null) {
      query = query.where('agentId', isEqualTo: agentId);
    }
    
    final snap = await query.get();
    
    final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
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
        .where('status', isEqualTo: 'termine')
        .get();
    if (snap.docs.isEmpty) return 0.0;
    final total = snap.docs.fold<int>(0, (sum, doc) {
      final data = doc.data() as Map<String, dynamic>;
      final start = (data['createdAt'] as Timestamp).toDate();
      final end   = (data['treatedAt'] as Timestamp).toDate();
      return sum + end.difference(start).inMinutes;
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
        .where('status', isEqualTo: 'termine')
        .where('queueType', isEqualTo: queueType)
        .where('treatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .get();
    if (snap.docs.isEmpty) return 0.0;
    int totalMinutes = 0;
    int count = 0;
    for (final d in snap.docs) {
      final data = d.data() as Map<String, dynamic>;
      final created = (data['createdAt'] as Timestamp?)?.toDate();
      final treated = (data['treatedAt'] as Timestamp?)?.toDate();
      if (created != null && treated != null) {
        totalMinutes += treated.difference(created).inMinutes;
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
    return _servicesCol.orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> ajouterService(String nom) async {
    await _servicesCol.add({
      'nom': nom,
      'actif': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> basculerServiceActif(String serviceId, bool actif) async {
    await _servicesCol.doc(serviceId).update({'actif': actif});
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

  /// Compte les tickets par période avec filtres optionnels
  Future<int> compterParPeriode({
    required String status,
    required DateTime from,
    required DateTime to,
    String? queueType,
    String? agentId,
  }) async {
    String dateField;
    switch (status) {
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
    Query q = _ticketsCollection.where('status', isEqualTo: status).where(
        dateField, isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    q = q.where(dateField, isLessThanOrEqualTo: Timestamp.fromDate(to));
    if (queueType != null) q = q.where('queueType', isEqualTo: queueType);
    if (agentId != null) q = q.where('agentId', isEqualTo: agentId);
    final snap = await q.get();
    return snap.docs.length;
  }

  /// Temps moyen de traitement (en minutes) avec filtres optionnels
  Future<double> calculerTempsMoyenTraitementParFiltres({
    required DateTime from,
    required DateTime to,
    String? queueType,
    String? agentId,
  }) async {
    Query q = _ticketsCollection
        .where('status', isEqualTo: 'termine')
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
        .where('status', isEqualTo: 'termine')
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
        .where('status', isEqualTo: 'termine')
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
        .where('status', isEqualTo: 'termine')
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
        .where('status', isEqualTo: 'termine')
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
        .where('status', isEqualTo: 'termine')
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
