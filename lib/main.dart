// main.dart
import 'package:fast_tmb/pages/client/accueil.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fast_tmb/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:fast_tmb/services/auth_service_v2.dart';
import 'package:fast_tmb/services/firestore_service.dart';
// import 'package:fast_tmb/services/websocket_service.dart';
import 'package:fast_tmb/auth/auth_wrapper.dart';
import 'package:fast_tmb/pages/client/file_en_cours.dart';
// TODO(QR): Fonctionnalité Scan/QR désactivée
// import 'package:fast_tmb/pages/client/scan_qr.dart';
import 'package:fast_tmb/pages/client/notifications.dart';
import 'package:fast_tmb/pages/client/parametres.dart';
import 'package:fast_tmb/pages/client/satisfaction_page.dart';
import 'package:fast_tmb/pages/connexion_page.dart';
import 'package:fast_tmb/pages/agent/tableau_bord_agent.dart';
import 'package:fast_tmb/pages/agent/statistiques_agent.dart';
// import 'package:fast_tmb/pages/agent/notifications_agent.dart'; // Désactivé (écran notifications agent)
import 'package:fast_tmb/pages/superagent/statistiques_superagent.dart';
import 'package:fast_tmb/pages/superagent/services_admin_page.dart';
// import 'package:fast_tmb/pages/superagent/agents_admin_page.dart'; // Désactivé provisoirement
import 'package:fast_tmb/pages/superagent/horaires_admin_page.dart';
import 'package:fast_tmb/pages/inscription_page.dart';
import 'package:fast_tmb/pages/public/sans_smartphone_page.dart';

import 'package:fast_tmb/utils/constantes_couleurs.dart';

import 'firebase_options.dart';

// Clé de navigation globale pour les notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    /**/options: DefaultFirebaseOptions.currentPlatform,
    // === n'efface pas les options mise en commentaire ci-dessous == //
/*
      options: FirebaseOptions(
          apiKey: "AIzaSyAUCW_cUN7nPocgUuxU0IYYfKC6ohT4XsA",
          appId: "1:398834852035:web:534467192582bd26664276",
          messagingSenderId: "398834852035",
          projectId: "fast-app-65ffc"
      )
*/
  );

  // Enregistre le handler de notifications FCM en arrière-plan (doit être top-level)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await NotificationService().init();
  
  // Configurer la clé de navigation pour les notifications
  NotificationService.setNavigatorKey(navigatorKey);
  
  runApp(const FastApp());
}

class FastApp extends StatelessWidget {
  const FastApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthServiceV2()),
        Provider(create: (_) => FirestoreService()),
        // Provider(create: (_) => WebSocketService()), // Désactivé car non utilisé et cause une exception
        Provider(create: (_) => NotificationService()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'fast',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: ConstantesCouleurs.orange,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: ConstantesCouleurs.orange,
            foregroundColor: Colors.white,
          ),
          colorScheme: ColorScheme.fromSwatch()
              .copyWith(secondary: ConstantesCouleurs.orange),
          fontFamily: 'Montserrat',
        ),
        home: const AuthWrapper(),
        routes: {
          '/accueil': (_) => const AccueilPage(),
          '/file_en_cours': (_) => const FileEnCoursPage(),
          // TODO(QR): Route désactivée car Scan/QR n'est plus utilisé
          // '/scan_qr': (_) => const ScanQrPage(),
          '/notifications': (_) => const NotificationsPage(),
          '/parametres': (_) => const ParametresPage(),
          '/connexion': (_) => const ConnexionPage(),
          '/inscription': (_) => const InscriptionPage(),
          '/tableau_bord_agent': (_) => const TableauBordAgentPage(),
          // '/notifications_agent': (_) => const NotificationsAgentPage(), // Désactivé (écran notifications agent)
          '/statistiques_agent': (_) => const StatistiquesAgentPage(),
          '/statistiques_superagent': (_) => const StatistiquesSuperAgentPage(),
          '/admin_services': (_) => const ServicesAdminPage(),
          // '/admin_agents': (_) => const AgentsAdminPage(), // Désactivé provisoirement
          '/admin_horaires': (_) => const HorairesAdminPage(),
          '/sans_smartphone': (_) => const SansSmartphonePage(),
        },
        onGenerateRoute: (settings) {
          // Route dynamique pour la page de satisfaction
          if (settings.name?.startsWith('/satisfaction/') == true) {
            final parts = settings.name!.split('/');
            if (parts.length >= 4) {
              final ticketId = parts[2];
              final ticketNumero = parts[3];
              final queueType = parts.length > 4 ? parts[4] : 'depot';
              return MaterialPageRoute(
                builder: (_) => SatisfactionPage(
                  ticketId: ticketId,
                  ticketNumero: ticketNumero,
                  queueType: queueType,
                ),
              );
            }
          }
          return null;
        },
      ),
    );
  }
}
