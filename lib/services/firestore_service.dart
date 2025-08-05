import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final CollectionReference _ticketsCollection = _db.collection('tickets');

  static const Duration _dureeMoyenneTraitement = Duration(minutes: 5);

  /// Nombre de tickets en file d'attente
  Stream<int> nombreEnAttenteStream() {
    return _ticketsCollection
        .where('status', isEqualTo: 'en_attente')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Estimation du temps d'attente
  Stream<Duration> tempsAttenteEstimeStream() {
    return nombreEnAttenteStream().map((count) =>
        Duration(minutes: count * _dureeMoyenneTraitement.inMinutes));
  }

  /// Ajoute un nouveau ticket pour l'utilisateur connecté de façon sécurisée (transaction Firestore)
  Future<void> ajouterTicket() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    // Vérifier si l'utilisateur a déjà un ticket actif (en_attente ou en_cours)
    final existing = await _ticketsCollection
        .where('creatorId', isEqualTo: user.uid)
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
        'creatorId': user.uid,
        'creatorEmail': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'en_attente',
        'numero': newNum,
      });
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

  /// Récupère le ticket actif (en attente ou en cours) de l'utilisateur connecté
  Stream<DocumentSnapshot?> monTicketStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _ticketsCollection
        .where('creatorId', isEqualTo: user.uid)
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
    if (user == null) return Stream.empty();
    // Notifications pour tous les rôles (client ou agent)
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Historique quotidien des tickets traités (7 jours par défaut)
  Future<Map<String,int>> historiqueQuotidien({int jours = 7}) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: jours));
    final snap = await _ticketsCollection
        .where('treatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .get();
    final Map<String,int> counts = {};
    for (final doc in snap.docs) {
      final date = (doc['treatedAt'] as Timestamp).toDate();
      final key = '${date.year}-${date.month}-${date.day}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// Passe le prochain ticket en attente à 'en_cours' et l'assigne à l'agent connecté
  Future<void> appelerProchainClient() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');
    // Chercher le prochain ticket en attente
    final snap = await _ticketsCollection
        .where('status', isEqualTo: 'en_attente')
        .orderBy('createdAt')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      throw Exception('Aucun client en attente');
    }
    final doc = snap.docs.first.reference;
    await doc.update({
      'status': 'en_cours',
      'agentId': user.uid,
      'agentEmail': user.email,
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marque le ticket en cours de l'agent comme 'absent'
  Future<void> marquerClientAbsent() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');
    // Chercher le ticket en cours de l'agent
    final snap = await _ticketsCollection
        .where('status', isEqualTo: 'en_cours')
        .where('agentId', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      throw Exception('Aucun client en cours à marquer absent');
    }
    final doc = snap.docs.first.reference;
    await doc.update({
      'status': 'absent',
      'absentAt': FieldValue.serverTimestamp(),
    });
  }

  /// Termine le ticket en cours de l'agent (status 'servi')
  Future<void> terminerServiceClient() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');
    // Chercher le ticket en cours de l'agent
    final snap = await _ticketsCollection
        .where('status', isEqualTo: 'en_cours')
        .where('agentId', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      throw Exception('Aucun client en cours à terminer');
    }
    final doc = snap.docs.first.reference;
    await doc.update({
      'status': 'termine',
      'treatedAt': FieldValue.serverTimestamp(),
    });
  }
}
