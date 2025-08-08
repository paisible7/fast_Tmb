// pages/client/scan_qr.dart
import 'package:fast_tmb/services/auth_service_v2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fast_tmb/services/firestore_service.dart';
import 'package:fast_tmb/utils/constantes_couleurs.dart';
import 'package:fast_tmb/widgets/barre_navigation.dart';
import 'package:fast_tmb/services/auth_service.dart';

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({Key? key}) : super(key: key);

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  final MobileScannerController controller = MobileScannerController();
  bool _scanned = false;
  bool _flashOn = false;
  bool _frontCamera = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_scanned) return;
    setState(() => _scanned = true);
    try {
      await Provider.of<FirestoreService>(context, listen: false)
          .ajouterTicket();
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthServiceV2>(context, listen: false);
    if (auth.currentUser?.role == 'agent') {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/tableau_bord_agent'));
      return const SizedBox.shrink();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner QR'),
        backgroundColor: ConstantesCouleurs.orange,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: BarreNavigation(),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: _onDetect,
                ),
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: ConstantesCouleurs.orange,
                        width: 4,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.transparent,
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    children: [
                      IconButton(
                        icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
                        onPressed: () {
                          controller.toggleTorch();
                          setState(() => _flashOn = !_flashOn);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.cameraswitch, color: Colors.white),
                        onPressed: () {
                          controller.switchCamera();
                          setState(() => _frontCamera = !_frontCamera);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: _scanned
                ? const Text(
                    'Ticket ajouté ✔',
                    style: TextStyle(
                      color: ConstantesCouleurs.orange,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : const Text(
                    'Placez un QR code dans la zone',
                    style: TextStyle(fontSize: 18, color: ConstantesCouleurs.orange),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}