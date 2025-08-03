import 'package:cloud_firestore/cloud_firestore.dart';

class Utilisateur {
  final String uid;
  final String email;
  final String role;

  Utilisateur({
    required this.uid,
    required this.email,
    this.role = 'client',
  });

  factory Utilisateur.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Utilisateur(
      uid: doc.id,
      email: data['email'] ?? '',
      role: data['role'] ?? 'client',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
    };
  }
}
