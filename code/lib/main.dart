// main.dart
import 'package:fast_tmb/pages/client/accueil.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:fast_tmb/services/auth_service_v2.dart';
import 'package:fast_tmb/services/firestore_service.dart';
import 'package:fast_tmb/services/notification_service.dart';
// import 'package:fast_tmb/services/websocket_service.dart';
import 'package:fast_tmb/auth/auth_wrapper.dart';
import 'package:fast_tmb/pages/client/file_en_cours.dart';
import 'package:fast_tmb/pages/client/scan_qr.dart';
import 'package:fast_tmb/pages/client/notifications.dart';
import 'package:fast_tmb/pages/client/parametres.dart';
import 'package:fast_tmb/pages/connexion_page.dart';
import 'package:fast_tmb/pages/agent/tableau_bord_agent.dart';
import 'package:fast_tmb/pages/agent/statistiques_agent.dart';

import 'package:fast_tmb/utils/constantes_couleurs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    /*options: FirebaseOptions(
        apiKey: "AIzaSyAUCW_cUN7nPocgUuxU0IYYfKC6ohT4XsA",
        appId: "1:398834852035:web:534467192582bd26664276",
        messagingSenderId: "398834852035",
        projectId: "fast-app-65ffc"
    )*/
  );


  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await NotificationService().init();
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
          '/scan_qr': (_) => const ScanQrPage(),
          '/notifications': (_) => const NotificationsPage(),
          '/parametres': (_) => const ParametresPage(),
          '/connexion': (_) => const ConnexionPage(),
          '/tableau_bord_agent': (_) => const TableauBordAgentPage(),
          '/statistiques_agent': (_) => const StatistiquesAgentPage(),
          },
      ),
    );
  }
}
