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
      List<dynamic> items = [];
      if (res['items'] is List) {
        items = res['items'] as List<dynamic>;
      } else if (res['data'] is Map && res['data']['items'] is List) {
        items = res['data']['items'] as List<dynamic>;
      } else if (res['data'] is List) {
        items = res['data'] as List<dynamic>;
      }

      final Map<String, CartItem> newCart = {};
      for (var item in items) {
        final productId =
            item['product_id']?.toString() ??
            item['productId']?.toString() ??
            '';
        if (productId.isEmpty) continue;
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final cartItemId = item['id']?.toString() ?? '';

        List<ProductOption> options = [];
        if (item['options'] != null && item['options'] is List) {
          options = (item['options'] as List)
              .map((o) => ProductOption.fromJson(o))
              .toList();
        }

        try {
          final product = productById(productId);
          final localId = _generateLocalId(productId, options);
          newCart[localId] = CartItem(
            cartItemId: cartItemId,
            product: product,
            quantity: qty,
            selectedOptions: options,
          );
        } catch (_) {}
      }
      cart = newCart;
      _recalcTotal();
      notifyListeners();
    } catch (e) {
      debugPrint('fetchCart error: $e');
    }
  }

  Future<List<String>> changeQty(String localId, int delta) async {
    final originalItem = cart[localId];
    if (originalItem == null) {
      if (delta > 0) {
        return addToCart(localId);
      }
      return [];
    }

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

    _cartDebounceTimers[localId] = Timer(
      const Duration(milliseconds: 400),
      () async {
        _cartDebounceTimers.remove(localId);

        try {
          final finalItem = cart[localId];
          final finalQty = finalItem?.quantity ?? 0;

          if (originalItem.cartItemId.isNotEmpty &&
              originalItem.cartItemId != 'local') {
            await api.updateCartItem(originalItem.cartItemId, finalQty);
          } else if (finalQty > 0 && finalItem != null) {
            await api.addToCart(
              finalItem.product.id,
              finalQty,
              options: finalItem.selectedOptions.map((e) => e.id).toList(),
            );
          }
          await fetchCart();
        } catch (e) {
          debugPrint('Cart sync error: $e');
        } finally {
          if (_cartDebounceTimers.isEmpty) {
            isUpdatingCart = false;
          }
          notifyListeners();
        }
      },
    );

    return [];
  }

  Future<List<String>> addToCart(
    String productId, {
    List<ProductOption> options = const [],
  }) async {
    final localId = _generateLocalId(productId, options);
    final existing = cart[localId];

    if (existing != null) {
      return changeQty(localId, 1);
    }

    try {
      final product = productById(productId);
      cart[localId] = CartItem(
        cartItemId: 'local',
        product: product,
        quantity: 1,
        selectedOptions: options,
      );
      _recalcTotal();
      notifyListeners();

      if (auth.loggedIn) {
        isUpdatingCart = true;
        notifyListeners();
        try {
          final warnings = await api.addToCart(
            productId,
            1,
            options: options.map((e) => e.id).toList(),
          );
          await fetchCart();
          return warnings;
        } catch (e) {
          debugPrint('addToCart API error: $e');
        } finally {
          isUpdatingCart = false;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('addToCart error: $e');
    }
    return [];
  }
}
