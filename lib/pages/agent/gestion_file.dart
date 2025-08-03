// pages/agent/gestion_file.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/services/websocket_service.dart';
import 'package:flutter_application_1/utils/constantes_couleurs.dart';

class GestionFilePage extends StatefulWidget {
  const GestionFilePage({Key? key}) : super(key: key);

  @override
  State<GestionFilePage> createState() => _GestionFilePageState();
}

class _GestionFilePageState extends State<GestionFilePage> {
  late WebSocketService ws;

  @override
  void initState() {
    super.initState();
    ws = Provider.of<WebSocketService>(context, listen: false);
  }

  void _envoyerCommande(String action) {
    ws.send({'action': action});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gérer la file')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () => _envoyerCommande('suivant'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: ConstantesCouleurs.orange),
              child: const Text('Suivant'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _envoyerCommande('absent'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: ConstantesCouleurs.orange),
              child: const Text('Absent'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _envoyerCommande('termine'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: ConstantesCouleurs.orange),
              child: const Text('Terminé'),
            ),
          ],
        ),
      ),
    );
  }
}
