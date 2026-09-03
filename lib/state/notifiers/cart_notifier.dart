import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/data/catalog.dart';
import 'package:emar_kafe/models/product.dart';
import 'package:emar_kafe/models/cart_item.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';

class CartNotifier extends ChangeNotifier {
  final ApiService api;
  final AuthNotifier auth;

  Map<String, CartItem> cart = {};
  double cartTotal = 0.0;
  bool isUpdatingCart = false;
  bool useFreeCoffeeReward = false;

  final Map<String, Timer> _debounceTimers = {};
  final Map<String, int> _pendingQty = {};
  final Map<String, CartItem> _pendingOriginal = {};

  CartNotifier(this.api, this.auth);

  void clear() {
    for (final t in _debounceTimers.values) t.cancel();
    _debounceTimers.clear();
    _pendingQty.clear();
    _pendingOriginal.clear();
    cart = {};
    cartTotal = 0.0;
    isUpdatingCart = false;
    notifyListeners();
  }

  int get cartCount => cart.values.fold(0, (s, i) => s + i.quantity);

  void setUseFreeCoffeeReward(bool value) {
    useFreeCoffeeReward = value;
    notifyListeners();
  }

  CartItem? get mostExpensiveCoffeeItem {
    CartItem? best;
    for (final item in cart.values) {
      final cat = item.product.category;
      if (cat == ProductCategory.hotCoffee || cat == ProductCategory.icedCoffee) {
        if (best == null || item.unitPrice > best.unitPrice) best = item;
      }
    }
    return best;
  }

  double get freeCoffeeDiscount {
    if (!useFreeCoffeeReward) return 0.0;
    return mostExpensiveCoffeeItem?.unitPrice ?? 0.0;
  }

  double get effectiveCartTotal =>
      (cartTotal - freeCoffeeDiscount).clamp(0.0, double.infinity);

  Product _productById(String id) => Catalog.instance.byId(id);

  void _recalcTotal() {
    cartTotal = cart.values.fold(0.0, (s, i) => s + i.totalPrice);
  }

  String _generateLocalId(String productId, List<ProductOption> options) {
    if (options.isEmpty) return productId;
    final sortedIds = (options.map((e) => e.id).toList())..sort();
    return '$productId-${sortedIds.join('-')}';
  }

  Future<void> fetchCart() async {
    if (!auth.loggedIn) return;
    try {
      final res = await api.getCart();
      List<dynamic> items = [];
      if (res['items'] is List) {
        items = res['items'] as List;
      } else if (res['data'] is Map && res['data']['items'] is List) {
        items = res['data']['items'] as List;
      } else if (res['data'] is List) {
        items = res['data'] as List;
      }

      final Map<String, CartItem> serverCart = {};
      for (final raw in items) {
        final productId = raw['product_id']?.toString() ?? raw['productId']?.toString() ?? '';
        if (productId.isEmpty) continue;
        final cartItemId = raw['id']?.toString() ?? '';
        final qty = (raw['quantity'] as num?)?.toInt() ?? 1;
        List<ProductOption> options = [];
        final rawOps = raw['selected_options'] ?? raw['options'];
        if (rawOps is List) options = rawOps.map((o) => ProductOption.fromJson(o)).toList();
        try {
          Product product;
          if (raw['products'] is Map) {
            product = Product.fromDb(raw['products'] as Map<String, dynamic>);
            Catalog.instance.registerProducts([product]);
          } else {
            product = _productById(productId);
          }
          final localId = _generateLocalId(productId, options);
          serverCart[localId] = CartItem(
            cartItemId: cartItemId,
            product: product,
            quantity: qty,
            selectedOptions: options,
            serverUnitPrice: (raw['unit_price'] as num?)?.toDouble(),
          );
        } catch (_) {}
      }

      final Map<String, CartItem> merged = {};
      for (final entry in serverCart.entries) {
        final key = entry.key;
        final serverItem = entry.value;
        final pendingQty = _pendingQty[key];
        if (pendingQty != null) {
          if (pendingQty > 0) merged[key] = serverItem.copyWith(quantity: pendingQty);
        } else {
          merged[key] = serverItem;
        }
      }
      for (final entry in cart.entries) {
        final key = entry.key;
        if (!merged.containsKey(key)) {
          final pending = _pendingQty[key];
          if (pending != null && pending > 0) merged[key] = entry.value.copyWith(quantity: pending);
        }
      }

      cart = merged;
      _recalcTotal();
      notifyListeners();
    } catch (e, s) {
      debugPrint('fetchCart error: $e\n$s');
    }
  }

  Future<List<String>> addToCart(String productId, {List<ProductOption> options = const []}) async {
    final localId = _generateLocalId(productId, options);
    if (cart.containsKey(localId)) return changeQty(localId, 1);
    try {
      final product = _productById(productId);
      cart[localId] = CartItem(cartItemId: 'local', product: product, quantity: 1, selectedOptions: options);
      _pendingQty[localId] = 1;
      _recalcTotal();
      notifyListeners();
      if (!auth.loggedIn) return [];
      isUpdatingCart = true;
      notifyListeners();
      try {
        final warnings = await api.addToCart(productId, 1, options: options.map((e) => e.toJson()).toList());
        await _syncIds();
        return warnings;
      } catch (e) {
        debugPrint('addToCart API error: $e');
        cart.remove(localId);
        _pendingQty.remove(localId);
        _recalcTotal();
        notifyListeners();
      } finally {
        _pendingQty.remove(localId);
        isUpdatingCart = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('addToCart local error: $e');
    }
    return [];
  }

  Future<List<String>> changeQty(String localId, int delta) async {
    final original = cart[localId];
    if (original == null) {
      if (delta > 0) return addToCart(localId);
      return [];
    }
    final newQty = original.quantity + delta;
    if (newQty <= 0) {
      cart.remove(localId);
    } else {
      cart[localId] = original.copyWith(quantity: newQty);
    }
    _pendingQty[localId] = newQty;
    _recalcTotal();
    notifyListeners();
    if (!auth.loggedIn) return [];
    _debounceTimers[localId]?.cancel();
    _pendingOriginal.putIfAbsent(localId, () => original);
    isUpdatingCart = true;
    notifyListeners();
    _debounceTimers[localId] = Timer(
      const Duration(milliseconds: 500),
      () => _flushItem(localId),
    );
    return [];
  }

  Future<void> _flushItem(String localId) async {
    _debounceTimers.remove(localId);
    final targetQty = _pendingQty.remove(localId);
    final originalItem = _pendingOriginal.remove(localId);
    if (targetQty == null) { _maybeStopUpdating(); return; }
    try {
      if (targetQty <= 0) {
        final cartItemId = originalItem?.cartItemId ?? '';
        if (cartItemId.isNotEmpty && cartItemId != 'local') await api.deleteCartItem(cartItemId);
      } else {
        final cartItemId = originalItem?.cartItemId ?? '';
        if (cartItemId.isNotEmpty && cartItemId != 'local') {
          await api.updateCartItem(cartItemId, targetQty);
        } else {
          final currentItem = cart[localId];
          if (currentItem != null) {
            await api.addToCart(currentItem.product.id, targetQty,
                options: currentItem.selectedOptions.map((e) => e.toJson()).toList());
          }
        }
        await _syncIds();
      }
    } catch (e) {
      debugPrint('_flushItem error for $localId: $e');
      await fetchCart();
    }
    _maybeStopUpdating();
  }

  void _maybeStopUpdating() {
    if (_debounceTimers.isEmpty) { isUpdatingCart = false; notifyListeners(); }
  }

  Future<void> _syncIds() async {
    if (!auth.loggedIn) return;
    try {
      final res = await api.getCart();
      List<dynamic> items = [];
      if (res['items'] is List) items = res['items'] as List;
      else if (res['data'] is Map && res['data']['items'] is List) items = res['data']['items'] as List;
      else if (res['data'] is List) items = res['data'] as List;
      for (final raw in items) {
        final productId = raw['product_id']?.toString() ?? raw['productId']?.toString() ?? '';
        if (productId.isEmpty) continue;
        final cartItemId = raw['id']?.toString() ?? '';
        if (cartItemId.isEmpty) continue;
        List<ProductOption> options = [];
        final rawOps = raw['selected_options'] ?? raw['options'];
        if (rawOps is List) options = rawOps.map((o) => ProductOption.fromJson(o)).toList();
        final localId = _generateLocalId(productId, options);
        final local = cart[localId];
        if (local != null && local.cartItemId != cartItemId) {
          cart[localId] = local.copyWith(cartItemId: cartItemId);
        }
      }
      notifyListeners();
    } catch (e) { debugPrint('_syncIds error: $e'); }
  }

  Future<void> flushDebounces() async {
    final keys = List<String>.from(_debounceTimers.keys);
    for (final key in keys) { _debounceTimers[key]?.cancel(); _debounceTimers.remove(key); }
    if (!auth.loggedIn) return;
    final pendingKeys = List<String>.from(_pendingQty.keys);
    for (final localId in pendingKeys) await _flushItem(localId);
    isUpdatingCart = false;
    notifyListeners();
  }
}
