// widgets/carte_ticket.dart
import 'package:flutter/material.dart';
import 'package:fast_tmb/models/ticket.dart';
import 'package:fast_tmb/utils/format_date.dart';
import 'package:fast_tmb/utils/constantes_couleurs.dart';

class CarteTicket extends StatelessWidget {
  final Ticket ticket;
  final bool surligne;
  final VoidCallback? onTap;

  const CarteTicket({
    Key? key,
    required this.ticket,
    this.surligne = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color statutColor;
    switch (ticket.status) {
      case 'en_attente':
        statutColor = ConstantesCouleurs.orange;
        break;
      case 'en_cours':
        statutColor = ConstantesCouleurs.orange;
        break;
      case 'termine':
        statutColor = ConstantesCouleurs.orange;
        break;
      case 'absent':
        statutColor = Colors.red;
        break;
      default:
        statutColor = Colors.grey;
    }

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: surligne
            ? ConstantesCouleurs.orange.withValues(alpha: 0.1)
            : Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Text(
                '#${ticket.numero}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        color: statutColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (ticket.queueType != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: ConstantesCouleurs.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              ticket.queueType == 'depot' ? 'Dépôt' : ticket.queueType == 'retrait' ? 'Retrait' : ticket.queueType!,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatDate(ticket.createdAt),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
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
