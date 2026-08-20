import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/branch.dart';
import '../models/campaign.dart';
import '../models/product.dart';
import '../config/app_config.dart';
import 'menu_data.dart' as seed;

class Catalog {
  Catalog._();
  static final Catalog instance = Catalog._();

  List<Product> _products = List.of(seed.seedProducts);
  List<Branch> _branches = seed.seedBranchNames.map((n) => Branch(id: n, name: n)).toList();
  final List<Campaign> _campaigns = List.of(seed.seedCampaigns);

  bool isRemote = false;

  List<Product> get products => List.unmodifiable(_products);
  List<Branch> get branches => List.unmodifiable(_branches);
  List<Campaign> get campaigns => List.unmodifiable(_campaigns);

  late Map<String, Product> _byId = {for (final p in _products) p.id: p};

  void registerProducts(List<Product> prods) {
    for (final p in prods) {
      _byId[p.id] = p;
      if (!_products.any((existing) => existing.id == p.id)) {
        _products.add(p);
      }
    }
  }

  Product byId(String id) =>
      _byId[id] ??
      Product(
        id: id,
        name: 'Bilinmeyen ürün',
        category: ProductCategory.hotCoffee,
        price: 0,
        icon: '❓',
        rating: 0,
        ratingCount: 0,
      );

  List<Product> similarTo(Product product, {int limit = 4}) {
    final sameCategory = _products
        .where((p) => p.category == product.category && p.id != product.id)
        .toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return sameCategory.take(limit).toList();
  }

  Future<bool> load() async {
    try {
      final res = await http.get(Uri.parse(AppConfig.menuUrl)).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final body = utf8.decode(res.bodyBytes);
        final json = jsonDecode(body);
        if (json is Map && json.containsKey('data')) {
          final list = json['data'] as List;
          if (list.isNotEmpty) {
            _products = list.map((p) => Product.fromDb(p as Map<String, dynamic>)).toList();
            _byId = {for (final p in _products) p.id: p};
            isRemote = true;
          }
        }
      }

      final branchRes = await http.get(Uri.parse(AppConfig.branchesUrl)).timeout(const Duration(seconds: 4));
      if (branchRes.statusCode == 200) {
        final branchBody = utf8.decode(branchRes.bodyBytes);
        final json = jsonDecode(branchBody);
        List? list;
        if (json is List) {
          list = json;
        } else if (json is Map && json.containsKey('data')) {
          list = json['data'] as List?;
        }
        if (list != null && list.isNotEmpty) {
          _branches = list.map((b) => Branch.fromDb(b as Map<String, dynamic>)).toList();
        }
      }

      return isRemote;
    } catch (e) {
      debugPrint('Katalog yükleme uyarısı (yerel yedek kullanılıyor): $e');
      return false;
    }
  }
}
