import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:fast_tmb/services/firestore_service.dart';
import 'package:fast_tmb/services/horaires_service.dart';
import 'package:fast_tmb/models/horaires.dart';
import 'package:fast_tmb/utils/constantes_couleurs.dart';

class SansSmartphonePage extends StatefulWidget {
  const SansSmartphonePage({Key? key}) : super(key: key);

  @override
  State<SansSmartphonePage> createState() => _SansSmartphonePageState();
}

class _SansSmartphonePageState extends State<SansSmartphonePage> {
  final _auth = FirebaseAuth.instance;
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _signingIn = true;
  String? _error;
  bool _creatingTicket = false;
  List<Map<String, dynamic>> _services = [];

  @override
  void initState() {
    super.initState();
    _ensureAnonymousSignIn();
    _chargerServices();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    super.dispose();
  }

  Future<void> _ensureAnonymousSignIn() async {
    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }
    } catch (e) {
      _error = 'Erreur de connexion anonyme. Veuillez réessayer.';
    } finally {
      if (mounted) {
        setState(() {
          _signingIn = false;
        });
      }
    }
  }

  Future<void> _chargerServices() async {
    try {
      final fs = context.read<FirestoreService>();
      final servicesStream = fs.streamServices();
      servicesStream.listen((services) {
        if (mounted) {
          setState(() {
            _services = services.docs
                .where((s) => (s.data() as Map<String, dynamic>)['actif'] == true)
                .map((s) => {
                  'id': s.id,
                  ...(s.data() as Map<String, dynamic>),
                })
                .toList();
          });
        }
      });
    } catch (e) {
      print('Erreur chargement services: $e');
      // Fallback sur dépôt/retrait si erreur
      setState(() {
        _services = [
          {'id': 'depot', 'nom': 'Dépôt', 'actif': true},
          {'id': 'retrait', 'nom': 'Retrait', 'actif': true},
        ];
      });
    }
  }

  Future<void> _creerTicket(BuildContext context, String serviceId) async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() { _creatingTicket = true; });
    
    try {
      final fs = context.read<FirestoreService>();
      
      // Créer le ticket avec les informations d'enregistrement
      await fs.ajouterTicketAvecEnregistrement(
        queueType: serviceId,
        clientName: _nomController.text.trim(),
        clientFirstName: _prenomController.text.trim(),
        guest: true,
      );

      // Récupérer le dernier ticket créé pour afficher le numéro
      final uid = _auth.currentUser!.uid;
      final snap = await FirebaseFirestore.instance
          .collection('tickets')
          .where('creatorId', isEqualTo: uid)
          .where('status', whereIn: ['en_attente', 'en_cours'])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (mounted) {
        String message = 'Ticket créé avec succès.';
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data();
          final num = data['numero'];
          final serviceName = _services.firstWhere(
            (s) => s['id'] == serviceId, 
            orElse: () => {'nom': serviceId}
          )['nom'];
          message = 'Ticket n°$num \u2013 $serviceName\n\nVeuillez patienter, vous serez appelé(e) prochainement.';
        }
        
        // Afficher un dialog de confirmation au lieu d'un SnackBar
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('Ticket créé'),
              ],
            ),
            content: Text(message, style: const TextStyle(fontSize: 16)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Réinitialiser le formulaire
                  _nomController.clear();
                  _prenomController.clear();
                },
                child: const Text('OK', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text('Erreur'),
              ],
            ),
            content: Text(e.toString(), style: const TextStyle(fontSize: 16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() { _creatingTicket = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final horairesService = HorairesService();
    final screenSize = MediaQuery.of(context).size;
    final isKioskMode = screenSize.width > 800; // Mode kiosque pour grands écrans

    return Scaffold(
      appBar: isKioskMode ? null : AppBar(
        title: const Text('Rejoindre la file'),
        backgroundColor: ConstantesCouleurs.orange,
      ),
      body: _signingIn
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 6),
                  SizedBox(height: 16),
                  Text('Connexion en cours...', style: TextStyle(fontSize: 18)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Card(
                    margin: const EdgeInsets.all(32),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _ensureAnonymousSignIn,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Réessayer', style: TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(isKioskMode ? 32 : 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (isKioskMode) ...[
                          const SizedBox(height: 20),
                          Text(
                            'BORNE LIBRE-SERVICE',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: ConstantesCouleurs.orange,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Obtenez votre ticket de file d\'attente',
                            style: TextStyle(fontSize: 20, color: Colors.black87),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                        ],
                        
                        // Bandeau horaires
                        StreamBuilder<Horaires>(
                          stream: horairesService.getHorairesStream(),
                          builder: (context, snapshot) {
                            final now = DateTime.now();
                            bool ouvert = false;
                            String texte = 'Chargement des horaires...';
                            if (snapshot.hasError) {
                              texte = 'Impossible de charger les horaires';
                            }
                            if (snapshot.hasData) {
                              try {
                                final horaires = snapshot.data!;
                                ouvert = horaires.isOpenNow(now);
                                final jour = now.weekday;
                                final duJour = horaires.getHorairesAffichage(jour);
                                texte = 'Aujourd\'hui: $duJour';
                              } catch (_) {}
                            }
                            return Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(isKioskMode ? 20 : 16),
                              decoration: BoxDecoration(
                                color: ouvert ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: ouvert ? Colors.green : Colors.red,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        ouvert ? Icons.check_circle : Icons.cancel,
                                        color: ouvert ? Colors.green : Colors.red,
                                        size: isKioskMode ? 32 : 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        ouvert ? 'GUICHET OUVERT' : 'GUICHET FERMÉ',
                                        style: TextStyle(
                                          color: ouvert ? Colors.green.shade800 : Colors.red.shade800,
                                          fontWeight: FontWeight.bold,
                                          fontSize: isKioskMode ? 24 : 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    texte,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: isKioskMode ? 18 : 14),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        
                        SizedBox(height: isKioskMode ? 40 : 24),
                        
                        // Formulaire d'enregistrement
                        Container(
                          constraints: BoxConstraints(maxWidth: isKioskMode ? 600 : double.infinity),
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: EdgeInsets.all(isKioskMode ? 32 : 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Vos informations',
                                    style: TextStyle(
                                      fontSize: isKioskMode ? 24 : 20,
                                      fontWeight: FontWeight.bold,
                                      color: ConstantesCouleurs.orange,
                                    ),
                                  ),
                                  SizedBox(height: isKioskMode ? 24 : 16),
                                  
                                  TextFormField(
                                    controller: _nomController,
                                    style: TextStyle(fontSize: isKioskMode ? 20 : 16),
                                    decoration: InputDecoration(
                                      labelText: 'Nom *',
                                      labelStyle: TextStyle(fontSize: isKioskMode ? 18 : 14),
                                      prefixIcon: const Icon(Icons.person),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding: EdgeInsets.all(isKioskMode ? 20 : 16),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Veuillez saisir votre nom';
                                      }
                                      return null;
                                    },
                                  ),
                                  
                                  SizedBox(height: isKioskMode ? 20 : 16),
                                  
                                  TextFormField(
                                    controller: _prenomController,
                                    style: TextStyle(fontSize: isKioskMode ? 20 : 16),
                                    decoration: InputDecoration(
                                      labelText: 'Prénom *',
                                      labelStyle: TextStyle(fontSize: isKioskMode ? 18 : 14),
                                      prefixIcon: const Icon(Icons.person_outline),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding: EdgeInsets.all(isKioskMode ? 20 : 16),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Veuillez saisir votre prénom';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(height: isKioskMode ? 40 : 24),
                        
                        // Sélecteur de services
                        Container(
                          constraints: BoxConstraints(maxWidth: isKioskMode ? 800 : double.infinity),
                          child: Column(
                            children: [
                              Text(
                                'Choisissez votre service',
                                style: TextStyle(
                                  fontSize: isKioskMode ? 24 : 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: isKioskMode ? 24 : 16),
                              
                              if (_services.isEmpty)
                                const CircularProgressIndicator()
                              else
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      alignment: WrapAlignment.center,
                                      children: _services.map((service) {
                                        return _ServiceButton(
                                          label: service['nom'] ?? 'Service',
                                          serviceId: service['id'] ?? 'unknown',
                                          isKioskMode: isKioskMode,
                                          isLoading: _creatingTicket,
                                          onPressed: () => _creerTicket(context, service['id'] ?? 'unknown'),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: isKioskMode ? 40 : 24),
                        
                        // Note informative
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Après avoir obtenu votre ticket, veuillez patienter. Vous serez appelé(e) dès qu\'un agent sera disponible.',
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontSize: isKioskMode ? 16 : 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _ServiceButton extends StatelessWidget {
  final String label;
  final String serviceId;
  final bool isKioskMode;
  final bool isLoading;
  final VoidCallback onPressed;
  
  const _ServiceButton({
    required this.label,
    required this.serviceId,
    required this.isKioskMode,
    required this.isLoading,
    required this.onPressed,
  });

  Color get _color {
    switch (serviceId.toLowerCase()) {
      case 'depot':
        return Colors.blue;
      case 'retrait':
        return Colors.teal;
      case 'consultation':
        return Colors.purple;
      case 'ouverture_compte':
        return Colors.orange;
      default:
        return ConstantesCouleurs.orange;
    }
  }

  IconData get _icon {
    switch (serviceId.toLowerCase()) {
      case 'depot':
        return Icons.south_west;
      case 'retrait':
        return Icons.north_east;
      case 'consultation':
        return Icons.visibility;
      case 'ouverture_compte':
        return Icons.account_circle;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonSize = isKioskMode ? 200.0 : 150.0;
    final fontSize = isKioskMode ? 20.0 : 16.0;
    final iconSize = isKioskMode ? 32.0 : 24.0;
    
    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _color,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: _color.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isKioskMode ? 20 : 16),
          ),
          padding: EdgeInsets.all(isKioskMode ? 16 : 12),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: isKioskMode ? 4 : 3,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _icon,
                    size: iconSize,
                    color: Colors.white,
                  ),
                  SizedBox(height: isKioskMode ? 12 : 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
      ),
    );
  }
}
