import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl/models/utilisateur.dart';

class AuthServiceV2 with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Utilisateur? _currentUser;
  bool _isInitializing = true;

  AuthServiceV2() {
    print('AuthServiceV2: Initialisation du service d\'authentification');
    _initializeAuth();
  }

  void _initializeAuth() {
    _auth.authStateChanges().listen((User? firebaseUser) async {
      print('AuthServiceV2: Changement d\'état détecté - User: ${firebaseUser?.email ?? "null"}');

      if (firebaseUser == null) {
        print('AuthServiceV2: Utilisateur déconnecté');
        _currentUser = null;

        if (_isInitializing) {
          _isInitializing = false;
          print('AuthServiceV2: Initialisation terminée (utilisateur déconnecté)');
        }

        notifyListeners();
        return;
      }
      else {
        print('AuthServiceV2: Récupération du profil pour ${firebaseUser.email}');
        _currentUser = await _getUserProfile(firebaseUser);
      }
      
      if (_isInitializing) {
        _isInitializing = false;
        print('AuthServiceV2: Initialisation terminée');
      }
      
      print('AuthServiceV2: Diffusion de l\'état utilisateur: ${_currentUser?.role ?? "null"}');
      notifyListeners();
    });
  }

  Future<Utilisateur?> _getUserProfile(User firebaseUser) async {
    try {
      // Tentative de récupération du profil avec timeout court
      final docRef = _firestore.collection('utilisateurs').doc(firebaseUser.uid);
      final doc = await docRef.get().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print('AuthServiceV2: Timeout Firestore - création d\'un utilisateur par défaut');
          throw TimeoutException('Firestore timeout', const Duration(seconds: 3));
        },
      );
      
      if (doc.exists) {
        print('AuthServiceV2: Profil existant trouvé');
        return Utilisateur.fromFirestore(doc);
      } else {
        print('AuthServiceV2: Nouvel utilisateur - création du profil');
        return await _createUserProfile(firebaseUser);
      }
    } catch (e) {
      print('AuthServiceV2: Erreur récupération profil: $e');
      // Créer un utilisateur par défaut en cas d'erreur
      return _createDefaultUser(firebaseUser);
    }
  }

  Future<Utilisateur> _createUserProfile(User firebaseUser) async {
    try {
      final role = firebaseUser.email!.contains('agent') ? 'agent' : 'client';
      
      await _firestore.collection('utilisateurs').doc(firebaseUser.uid).set({
        'email': firebaseUser.email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 3));
      
      print('AuthServiceV2: Nouveau profil créé avec rôle: $role');
      return Utilisateur(
        uid: firebaseUser.uid,
        email: firebaseUser.email!,
        role: role,
      );
    } catch (e) {
      print('AuthServiceV2: Erreur création profil: $e');
      return _createDefaultUser(firebaseUser);
    }
  }

  Utilisateur _createDefaultUser(User firebaseUser) {
    final role = firebaseUser.email!.contains('agent') ? 'agent' : 'client';
    print('AuthServiceV2: Création utilisateur par défaut avec rôle: $role');
    return Utilisateur(
      uid: firebaseUser.uid,
      email: firebaseUser.email!,
      role: role,
    );
  }

  // Getters
  Utilisateur? get currentUser => _currentUser;
  bool get isInitializing => _isInitializing;

  // Méthodes d'authentification
  Future<Utilisateur?> signIn(String email, String password) async {
    try {
      print('AuthServiceV2: Tentative de connexion pour $email...');
      
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        print('AuthServiceV2: Authentification Firebase réussie');
        // L'utilisateur sera automatiquement mis à jour par authStateChanges
        // Attendre un peu pour que l'état soit mis à jour
        await Future.delayed(const Duration(milliseconds: 500));
        return _currentUser;
      }
      
      return null;
    } catch (e) {
      print('AuthServiceV2: Erreur de connexion: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
  //  await FirebaseAuth.instance.signOut();
   // notifyListeners();
    try {
      print('AuthServiceV2: Déconnexion...');
      await _auth.signOut();
      print('AuthServiceV2: Déconnexion réussie');
    } catch (e) {
      print('AuthServiceV2: Erreur de déconnexion: $e');
      rethrow;
    }
  }


  @override
  void dispose() {
    super.dispose();
  }
}
