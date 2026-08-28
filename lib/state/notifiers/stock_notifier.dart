import 'package:flutter/foundation.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/services/realtime_service.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';

class StockNotifier extends ChangeNotifier {
  final ApiService api;
  final AuthNotifier auth;
  final RealtimeService? realtime;

  // branchId -> set of productIds out of stock
  final Map<String, Set<String>> _outOfStockByBranch = {};

  StockNotifier(this.api, this.auth, {this.realtime});

  Future<void> fetchBranchStock(String branchId) async {
    // 1. Subscribe to realtime updates for this branch
    realtime?.subscribeToBranchStock(branchId, _handleRealtimeStockUpdate);

    // 2. Fetch current snapshot from API
    try {
      final list = await api.getBranchProducts(branchId);
      final stockSet = _getBranchStock(branchId);
      stockSet.clear();
      for (var item in list) {
        if (item['is_available'] == false) {
          stockSet.add(item['product_id']);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Fetch branch stock error: $e');
    }
  }

  void _handleRealtimeStockUpdate(Map<String, dynamic> record) {
    final branchId = record['branch_id']?.toString();
    final productId = record['product_id']?.toString();
    final isAvailable = record['is_available'] == true;

    if (branchId != null && productId != null) {
      final stockSet = _getBranchStock(branchId);
      if (isAvailable) {
        stockSet.remove(productId);
      } else {
        stockSet.add(productId);
      }
      notifyListeners();
    }
  }

  Set<String> _getBranchStock(String? branchId) {
    if (branchId == null) return {};
    return _outOfStockByBranch.putIfAbsent(branchId, () => {});
  }

  Set<String> get currentBranchOutOfStock =>
      _getBranchStock(auth.selectedBranchId);

  bool isOutOfStock(String productId, {String? branchId}) {
    final bId = branchId ?? auth.selectedBranchId;
    return _getBranchStock(bId).contains(productId);
  }

  Future<void> toggleStock(String productId, {String? branchId}) async {
    final bId = branchId ?? auth.selectedBranchId;
    if (bId == null) return;

    final stockSet = _getBranchStock(bId);
    final willBeAvailable = stockSet.contains(productId);
    if (willBeAvailable) {
      stockSet.remove(productId);
    } else {
      stockSet.add(productId);
    }
    notifyListeners();

    try {
      await api.updateBranchProductAvailability(
        bId,
        productId,
        willBeAvailable,
      );
    } catch (e) {
      debugPrint('Branch stock update error: $e');
    }
  }
}
