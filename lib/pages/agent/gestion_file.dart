import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fast_tmb/services/firestore_service.dart';
import 'package:fast_tmb/utils/constantes_couleurs.dart';

class GestionFilePage extends StatefulWidget {
  const GestionFilePage({Key? key}) : super(key: key);

  @override
  State<GestionFilePage> createState() => _GestionFilePageState();
}

class _GestionFilePageState extends State<GestionFilePage> {
  bool _isLoading = false;
  String? _feedback;

  Future<void> _appelSuivant() async {
    setState(() {
      _isLoading = true;
      _feedback = null;
    });
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    try {
      await firestore.appelerProchainClient();
      setState(() => _feedback = 'Client appelé avec succès.');
    } catch (e) {
      setState(() => _feedback = 'Erreur : ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _marquerAbsent() async {
    setState(() {
      _isLoading = true;
      _feedback = null;
    });
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    try {
      await firestore.marquerClientAbsent();
      setState(() => _feedback = 'Client marqué comme absent.');
    } catch (e) {
      setState(() => _feedback = 'Erreur : ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _terminerService() async {
    setState(() {
      _isLoading = true;
      _feedback = null;
    });
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    try {
      await firestore.terminerServiceClient();
      setState(() => _feedback = 'Service terminé.');
    } catch (e) {
      setState(() => _feedback = 'Erreur : ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gérer la file')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_feedback != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_feedback!, style: TextStyle(color: _feedback!.startsWith('Erreur') ? Colors.red : Colors.green)),
              ),
            ElevatedButton(
              onPressed: _isLoading ? null : _appelSuivant,
              style: ElevatedButton.styleFrom(backgroundColor: ConstantesCouleurs.orange),
              child: _isLoading ? const CircularProgressIndicator() : const Text('Appeler Suivant'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _marquerAbsent,
              style: ElevatedButton.styleFrom(backgroundColor: ConstantesCouleurs.orange),
              child: const Text('Marquer Absent'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _terminerService,
              style: ElevatedButton.styleFrom(backgroundColor: ConstantesCouleurs.orange),
              child: const Text('Terminer Service'),
            ),
          ],
        ),
      ),
    );
  }
}
