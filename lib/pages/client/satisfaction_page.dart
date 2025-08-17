// pages/client/satisfaction_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fast_tmb/services/firestore_service.dart';
import 'package:fast_tmb/utils/constantes_couleurs.dart';

class SatisfactionPage extends StatefulWidget {
  final String ticketId;
  final String ticketNumero;
  final String queueType;
  final bool showInBottomSheet;

  const SatisfactionPage({
    Key? key,
    required this.ticketId,
    required this.ticketNumero,
    required this.queueType,
    this.showInBottomSheet = false,
  }) : super(key: key);

  @override
  State<SatisfactionPage> createState() => _SatisfactionPageState();
}

class _SatisfactionPageState extends State<SatisfactionPage> {
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitSatisfaction() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une note'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.ajouterEvaluationService(
        score: _selectedRating,
        comment: _commentController.text.trim(),
      );

      if (mounted) {
        // Afficher un dialog de remerciement
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('Merci !'),
              ],
            ),
            content: const Text(
              'Votre avis a été enregistré. Merci de nous aider à améliorer notre service bancaire et cette application !',
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ConstantesCouleurs.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // Fermer le dialog
                  if (widget.showInBottomSheet) {
                    Navigator.of(context).pop(); // Fermer le BottomSheet
                  } else {
                    Navigator.of(context).pushNamedAndRemoveUntil('/accueil', (route) => false);
                  }
                },
                child: const Text('Retour à l\'accueil'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Barre de fermeture pour le BottomSheet
          if (widget.showInBottomSheet) ...[
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Évaluez votre expérience',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          // En-tête avec numéro de ticket
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ConstantesCouleurs.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ConstantesCouleurs.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 60,
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Service terminé !',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ticket #${widget.ticketNumero}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Question de satisfaction
          const Text(
            'Comment évaluez-vous notre service ?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Votre avis sur le service bancaire et cette application nous aide à nous améliorer',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Étoiles de notation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final rating = index + 1;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedRating = rating;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _selectedRating >= rating ? Icons.star : Icons.star_border,
                    size: 40,
                    color: _selectedRating >= rating 
                        ? ConstantesCouleurs.orange
                        : Colors.grey[400],
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // Texte descriptif de la note
          if (_selectedRating > 0)
            Text(
              _getRatingText(_selectedRating),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: ConstantesCouleurs.orange,
              ),
            ),

          const SizedBox(height: 32),

          // Zone de commentaire
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Commentaire (optionnel)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Partagez votre expérience, suggestions d\'amélioration...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: ConstantesCouleurs.orange),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Boutons d'action
          Row(
            children: [
              // Bouton ignorer
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : () {
                    if (widget.showInBottomSheet) {
                      Navigator.of(context).pop(); // Fermer le BottomSheet
                    } else {
                      Navigator.of(context).pushNamedAndRemoveUntil('/accueil', (route) => false);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: Colors.grey),
                  ),
                  child: const Text(
                    'Ignorer',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Bouton envoyer
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitSatisfaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ConstantesCouleurs.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Envoyer l\'évaluation',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Note de confidentialité
          Text(
            'Vos commentaires nous aident à améliorer notre service et restent confidentiels.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    // Retourner le contenu avec ou sans Scaffold selon le mode
    if (widget.showInBottomSheet) {
      return content;
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Évaluez votre expérience'),
          backgroundColor: ConstantesCouleurs.orange,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: content,
      );
    }
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Très insatisfait';
      case 2:
        return 'Insatisfait';
      case 3:
        return 'Neutre';
      case 4:
        return 'Satisfait';
      case 5:
        return 'Très satisfait';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
      case 2:
        return Colors.red;
      case 3:
        return Colors.orange;
      case 4:
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
