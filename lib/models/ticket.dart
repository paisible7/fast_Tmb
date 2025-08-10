import 'package:cloud_firestore/cloud_firestore.dart';

class Ticket {
  final String id;
  final int numero;
  final DateTime createdAt;
  final DateTime? treatedAt;
  final DateTime? startedAt;
  final DateTime? absentAt;
  final DateTime? cancelledAt;
  final String status;
  final String? uid;
  final String? agentId;
  final String? queueType; // 'depot' | 'retrait'
  final int? satisfactionScore; // 1-5 étoiles
  final String? satisfactionComment; // commentaire optionnel
  final String? clientName; // nom pour clients sans smartphone
  final String? clientFirstName; // prénom pour clients sans smartphone
  final bool guest; // true si ticket créé via page sans smartphone

  Ticket({
    required this.id,
    required this.numero,
    required this.createdAt,
    this.treatedAt,
    this.startedAt,
    this.absentAt,
    this.cancelledAt,
    required this.status,
    this.uid,
    this.agentId,
    this.queueType,
    this.satisfactionScore,
    this.satisfactionComment,
    this.clientName,
    this.clientFirstName,
    this.guest = false,
  });

  factory Ticket.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Ticket(
      id: doc.id,
      numero: data['numero'] as int,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      treatedAt: data['treatedAt'] != null
          ? (data['treatedAt'] as Timestamp).toDate()
          : null,
      startedAt: data['startedAt'] != null
          ? (data['startedAt'] as Timestamp).toDate()
          : null,
      absentAt: data['absentAt'] != null
          ? (data['absentAt'] as Timestamp).toDate()
          : null,
      cancelledAt: data['cancelledAt'] != null
          ? (data['cancelledAt'] as Timestamp).toDate()
          : null,
      status: data['status'] as String,
      uid: data['uid'] as String?,
      agentId: data['agentId'] as String?,
      queueType: data['queueType'] as String?,
      satisfactionScore: data['satisfactionScore'] as int?,
      satisfactionComment: data['satisfactionComment'] as String?,
      clientName: data['clientName'] as String?,
      clientFirstName: data['clientFirstName'] as String?,
      guest: data['guest'] as bool? ?? false,
    );
  }
}
