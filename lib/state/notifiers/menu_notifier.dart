import 'package:flutter/foundation.dart';
import 'package:emar_kafe/models/product.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/data/catalog.dart';

class MenuNotifier extends ChangeNotifier {
  final ApiService api;

  final List<Product> _products = [];
  List<Product> get products => List.unmodifiable(_products);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  int _currentPage = 1;

  MenuNotifier(this.api);

  Future<void> fetchFirstPage({String? branchId}) async {
    _currentBranchId = branchId;
    _currentPage = 1;
    _hasMore = true;
    _products.clear();
    await _fetchPage(_currentPage, _currentBranchId);
  }

  String? _currentBranchId;

  Future<void> fetchNextPage() async {
    if (_isLoading || !_hasMore) return;
    _currentPage++;
    await _fetchPage(_currentPage, _currentBranchId);
  }

  Future<void> _fetchPage(int page, String? branchId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await api.getMenu(page: page, limit: 100, branchId: branchId);
      final list = res['data'] as List<dynamic>? ?? [];

      if (list.isEmpty) {
        _hasMore = false;
      } else {
        final newProducts = list
            .map((p) => Product.fromDb(p as Map<String, dynamic>))
            .toList();
        _products.addAll(newProducts);
        Catalog.instance.registerProducts(newProducts);
        if (newProducts.length < 100) {
          _hasMore = false;
        }
      }
    } catch (e) {
      debugPrint('MenuNotifier fetch error: $e');
      _hasMore = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createProduct({
    required String categoryId,
    required String name,
    required double basePrice,
    String? description,
    String? imageUrl,
    bool isActive = true,
    bool isLoyaltyEligible = true,
  }) async {
    try {
      await api.createProduct(
        categoryId: categoryId,
        name: name,
        basePrice: basePrice,
        description: description,
        imageUrl: imageUrl,
        isActive: isActive,
        isLoyaltyEligible: isLoyaltyEligible,
      );
      await fetchFirstPage(branchId: _currentBranchId);
      return true;
    } catch (e) {
      debugPrint('Create product error: $e');
      return false;
    }
  }

  Future<bool> updateProduct(
    String productId, {
    String? categoryId,
    String? name,
    double? basePrice,
    String? description,
    String? imageUrl,
    bool? isActive,
    bool? isLoyaltyEligible,
  }) async {
    try {
      await api.updateProduct(
        productId,
        categoryId: categoryId,
        name: name,
        basePrice: basePrice,
        description: description,
        imageUrl: imageUrl,
        isActive: isActive,
        isLoyaltyEligible: isLoyaltyEligible,
      );
      await fetchFirstPage(branchId: _currentBranchId);
      return true;
    } catch (e) {
      debugPrint('Update product error: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    try {
      await api.deleteProduct(productId);
      Catalog.instance.removeProduct(productId);
      _products.removeWhere((p) => p.id == productId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Delete product error: $e');
      return false;
    }
  }
}
