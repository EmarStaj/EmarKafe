import 'package:flutter/foundation.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';

class WalletNotifier extends ChangeNotifier {
  void clear() {
    walletBalance = 0.0;
    notifyListeners();
  }
  final ApiService api;
  final AuthNotifier auth;

  double walletBalance = 0.0;
  bool isUpdatingWallet = false;

  WalletNotifier(this.api, this.auth);

  Future<void> fetchWalletBalance() async {
    if (!auth.loggedIn) return;
    try {
      final wallet = await api.getWalletBalance();
      num? b = wallet['balance'] as num?;
      if (b == null) {
        if (wallet['wallet_balance'] is num) {
          b = wallet['wallet_balance'] as num;
        } else if (wallet['data'] is num) {
          b = wallet['data'] as num;
        } else if (wallet['data'] is Map) {
          b =
              (wallet['data']['balance'] as num?) ??
              (wallet['data']['wallet_balance'] as num?);
        }
      }
      if (b != null) {
        walletBalance = b.toDouble();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchWalletBalance error: $e');
    }
  }

  Future<void> addWalletBalance(double amount) async {
    isUpdatingWallet = true;
    notifyListeners();
    try {
      if (auth.loggedIn) {
        await api.topupWallet(amount);
        await fetchWalletBalance();
      } else {
        walletBalance += amount;
      }
    } catch (e) {
      debugPrint('Wallet topup API error: $e');
      walletBalance += amount;
    } finally {
      isUpdatingWallet = false;
      notifyListeners();
    }
  }

  Future<String?> generateWalletToken() async {
    if (!auth.loggedIn) throw Exception('Lütfen önce giriş yapınız.');
    isUpdatingWallet = true;
    notifyListeners();
    try {
      final token = await api.getWalletQrToken();
      debugPrint('generateWalletToken success: $token');
      return token;
    } catch (e) {
      debugPrint('generateWalletToken error: $e');
      rethrow;
    } finally {
      isUpdatingWallet = false;
      notifyListeners();
    }
  }
}
