import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../services/api_service.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/pressable_scale.dart';
import '../login_screen.dart';

import 'wallet_screen.dart';

class CartTab extends StatefulWidget {
  const CartTab({super.key});

  @override
  State<CartTab> createState() => _CartTabState();
}

class _CartTabState extends State<CartTab> {
  bool _isOrdering = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final app = context.read<AppState>();
        if (app.loggedIn) {
          app.wallet.fetchWalletBalance();
          app.fetchCart();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final entries = app.cartItems.values.toList()
      ..sort((a, b) => a.product.name.compareTo(b.product.name));
    final now = DateTime.now();
    final prepMap = {for (final e in entries) e.product.id: e.quantity};
    final prep = app.prepMinutesFor(prepMap, now);
    final beforeSix = now.hour < 18;
    final coffeeQty = entries
        .where((e) => e.product.isCoffee)
        .fold(0, (s, e) => s + e.quantity);
    final dessertQty = entries
        .where((e) => e.product.category == ProductCategory.dessert)
        .fold(0, (s, e) => s + e.quantity);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              'Sepetim',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: EmarColors.espresso,
              ),
            ),
          ),
          if (entries.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Sepetin boş — menüden bir şeyler seç ☕',
                  style: TextStyle(color: EmarColors.espresso),
                ),
              ),
            )
          else ...[
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final cartItem = entries[i];
                  final product = cartItem.product;
                  final qty = cartItem.quantity;
                  final localId = app.cartItems.keys.firstWhere(
                    (k) => app.cartItems[k] == cartItem,
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Text(
                          product.icon,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                              if (cartItem.selectedOptions.isNotEmpty)
                                Text(
                                  cartItem.selectedOptions
                                      .map((o) => o.name)
                                      .join(', '),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: EmarColors.espresso.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 20,
                          ),
                          onPressed: () =>
                              context.read<AppState>().changeQty(localId, -1),
                        ),
                        Text(
                          '$qty',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          onPressed: () =>
                              context.read<AppState>().changeQty(localId, 1),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(
                            '${cartItem.totalPrice.toStringAsFixed(0)}₺',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 108),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: EmarColors.oatDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('⏱', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$prep dk',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const Text(
                                'tahmini hazırlanma süresi',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: EmarColors.espresso,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: EmarColors.oatDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Sipariş saatin ${TimeOfDay.fromDateTime(now).format(context)} — '
                      "${beforeSix ? '18:00’den önce' : '18:00’den sonra'} olduğu için temel süre "
                      '${beforeSix ? "kahve 2 dk, tatlı 3 dk, ikisi birlikte 4 dk" : "kahve 3 dk, tatlı 5 dk, ikisi birlikte 6 dk"}. '
                      '${coffeeQty + dessertQty > 2 ? "Sepetinde $coffeeQty kahve, $dessertQty tatlı var; her fazladan 2 üründe barista için +1 dk ekleniyor." : ""}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: EmarColors.espresso,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cüzdan Bakiyesi',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: EmarColors.moss,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${app.walletBalance.toStringAsFixed(2)}₺',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: EmarColors.moss,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.of(
                              context,
                            ).push(softRoute(const WalletScreen())),
                            child: const Icon(
                              Icons.account_balance_wallet,
                              color: EmarColors.moss,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Toplam',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${app.cartTotal.toStringAsFixed(2)}₺',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: EmarColors.paprika,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PressableScale(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EmarColors.espresso,
                        ),
                        onPressed: (app.isUpdatingCart || _isOrdering)
                            ? null
                            : () => _handleQrCheckout(context, app),
                        child: Text(
                          _isOrdering
                              ? 'QR Kod Üretiliyor...'
                              : (app.loggedIn
                                    ? 'Kasada QR Kod ile Öde'
                                    : 'Sipariş İçin Giriş Yap'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleQrCheckout(BuildContext context, AppState app) async {
    debugPrint('>>> [_handleQrCheckout] Button tapped. loggedIn=${app.loggedIn}');
    if (!app.loggedIn) {
      Navigator.of(context).push(softRoute(const LoginScreen()));
      return;
    }

    setState(() => _isOrdering = true);

    try {
      // Refresh wallet balance before proceeding
      debugPrint('>>> [_handleQrCheckout] Fetching wallet balance...');
      await app.fetchWalletBalance();
      if (!mounted) return;
      debugPrint('>>> [_handleQrCheckout] Wallet balance: ${app.walletBalance}, Cart total: ${app.cartTotal}');

      if (app.walletBalance < app.cartTotal) {
        debugPrint('>>> [_handleQrCheckout] Insufficient balance: ${app.walletBalance} < ${app.cartTotal}');
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: EmarColors.surface,
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: EmarColors.paprika),
                SizedBox(width: 8),
                Text('Yetersiz Bakiye'),
              ],
            ),
            content: Text(
              'Sepet tutarınız: ${app.cartTotal.toStringAsFixed(2)} ₺\n'
              'Cüzdan bakiyeniz: ${app.walletBalance.toStringAsFixed(2)} ₺\n\n'
              'Kasada ödeme yapabilmek için lütfen cüzdanınıza bakiye yükleyin.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.of(context).push(softRoute(const WalletScreen()));
                },
                child: const Text('Bakiye Yükle'),
              ),
            ],
          ),
        );
        return;
      }

      debugPrint('>>> [_handleQrCheckout] Requesting QR token from backend...');
      final token = await app.generateWalletToken();
      debugPrint('>>> [_handleQrCheckout] QR token received: $token');
      if (!mounted) return;

      if (token != null && token.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            title: const Text(
              'Kasada Ödeme QR Kodunuz',
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Lütfen bu kodu baristaya okutunuz.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                QrImageView(
                  data: token,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
                const SizedBox(height: 16),
                SelectableText(
                  token,
                  style: const TextStyle(
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  app.fetchCart();
                },
                child: const Text('Kapat'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('>>> [_handleQrCheckout] Error caught: $e');
      if (mounted) {
        if (e is ApiException && e.errors != null && e.errors!.isNotEmpty) {
          String msg =
              'Aşağıdaki ürünler seçtiğiniz şubede temin edilemiyor. Lütfen sepetinizden çıkartın veya şubenizi değiştirin:\n';
          for (var err in e.errors!) {
            msg += '\n- ${err['message']}';
          }
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Stok Uyarısı'),
              content: Text(msg),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Tamam'),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Ödeme / QR Hatası'),
              content: Text(
                e.toString().replaceAll('Exception: ', '').replaceAll('ApiException: ', ''),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Tamam'),
                ),
              ],
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isOrdering = false);
    }
  }
}
