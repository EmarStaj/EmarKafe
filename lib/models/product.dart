enum ProductCategory { hotCoffee, icedCoffee, dessert }

extension ProductCategoryLabel on ProductCategory {
  String get label => switch (this) {
    ProductCategory.hotCoffee => 'Sıcak Kahve',
    ProductCategory.icedCoffee => 'Soğuk Kahve',
    ProductCategory.dessert => 'Tatlı',
  };
}

ProductCategory productCategoryFromName(String name) => switch (name.trim()) {
  'Soğuk Kahve' => ProductCategory.icedCoffee,
  'Tatlı' => ProductCategory.dessert,
  _ => ProductCategory.hotCoffee,
};

class ProductOption {
  final String id;
  final String name;
  final double priceDelta;

  const ProductOption({
    required this.id,
    required this.name,
    this.priceDelta = 0.0,
  });

  factory ProductOption.fromJson(Map<String, dynamic> json) {
    return ProductOption(
      id: json['id'] as String,
      name: json['name'] as String,
      priceDelta: (json['price_delta'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price_delta': priceDelta,
  };
}

class Product {
  final String id;
  final String name;
  final ProductCategory category;
  final double price;
  final String icon;
  final double rating;
  final int ratingCount;
  final List<String> pairsWith;
  final String categoryId;
  final String? description;
  final bool isActive;
  final bool isLoyaltyEligible;
  final List<ProductOption> options; // ADDED

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.icon,
    required this.rating,
    required this.ratingCount,
    this.pairsWith = const [],
    this.categoryId = '',
    this.description,
    this.isActive = true,
    this.isLoyaltyEligible = true,
    this.options = const [], // ADDED
  });

  factory Product.fromDb(
    Map<String, dynamic> row, {
    List<String> pairsWith = const [],
  }) {
    final categoryName =
        (row['categories'] as Map<String, dynamic>?)?['name'] as String? ?? '';

    List<ProductOption> parsedOptions = [];
    if (row['product_options'] != null && row['product_options'] is List) {
      for (var group in (row['product_options'] as List)) {
        if (group['product_option_values'] != null && group['product_option_values'] is List) {
          for (var val in (group['product_option_values'] as List)) {
            parsedOptions.add(ProductOption(
              id: val['id'].toString(),
              name: "${group['name']}: ${val['label']}",
              priceDelta: (val['price_delta'] as num?)?.toDouble() ?? 0.0,
            ));
          }
        }
      }
    } else if (row['options'] != null && row['options'] is List) {
      for (var opt in (row['options'] as List)) {
        if (opt is Map<String, dynamic>) {
          parsedOptions.add(ProductOption.fromJson(opt));
        }
      }
    }

    return Product(
      id: row['id'] as String,
      name: row['name'] as String,
      category: productCategoryFromName(categoryName),
      categoryId: row['category_id'] as String,
      price: (row['base_price'] as num).toDouble(),
      icon: row['icon'] as String? ?? '☕',
      rating:
          (row['avg_rating'] as num?)?.toDouble() ??
          (row['rating'] as num?)?.toDouble() ??
          0.0,
      ratingCount: (row['rating_count'] as num?)?.toInt() ?? 0,
      description: row['description'] as String?,
      isActive: row['is_active'] as bool? ?? true,
      isLoyaltyEligible: row['is_loyalty_eligible'] as bool? ?? true,
      pairsWith: pairsWith,
      options: parsedOptions,
    );
  }

  bool get isDessert => category == ProductCategory.dessert;
  bool get isCoffee => !isDessert;
}
