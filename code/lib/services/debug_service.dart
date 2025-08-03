import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DebugService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Test la connectivité Firestore
  static Future<void> testFirestoreConnectivity() async {
    try {
      print('DEBUG: Test de connectivité Firestore...');
      
      // Test simple d'écriture/lecture
      final testDoc = _firestore.collection('test').doc('connectivity');
      await testDoc.set({'timestamp': FieldValue.serverTimestamp()});
      print('DEBUG: ✅ Écriture Firestore réussie');
      
      final snapshot = await testDoc.get();
      if (snapshot.exists) {
        print('DEBUG: ✅ Lecture Firestore réussie');
        await testDoc.delete();
        print('DEBUG: ✅ Suppression Firestore réussie');
      }
    } catch (e) {
      print('DEBUG: ❌ Erreur Firestore: $e');
    }
  }

  /// Test la récupération du profil utilisateur
  static Future<void> testUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('DEBUG: ❌ Aucun utilisateur connecté');
        return;
      }

      print('DEBUG: Test récupération profil pour ${user.email} (UID: ${user.uid})');
      
      // Vérifier si le document existe
      final docRef = _firestore.collection('utilisateurs').doc(user.uid);
      final snapshot = await docRef.get();
      
      if (snapshot.exists) {
        print('DEBUG: ✅ Document utilisateur existe');
        print('DEBUG: Données: ${snapshot.data()}');
      } else {
        print('DEBUG: ❌ Document utilisateur n\'existe pas');
        print('DEBUG: Tentative de création...');
        
        final role = user.email!.contains('agent') ? 'agent' : 'client';
        await docRef.set({
          'email': user.email,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        print('DEBUG: ✅ Document utilisateur créé avec rôle: $role');
      }
    } catch (e) {
      print('DEBUG: ❌ Erreur récupération profil: $e');
    }
  }

  /// Test complet
  static Future<void> runFullDiagnostic() async {
    print('DEBUG: === DIAGNOSTIC COMPLET ===');
    await testFirestoreConnectivity();
    await testUserProfile();
    print('DEBUG: === FIN DIAGNOSTIC ===');
  }
}
