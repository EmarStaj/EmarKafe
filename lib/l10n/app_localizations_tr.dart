// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'EMAR Kafe';

  @override
  String get home => 'Anasayfa';

  @override
  String get cart => 'Sepetim';

  @override
  String get campaigns => 'Kampanyalar';

  @override
  String get profile => 'Hesabım';

  @override
  String get selectBranch => 'Şube Seç';

  @override
  String get login => 'Giriş Yap';

  @override
  String get logout => 'Çıkış Yap';

  @override
  String get wallet => 'Cüzdanım';

  @override
  String get walletBalance => 'Cüzdan Bakiyesi';

  @override
  String get topUpBalance => 'Bakiye Yükle';

  @override
  String get orderHistory => 'Sipariş Geçmişim';

  @override
  String get orderTracking => 'Sipariş Takibi';

  @override
  String get emptyCart => 'Sepetiniz boş';

  @override
  String get totalPrice => 'Toplam Tutar';

  @override
  String get checkout => 'Siparişi Tamamla';

  @override
  String get loyaltyRewardInfo => '5 Siparişte 1 Kahve Hediye!';

  @override
  String get freeCoffeeReady => 'Bedava İçecek Kullanılabilir';

  @override
  String get outOfStock => 'Tükendi';
}
