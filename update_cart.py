import re

with open('lib/screens/customer/cart_tab.dart', 'r') as f:
    content = f.read()

# Eklenecek import var mı? qr_flutter lazım olabilir dialog için ama select text de yeterli.
# Import QrImageView
if 'qr_flutter' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:qr_flutter/qr_flutter.dart';")

# Hedef blok:
target_block = """                          try {
                            final app = context.read<AppState>();
                            final token = await app.generateWalletToken();
                            final order = await app.placeOrder(useWallet: true);
                            if (order != null && context.mounted) {
                              Navigator.of(context).push(softRoute(OrderTrackingScreen(order: order, qrToken: token)));
                            }
                          } catch (e) {"""

new_block = """                          try {
                            final app = context.read<AppState>();
                            
                            // Barista'ya okutmak için SADECE QR üret
                            final token = await app.generateWalletToken();
                            
                            if (token != null && context.mounted) {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (c) => AlertDialog(
                                  title: const Text('Kasada Ödeme QR Kodunuz', textAlign: TextAlign.center),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Lütfen bu kodu baristaya okutunuz.', textAlign: TextAlign.center),
                                      const SizedBox(height: 16),
                                      QrImageView(
                                        data: token,
                                        version: QrVersions.auto,
                                        size: 200.0,
                                      ),
                                      const SizedBox(height: 16),
                                      SelectableText(token, style: const TextStyle(fontSize: 10)),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(c);
                                        app.fetchCart(); // Kapatınca sepeti yenile
                                      },
                                      child: const Text('Kapat'),
                                    )
                                  ],
                                )
                              );
                            }
                          } catch (e) {"""

content = content.replace(target_block, new_block)

# Buton textini de değiştirelim
content = content.replace("? 'Güncelleniyor...' \n                            : (app.loggedIn ? 'Cüzdan İle Öde ve Onayla' : 'Sipariş İçin Giriş Yap')", "? 'Güncelleniyor...' \n                            : (app.loggedIn ? 'Kasada QR ile Öde' : 'Sipariş İçin Giriş Yap')")

with open('lib/screens/customer/cart_tab.dart', 'w') as f:
    f.write(content)

