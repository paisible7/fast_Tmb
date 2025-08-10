import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fast_tmb/models/utilisateur.dart';

class AuthServiceV2 with ChangeNotifier {
  /// Inscription d'un nouvel utilisateur (client par défaut)
  Future<Utilisateur?> signUp(String email, String password, {required String prenom, required String nom}) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user == null) return null;
      // Création du profil Firestore (rôle client par défaut)
      await _firestore.collection('utilisateurs').doc(user.uid).set({
        'email': email,
        'prenom': prenom,
        'nom': nom,
        'role': 'client',
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('AuthServiceV2: Utilisateur inscrit et profil créé');
      return Utilisateur(uid: user.uid, email: email, role: 'client');
    } on FirebaseAuthException catch (e) {
      print('AuthServiceV2: Erreur FirebaseAuth lors de l\'inscription: $e');
      rethrow;
    } catch (e) {
      print('AuthServiceV2: Erreur lors de l\'inscription: $e');
      rethrow;
    }
  }

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
        // Ne pas changer _isInitializing ici car on peut être en cours de reconnexion
      } else {
        print('AuthServiceV2: Récupération du profil pour ${firebaseUser.email}');
        _currentUser = await _getUserProfile(firebaseUser);
      }
      
      // Toujours marquer l'initialisation comme terminée après traitement
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
        // Ne pas créer automatiquement de profil ici.
        // Les clients sont créés via signUp(), les agents/superagents doivent être provisionnés manuellement.
        print('AuthServiceV2: Aucun profil Firestore — rôle inconnu (éviter redirection erronée)');
        return Utilisateur(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          role: 'unknown',
        );
      }
    } catch (e) {
      print('AuthServiceV2: Erreur récupération profil: $e');
      // En cas d'erreur, retourner un utilisateur avec rôle 'unknown' pour éviter une mauvaise redirection
      return Utilisateur(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        role: 'unknown',
      );
    }
  }

  // ignore: unused_element
  Utilisateur _createDefaultUser(User firebaseUser) {
    // Utilisé seulement par signUp() pour créer un client par défaut
    const role = 'client';
    print('AuthServiceV2: Création utilisateur par défaut (non persistant) avec rôle: $role (signup uniquement)');
    return Utilisateur(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
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
        
        // Attendre que authStateChanges traite le changement d'état
        print('AuthServiceV2: Attente de la mise à jour de l\'état...');
        int attempts = 0;
        while (_currentUser == null && attempts < 20) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
          if (attempts % 5 == 0) {
            print('AuthServiceV2: Tentative $attempts/20 - currentUser: ${_currentUser?.email ?? "null"}');
          }
        }
        
        if (_currentUser == null) {
          print('AuthServiceV2: TIMEOUT - récupération manuelle du profil');
          _currentUser = await _getUserProfile(credential.user!);
          print('AuthServiceV2: Profil récupéré manuellement: ${_currentUser?.email} (${_currentUser?.role})');
          notifyListeners();
        }
        
        print('AuthServiceV2: Connexion terminée - User: ${_currentUser?.email} (${_currentUser?.role})');
        return _currentUser;
      }
      
      return null;
    } catch (e) {
      print('AuthServiceV2: Erreur de connexion: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      print('AuthServiceV2: 🚪 Déconnexion...');
      await _auth.signOut();
      
      // Forcer la mise à jour de l'état
      _currentUser = null;
      print('AuthServiceV2: ✅ Déconnexion réussie - état nettoyé');
      notifyListeners();
    } catch (e) {
      print('AuthServiceV2: ❌ Erreur de déconnexion: $e');
      rethrow;
    }
  }
  
  // Méthode pour forcer la réinitialisation (utile pour debug)
  void forceRefresh() {
    print('AuthServiceV2: 🔄 Forçage de la mise à jour...');
    final currentFirebaseUser = _auth.currentUser;
    if (currentFirebaseUser != null) {
      _getUserProfile(currentFirebaseUser).then((user) {
        _currentUser = user;
        notifyListeners();
      });
    } else {
      _currentUser = null;
      notifyListeners();
    }
  }


  @override
  void dispose() {
    super.dispose();
  }
}
