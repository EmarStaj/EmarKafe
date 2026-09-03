// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'EMAR Coffee';

  @override
  String get home => 'Home';

  @override
  String get cart => 'My Cart';

  @override
  String get campaigns => 'Offers';

  @override
  String get profile => 'Profile';

  @override
  String get selectBranch => 'Select Branch';

  @override
  String get login => 'Sign In';

  @override
  String get logout => 'Sign Out';

  @override
  String get wallet => 'My Wallet';

  @override
  String get walletBalance => 'Wallet Balance';

  @override
  String get topUpBalance => 'Add Funds';

  @override
  String get orderHistory => 'Order History';

  @override
  String get orderTracking => 'Order Tracking';

  @override
  String get emptyCart => 'Your cart is empty';

  @override
  String get totalPrice => 'Total Amount';

  @override
  String get checkout => 'Complete Order';

  @override
  String get loyaltyRewardInfo => '1 Free Coffee Every 5 Orders!';

  @override
  String get freeCoffeeReady => 'Free Drink Available';

  @override
  String get outOfStock => 'Out of Stock';
}
