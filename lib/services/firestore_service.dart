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

  /// Ajoute un nouveau ticket pour l'utilisateur connecté
  Future<void> ajouterTicket() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    // TODO: Ajouter une vérification pour s'assurer que l'utilisateur n'a pas déjà un ticket actif.

    final query = await _ticketsCollection
        .orderBy('numero', descending: true)
        .limit(1)
        .get();
    int nextNumero = 1;
    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data() as Map<String, dynamic>;
      nextNumero = (data['numero'] as int) + 1;
    }

    await _ticketsCollection.add({
      'creatorId': user.uid, // Ajout de l'ID du créateur
      'creatorEmail': user.email, // Optionnel: stocker l'email pour un accès facile
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'en_attente',
      'numero': nextNumero,
    });
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
}
