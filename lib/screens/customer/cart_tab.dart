import 'dart:async';
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
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final entries = app.cartItems.entries.toList()
      ..sort((a, b) => a.value.product.name.compareTo(b.value.product.name));
    final now = DateTime.now();
    final prepMap = {for (final e in entries) e.value.product.id: e.value.quantity};
    final prep = app.prepMinutesFor(prepMap, now);
    final beforeSix = now.hour < 18;
    final coffeeQty = entries
        .where((e) => e.value.product.isCoffee)
        .fold(0, (s, e) => s + e.value.quantity);
    final dessertQty = entries
        .where((e) => e.value.product.category == ProductCategory.dessert)
        .fold(0, (s, e) => s + e.value.quantity);

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
                  final entry = entries[i];
                  final localId = entry.key;
                  final cartItem = entry.value;
                  final product = cartItem.product;
                  final qty = cartItem.quantity;
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
                        PressableScale(
                          child: GestureDetector(
                            onTap: () => context.read<AppState>().changeQty(localId, -1),
                            child: Container(
                              width: 36, height: 36,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: EmarColors.oatDark,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.remove, size: 16, color: EmarColors.espresso),
                            ),
                          ),
                        ),
                        Text(
                          '$qty',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        PressableScale(
                          child: GestureDetector(
                            onTap: () => context.read<AppState>().changeQty(localId, 1),
                            child: Container(
                              width: 36, height: 36,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: EmarColors.espresso,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add, size: 16, color: EmarColors.surface),
                            ),
                          ),
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
                  if (app.freeCoffeesEarned > 0 && app.mostExpensiveCoffeeItem != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: EmarColors.moss.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: EmarColors.moss.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('🎁', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '1 Adet Bedava Kahve Hakkın Var!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: EmarColors.espresso,
                                  ),
                                ),
                                Text(
                                  'En pahalı kahven (${app.mostExpensiveCoffeeItem!.product.name}, ${app.mostExpensiveCoffeeItem!.unitPrice.toStringAsFixed(0)}₺) hediye edilsin.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: EmarColors.espresso.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: app.useFreeCoffeeReward,
                            activeColor: EmarColors.moss,
                            onChanged: (val) => app.setUseFreeCoffeeReward(val),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  if (app.useFreeCoffeeReward && app.freeCoffeeDiscount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '🎁 Hediye Kahve (${app.mostExpensiveCoffeeItem?.product.name})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: EmarColors.moss,
                          ),
                        ),
                        Text(
                          '-${app.freeCoffeeDiscount.toStringAsFixed(2)}₺',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: EmarColors.moss,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                        '${app.effectiveCartTotal.toStringAsFixed(2)}₺',
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
      // 1. Flush any pending cart debounce and sync with backend
      debugPrint('>>> [_handleQrCheckout] Syncing cart to backend...');
      await app.cart.flushDebounces();
      if (!mounted) return;

      if (app.cartItems.isEmpty) {
        debugPrint('>>> [_handleQrCheckout] Cart is empty');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sepetiniz boş. Lütfen önce menüden ürün ekleyin.'),
            backgroundColor: EmarColors.paprika,
          ),
        );
        return;
      }

      // 2. Refresh wallet balance before proceeding
      debugPrint('>>> [_handleQrCheckout] Fetching wallet balance...');
      await app.fetchWalletBalance();
      if (!mounted) return;
      debugPrint('>>> [_handleQrCheckout] Wallet balance: ${app.walletBalance}, Effective Cart total: ${app.effectiveCartTotal}');

      if (app.walletBalance < app.effectiveCartTotal) {
        debugPrint('>>> [_handleQrCheckout] Insufficient balance: ${app.walletBalance} < ${app.effectiveCartTotal}');
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
              'Sepet tutarınız: ${app.effectiveCartTotal.toStringAsFixed(2)} ₺\n'
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
      final token = await app.generateWalletToken(
        rewardId: app.useFreeCoffeeReward ? app.orders.availableRewardId : null,
        useReward: app.useFreeCoffeeReward,
      );
      debugPrint('>>> [_handleQrCheckout] QR token received: $token');
      if (!mounted) return;

      if (token != null && token.isNotEmpty) {
        final initialOrderCount = app.orders.orderHistory.length;
        Timer? pollTimer;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) {
            pollTimer ??= Timer.periodic(const Duration(seconds: 2), (_) async {
              if (!mounted) return;
              await app.orders.fetchOrders();
              await app.fetchWalletBalance();
              await app.fetchCart();
              if (!mounted) return;
              if (app.orders.orderHistory.length > initialOrderCount || app.cart.cart.isEmpty) {
                pollTimer?.cancel();
                if (app.useFreeCoffeeReward) {
                  await app.orders.redeemAvailableReward(branchId: app.selectedBranchId);
                  app.setUseFreeCoffeeReward(false);
                }
                if (Navigator.canPop(c)) {
                  Navigator.pop(c);
                }
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Siparişiniz kasada başarıyla onaylandı! ✅'),
                      backgroundColor: EmarColors.moss,
                    ),
                  );
                }
              }
            });

            return Dialog(
              backgroundColor: EmarColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Kasada Ödeme QR Kodunuz',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Lütfen bu kodu baristaya okutunuz.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: EmarColors.espresso.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: 200,
                          height: 200,
                          child: QrImageView(
                            data: token,
                            version: QrVersions.auto,
                            size: 200.0,
                            gapless: true,
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: EmarColors.espresso,
                            ),
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: EmarColors.espresso,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SelectableText(
                        token,
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EmarColors.espresso,
                          ),
                          onPressed: () {
                            pollTimer?.cancel();
                            Navigator.pop(c);
                            app.fetchCart();
                            app.fetchWalletBalance();
                            app.orders.fetchOrders();
                          },
                          child: const Text('Kapat'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
        pollTimer?.cancel();
        await app.fetchCart();
        await app.fetchWalletBalance();
        await app.orders.fetchOrders();
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
