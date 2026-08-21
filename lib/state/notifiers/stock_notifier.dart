import 'package:flutter/foundation.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';

class StockNotifier extends ChangeNotifier {
  final ApiService api;
  final AuthNotifier auth;

  // branchId -> set of productIds out of stock
  final Map<String, Set<String>> _outOfStockByBranch = {};

  StockNotifier(this.api, this.auth);

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
