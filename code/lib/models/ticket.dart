import 'package:cloud_firestore/cloud_firestore.dart';

class Ticket {
  final String id;
  final int numero;
  final DateTime createdAt;
  final DateTime? treatedAt;
  final String status;
  final String? uid;

  Ticket({
    required this.id,
    required this.numero,
    required this.createdAt,
    this.treatedAt,
    required this.status,
    this.uid,
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
      status: data['status'] as String,
      uid: data['uid'] as String?,
    );
  }
}
