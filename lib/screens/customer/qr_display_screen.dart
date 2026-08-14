import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/pressable_scale.dart';
import 'order_tracking_screen.dart';

class QRDisplayScreen extends StatelessWidget {
  final OrderRecord? order;
  final String? qrToken;
  const QRDisplayScreen({super.key, this.order, this.qrToken});

  @override
  Widget build(BuildContext context) {
    final token = qrToken ?? order?.shortId ?? '';
    final isWallet = qrToken != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isWallet ? 'Cüzdan ile Öde' : 'Siparişi Onayla (QR)'),
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
              Icon(
                isWallet ? Icons.account_balance_wallet_rounded : Icons.check_circle_outline_rounded,
                size: 64,
                color: EmarColors.paprika,
              ),
              const SizedBox(height: 16),
              Text(
                isWallet ? 'QR Kodu Okutun' : 'Siparişin Hazır!',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: EmarColors.espresso, letterSpacing: -0.5),
              ),
              const SizedBox(height: 12),
              Text(
                isWallet 
                  ? 'Kasadaki baristaya bu QR kodu okutarak cüzdanınızdan ödeme yapabilirsiniz.\n(Kod 3 dakika geçerlidir)' 
                  : 'Lütfen bu QR kodu baristaya okutun. Siparişiniz okutulduktan sonra hazırlanmaya başlayacaktır.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: EmarColors.moss, height: 1.4),
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
              const SizedBox(height: 40),
              if (!isWallet)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: EmarColors.espresso.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Sipariş No: ${order?.shortId ?? ''}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: EmarColors.espresso, letterSpacing: 0.5),
                  ),
                ),
              const SizedBox(height: 12),
              SelectableText(
                '(Test) QR Token:\n$token',
                style: TextStyle(fontSize: 11, color: EmarColors.espresso.withValues(alpha: 0.4), fontFamily: 'monospace'),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (!isWallet && order != null)
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
                          MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: order!)),
                        );
                      },
                      child: const Text('Sipariş Takibine Git', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              if (isWallet)
                const Padding(
                  padding: EdgeInsets.only(bottom: 24.0),
                  child: Text(
                    'Onaylandığında siparişiniz ana sayfada belirecektir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: EmarColors.moss, fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
