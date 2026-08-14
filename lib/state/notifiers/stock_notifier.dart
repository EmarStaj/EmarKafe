import 'package:flutter/foundation.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';
import 'package:emar_kafe/models/catalog.dart';

class StockNotifier extends ChangeNotifier {
  final ApiService api;
  final AuthNotifier auth;
  
  final Set<String> outOfStock = {};

  StockNotifier(this.api, this.auth);

  bool isOutOfStock(String productId) => outOfStock.contains(productId);

  void toggleStock(String productId) {
    if (!outOfStock.add(productId)) outOfStock.remove(productId);
    notifyListeners();
  }
}
