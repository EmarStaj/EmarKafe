import 'package:emar_kafe/models/order_record.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/order_record.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/pressable_scale.dart';
import 'order_tracking_screen.dart';

class QRDisplayScreen extends StatefulWidget {
  final OrderRecord? order;
  final String? qrToken;
  const QRDisplayScreen({super.key, this.order, this.qrToken});

  @override
  State<QRDisplayScreen> createState() => _QRDisplayScreenState();
}

class _QRDisplayScreenState extends State<QRDisplayScreen> {
  bool _scanning = false;

  @override
  Widget build(BuildContext context) {
    final token = widget.qrToken ?? widget.order?.shortId ?? '';
    final isWallet = widget.qrToken != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Siparişi Onayla (QR)'),
        backgroundColor: EmarColors.oat,
      ),
      backgroundColor: EmarColors.oat,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 64,
                color: EmarColors.paprika,
              ),
              const SizedBox(height: 16),
              const Text(
                'Siparişin Hazır!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: EmarColors.espresso, letterSpacing: -0.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'Lütfen bu QR kodu baristaya okutun. Siparişiniz okutulduktan sonra hazırlanmaya başlayacaktır.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: EmarColors.moss, height: 1.4),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: EmarColors.espresso.withValues(alpha: 0.05)),
                  boxShadow: [
                    BoxShadow(color: EmarColors.espresso.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 12))
                  ],
                ),
                child: QrImageView(
                  data: token,
                  version: QrVersions.auto,
                  size: 220.0,
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: EmarColors.espresso,
                  ),
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.circle,
                    color: EmarColors.paprika,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                '(Test) QR Token:\n$token',
                style: TextStyle(fontSize: 11, color: EmarColors.espresso.withValues(alpha: 0.4), fontFamily: 'monospace'),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (isWallet)
                PressableScale(
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EmarColors.paprika,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _scanning ? null : () async {
                        setState(() => _scanning = true);
                        try {
                          final app = context.read<AppState>();
                          await app.placeOrder(useWallet: true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sipariş başarıyla tarandı ve mutfağa iletildi!'))
                            );
                            Navigator.of(context).pop();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Hata: '))
                            );
                            setState(() => _scanning = false);
                          }
                        }
                      },
                      child: _scanning 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('(Test) Barista Olarak Okut', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (!isWallet && widget.order != null)
                PressableScale(
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EmarColors.espresso,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: widget.order!)),
                        );
                      },
                      child: const Text('Sipariş Takibine Git', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}