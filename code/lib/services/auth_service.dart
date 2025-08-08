import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fast_tmb/models/utilisateur.dart';
import 'package:fast_tmb/services/debug_service.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StreamController<Utilisateur?> _userController = StreamController<Utilisateur?>.broadcast();

  Utilisateur? _currentUser;
  Completer<Utilisateur?>? _signInCompleter;
  bool _isInitializing = true;

  AuthService() {
    print('AuthService: Initialisation du service d\'authentification');
    _auth.authStateChanges().listen((User? firebaseUser) async {
      print('AuthService: Changement d\'état détecté - User: ${firebaseUser?.email ?? "null"}');
      
      if (firebaseUser == null) {
        print('AuthService: Utilisateur déconnecté');
        _currentUser = null;
        // Nettoyage du completer si besoin
        if (_signInCompleter != null && !_signInCompleter!.isCompleted) {
          _signInCompleter!.complete(null);
          _signInCompleter = null;
        }
      
      } else {
        try {
          print('AuthService: Récupération du profil pour ${firebaseUser.email}');
          print('AuthService: UID utilisateur: ${firebaseUser.uid}');
          
          // Diagnostic complet en cas de problème
          await DebugService.runFullDiagnostic();
          
          DocumentSnapshot doc = await _firestore.collection('utilisateurs').doc(firebaseUser.uid).get();
          
          if (doc.exists) {
            print('AuthService: Profil existant trouvé');
            _currentUser = Utilisateur.fromFirestore(doc);
            print('AuthService: Rôle récupéré: ${_currentUser!.role}');
          } else {
            print('AuthService: Nouvel utilisateur détecté. Création du document dans Firestore...');
            final role = firebaseUser.email!.contains('agent') ? 'agent' : 'client';
            print('AuthService: Rôle attribué: $role');
            
            await _firestore.collection('utilisateurs').doc(firebaseUser.uid).set({
              'email': firebaseUser.email,
              'role': role,
            });
            
            DocumentSnapshot newDoc = await _firestore.collection('utilisateurs').doc(firebaseUser.uid).get();
            _currentUser = Utilisateur.fromFirestore(newDoc);
            print('AuthService: Nouveau profil créé avec rôle: ${_currentUser!.role}');
          }
        } catch (e) {
          print('AuthService: ERREUR lors de la récupération du profil: $e');
          print('AuthService: Type d\'erreur: ${e.runtimeType}');
          
          // En cas d'erreur, créer un utilisateur avec un rôle par défaut
          print('AuthService: Création d\'un utilisateur par défaut...');
          try {
            final role = firebaseUser.email!.contains('agent') ? 'agent' : 'client';
            _currentUser = Utilisateur(
              uid: firebaseUser.uid,
              email: firebaseUser.email!,
              role: role,
            );
            print('AuthService: Utilisateur par défaut créé avec rôle: $role');
          } catch (defaultError) {
            print('AuthService: Impossible de créer un utilisateur par défaut: $defaultError');
            _currentUser = null;
          }
        }
      }
      
      if (_isInitializing) {
        _isInitializing = false;
      }
      print('AuthService: Diffusion de l\'état utilisateur: ${_currentUser?.role ?? "null"}');
      _userController.add(_currentUser);
      notifyListeners();
      
      // Si on attend une connexion, on complète le Future
      if (_signInCompleter != null && !_signInCompleter!.isCompleted) {
        _signInCompleter!.complete(_currentUser);
        _signInCompleter = null;
      }
    });
  }

  Stream<Utilisateur?> get userStream => _userController.stream;
  Utilisateur? get currentUser => _currentUser;
  bool get isInitializing => _isInitializing;

  Future<Utilisateur?> signIn(String email, String password) async {
    try {
      print('AuthService: Tentative de connexion pour $email...');
      
      // Créer un Completer pour attendre que le profil soit récupéré
      _signInCompleter = Completer<Utilisateur?>();
      
      // Lancer l'authentification
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      print('AuthService: Authentification Firebase réussie, attente du profil...');
      
      // Attendre que l'écouteur authStateChanges termine son travail
      final result = await _signInCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('AuthService: TIMEOUT - Le profil utilisateur n\'a pas pu être récupéré');
          return null;
        },
      );
      
      print('AuthService: Connexion terminée avec succès. Rôle: ${result?.role ?? "null"}');
      return result;
    } catch (e) {
      print('AuthService: ERREUR DANS SIGNIN: ${e.toString()}');
      _signInCompleter = null;
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    // Nettoyage manuel du state
    _currentUser = null;
    _userController.add(null);
    if (_signInCompleter != null && !_signInCompleter!.isCompleted) {
      _signInCompleter!.complete(null);
      _signInCompleter = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    print('AuthService: Nettoyage des ressources');
    _userController.close();
    _signInCompleter = null;
    super.dispose();
  }
}
