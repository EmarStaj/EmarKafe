import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final List<dynamic>? errors;

  ApiException(this.message, this.statusCode, {this.errors});

  @override
  String toString() => 'ApiException: $message';
}

class ApiService {
  static String get baseUrl => AppConfig.baseUrl;
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';

  final FlutterSecureStorage _storage;
  late final Dio _dio;
  late final Dio _tokenDio;

  String? _token;
  String? _refreshToken;

  String? get token => _token;
  String? get refreshToken => _refreshToken;
  Dio get dio => _dio;

  ApiService({FlutterSecureStorage storage = const FlutterSecureStorage(), Dio? dioClient})
      : _storage = storage {
    _dio = dioClient ??
        Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: {'Content-Type': 'application/json'},
          ),
        );

    _tokenDio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
        onError: (DioException err, handler) async {
          final isAuthEndpoint = err.requestOptions.path.contains('/auth/login') ||
              err.requestOptions.path.contains('/auth/register') ||
              err.requestOptions.path.contains('/auth/refresh');

          if (err.response?.statusCode == 401 && !isAuthEndpoint && _refreshToken != null && _refreshToken!.isNotEmpty) {
            try {
              final refreshRes = await _tokenDio.post(
                '$baseUrl/api/v1/auth/refresh',
                data: {'refresh_token': _refreshToken},
              );

              final data = refreshRes.data;
              String? newAccess;
              String? newRefresh;

              if (data is Map<String, dynamic>) {
                if (data['data'] is Map<String, dynamic>) {
                  newAccess = data['data']['access_token']?.toString();
                  newRefresh = data['data']['refresh_token']?.toString();
                } else {
                  newAccess = data['access_token']?.toString();
                  newRefresh = data['refresh_token']?.toString();
                }
              }

              if (newAccess != null && newAccess.isNotEmpty) {
                await saveTokens(newAccess, refreshToken: newRefresh);
                err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
                final response = await _dio.fetch(err.requestOptions);
                return handler.resolve(response);
              }
            } catch (refreshErr) {
              debugPrint('Token refresh failed: $refreshErr');
              await clearToken();
            }
          }
          return handler.next(err);
        },
      ),
    );
  }

  Future<void> init() async {
    try {
      _token = await _storage.read(key: _tokenKey);
      _refreshToken = await _storage.read(key: _refreshTokenKey);
    } catch (e) {
      debugPrint('SecureStorage read error: $e');
    }
  }

  Future<void> saveTokens(String token, {String? refreshToken}) async {
    _token = token;
    try {
      await _storage.write(key: _tokenKey, value: token);
      if (refreshToken != null) {
        _refreshToken = refreshToken;
        await _storage.write(key: _refreshTokenKey, value: refreshToken);
      }
    } catch (e) {
      debugPrint('SecureStorage write error: $e');
    }
  }

  Future<void> clearToken() async {
    _token = null;
    _refreshToken = null;
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _refreshTokenKey);
    } catch (e) {
      debugPrint('SecureStorage delete error: $e');
    }
  }

  // --- Generic Request Handlers ---

  Future<Response> _get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> _post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> _put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> _delete(String path, {dynamic data}) async {
    try {
      return await _dio.delete(path, data: data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // --- Auth ---

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _post(
      '$baseUrl/api/v1/auth/login',
      data: {'email': email, 'password': password},
    );
    return _processResponse(res);
  }

  Future<Map<String, dynamic>> register(
    String email,
    String phone,
    String password,
    String name,
    String birthDate, {
    String? role,
    String? branchId,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'phone': phone,
      'password': password,
      'full_name': name,
      'birth_date': birthDate,
    };
    if (role != null) body['role'] = role;
    if (branchId != null) body['branch_id'] = branchId;

    final res = await _post(
      '$baseUrl/api/v1/auth/register',
      data: body,
    );
    return _processResponse(res);
  }

  Future<void> forgotPassword(String email) async {
    final res = await _post(
      '$baseUrl/api/v1/auth/forgot-password',
      data: {'email': email},
    );
    _processResponse(res);
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _get('$baseUrl/api/v1/auth/me');
    return _processResponse(res);
  }

  Future<void> logout() async {
    try {
      await _post('$baseUrl/api/v1/auth/logout');
    } catch (_) {}
    await clearToken();
  }

  // --- Profile ---

  Future<Map<String, dynamic>> getProfile() async {
    final res = await _get('$baseUrl/api/v1/profile/me');
    return _processResponse(res);
  }

  Future<void> updateProfile({
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
    String? birthDate,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (birthDate != null) body['birth_date'] = birthDate;

    final res = await _put(
      '$baseUrl/api/v1/profile/me',
      data: body,
    );
    _processResponse(res);
  }

  Future<void> setDefaultBranch(String branchId) async {
    final res = await _put(
      '$baseUrl/api/v1/profile/me/default-branch',
      data: {'branch_id': branchId},
    );
    _processResponse(res);
  }

  Future<void> updateEmail(String newEmail) async {
    final res = await _put(
      '$baseUrl/api/v1/profile/email',
      data: {'email': newEmail},
    );
    _processResponse(res);
  }

  Future<void> deleteAccount() async {
    final res = await _delete('$baseUrl/api/v1/profile/me');
    _processResponse(res);
    await clearToken();
  }

  // --- Catalog & Menu ---

  Future<Map<String, dynamic>> getMenu({
    int page = 1,
    int limit = 20,
    String? categoryId,
    String? search,
    String? branchId,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (branchId != null) params['branch_id'] = branchId;
    if (categoryId != null) params['category_id'] = categoryId;
    if (search != null) params['search'] = search;

    final res = await _get('$baseUrl/api/v1/menu', queryParameters: params);
    return _processResponse(res);
  }

  Future<List<dynamic>> getCategories() async {
    final res = await _get('$baseUrl/api/v1/categories');
    final data = _processResponse(res);
    return data['data'] as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> getBranches() async {
    final res = await _get('$baseUrl/api/v1/branches');
    final data = _processResponse(res);
    return data['data'] as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> getBranchProducts(String branchId) async {
    final res = await _get('$baseUrl/api/v1/branches/$branchId/products');
    final data = _processResponse(res);
    return data['data'] as List<dynamic>;
  }

  Future<void> updateBranchProductAvailability(
    String branchId,
    String productId,
    bool isAvailable,
  ) async {
    final res = await _put(
      '$baseUrl/api/v1/branches/$branchId/products/$productId',
      data: {'is_available': isAvailable},
    );
    _processResponse(res);
  }

  // --- Wallet ---

  Future<Map<String, dynamic>> getWalletBalance() async {
    final res = await _get('$baseUrl/api/v1/wallet/balance');
    return _processResponse(res);
  }

  Future<void> topupWallet(double amount) async {
    final res = await _post(
      '$baseUrl/api/v1/wallet/topup',
      data: {'amount': amount},
    );
    _processResponse(res);
  }

  Future<String> getWalletQrToken() async {
    final res = await _get('$baseUrl/api/v1/wallet/qr');
    final data = _processResponse(res);
    return data['qr_token'] as String;
  }

  // --- Cart ---

  Future<Map<String, dynamic>> getCart() async {
    final res = await _get('$baseUrl/api/v1/cart');
    return _processResponse(res);
  }

  Future<List<String>> addToCart(
    String productId,
    int qty, {
    List<dynamic>? options,
  }) async {
    final payload = <String, dynamic>{'product_id': productId, 'quantity': qty};
    if (options != null && options.isNotEmpty) {
      payload['selected_options'] = options;
    }

    final res = await _post(
      '$baseUrl/api/v1/cart',
      data: payload,
    );
    _processResponse(res);

    if (res.statusCode == 201 || res.statusCode == 200) {
      try {
        final body = res.data;
        if (body is Map<String, dynamic> && body['warnings'] != null) {
          final warnings = body['warnings'] as List<dynamic>;
          return warnings.map((w) => w['message'].toString()).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  Future<void> updateCartItem(String cartItemId, int qty) async {
    final res = await _put(
      '$baseUrl/api/v1/cart/$cartItemId',
      data: {'quantity': qty},
    );
    _processResponse(res);
  }

  Future<void> deleteCartItem(String cartItemId) async {
    final res = await _delete('$baseUrl/api/v1/cart/$cartItemId');
    _processResponse(res);
  }

  Future<void> clearCart() async {
    final res = await _delete('$baseUrl/api/v1/cart');
    _processResponse(res);
  }

  // --- Orders ---

  Future<void> placeOrder(String branchId) async {
    final res = await _post(
      '$baseUrl/api/v1/orders',
      data: {'branch_id': branchId},
    );
    _processResponse(res);
  }

  Future<List<dynamic>> getMyOrders() async {
    final res = await _get('$baseUrl/api/v1/orders');
    final data = _processResponse(res);
    return data['data'] as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> getBranchOrders() async {
    final res = await _get('$baseUrl/api/v1/orders/branch');
    final data = _processResponse(res);
    return data['data'] as List<dynamic>? ?? [];
  }

  Future<void> scanQrOrder(String qrToken) async {
    final res = await _post(
      '$baseUrl/api/v1/orders/scan-qr',
      data: {'qr_token': qrToken},
    );
    _processResponse(res);
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    final res = await _put(
      '$baseUrl/api/v1/orders/$orderId/status',
      data: {'status': status},
    );
    _processResponse(res);
  }

  // --- Loyalty ---

  Future<Map<String, dynamic>> getLoyaltyProgress() async {
    final res = await _get('$baseUrl/api/v1/loyalty');
    return _processResponse(res);
  }

  Future<void> redeemLoyaltyReward(String rewardId, String branchId) async {
    final res = await _post(
      '$baseUrl/api/v1/loyalty/redeem',
      data: {'reward_id': rewardId, 'branch_id': branchId},
    );
    _processResponse(res);
  }

  // --- Staff Management ---

  /// Admin: tüm personeli listele. Manager: kendi şubesinin personelini listele.
  Future<List<dynamic>> getStaff({String? branchId}) async {
    final params = <String, dynamic>{};
    if (branchId != null) params['branch_id'] = branchId;
    final res = await _get('$baseUrl/api/v1/staff', queryParameters: params.isEmpty ? null : params);
    final data = _processResponse(res);
    return data['data'] as List<dynamic>? ??
        (data['staff'] as List<dynamic>? ?? []);
  }

  /// Admin: yeni personel oluştur (barista veya branch_manager).
  Future<Map<String, dynamic>> createStaff({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? branchId,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'full_name': fullName,
      'role': role,
    };
    if (branchId != null) body['branch_id'] = branchId;
    final res = await _post(
      '$baseUrl/api/v1/staff',
      data: body,
    );
    return _processResponse(res);
  }

  /// Personeli güncelle (rol, şube vb.)
  Future<void> updateStaff(
    String staffId, {
    String? role,
    String? branchId,
    String? fullName,
  }) async {
    final body = <String, dynamic>{};
    if (role != null) body['role'] = role;
    if (branchId != null) body['branch_id'] = branchId;
    if (fullName != null) body['full_name'] = fullName;
    final res = await _put(
      '$baseUrl/api/v1/staff/$staffId',
      data: body,
    );
    _processResponse(res);
  }

  /// Personeli sil (Supabase auth kaydı dahil).
  Future<void> deleteStaff(String staffId) async {
    final res = await _delete('$baseUrl/api/v1/staff/$staffId');
    _processResponse(res);
  }

  // --- Ratings ---

  Future<void> rateProduct(String productId, String orderId, int rating) async {
    final res = await _post(
      '$baseUrl/api/v1/ratings',
      data: {
        'product_id': productId,
        'order_id': orderId,
        'rating': rating,
      },
    );
    _processResponse(res);
  }

  // --- Favorites ---

  Future<List<dynamic>> getFavorites() async {
    final res = await _get('$baseUrl/api/v1/favorites');
    final data = _processResponse(res);
    return data['data'] as List<dynamic>? ?? [];
  }

  Future<void> addFavorite(String productId) async {
    final res = await _post(
      '$baseUrl/api/v1/favorites',
      data: {'product_id': productId},
    );
    _processResponse(res);
  }

  Future<void> removeFavorite(String productId) async {
    final res = await _delete('$baseUrl/api/v1/favorites/$productId');
    _processResponse(res);
  }

  // --- Device Tokens (OneSignal) ---

  Future<void> registerDeviceToken(String osId) async {
    if (_token == null) return;
    try {
      await _post(
        '$baseUrl/api/v1/device-tokens',
        data: {
          'onesignal_id': osId,
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        },
      );
    } catch (_) {}
  }

  Map<String, dynamic> _processResponse(Response response) {
    final statusCode = response.statusCode ?? 200;
    if (statusCode >= 200 && statusCode < 300) {
      final data = response.data;
      if (data == null) return {};
      if (data is Map<String, dynamic>) {
        if (data['success'] == false) {
          final msg = data['message']?.toString() ?? 'Sunucu işlemi reddetti';
          throw ApiException(msg, statusCode);
        }
        if (data.containsKey('data')) {
          final innerData = data['data'];
          if (innerData is Map<String, dynamic>) {
            if (data.containsKey('message')) {
              innerData['__message'] = data['message'];
            }
            return innerData;
          }
          if (innerData is List) {
            return {'data': innerData};
          }
        }
        return data;
      }
      return {};
    }
    throw ApiException('Sunucu hatası: $statusCode', statusCode);
  }

  ApiException _handleDioError(DioException e) {
    final statusCode = e.response?.statusCode ?? 500;
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return ApiException('Bağlantı zaman aşımına uğradı', 408);
    }

    String msg = 'Sunucu hatası: ';
    if (statusCode == 400 || statusCode == 401) {
      msg = 'E-posta veya şifre hatalı.';
    } else if (statusCode == 429) {
      msg = 'Çok fazla deneme yaptınız. 15 dakika bekleyin.';
    } else if (statusCode >= 500) {
      msg = 'Sunucu hatası. Lütfen tekrar deneyin.';
    }

    List<dynamic>? errors;
    final resData = e.response?.data;
    if (resData is Map<String, dynamic>) {
      if (resData['message'] != null) {
        msg = resData['message'].toString();
      }
      errors = resData['errors'] as List<dynamic>?;
    }
    return ApiException(msg, statusCode, errors: errors);
  }
}
