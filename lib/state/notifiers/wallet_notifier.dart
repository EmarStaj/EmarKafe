import 'package:flutter/foundation.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';

class WalletNotifier extends ChangeNotifier {
  final ApiService api;
  final AuthNotifier auth;
  
  double walletBalance = 0.0;
  bool isUpdatingWallet = false;

  WalletNotifier(this.api, this.auth);

  Future<void> fetchWalletBalance() async {
    if (!auth.loggedIn) return;
    try {
      final wallet = await api.getWalletBalance();
      walletBalance = (wallet['balance'] ?? 0.0).toDouble();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> addWalletBalance(double amount) async {
    if (!auth.loggedIn) return;
    try {
      isUpdatingWallet = true;
      notifyListeners();
      await api.topupWallet(amount);
      await fetchWalletBalance();
    } catch (e) {
      debugPrint('Wallet topup error: ');
    } finally {
      isUpdatingWallet = false;
      notifyListeners();
    }
  }

  Future<String?> generateWalletToken() async {
    if (!auth.loggedIn) return null;
    isUpdatingWallet = true;
    notifyListeners();
    try {
      return await api.getWalletQrToken();
    } catch (e) {
      return null;
    } finally {
      isUpdatingWallet = false;
      notifyListeners();
    }
  }
}
