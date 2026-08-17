/// EMAR Kafe Uygulama Konfigürasyonu
/// Backend sunucu adresi ve global API yollarını tek bir merkezi noktadan yönetir.
/// 
/// Backend adresi değiştiğinde yalnızca bu dosyadaki [_defaultBaseUrl] değerini 
/// güncellemek yeterlidir. Ayrıca derleme anında `--dart-define=API_BASE_URL=https://yeni-adres.com`
/// parametresiyle de esnekçe ezilebilir.
class AppConfig {
  AppConfig._();

  /// Varsayılan Backend Sunucu Adresi (Protokol dahil, sonda slash olmadan)
  static const String _defaultBaseUrl = 'https://emarkafe.duckdns.org';

  /// Aktif Base URL
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  /// API Ana Yolu
  static String get apiBaseUrl => '$baseUrl/api';

  // Sık Kullanılan Modül URL Tanımları
  static String get authUrl => '$apiBaseUrl/auth';
  static String get profileUrl => '$apiBaseUrl/profile';
  static String get menuUrl => '$apiBaseUrl/menu';
  static String get categoriesUrl => '$apiBaseUrl/categories';
  static String get branchesUrl => '$apiBaseUrl/branches';
  static String get cartUrl => '$apiBaseUrl/cart';
  static String get ordersUrl => '$apiBaseUrl/orders';
  static String get walletUrl => '$apiBaseUrl/wallet';
  static String get loyaltyUrl => '$apiBaseUrl/loyalty';
  static String get ratingsUrl => '$apiBaseUrl/ratings';
  static String get favoritesUrl => '$apiBaseUrl/favorites';
  static String get deviceTokensUrl => '$apiBaseUrl/device-tokens';
  static String get settingsUrl => '$apiBaseUrl/settings';
  static String get auditUrl => '$apiBaseUrl/audit';
  static String get staffUrl => '$apiBaseUrl/staff';
}
