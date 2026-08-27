import 'dart:async';
import 'package:flutter/material.dart';
import 'package:emar_kafe/models/order_record.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';
import 'package:emar_kafe/state/notifiers/cart_notifier.dart';
import 'package:emar_kafe/state/notifiers/wallet_notifier.dart';

import 'package:emar_kafe/services/realtime_service.dart';

class OrderNotifier extends ChangeNotifier with WidgetsBindingObserver {
  void clear() {
    orderHistory = [];
    loyaltyProgress = 0;
    freeCoffeesEarned = 0;
    rateReminderNotifier.value = null;
    stopPolling();
    realtime?.unsubscribe();
    notifyListeners();
  }
  final ValueNotifier<OrderRecord?> rateReminderNotifier = ValueNotifier(null);
  final ApiService api;
  final AuthNotifier auth;
  final CartNotifier cart;
  final WalletNotifier wallet;
  final RealtimeService? realtime;

  List<OrderRecord> orderHistory = [];
  List<OrderRecord> get activeBaristaOrders => orderHistory;
  int loyaltyProgress = 0;
  int freeCoffeesEarned = 0;

  Timer? _pollingTimer;

  OrderNotifier(this.api, this.auth, this.cart, this.wallet, {this.realtime}) {
    WidgetsBinding.instance.addObserver(this);
    initRealtime();
    startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      initRealtime();
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
    realtime?.unsubscribe();
    super.dispose();
  }

  void initRealtime() {
    if (!auth.loggedIn) return;
    if (auth.role == UserRole.customer && auth.userId.isNotEmpty) {
      realtime?.subscribeToUserOrders(auth.userId, (record) {
        fetchOrders();
      });
    } else if ((auth.role == UserRole.barista || auth.role == UserRole.manager || auth.role == UserRole.admin) &&
        (auth.selectedBranchId?.isNotEmpty ?? false)) {
      realtime?.subscribeToBranchOrders(auth.selectedBranchId!, (record) {
        fetchOrders();
      });
    }
  }

  void startPolling() {
    _pollingTimer?.cancel();
    // Lightweight 60s fallback heartbeat (realtime handles instant updates)
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (auth.loggedIn) fetchOrders();
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  Future<void> fetchLoyalty() async {
    if (!auth.loggedIn || auth.role != UserRole.customer) return;
    try {
      final res = await api.getLoyaltyProgress();
      final data = res['data'] ?? res;
      if (data is Map) {
        final progressList = data['progress'] as List<dynamic>?;
        final rewardsList = data['rewards'] as List<dynamic>?;

        if (progressList != null && progressList.isNotEmpty) {
          final first = progressList.first as Map<String, dynamic>;
          loyaltyProgress = (first['current_count'] as num?)?.toInt() ?? 0;
        } else {
          loyaltyProgress = 0;
        }

        if (rewardsList != null) {
          freeCoffeesEarned = rewardsList
              .where((r) => r['status'] == 'earned')
              .length;
        } else {
          freeCoffeesEarned = 0;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Loyalty fetch error: $e');
    }
  }

  Future<void> fetchOrders() async {
    if (!auth.loggedIn) return;
    try {
      if (auth.role == UserRole.customer) {
        final res = await api.getMyOrders();
        orderHistory = res.map((json) => OrderRecord.fromJson(json)).toList();
        await fetchLoyalty();
        await wallet.fetchWalletBalance();
        notifyListeners();
      } else {
        final res = await api.getBranchOrders();
        orderHistory = res.map((json) => OrderRecord.fromJson(json)).toList();
        notifyListeners();
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

    await cart.flushDebounces();

    if (useWallet) {
      if (wallet.walletBalance < cart.cartTotal) {
        throw Exception('Yetersiz bakiye');
      }
    }

    if (auth.selectedBranchId == null) throw Exception('Şube seçilmedi');

    await api.placeOrder(auth.selectedBranchId!);
    await cart.fetchCart();
    await fetchOrders();
    if (useWallet) await wallet.fetchWalletBalance();

    return activeOrder;
  }

  Future<void> advanceOrderStatus(OrderRecord order) async {
    OrderStatus newStatus;
    switch (order.computedStatus) {
      case OrderStatus.created:
      case OrderStatus.received:
        newStatus = OrderStatus.preparing;
        break;
      case OrderStatus.preparing:
        newStatus = OrderStatus.ready;
        break;
      case OrderStatus.ready:
        newStatus = OrderStatus.completed;
        break;
      default:
        newStatus = OrderStatus.ready;
        break;
    }

    try {
      await api.updateOrderStatus(order.id, newStatus.name);
      await fetchOrders();
    } catch (e) {
      debugPrint('Order update error: $e');
    }
  }

  Future<void> confirmOrderFromQR(String qrToken) async {
    try {
      await api.scanQrOrder(qrToken);
      await fetchOrders();
    } catch (e) {
      throw Exception('QR tarama basarisiz: $e');
    }
  }

  Future<void> markPickedUp(OrderRecord order) async {
    try {
      await api.updateOrderStatus(order.id, OrderStatus.completed.name);
      await fetchOrders();
    } catch (e) {
      debugPrint('Pick up error: $e');
    }
  }

  int prepMinutesFor(Map<String, int> items, DateTime at) {
    return OrderRecord.computePrep(items, at);
  }
}
