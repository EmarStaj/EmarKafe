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
  
  // localId -> CartItem (localId can be productId + options hash)
  Map<String, CartItem> cart = {};
  double cartTotal = 0.0;
  bool isUpdatingCart = false;
  final Map<String, Timer> _cartDebounceTimers = {};

  CartNotifier(this.api, this.auth);

  int get cartCount => cart.values.fold(0, (sum, item) => sum + item.quantity);

  Product productById(String id) {
    return Catalog.instance.byId(id);
  }

  void _recalcTotal() {
    cartTotal = 0.0;
    cart.forEach((key, item) {
      cartTotal += item.totalPrice;
    });
  }
  
  String _generateLocalId(String productId, List<ProductOption> options) {
    if (options.isEmpty) return productId;
    final optIds = options.map((e) => e.id).toList()..sort();
    return '$productId-${optIds.join('-')}';
  }

  Future<void> fetchCart() async {
    if (!auth.loggedIn) return;
    try {
      final res = await api.getCart();
      final items = res['items'] as List<dynamic>? ?? [];
      
      cart.clear();
      for (var item in items) {
        final productId = item['product_id'] as String;
        final qty = item['quantity'] as int;
        final cartItemId = item['id'] as String;
        
        List<ProductOption> options = [];
        if (item['options'] != null) {
           options = (item['options'] as List).map((o) => ProductOption.fromJson(o)).toList();
        }
        
        try {
          final product = productById(productId);
          final localId = _generateLocalId(productId, options);
          cart[localId] = CartItem(
            cartItemId: cartItemId,
            product: product,
            quantity: qty,
            selectedOptions: options,
          );
        } catch (_) {}
      }
      _recalcTotal();
      notifyListeners();
    } catch (_) {}
  }

  Future<List<String>> changeQty(String localId, int delta) async {
    final originalItem = cart[localId];
    if (originalItem == null) return [];
    
    final nextQty = originalItem.quantity + delta;
    
    if (nextQty <= 0) {
      cart.remove(localId);
    } else {
      cart[localId] = originalItem.copyWith(quantity: nextQty);
    }
    
    _recalcTotal();
    notifyListeners();

    if (!auth.loggedIn) return [];
    
    _cartDebounceTimers[localId]?.cancel();
    isUpdatingCart = true;
    notifyListeners();

    _cartDebounceTimers[localId] = Timer(const Duration(milliseconds: 600), () async {
      _cartDebounceTimers.remove(localId);
      
      try {
        final finalItem = cart[localId];
        final finalQty = finalItem?.quantity ?? 0;
        
        if (originalItem.cartItemId.isNotEmpty && originalItem.cartItemId != 'local') {
          await api.updateCartItem(originalItem.cartItemId, finalQty);
        } else if (finalQty > 0 && finalItem != null) {
          // If it's a new item, we might need to add it with options
          await api.addToCart(finalItem.product.id, finalQty, options: finalItem.selectedOptions.map((e) => e.id).toList());
        }
        await fetchCart();
      } catch (e) {
        cart[localId] = originalItem;
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

  Future<List<String>> addToCart(String productId, {List<ProductOption> options = const []}) async {
    final localId = _generateLocalId(productId, options);
    final existing = cart[localId];
    
    if (existing != null) {
      return changeQty(localId, 1);
    } else {
      try {
        final product = productById(productId);
        cart[localId] = CartItem(cartItemId: 'local', product: product, quantity: 1, selectedOptions: options);
        _recalcTotal();
        notifyListeners();
        
        if (auth.loggedIn) {
           isUpdatingCart = true;
           notifyListeners();
           await api.addToCart(productId, 1, options: options.map((e) => e.id).toList());
           await fetchCart();
           isUpdatingCart = false;
           notifyListeners();
        }
      } catch (_) {}
    }
    return [];
  }
}
