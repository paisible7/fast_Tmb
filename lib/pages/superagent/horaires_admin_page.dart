import 'package:flutter/material.dart';
import 'package:fast_tmb/models/horaires.dart';
import 'package:fast_tmb/services/horaires_service.dart';
import 'package:fast_tmb/widgets/role_guard.dart';
import 'package:fast_tmb/widgets/barre_navigation.dart';
import 'package:fast_tmb/utils/constantes_couleurs.dart';

class HorairesAdminPage extends StatefulWidget {
  const HorairesAdminPage({Key? key}) : super(key: key);

  @override
  State<HorairesAdminPage> createState() => _HorairesAdminPageState();
}

class _HorairesAdminPageState extends State<HorairesAdminPage> {
  final HorairesService _horairesService = HorairesService();
  Horaires? _horaires;
  bool _loading = true;
  bool _saving = false;

  final Map<String, String> _joursLabels = {
    'lundi': 'Lundi',
    'mardi': 'Mardi',
    'mercredi': 'Mercredi',
    'jeudi': 'Jeudi',
    'vendredi': 'Vendredi',
    'samedi': 'Samedi',
    'dimanche': 'Dimanche',
  };

  @override
  void initState() {
    super.initState();
    _chargerHoraires();
  }

  Future<void> _chargerHoraires() async {
    try {
      final horaires = await _horairesService.getHoraires();
      setState(() {
        _horaires = horaires;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _sauvegarder() async {
    if (_horaires == null) return;

    setState(() => _saving = true);
    try {
      await _horairesService.saveHoraires(_horaires!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horaires sauvegardés'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  void _toggleJourOuvert(String jour) {
    if (_horaires == null) return;

    final horaireJour = _horaires!.jours[jour];
    if (horaireJour == null) return;

    final nouveauHoraire = HoraireJour(
      ouvert: !horaireJour.ouvert,
      creneaux: horaireJour.ouvert ? [] : [CreneauHoraire(8, 0, 17, 0)], // Créneau par défaut
    );

    setState(() {
      _horaires = _horaires!.copyWith(
        jours: Map.from(_horaires!.jours)..[jour] = nouveauHoraire,
      );
    });
  }

  void _ajouterCreneau(String jour) {
    if (_horaires == null) return;

    final horaireJour = _horaires!.jours[jour];
    if (horaireJour == null || !horaireJour.ouvert) return;

    final nouveauxCreneaux = List<CreneauHoraire>.from(horaireJour.creneaux)
      ..add(CreneauHoraire(8, 0, 12, 0));

    final nouveauHoraire = HoraireJour(
      ouvert: horaireJour.ouvert,
      creneaux: nouveauxCreneaux,
    );

    setState(() {
      _horaires = _horaires!.copyWith(
        jours: Map.from(_horaires!.jours)..[jour] = nouveauHoraire,
      );
    });
  }

  void _supprimerCreneau(String jour, int index) {
    if (_horaires == null) return;

    final horaireJour = _horaires!.jours[jour];
    if (horaireJour == null || index >= horaireJour.creneaux.length) return;

    final nouveauxCreneaux = List<CreneauHoraire>.from(horaireJour.creneaux)
      ..removeAt(index);

    final nouveauHoraire = HoraireJour(
      ouvert: horaireJour.ouvert,
      creneaux: nouveauxCreneaux,
    );

    setState(() {
      _horaires = _horaires!.copyWith(
        jours: Map.from(_horaires!.jours)..[jour] = nouveauHoraire,
      );
    });
  }

  void _modifierCreneau(String jour, int index, CreneauHoraire nouveauCreneau) {
    if (_horaires == null) return;

    final horaireJour = _horaires!.jours[jour];
    if (horaireJour == null || index >= horaireJour.creneaux.length) return;

    final nouveauxCreneaux = List<CreneauHoraire>.from(horaireJour.creneaux);
    nouveauxCreneaux[index] = nouveauCreneau;

    final nouveauHoraire = HoraireJour(
      ouvert: horaireJour.ouvert,
      creneaux: nouveauxCreneaux,
    );

    setState(() {
      _horaires = _horaires!.copyWith(
        jours: Map.from(_horaires!.jours)..[jour] = nouveauHoraire,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['superagent'],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administration - Horaires'),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              )
            else
              IconButton(
                onPressed: _sauvegarder,
                icon: const Icon(Icons.save),
                tooltip: 'Sauvegarder',
              ),
          ],
        ),
        bottomNavigationBar: const BarreNavigation(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _horaires == null
                ? const Center(child: Text('Erreur de chargement'))
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Configuration des horaires d\'ouverture',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Définissez les horaires d\'ouverture pour la délivrance des tickets.',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView(
                            children: _joursLabels.entries.map((entry) {
                              final jour = entry.key;
                              final label = entry.value;
                              final horaireJour = _horaires!.jours[jour];

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ExpansionTile(
                                  title: Row(
                                    children: [
                                      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      const Spacer(),
                                      Switch(
                                        value: horaireJour?.ouvert ?? false,
                                        onChanged: (_) => _toggleJourOuvert(jour),
                                        activeColor: ConstantesCouleurs.orange,
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    horaireJour?.ouvert == true
                                        ? horaireJour!.creneaux.isEmpty
                                            ? 'Ouvert - Aucun créneau défini'
                                            : 'Ouvert - ${horaireJour.creneaux.length} créneau(x)'
                                        : 'Fermé',
                                    style: TextStyle(
                                      color: horaireJour?.ouvert == true ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  children: [
                                    if (horaireJour?.ouvert == true) ...[
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text('Créneaux horaires:', style: TextStyle(fontWeight: FontWeight.w600)),
                                                TextButton.icon(
                                                  onPressed: () => _ajouterCreneau(jour),
                                                  icon: const Icon(Icons.add),
                                                  label: const Text('Ajouter'),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (horaireJour!.creneaux.isEmpty)
                                              const Text('Aucun créneau défini', style: TextStyle(color: Colors.grey))
                                            else
                                              ...horaireJour.creneaux.asMap().entries.map((entry) {
                                                final index = entry.key;
                                                final creneau = entry.value;
                                                return _buildCreneauEditor(jour, index, creneau);
                                              }),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _sauvegarder,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(_saving ? 'Sauvegarde...' : 'Sauvegarder les horaires'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ConstantesCouleurs.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildCreneauEditor(String jour, int index, CreneauHoraire creneau) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildTimeField(
                      'Début',
                      creneau.startHour,
                      creneau.startMinute,
                      (hour, minute) {
                        final nouveauCreneau = CreneauHoraire(
                          hour,
                          minute,
                          creneau.endHour,
                          creneau.endMinute,
                        );
                        _modifierCreneau(jour, index, nouveauCreneau);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimeField(
                      'Fin',
                      creneau.endHour,
                      creneau.endMinute,
                      (hour, minute) {
                        final nouveauCreneau = CreneauHoraire(
                          creneau.startHour,
                          creneau.startMinute,
                          hour,
                          minute,
                        );
                        _modifierCreneau(jour, index, nouveauCreneau);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _supprimerCreneau(jour, index),
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Supprimer ce créneau',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField(
    String label,
    int hour,
    int minute,
    Function(int hour, int minute) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: hour, minute: minute),
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                );
              },
            );
            if (time != null) {
              onChanged(time.hour, time.minute);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
