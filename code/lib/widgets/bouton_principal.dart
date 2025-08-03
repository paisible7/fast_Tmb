// widgets/bouton_principal.dart
import 'package:flutter/material.dart';
import 'package:fl/utils/constantes_couleurs.dart';

class BoutonPrincipal extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const BoutonPrincipal({
    Key? key,
    required this.text,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: ConstantesCouleurs.orange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
