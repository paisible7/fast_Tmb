import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

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
      onDidReceiveNotificationResponse: (payload) {},
    );
    await FirebaseMessaging.instance.requestPermission();
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
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotification(message);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {});
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
      payload: message.data['payload'] as String? ?? '',
    );
  }

  Future<void> showLocalNotification(
      String title,
      String body, {
        String? payload,
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
      payload: payload ?? '',
    );
  }
}
