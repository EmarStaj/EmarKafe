import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/product_detail_sheet.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favoritesNotifier = context.watch<FavoritesNotifier>();
    final favProducts = favoritesNotifier.favoriteProducts;

    return Scaffold(
      backgroundColor: EmarColors.oat,
      appBar: AppBar(
        backgroundColor: EmarColors.espresso,
        foregroundColor: EmarColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: EmarColors.surface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Text(
              'Favorilerim',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: EmarColors.surface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: EmarColors.paprika,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${favProducts.length}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      body: favProducts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: EmarColors.paprika.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        size: 40,
                        color: EmarColors.paprika,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Henüz favorin yok',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: EmarColors.espresso,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sevdiğin kahve ve tatlıları detay sayfasındaki kalp ikonuna basarak buraya ekleyebilirsin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: EmarColors.espresso.withValues(alpha: 0.6),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    PressableScale(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EmarColors.espresso,
                          foregroundColor: EmarColors.surface,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.coffee_rounded, size: 18),
                        label: const Text('Menüyü Keşfet', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.78,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: favProducts.length,
              itemBuilder: (context, i) {
                final product = favProducts[i];
                return _FavoriteProductCard(product: product);
              },
            ),
    );
  }
}

class _FavoriteProductCard extends StatelessWidget {
  final Product product;
  const _FavoriteProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final outOfStock = app.isOutOfStock(product.id);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showProductDetail(context, product),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EmarColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: EmarColors.espresso.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: EmarColors.oatDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(product.icon, style: const TextStyle(fontSize: 22)),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.favorite_rounded, color: EmarColors.paprika, size: 22),
                  onPressed: () => context.read<AppState>().toggleFavorite(product.id),
                ),
              ],
            ),
            const Spacer(),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: EmarColors.espresso,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              product.category.label,
              style: TextStyle(
                fontSize: 11,
                color: EmarColors.espresso.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${product.price.toStringAsFixed(0)}₺',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: EmarColors.paprika,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: outOfStock ? Colors.grey.withValues(alpha: 0.2) : EmarColors.espresso,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    outOfStock ? 'Tükendi' : 'Seç',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: outOfStock ? Colors.grey : EmarColors.surface,
                    ),
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
