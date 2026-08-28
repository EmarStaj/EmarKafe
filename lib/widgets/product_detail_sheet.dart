import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../data/menu_data.dart';
import '../models/product.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'pressable_scale.dart';

Future<void> showProductDetail(BuildContext context, Product product) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _ProductDetailSheet(product: product),
  );
}

class _ProductDetailSheet extends StatefulWidget {
  final Product product;
  const _ProductDetailSheet({required this.product});

  @override
  State<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<_ProductDetailSheet> {
  // Map of GroupId -> Selected Single Option Item
  final Map<String, ProductOptionItem> _singleSelections = {};
  // Set of Selected Multi-Option Items
  final Set<ProductOptionItem> _multiSelections = {};
  // For legacy flat options
  final List<ProductOption> _legacySelectedOptions = [];

  @override
  void initState() {
    super.initState();
    _initDefaultSelections();
  }

  void _initDefaultSelections() {
    final groups = widget.product.optionGroups;
    for (final group in groups) {
      if (!group.isMultiSelect && group.items.isNotEmpty) {
        if (group.isRequired || group.name.toLowerCase().contains('boyut') || group.name.toLowerCase().contains('şeker')) {
          _singleSelections[group.id] = group.items.first;
        }
      }
    }
  }

  List<ProductOption> get _allSelectedProductOptions {
    final List<ProductOption> list = [];
    // From structured groups
    for (final group in widget.product.optionGroups) {
      if (!group.isMultiSelect) {
        final selected = _singleSelections[group.id];
        if (selected != null) {
          list.add(selected.toProductOption(group.name));
        }
      } else {
        for (final item in group.items) {
          if (_multiSelections.contains(item)) {
            list.add(item.toProductOption(group.name));
          }
        }
      }
    }
    // From legacy flat options
    list.addAll(_legacySelectedOptions);
    return list;
  }

  double get _currentPrice {
    double total = widget.product.price;
    for (final opt in _allSelectedProductOptions) {
      total += opt.priceDelta;
    }
    return total < 0 ? 0 : total;
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final app = context.watch<AppState>();

    // Dynamic cross-pairing: if coffee -> suggest top desserts; if dessert -> suggest top coffees!
    List<Product> pairs = product.pairsWith
        .map(productById)
        .where((p) => p.name != 'Bilinmeyen ürün' && p.id != product.id)
        .toList();
    if (pairs.isEmpty) {
      final all = Catalog.instance.products;
      if (product.isCoffee) {
        pairs = all.where((p) => p.isDessert && p.id != product.id).toList()
          ..sort((a, b) => b.rating.compareTo(a.rating));
      } else {
        pairs = all.where((p) => p.isCoffee && p.id != product.id).toList()
          ..sort((a, b) => b.rating.compareTo(a.rating));
      }
      pairs = pairs.take(4).toList();
    }

    final similar = similarTo(product);
    final myRating = app.ratings[product.id] ?? 0;
    final outOfStock = app.isOutOfStock(product.id);

    return DraggableScrollableSheet(
      initialChildSize: 0.76,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: EmarColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: EmarColors.espresso.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Hero(
                    tag: 'product-icon-${product.id}',
                    child: Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: RadialGradient(
                          center: const Alignment(-0.4, -0.4),
                          colors: [EmarColors.gold, EmarColors.roast],
                        ),
                      ),
                      child: Text(
                        product.icon,
                        style: const TextStyle(fontSize: 30),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${product.category.label} · ${product.ratingCount} puanlama',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: EmarColors.espresso.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${product.price.toStringAsFixed(0)}₺',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: EmarColors.paprika,
                                fontSize: 16,
                              ),
                            ),
                            if (outOfStock) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: EmarColors.paprikaDim.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Şu an tükendi',
                                  style: TextStyle(
                                    color: EmarColors.paprikaDim,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      app.isFavorite(product.id)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: app.isFavorite(product.id)
                          ? EmarColors.paprika
                          : EmarColors.espresso.withValues(alpha: 0.45),
                      size: 28,
                    ),
                    tooltip: 'Favori',
                    onPressed: () {
                      final wasFav = app.isFavorite(product.id);
                      app.toggleFavorite(product.id);
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            wasFav
                                ? '${product.name} favorilerden çıkarıldı.'
                                : '${product.name} favorilere eklendi! ❤️',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Bu ürünü puanla',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              _RatingSection(product: product, myRating: myRating),

              // Structured Option Groups
              if (product.optionGroups.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),
                ...product.optionGroups.map((group) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: EmarColors.espresso,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: group.isRequired
                                  ? EmarColors.paprika.withValues(alpha: 0.1)
                                  : EmarColors.moss.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              group.isRequired ? 'Zorunlu' : 'İsteğe Bağlı',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: group.isRequired ? EmarColors.paprika : EmarColors.moss,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: group.items.map((item) {
                          final isSelected = group.isMultiSelect
                              ? _multiSelections.contains(item)
                              : _singleSelections[group.id]?.id == item.id;

                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                if (group.isMultiSelect) {
                                  if (_multiSelections.contains(item)) {
                                    _multiSelections.remove(item);
                                  } else {
                                    _multiSelections.add(item);
                                  }
                                } else {
                                  if (_singleSelections[group.id]?.id == item.id && !group.isRequired) {
                                    _singleSelections.remove(group.id);
                                  } else {
                                    _singleSelections[group.id] = item;
                                  }
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? EmarColors.espresso : EmarColors.oatDark,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? EmarColors.espresso : EmarColors.espresso.withValues(alpha: 0.08),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected) ...[
                                    const Icon(Icons.check, size: 14, color: EmarColors.surface),
                                    const SizedBox(width: 5),
                                  ],
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? EmarColors.surface : EmarColors.espresso,
                                    ),
                                  ),
                                  if (item.priceDelta != 0) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '${item.priceDelta > 0 ? '+' : ''}${item.priceDelta.toStringAsFixed(0)}₺',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? EmarColors.gold : EmarColors.paprika,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],
                  );
                }),
              ] else if (product.options.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Opsiyonlar',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...product.options.map((opt) {
                  final selected = _legacySelectedOptions.contains(opt);
                  return CheckboxListTile(
                    value: selected,
                    onChanged: (v) {
                      setState(() {
                        if (_legacySelectedOptions.contains(opt)) {
                          _legacySelectedOptions.remove(opt);
                        } else {
                          _legacySelectedOptions.add(opt);
                        }
                      });
                    },
                    title: Text(opt.name),
                    subtitle: opt.priceDelta != 0
                        ? Text(
                            '${opt.priceDelta > 0 ? '+' : ''}${opt.priceDelta.toStringAsFixed(0)}₺',
                            style: TextStyle(
                              color: opt.priceDelta > 0
                                  ? EmarColors.paprika
                                  : EmarColors.moss,
                            ),
                          )
                        : null,
                    activeColor: EmarColors.espresso,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }),
              ],

              const SizedBox(height: 8),
              _PairRow(title: 'Yanında bunlar iyi gider', products: pairs),
              const SizedBox(height: 16),
              _PairRow(title: 'Bunları da sevebilirsin', products: similar),
              const SizedBox(height: 20),
              PressableScale(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: outOfStock
                        ? null
                        : () async {
                            final warnings = await context
                                .read<AppState>()
                                .addToCart(
                                  product.id,
                                  options: _allSelectedProductOptions,
                                );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              if (warnings.isNotEmpty) {
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
                          },
                    child: Text(
                      outOfStock
                          ? 'Şu An Tükendi'
                          : 'Sepete Ekle · ${_currentPrice.toStringAsFixed(0)}₺',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RatingSection extends StatelessWidget {
  final Product product;
  final double myRating;
  const _RatingSection({required this.product, required this.myRating});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ordered = app.hasOrderedProduct(product.id);

    if (!ordered) {
      return Text(
        'Bu ürünü değerlendirmek için önce sipariş etmelisin.',
        style: TextStyle(
          fontSize: 12,
          color: EmarColors.espresso.withValues(alpha: 0.5),
        ),
      );
    }

    final unlocked = app.canRateProduct(product.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (i) {
            final filled = i < myRating;
            return IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32),
              onPressed: unlocked
                  ? () =>
                        context.read<AppState>().rateProduct(product.id, i + 1)
                  : null,
              icon: Icon(
                filled ? Icons.star_rounded : Icons.star_border_rounded,
                color: unlocked
                    ? EmarColors.gold
                    : EmarColors.espresso.withValues(alpha: 0.25),
                size: 26,
              ),
            );
          }),
        ),
        if (!unlocked)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Değerlendirme, siparişin hazır olmasından 5 dk sonra ya da bir sonraki girişinde açılacak.',
              style: TextStyle(
                fontSize: 11,
                color: EmarColors.espresso.withValues(alpha: 0.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _PairRow extends StatelessWidget {
  final String title;
  final List<Product> products;
  const _PairRow({required this.title, required this.products});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: EmarColors.espresso.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final p = products[i];
              final out = context.watch<AppState>().isOutOfStock(p.id);
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: out
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        showProductDetail(context, p);
                      },
                child: Opacity(
                  opacity: out ? 0.45 : 1,
                  child: Container(
                    padding: const EdgeInsets.only(left: 4, right: 12),
                    decoration: BoxDecoration(
                      color: EmarColors.oatDark,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: EmarColors.moss,
                          child: Text(
                            p.icon,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
