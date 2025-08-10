import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fast_tmb/services/firestore_service.dart';
import 'package:fast_tmb/widgets/barre_navigation.dart';
import 'package:fast_tmb/widgets/role_guard.dart';

class AgentsAdminPage extends StatefulWidget {
  const AgentsAdminPage({Key? key}) : super(key: key);

  @override
  State<AgentsAdminPage> createState() => _AgentsAdminPageState();
}

class _AgentsAdminPageState extends State<AgentsAdminPage> {
  final _emailCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    super.dispose();
  }

  Future<void> _provisionner() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() => _loading = true);
    try {
      await Provider.of<FirestoreService>(context, listen: false)
          .creerDemandeProvisionAgent(email: email, prenom: _prenomCtrl.text.trim().isEmpty ? null : _prenomCtrl.text.trim(), nom: _nomCtrl.text.trim().isEmpty ? null : _nomCtrl.text.trim());
      _emailCtrl.clear();
      _prenomCtrl.clear();
      _nomCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande de création envoyée'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    return RoleGuard(
      allowedRoles: const ['superagent'],
      child: Scaffold(
        appBar: AppBar(title: const Text('Administration - Agents')),
        bottomNavigationBar: const BarreNavigation(),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Provisionner un nouvel agent', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')), 
              Row(children: [
                Expanded(child: TextField(controller: _prenomCtrl, decoration: const InputDecoration(labelText: 'Prénom'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _nomCtrl, decoration: const InputDecoration(labelText: 'Nom'))),
              ]),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: _loading ? null : _provisionner,
                  child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Envoyer demande'),
                ),
              ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Liste des agents'),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: fs.streamAgents(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text('Aucun agent'));
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final data = d.data() as Map<String, dynamic>;
                      final email = data['email'] ?? d.id;
                      final nom = [data['prenom'], data['nom']].where((e) => (e as String?)?.isNotEmpty == true).join(' ');
                      return ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(nom.isEmpty ? email : '$nom · $email'),
                        subtitle: Text('ID: ${d.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
