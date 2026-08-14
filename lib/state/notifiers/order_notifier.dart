import 'dart:async';
import 'package:flutter/material.dart';
import 'package:emar_kafe/models/order_record.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';
import 'package:emar_kafe/state/notifiers/cart_notifier.dart';
import 'package:emar_kafe/state/notifiers/wallet_notifier.dart';

class OrderNotifier extends ChangeNotifier with WidgetsBindingObserver {
  final ValueNotifier<OrderRecord?> rateReminderNotifier = ValueNotifier(null);
  final ApiService api;
  final AuthNotifier auth;
  final CartNotifier cart;
  final WalletNotifier wallet;
  
  List<OrderRecord> orderHistory = [];
  List<OrderRecord> get activeBaristaOrders => orderHistory;
  Timer? _pollingTimer;


  OrderNotifier(this.api, this.auth, this.cart, this.wallet) {
    WidgetsBinding.instance.addObserver(this);
    startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startPolling();
      if (auth.loggedIn) fetchOrders();
    } else if (state == AppLifecycleState.paused) {
      stopPolling();
    }
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    super.dispose();
  }

  void startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (auth.loggedIn) fetchOrders();
    });
  }
  
  void stopPolling() {
    _pollingTimer?.cancel();
  }

  Future<void> fetchOrders() async {
    if (!auth.loggedIn) return;
    try {
      if (auth.role == UserRole.customer) {
        final res = await api.getMyOrders();
        if (res is List) {
          orderHistory = res.map((json) => OrderRecord.fromJson(json)).toList();
          notifyListeners();
        }
      } else {
        final res = await api.getBranchOrders();
        if (res is List) {
          orderHistory = res.map((json) => OrderRecord.fromJson(json)).toList();
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  OrderRecord? get activeOrder {
    if (orderHistory.isEmpty) return null;
    final latest = orderHistory.first;
    if (latest.pickedUp) return null;
    return latest;
  }

  Future<OrderRecord?> placeOrder({bool useWallet = false}) async {
    if (!auth.loggedIn) return null;
    
    if (useWallet) {
      if (wallet.walletBalance < cart.cartTotal) throw Exception('Yetersiz bakiye');
    }
    
    if (auth.selectedBranchId == null) throw Exception('Şube seçilmedi');

    await api.placeOrder(auth.selectedBranchId!); 
    await cart.fetchCart(); 
    await fetchOrders(); 
    if (useWallet) await wallet.fetchWalletBalance();
    
    return activeOrder;
  }

  Future<void> advanceOrderStatus(OrderRecord order) async {
    var newStatus = OrderStatus.received;
    if (order.manualStatus == OrderStatus.received || order.manualStatus == OrderStatus.created) {
      newStatus = OrderStatus.preparing;
    } else if (order.manualStatus == OrderStatus.preparing) {
      newStatus = OrderStatus.ready;
    } else {
      return;
    }
    
    try {
      await api.updateOrderStatus(order.id, newStatus.name);
      await fetchOrders(); 
    } catch (e) {
      debugPrint('Order update error: ');
    }
  }

  Future<void> confirmOrderFromQR(String qrToken) async {
    try {
      await api.scanQrOrder(qrToken);
      await fetchOrders();
    } catch (e) {
      throw Exception('QR tarama basarisiz: ');
    }
  }

  Future<void> markPickedUp(OrderRecord order) async {
    try {
      await api.updateOrderStatus(order.id, OrderStatus.completed.name);
      await fetchOrders();
    } catch (e) {
      debugPrint('Pick up error: ');
    }
  }

  int prepMinutesFor(Map<String, int> items, DateTime at) {
    return OrderRecord.computePrep(items, at); // Need to expose computePrep as static public
  }
}
