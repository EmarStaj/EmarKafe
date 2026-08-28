import 'package:emar_kafe/models/branch.dart';
import 'package:emar_kafe/models/campaign.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/data/catalog.dart';
import 'package:emar_kafe/models/order_record.dart';
import 'package:emar_kafe/models/cart_item.dart';
import 'package:emar_kafe/models/product.dart';
import 'package:emar_kafe/state/notifiers/menu_notifier.dart';

import 'notifiers/auth_notifier.dart';
import 'notifiers/cart_notifier.dart';
import 'notifiers/order_notifier.dart';
import 'notifiers/wallet_notifier.dart';
import 'notifiers/stock_notifier.dart';
import 'notifiers/staff_notifier.dart';
import 'notifiers/favorites_notifier.dart';

export 'notifiers/auth_notifier.dart';
export 'notifiers/cart_notifier.dart';
export 'notifiers/order_notifier.dart';
export 'notifiers/wallet_notifier.dart';
export 'notifiers/stock_notifier.dart';
export 'notifiers/staff_notifier.dart';
export 'notifiers/favorites_notifier.dart';

class AppState extends ChangeNotifier {
  final AuthNotifier auth;
  final CartNotifier cart;
  final OrderNotifier orders;
  final WalletNotifier wallet;
  final StockNotifier stock;
  final MenuNotifier menu;
  final StaffNotifier staff;
  final FavoritesNotifier favorites;

  ApiService get api => auth.api;

  // Aliases for legacy UI
  bool get loggedIn => auth.loggedIn;
  String get userName => auth.userName;
  String get userEmail => auth.userEmail;
  UserRole get role => auth.role;
  DateTime? get birthday => auth.birthday;
  String? get selectedBranchId => auth.selectedBranchId;
  String get selectedBranchName => auth.selectedBranchName;
  String getBranchName(String? id) => auth.getBranchName(id);
  List<Branch> get branches => auth.branches;

  Map<String, CartItem> get cartItems => cart.cart;
  double get cartTotal => cart.cartTotal;
  double get effectiveCartTotal => cart.effectiveCartTotal;
  double get freeCoffeeDiscount => cart.freeCoffeeDiscount;
  bool get useFreeCoffeeReward => cart.useFreeCoffeeReward;
  CartItem? get mostExpensiveCoffeeItem => cart.mostExpensiveCoffeeItem;
  void setUseFreeCoffeeReward(bool value) => cart.setUseFreeCoffeeReward(value);
  int get cartCount => cart.cartCount;
  bool get isUpdatingCart => cart.isUpdatingCart;

  List<OrderRecord> get orderHistory => orders.orderHistory;
  OrderRecord? get activeOrder => orders.activeOrder;

  double get walletBalance => wallet.walletBalance;

  int get loyaltyProgress => orders.loyaltyProgress;
  int get freeCoffeesEarned => orders.freeCoffeesEarned;

  bool isFavorite(String id) => favorites.isFavorite(id);
  Future<void> toggleFavorite(String id) => favorites.toggleFavorite(id);

  List<Campaign> campaignList = [];
  Map<String, double> ratings = {};

  Function(OrderRecord)? onRateReminder;

  AppState(
    this.auth,
    this.cart,
    this.orders,
    this.wallet,
    this.stock,
    this.menu,
    this.staff, [
    FavoritesNotifier? favNotifier,
  ]) : favorites = favNotifier ?? FavoritesNotifier(auth.api, auth) {
    auth.addListener(() {
      if (auth.loggedIn) {
        wallet.fetchWalletBalance();
        orders.fetchOrders();
        cart.fetchCart();
        favorites.fetchFavorites();
        if (auth.selectedBranchId != null) {
          stock.fetchBranchStock(auth.selectedBranchId!);
        }
      } else {
        favorites.clear();
      }
      notifyListeners();
    });
    cart.addListener(notifyListeners);
    orders.addListener(notifyListeners);
    wallet.addListener(notifyListeners);
    stock.addListener(notifyListeners);
    staff.addListener(notifyListeners);
    favorites.addListener(notifyListeners);
    campaignList = List.of(Catalog.instance.campaigns);
    if (auth.loggedIn) {
      wallet.fetchWalletBalance();
      orders.fetchOrders();
      cart.fetchCart();
      favorites.fetchFavorites();
      if (auth.selectedBranchId != null) {
        stock.fetchBranchStock(auth.selectedBranchId!);
      }
    }
  }

  void addCampaign(Campaign c) {
    campaignList.insert(0, c);
    notifyListeners();
  }

  void removeCampaign(Campaign c) {
    campaignList.remove(c);
    notifyListeners();
  }

  bool isOutOfStock(String productId) => stock.isOutOfStock(productId);
  Future<void> toggleStock(String productId) => stock.toggleStock(productId);

  Future<bool> createBranch({
    required String name,
    String? address,
    String? phoneNumber,
    bool isActive = true,
  }) => auth.createBranch(name: name, address: address, phoneNumber: phoneNumber, isActive: isActive);

  Future<bool> updateBranch(
    String branchId, {
    String? name,
    String? address,
    String? phoneNumber,
    bool? isActive,
  }) => auth.updateBranch(branchId, name: name, address: address, phoneNumber: phoneNumber, isActive: isActive);

  Future<bool> deleteBranch(String branchId) => auth.deleteBranch(branchId);

  Future<bool> createProduct({
    required String categoryId,
    required String name,
    required double basePrice,
    String? description,
    String? imageUrl,
    bool isActive = true,
    bool isLoyaltyEligible = true,
  }) => menu.createProduct(
    categoryId: categoryId,
    name: name,
    basePrice: basePrice,
    description: description,
    imageUrl: imageUrl,
    isActive: isActive,
    isLoyaltyEligible: isLoyaltyEligible,
  );

  Future<bool> updateProduct(
    String productId, {
    String? categoryId,
    String? name,
    double? basePrice,
    String? description,
    String? imageUrl,
    bool? isActive,
    bool? isLoyaltyEligible,
  }) => menu.updateProduct(
    productId,
    categoryId: categoryId,
    name: name,
    basePrice: basePrice,
    description: description,
    imageUrl: imageUrl,
    isActive: isActive,
    isLoyaltyEligible: isLoyaltyEligible,
  );

  Future<bool> deleteProduct(String productId) => menu.deleteProduct(productId);

  Future<void> loginWithCredentials({
    required String email,
    required String password,
  }) async {
    await auth.loginWithCredentials(email: email, password: password);
    await wallet.fetchWalletBalance();
    await orders.fetchOrders();
    if (auth.selectedBranchId != null) {
      stock.fetchBranchStock(auth.selectedBranchId!);
      menu.fetchFirstPage();
    }
  }
  Future<String?> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required DateTime birthDate,
    required UserRole selectedRole,
    required String branch,
  }) async {
    final res = await auth.register(
    name: name,
    email: email,
    phone: phone,
    password: password,
    birthDate: birthDate,
    selectedRole: selectedRole,
    branch: branch,
    );
    await wallet.fetchWalletBalance();
    await orders.fetchOrders();
    if (auth.selectedBranchId != null) {
      stock.fetchBranchStock(auth.selectedBranchId!);
      menu.fetchFirstPage();
    }
    return res;
  }
  Future<void> logout() async {
    await auth.logout();
    cart.clear();
    orders.clear();
    wallet.clear();
    staff.clear();
  }
  void selectBranch(String branchId) {
    auth.selectBranch(branchId);
    stock.fetchBranchStock(branchId);
    menu.fetchFirstPage();
  }

  Future<List<String>> changeQty(String productId, int delta) =>
      cart.changeQty(productId, delta);
  Future<List<String>> addToCart(
    String productId, {
    List<ProductOption> options = const [],
  }) => cart.addToCart(productId, options: options);
  Future<void> fetchCart() => cart.fetchCart();

  int prepMinutesFor(Map<String, int> items, DateTime at) =>
      orders.prepMinutesFor(items, at);
  Future<OrderRecord?> placeOrder({bool useWallet = false}) =>
      orders.placeOrder(useWallet: useWallet);
  Future<void> advanceOrderStatus(OrderRecord order) =>
      orders.advanceOrderStatus(order);
  Future<void> confirmOrderFromQR(String qrToken) =>
      orders.confirmOrderFromQR(qrToken);
  Future<void> markPickedUp(OrderRecord order) => orders.markPickedUp(order);

  Future<void> fetchWalletBalance() => wallet.fetchWalletBalance();
  Future<void> addWalletBalance(double amount) =>
      wallet.addWalletBalance(amount);
  Future<String?> generateWalletToken({
    String? rewardId,
    bool useReward = false,
  }) =>
      wallet.generateWalletToken(rewardId: rewardId, useReward: useReward);
  Future<String?> generateWalletQR({
    String? rewardId,
    bool useReward = false,
  }) =>
      wallet.generateWalletToken(rewardId: rewardId, useReward: useReward);

  bool hasOrderedProduct(String productId) {
    for (var order in orders.orderHistory) {
      if (order.items.containsKey(productId)) return true;
    }
    return false;
  }

  bool canRateProduct(String productId) {
    return hasOrderedProduct(productId) && !ratings.containsKey(productId);
  }

  Future<void> rateProduct(
    String productId,
    double rating, {
    String? orderId,
  }) async {
    ratings[productId] = rating;
    notifyListeners();

    try {
      String targetOrderId = orderId ?? '';
      if (targetOrderId.isEmpty) {
        for (var order in orders.orderHistory) {
          if (order.items.containsKey(productId)) {
            targetOrderId = order.id;
            break;
          }
        }
      }

      if (targetOrderId.isNotEmpty) {
        await api.rateProduct(productId, targetOrderId, rating.toInt());
      }
    } catch (e) {
      debugPrint('Rating submit error: $e');
    }
  }

  Future<void> updateEmail(String newEmail) => auth.updateEmail(newEmail);
  Future<void> updateProfile({
    String? name,
    String? email,
    String? phone,
    DateTime? birthDate,
  }) async {
    await api.updateProfile(
      fullName: name,
      email: email,
      phone: phone,
      birthDate: birthDate?.toIso8601String().split('T').first,
    );
    await auth.fetchMe(); // refresh user data
  }
  Future<void> deleteAccount() => auth.deleteAccount();
}
