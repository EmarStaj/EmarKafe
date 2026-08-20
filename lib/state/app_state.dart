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

import 'package:emar_kafe/state/notifiers/auth_notifier.dart';
import 'package:emar_kafe/state/notifiers/cart_notifier.dart';
import 'package:emar_kafe/state/notifiers/order_notifier.dart';
import 'package:emar_kafe/state/notifiers/wallet_notifier.dart';
import 'package:emar_kafe/state/notifiers/stock_notifier.dart';
import 'package:emar_kafe/state/notifiers/staff_notifier.dart';

export 'package:emar_kafe/state/notifiers/auth_notifier.dart';
export 'package:emar_kafe/state/notifiers/cart_notifier.dart';
export 'package:emar_kafe/state/notifiers/order_notifier.dart';
export 'package:emar_kafe/state/notifiers/wallet_notifier.dart';
export 'package:emar_kafe/state/notifiers/stock_notifier.dart';
export 'package:emar_kafe/state/notifiers/staff_notifier.dart';

class AppState extends ChangeNotifier {
  final AuthNotifier auth;
  final CartNotifier cart;
  final OrderNotifier orders;
  final WalletNotifier wallet;
  final StockNotifier stock;
  final MenuNotifier menu;
  final StaffNotifier staff;

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
  int get cartCount => cart.cartCount;
  bool get isUpdatingCart => cart.isUpdatingCart;

  List<OrderRecord> get orderHistory => orders.orderHistory;
  OrderRecord? get activeOrder => orders.activeOrder;

  double get walletBalance => wallet.walletBalance;

  int get loyaltyProgress => orders.loyaltyProgress;
  int get freeCoffeesEarned => orders.freeCoffeesEarned;

  List<Campaign> campaignList = [];
  Map<String, double> ratings = {};
  
  Function(OrderRecord)? onRateReminder;

  AppState(this.auth, this.cart, this.orders, this.wallet, this.stock, this.menu, this.staff) {
    auth.addListener(notifyListeners);
    cart.addListener(notifyListeners);
    orders.addListener(notifyListeners);
    wallet.addListener(notifyListeners);
    stock.addListener(notifyListeners);
    staff.addListener(notifyListeners);
    campaignList = List.of(Catalog.instance.campaigns);
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

  Future<void> loginWithCredentials({required String email, required String password}) => auth.loginWithCredentials(email: email, password: password);
  Future<String?> register({required String name, required String email, required String phone, required String password, required DateTime birthDate, required UserRole selectedRole, required String branch}) => auth.register(name: name, email: email, phone: phone, password: password, birthDate: birthDate, selectedRole: selectedRole, branch: branch);
  Future<void> logout() => auth.logout();
  void selectBranch(String branchId) => auth.selectBranch(branchId);

  Future<List<String>> changeQty(String productId, int delta) => cart.changeQty(productId, delta);
  Future<List<String>> addToCart(String productId, {List<ProductOption> options = const []}) => cart.addToCart(productId, options: options);

  int prepMinutesFor(Map<String, int> items, DateTime at) => orders.prepMinutesFor(items, at);
  Future<OrderRecord?> placeOrder({bool useWallet = false}) => orders.placeOrder(useWallet: useWallet);
  Future<void> advanceOrderStatus(OrderRecord order) => orders.advanceOrderStatus(order);
  Future<void> confirmOrderFromQR(String qrToken) => orders.confirmOrderFromQR(qrToken);
  Future<void> markPickedUp(OrderRecord order) => orders.markPickedUp(order);

  Future<void> addWalletBalance(double amount) => wallet.addWalletBalance(amount);
  Future<String?> generateWalletToken() => wallet.generateWalletToken();
  Future<String?> generateWalletQR() => wallet.generateWalletToken();

  bool hasOrderedProduct(String productId) {
    for (var order in orders.orderHistory) {
      if (order.items.containsKey(productId)) return true;
    }
    return false;
  }
  bool canRateProduct(String productId) {
    return hasOrderedProduct(productId) && !ratings.containsKey(productId);
  }
  Future<void> rateProduct(String productId, double rating, {String? orderId}) async {
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
  Future<void> deleteAccount() => auth.deleteAccount();
}
