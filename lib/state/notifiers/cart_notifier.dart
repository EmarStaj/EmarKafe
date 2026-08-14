import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/models/catalog.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';

class CartNotifier extends ChangeNotifier {
  final ApiService api;
  final AuthNotifier auth;
  
  Map<String, int> cart = {};
  Map<String, String> cartItemIds = {};
  double cartTotal = 0.0;
  bool isUpdatingCart = false;
  final Map<String, Timer> _cartDebounceTimers = {};

  CartNotifier(this.api, this.auth);

  int get cartCount => cart.values.fold(0, (a, b) => a + b);

  Product productById(String id) {
    for (var cat in Catalog.instance.categories) {
      for (var p in cat.items) {
        if (p.id == id) return p;
      }
    }
    throw Exception('Product not found: ');
  }

  void _recalcTotal() {
    cartTotal = 0.0;
    cart.forEach((id, qty) {
      try {
        final product = productById(id);
        cartTotal += product.price * qty;
      } catch (_) {}
    });
  }

  Future<void> fetchCart() async {
    if (!auth.loggedIn) return;
    try {
      final res = await api.getCart();
      final items = res['items'] as List<dynamic>? ?? [];
      
      cart.clear();
      cartItemIds.clear();
      for (var item in items) {
        final productId = item['product_id'] as String;
        final qty = item['quantity'] as int;
        cart[productId] = qty;
        cartItemIds[productId] = item['id'];
      }
      _recalcTotal();
      notifyListeners();
    } catch (_) {}
  }

  Future<List<String>> changeQty(String productId, int delta) async {
    final originalQty = cart[productId] ?? 0;
    final next = originalQty + delta;
    
    if (next <= 0) {
      cart.remove(productId);
    } else {
      cart[productId] = next;
    }
    
    _recalcTotal();
    notifyListeners();

    if (!auth.loggedIn) return [];
    
    _cartDebounceTimers[productId]?.cancel();
    isUpdatingCart = true;
    notifyListeners();

    _cartDebounceTimers[productId] = Timer(const Duration(milliseconds: 600), () async {
      _cartDebounceTimers.remove(productId);
      
      try {
        final cartItemId = cartItemIds[productId];
        final finalQty = cart[productId] ?? 0;
        
        if (cartItemId != null) {
          await api.updateCartItem(cartItemId, finalQty);
        } else {
          if (finalQty > 0) {
            await api.addToCart(productId, finalQty);
          }
        }
        await fetchCart();
      } catch (e) {
        cart[productId] = originalQty;
        if (originalQty <= 0) cart.remove(productId);
        _recalcTotal();
      } finally {
        if (_cartDebounceTimers.isEmpty) {
          isUpdatingCart = false;
        }
        notifyListeners();
      }
    });

    return [];
  }

  Future<List<String>> addToCart(String productId) {
    return changeQty(productId, 1);
  }
}
