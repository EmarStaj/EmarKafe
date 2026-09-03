import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../state/app_state.dart';
import '../state/notifiers/cart_notifier.dart';
import '../state/notifiers/stock_notifier.dart';
import '../state/notifiers/auth_notifier.dart';
import '../theme.dart';
import '../widgets/pressable_scale.dart';


class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final qty = context.select<CartNotifier, int>(
      (c) => c.cart.values
          .where((i) => i.product.id == product.id)
          .fold(0, (s, i) => s + i.quantity),
    );
    final selectedBranch = context.select<AuthNotifier, String?>((a) => a.selectedBranchId);
    final selectedBranchName = context.select<AuthNotifier, String>((a) => a.selectedBranchName);
    final outOfStock = context.select<StockNotifier, bool>(
      (s) => s.isOutOfStock(product.id, branchId: selectedBranch),
    );

    return InkWell(
      onTap: outOfStock
          ? () {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${product.name}, $selectedBranchName şubesinde şu an bulunmamaktadır.',
                  ),
                  backgroundColor: EmarColors.paprika,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: outOfStock
              ? EmarColors.surface.withValues(alpha: 0.65)
              : EmarColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: outOfStock
                ? EmarColors.paprika.withValues(alpha: 0.25)
                : EmarColors.espresso.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Opacity(
                  opacity: outOfStock ? 0.35 : 1.0,
                  child: Hero(
                    tag: 'product-icon-${product.id}',
                    child: Container(
                      width: double.infinity,
                      height: 68,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: RadialGradient(
                          center: const Alignment(-0.4, -0.4),
                          colors: [EmarColors.gold, EmarColors.roast],
                        ),
                      ),
                      child: Semantics(
                        label: product.name,
                        child: Text(
                          product.icon,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                  ),
                ),
                if (outOfStock)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: EmarColors.paprika,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.block_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Tükendi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: -6,
                    bottom: -10,
                    child: _QuickAddStepper(productId: product.id, qty: qty),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: outOfStock
                    ? EmarColors.espresso.withValues(alpha: 0.45)
                    : EmarColors.espresso,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '★ ${product.rating.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: outOfStock
                        ? EmarColors.gold.withValues(alpha: 0.4)
                        : EmarColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  outOfStock ? 'Şubede Yok' : '${product.price.toStringAsFixed(0)}₺',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: outOfStock
                        ? EmarColors.paprika
                        : EmarColors.espresso.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddStepper extends StatelessWidget {
  final String productId;
  final int qty;
  const _QuickAddStepper({required this.productId, required this.qty});

  void _handleQty(BuildContext context, AppState app, int delta) async {
    final warnings = await app.changeQty(productId, delta);
    if (warnings.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dikkat: ${warnings.first}'),
          backgroundColor: EmarColors.paprika,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: qty > 0
          ? Container(
              key: const ValueKey('stepper'),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: EmarColors.espresso,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: EmarColors.espresso.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepBtn(
                    icon: Icons.remove,
                    onTap: () => _handleQty(context, app, -1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '$qty',
                      style: const TextStyle(
                        color: EmarColors.surface,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  _StepBtn(
                    icon: Icons.add,
                    onTap: () => _handleQty(context, app, 1),
                  ),
                ],
              ),
            )
          : _StepBtn(
              key: const ValueKey('add'),
              icon: Icons.add,
              filled: true,
              onTap: () => _handleQty(context, app, 1),
            ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  const _StepBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? EmarColors.espresso : Colors.transparent,
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: EmarColors.espresso.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, size: 15, color: EmarColors.surface),
        ),
      ),
    );
  }
}

