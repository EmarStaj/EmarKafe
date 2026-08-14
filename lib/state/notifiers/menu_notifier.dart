import 'package:flutter/foundation.dart';
import 'package:emar_kafe/models/product.dart';
import 'package:emar_kafe/services/api_service.dart';

class MenuNotifier extends ChangeNotifier {
  final ApiService api;
  
  List<Product> _products = [];
  List<Product> get products => List.unmodifiable(_products);
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  bool _hasMore = true;
  bool get hasMore => _hasMore;
  
  int _currentPage = 1;

  MenuNotifier(this.api);

  Future<void> fetchFirstPage() async {
    _currentPage = 1;
    _hasMore = true;
    _products.clear();
    await _fetchPage(_currentPage);
  }

  Future<void> fetchNextPage() async {
    if (_isLoading || !_hasMore) return;
    _currentPage++;
    await _fetchPage(_currentPage);
  }

  Future<void> _fetchPage(int page) async {
    _isLoading = true;
    // We notify here if we want to show a loading indicator at the bottom
    notifyListeners();
    
    try {
      final res = await api.getMenu(page: page, limit: 10);
      final list = res['data'] as List<dynamic>? ?? [];
      
      if (list.isEmpty) {
        _hasMore = false;
      } else {
        final newProducts = list.map((p) => Product.fromDb(p as Map<String, dynamic>)).toList();
        _products.addAll(newProducts);
        if (newProducts.length < 10) {
          _hasMore = false;
        }
      }
    } catch (e) {
      debugPrint('MenuNotifier fetch error: ');
      _hasMore = false; // Stop loading on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
