import 'package:flutter/foundation.dart';
import '../../services/api_service.dart';
import 'auth_notifier.dart';
import '../../data/catalog.dart';
import '../../models/product.dart';

class FavoritesNotifier extends ChangeNotifier {
  final ApiService api;
  final AuthNotifier auth;

  Set<String> _favoriteProductIds = {};
  bool _isLoading = false;

  FavoritesNotifier(this.api, this.auth);

  Set<String> get favoriteProductIds => Set.unmodifiable(_favoriteProductIds);
  int get count => _favoriteProductIds.length;
  bool get isLoading => _isLoading;

  bool isFavorite(String productId) => _favoriteProductIds.contains(productId);

  List<Product> get favoriteProducts {
    return _favoriteProductIds
        .map((id) => Catalog.instance.byId(id))
        .where((p) => p.name != 'Bilinmeyen ürün')
        .toList();
  }

  void clear() {
    _favoriteProductIds = {};
    notifyListeners();
  }

  Future<void> fetchFavorites() async {
    if (!auth.loggedIn) {
      clear();
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final list = await api.getFavorites();
      final Set<String> ids = {};
      for (final item in list) {
        final pId = item['product_id']?.toString() ?? item['productId']?.toString();
        if (pId != null && pId.isNotEmpty) {
          ids.add(pId);
        }
      }
      _favoriteProductIds = ids;
    } catch (_) {
      // Keep existing state on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String productId) async {
    final wasFav = _favoriteProductIds.contains(productId);
    if (wasFav) {
      _favoriteProductIds.remove(productId);
    } else {
      _favoriteProductIds.add(productId);
    }
    notifyListeners();

    if (!auth.loggedIn) return;

    try {
      if (wasFav) {
        await api.removeFavorite(productId);
      } else {
        await api.addFavorite(productId);
      }
    } catch (_) {
      // Rollback on network failure
      if (wasFav) {
        _favoriteProductIds.add(productId);
      } else {
        _favoriteProductIds.remove(productId);
      }
      notifyListeners();
    }
  }
}
