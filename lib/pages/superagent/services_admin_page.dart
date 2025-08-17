import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fast_tmb/services/firestore_service.dart';
import 'package:fast_tmb/widgets/barre_navigation.dart';
import 'package:fast_tmb/widgets/role_guard.dart';

class ServicesAdminPage extends StatefulWidget {
  const ServicesAdminPage({Key? key}) : super(key: key);

  @override
  State<ServicesAdminPage> createState() => _ServicesAdminPageState();
}

class _ServicesAdminPageState extends State<ServicesAdminPage> {
  final _nomCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nomCtrl.dispose();
    super.dispose();
  }

  Future<void> _ajouter() async {
    final nom = _nomCtrl.text.trim();
    if (nom.isEmpty) return;
    setState(() => _loading = true);
    try {
      await Provider.of<FirestoreService>(context, listen: false).ajouterService(nom);
      _nomCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service ajouté'), backgroundColor: Colors.green));
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
        appBar: AppBar(title: const Text('Administration - Services')),
        bottomNavigationBar: const BarreNavigation(),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _nomCtrl,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _loading ? null : _ajouter(),
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nom du service',
                      hintText: 'Ex: Dépôt, Retrait, Informations…',
                      helperText: 'Saisissez le nom du service puis appuyez sur Ajouter ou Entrée',
                      prefixIcon: Icon(Icons.add_business_outlined),
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _ajouter,
                  icon: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add),
                  label: const Text('Ajouter'),
                )
              ]),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: fs.streamServices(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text('Aucun service'));
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final d = docs[i];
                        final data = d.data() as Map<String, dynamic>;
                        final nom = (data['nom'] as String?) ?? d.id;
                        final actif = (data['actif'] as bool?) ?? false;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: actif ? Colors.green.shade50 : Colors.grey.shade200,
                            child: Icon(actif ? Icons.check_circle : Icons.pause_circle_filled, color: actif ? Colors.green : Colors.grey),
                          ),
                          title: Text(nom),
                          subtitle: Text(actif ? 'Actif' : 'Inactif'),
                          trailing: Wrap(spacing: 8, children: [
                            IconButton(
                              tooltip: 'Renommer',
                              icon: const Icon(Icons.edit),
                              onPressed: () async {
                                final ctrl = TextEditingController(text: nom);
                                final res = await showDialog<String>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Renommer le service'),
                                    content: TextField(
                                      controller: ctrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Nom',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                                      ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Enregistrer')),
                                    ],
                                  ),
                                );
                                if (res != null && res.isNotEmpty && res != nom) {
                                  try {
                                    await fs.renommerService(d.id, res);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                                  }
                                }
                              },
                            ),
                            Switch(
                              value: actif,
                              onChanged: (v) async {
                                try {
                                  await fs.basculerServiceActif(d.id, v);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                                }
                              },
                            ),
                            IconButton(
                              tooltip: 'Supprimer',
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Supprimer le service'),
                                    content: Text('Confirmer la suppression de "'+nom+'" ?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                                      ElevatedButton(style: ButtonStyle(backgroundColor: MaterialStatePropertyAll(Colors.red)), onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  try {
                                    await fs.supprimerService(d.id);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                                  }
                                }
                              },
                            ),
                          ]),
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
