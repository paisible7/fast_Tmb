import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:fast_tmb/firebase_options.dart';
import 'package:fast_tmb/pages/client/satisfaction_page.dart';

/// Handler global pour notifications FCM en background
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase doit être initialisé dans l'isolement background
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (_) {
    // ignore si déjà initialisé
  }
  // Affiche une notification locale même en background
  final notif = message.notification;
  if (notif == null) return;
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const androidDetails = AndroidNotificationDetails(
    'fast_channel',
    'Notifications Fast',
    channelDescription: 'Notifications de l’app Fast',
    importance: Importance.max,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );
  const iOSDetails = DarwinNotificationDetails();
  final details = NotificationDetails(
    android: androidDetails,
    iOS: iOSDetails,
  );
  await flutterLocalNotificationsPlugin.show(
    notif.hashCode,
    notif.title,
    notif.body,
    details,
    payload: message.data['payload'] as String? ?? '',
  );
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Bottom sheet générique pour afficher le contenu d'une notification dans l'app
  void _showGenericNotificationBottomSheet({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) {
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      // Pas de contexte: fallback notification locale
      showLocalNotification(title, body, data: data);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                if (body.isNotEmpty)
                  Text(
                    body,
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        if (data != null) {
                          _handleNotificationTapData(data);
                        }
                      },
                      child: const Text('Ouvrir'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Méthode publique pour ouvrir un bottom sheet générique depuis l'UI
  void openNotificationBottomSheet({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) {
    _showGenericNotificationBottomSheet(title: title, body: body, data: data);
  }

  // Méthode publique pour ouvrir le bottom sheet d'évaluation depuis d'autres écrans
  void openEvaluationBottomSheet({
    required String ticketId,
    required String numero,
    String queueType = 'depot',
  }) {
    _showEvaluationBottomSheet({
      'type': 'evaluation',
      'ticketId': ticketId,
      'numero': numero,
      'queueType': queueType,
    });
  }

  Future<void> init() async {
    const AndroidInitializationSettings androidInitSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings iosInitSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );
    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final Map<String, dynamic> data = jsonDecode(payload) as Map<String, dynamic>;
          await _handleNotificationTapData(data);
        } catch (e) {
          debugPrint('[NotificationService] Failed to parse notification payload: $e');
        }
      },
    );
    // Demandes de permissions
    await FirebaseMessaging.instance.requestPermission();
    // Android 13+: permission runtime
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'fast_channel',
      'Notifications Fast',
      description: 'Canal pour les notifications de l’application Fast',
      importance: Importance.max,
    );
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // App au premier plan: pas d'ouverture automatique de bottom sheet.
      // Ne montrer des notifications locales que pour certains types côté client.
      final notif = message.notification;
      final data = message.data;
      final type = data['type'] as String?;

      if (type == 'ticket_absent' || type == 'service_termine' || type == 'ticket_called') {
        final title = notif?.title ?? 'Notification';
        final body = notif?.body ?? '';
        debugPrint('[NotificationService] FCM foreground: reçu $type, affichage notification locale');
        await showLocalNotification(title, body, data: data);
      }
      // Ignorer les autres types (ex: ticket_called, queue_update) en foreground côté client.
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      // Handle taps on push notifications when app is brought to foreground
      await _handleNotificationTapData(message.data);
    });

    // Enregistre le token FCM de l'appareil et gère le rafraîchissement
    await _registerAndPersistFcmToken();
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await _persistToken(token);
    });

    // Si l'utilisateur se connecte après l'init, on persiste aussi le token
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        debugPrint('[NotificationService] Auth state changed: User is logged in. Persisting token...');
        await _registerAndPersistFcmToken();
        // Démarre l'écoute des notifications Firestore pour l'utilisateur connecté
        _listenFirestoreNotifications(user.uid);
      }
    });
    // Si déjà connecté, démarre l'écoute
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      _listenFirestoreNotifications(current.uid);
    }
  }

  Future<void> _showNotification(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'fast_channel',
        'Notifications Fast',
        channelDescription: 'Canal pour les notifications de l’application Fast',
        icon: notif.android?.smallIcon ?? '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _flutterLocalNotificationsPlugin.show(
      notif.hashCode,
      notif.title,
      notif.body,
      details,
      // Pass full data map as JSON so we can route on tap
      payload: jsonEncode(message.data),
    );
  }

  Future<void> showLocalNotification(
    String title,
    String body, {
      Map<String, dynamic>? data,
    }) async {
    const androidDetails = AndroidNotificationDetails(
      'fast_channel',
      'Notifications Fast',
      channelDescription: 'Notifications de l’app Fast',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iOSDetails = DarwinNotificationDetails();
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );
    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: data == null ? '' : jsonEncode(data),
    );
  }

  // -- Gestion des tokens FCM --
  Future<void> _registerAndPersistFcmToken() async {
    debugPrint('[NotificationService] Attempting to register and persist FCM token...');
    try {
      String? token;
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        token = await FirebaseMessaging.instance.getToken();
      } else {
        // Web/Desktop: si vous configurez une VAPID key côté Web, vous pouvez l'ajouter ici
        // token = await FirebaseMessaging.instance.getToken(vapidKey: '<VAPID_KEY>');
        token = await FirebaseMessaging.instance.getToken();
      }
      if (token != null) {
        debugPrint('[NotificationService] FCM Token received: $token');
        await _persistToken(token);
      } else {
        debugPrint('[NotificationService] Failed to get FCM token (token is null).');
      }
    } catch (e) {
      debugPrint('[NotificationService] ERROR getting/persisting FCM token: $e');
    }
  }

  Future<void> _persistToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[NotificationService] Cannot persist token, user is null.');
      return;
    }
    debugPrint('[NotificationService] Persisting token for user ${user.uid}...');
    final users = FirebaseFirestore.instance.collection('utilisateurs');
    final tokensCol = users.doc(user.uid).collection('fcmTokens');
    await tokensCol.doc(token).set({
      'token': token,
      'platform': Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : Platform.isMacOS
                  ? 'macos'
                  : 'web',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _listenFirestoreNotifications(String uid) {
    // Afficher une notification locale quand un nouveau doc arrive dans la sous-collection notifications
    FirebaseFirestore.instance
        .collection('utilisateurs')
        .doc(uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docChanges.isEmpty) return;
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final Map<String, dynamic>? data = change.doc.data();
          final title = data?['title'] as String? ?? 'Notification';
          final body = data?['body'] as String? ?? '';
          final notificationData = data?['data'] as Map<String, dynamic>? ?? {};
          final type = notificationData['type'] as String?;
          // Vérifier si c'est une notification d'évaluation (désormais non utilisée pour déclencher le bottom sheet)
          if (type == 'evaluation') {
            // Ne proposer l'évaluation qu'aux clients
            FirebaseFirestore.instance
                .collection('utilisateurs')
                .doc(uid)
                .get()
                .then((doc) {
              final role = (doc.data() as Map<String, dynamic>?)?['role'] as String?;
              if (role == 'client') {
                // pas d'ouverture automatique
              } else {
                // Pour les non-clients, juste une notification locale informative
                showLocalNotification(title, body, data: {
                  'type': 'info',
                });
              }
            });
          } else if (type == 'ticket_absent' || type == 'service_termine' || type == 'ticket_called') {
            // Ne pas ouvrir automatiquement, seulement une notification locale pour ces types
            debugPrint('[NotificationService] Firestore listener: reçu $type, affichage notification locale');
            showLocalNotification(title, body, data: notificationData);
          } else {
            showLocalNotification(title, body);
          }
        }
      }
    });
  }

  // Cache local (mémoire process) des tickets pour lesquels on a déjà montré l'évaluation
  final Set<String> _evaluationShownForTickets = <String>{};

  // Ecoute des changements de tickets du client connecté (désactivé pour l'ouverture auto)
  void startClientServedTicketListener() {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return;
    FirebaseFirestore.instance
        .collection('tickets')
        .where('uid', isEqualTo: current.uid)
        .where('status', isEqualTo: 'servi')
        .orderBy('treatedAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) async {
      if (snap.docChanges.isEmpty) return;
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          final ticketId = change.doc.id;
          // L'ouverture automatique du bottom sheet d'évaluation est désactivée.
          // On peut logguer ou préparer des états si nécessaire, mais aucune UI n'est ouverte ici.
          debugPrint('[NotificationService] Ticket servi détecté (auto UI désactivée): $ticketId');
        }
      }
    });
  }

  Future<void> _handleNotificationTapData(Map<String, dynamic> data) async {
    try {
      final type = data['type'] as String?;
      if (type == 'evaluation') {
        // Only navigate for clients
        final current = FirebaseAuth.instance.currentUser;
        if (current == null) return;
        final userDoc = await FirebaseFirestore.instance.collection('utilisateurs').doc(current.uid).get();
        final role = (userDoc.data() as Map<String, dynamic>?)?['role'] as String?;
        if (role != 'client') return;

        final ticketId = data['ticketId'] as String?;
        final numero = data['numero']?.toString();
        final queueType = (data['queueType'] as String?) ?? 'depot';
        if (ticketId == null) return;
        _navigateToSatisfaction(ticketId: ticketId, numero: numero ?? 'N/A', queueType: queueType);
        return;
      }

      // Navigation pour les autres types informatifs
      if (type == 'ticket_called' || type == 'queue_update' || type == 'service_termine') {
        final current = FirebaseAuth.instance.currentUser;
        if (current == null) return;
        final userDoc = await FirebaseFirestore.instance.collection('utilisateurs').doc(current.uid).get();
        final role = (userDoc.data() as Map<String, dynamic>?)?['role'] as String?;
        if (role == 'client') {
          final context = _navigatorKey?.currentContext;
          if (context != null) {
            Navigator.of(context).pushNamed('/file_en_cours');
          }
        }
        return;
      }
    } catch (e) {
      debugPrint('[NotificationService] _handleNotificationTapData error: $e');
    }
  }

  void _navigateToSatisfaction({required String ticketId, required String numero, required String queueType}) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;
    Navigator.of(context).pushNamed('/satisfaction/$ticketId/$numero');
  }

  void _showEvaluationBottomSheet(Map<String, dynamic> notificationData) {
    // Obtenir le contexte de navigation global
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      debugPrint('Contexte de navigation non disponible pour afficher l\'évaluation');
      return;
    }

    // Extraire les données du ticket
    final ticketId = notificationData['ticketId'] as String?;
    final numero = notificationData['numero'];
    final queueType = notificationData['queueType'] as String?;

    if (ticketId == null) {
      debugPrint('ID de ticket manquant dans la notification d\'évaluation');
      return;
    }

    // Afficher le BottomSheet d'évaluation
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SatisfactionPage(
          ticketId: ticketId,
          ticketNumero: numero?.toString() ?? 'N/A',
          queueType: queueType ?? 'depot',
          showInBottomSheet: true,
        ),
      ),
    );
  }

  // Clé de navigation globale pour accéder au contexte
  static GlobalKey<NavigatorState>? _navigatorKey;
  
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }
}
