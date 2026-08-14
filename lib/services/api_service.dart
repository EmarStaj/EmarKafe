import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final List<dynamic>? errors;
  
  ApiException(this.message, this.statusCode, {this.errors});
  
  @override
  String toString() => 'ApiException: $message';
}

class ApiService {
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://emarkafe.duckdns.org');
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  
  final _storage = const FlutterSecureStorage();

  String? _token;
  String? _refreshToken;
  
  String? get token => _token;
  String? get refreshToken => _refreshToken;

  Future<void> init() async {
    _token = await _storage.read(key: _tokenKey);
    _refreshToken = await _storage.read(key: _refreshTokenKey);
  }

  Future<void> saveTokens(String token, {String? refreshToken}) async {
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
    if (refreshToken != null) {
      _refreshToken = refreshToken;
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<void> clearToken() async {
    _token = null;
    _refreshToken = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  
  Future<http.Response> _get(Uri url, {Map<String, String>? headers}) async {
    return await _get(url, headers: headers).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw ApiException('Bağlantı zaman aşımına uğradı', 408),
    );
  }

  Future<http.Response> _post(Uri url, {Map<String, String>? headers, Object? body}) async {
    return await _post(url, headers: headers, body: body).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw ApiException('Bağlantı zaman aşımına uğradı', 408),
    );
  }

  Future<http.Response> _put(Uri url, {Map<String, String>? headers, Object? body}) async {
    return await _put(url, headers: headers, body: body).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw ApiException('Bağlantı zaman aşımına uğradı', 408),
    );
  }

  Future<http.Response> _delete(Uri url, {Map<String, String>? headers}) async {
    return await _delete(url, headers: headers).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw ApiException('Bağlantı zaman aşımına uğradı', 408),
    );
  }

  Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // --- Auth ---

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _processResponse(res);
  }

  Future<Map<String, dynamic>> register(String email, String phone, String password, String name, String birthDate, {String? role, String? branchId}) async {
    final res = await _post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'phone': phone,
        'password': password,
        'full_name': name,
        'birth_date': birthDate,
        if (role != null) 'role': role,
        if (branchId != null) 'branch_id': branchId,
      }),
    );
    return _processResponse(res);
  }


  Future<void> forgotPassword(String email) async {
    final res = await _post(
      Uri.parse('$baseUrl/api/auth/forgot-password'),
      headers: _headers,
      body: jsonEncode({'email': email}),
    );
    _processResponse(res);
  }

  Future<Map<String, dynamic>> getMenu({int page = 1, int limit = 20}) async {
    final res = await _get(Uri.parse('$baseUrl/api/menu?page=$page&limit=$limit'), headers: _headers);
    return _processResponse(res);
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _get(Uri.parse('$baseUrl/api/auth/me'), headers: _headers);
    return _processResponse(res);
  }

  Future<void> logout() async {
    try {
      await _post(Uri.parse('$baseUrl/api/auth/logout'), headers: _headers);
    } catch (_) {}
    await clearToken();
  }

  // --- Profile ---

  Future<Map<String, dynamic>> getProfile() async {
    final res = await _get(Uri.parse('$baseUrl/api/profile/me'), headers: _headers);
    return _processResponse(res);
  }

  Future<void> updateProfile({String? fullName, String? phone, String? avatarUrl, String? birthDate, String? branch, String? role}) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (phone != null) body['phone'] = phone;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (birthDate != null) body['birth_date'] = birthDate;
    if (branch != null) body['branch'] = branch;
    if (role != null) body['role'] = role;
    
    final res = await _put(
      Uri.parse('$baseUrl/api/profile/me'),
      headers: _headers,
      body: jsonEncode(body),
    );
    _processResponse(res);
  }

  Future<void> setDefaultBranch(String branchId) async {
    final res = await _put(
      Uri.parse('$baseUrl/api/profile/me/default-branch'),
      headers: _headers,
      body: jsonEncode({'branch_id': branchId}),
    );
    _processResponse(res);
  }

  // --- Wallet ---

  Future<Map<String, dynamic>> getWalletBalance() async {
    final res = await _get(Uri.parse('$baseUrl/api/wallet/balance'), headers: _headers);
    return _processResponse(res);
  }

  Future<void> topupWallet(double amount) async {
    final res = await _post(
      Uri.parse('$baseUrl/api/wallet/topup'),
      headers: _headers,
      body: jsonEncode({'amount': amount}),
    );
    _processResponse(res);
  }

  Future<String> getWalletQrToken() async {
    final res = await _get(Uri.parse('$baseUrl/api/wallet/qr'), headers: _headers);
    final data = _processResponse(res);
    return data['qr_token'] as String;
  }

  // --- Cart ---

  Future<Map<String, dynamic>> getCart() async {
    final res = await _get(Uri.parse('$baseUrl/api/cart'), headers: _headers);
    return _processResponse(res);
  }

  Future<List<String>> addToCart(String productId, int qty, {List<String> options = const []}) async {
    final res = await _post(
      Uri.parse('$baseUrl/api/cart'),
      headers: _headers,
      body: jsonEncode({'product_id': productId, 'quantity': qty}),
    );
    _processResponse(res);
    
    // Check if warnings exists in the original json body
    if (res.statusCode == 201 || res.statusCode == 200) {
      try {
        final body = jsonDecode(res.body);
        if (body['warnings'] != null) {
          final warnings = body['warnings'] as List<dynamic>;
          return warnings.map((w) => w['message'].toString()).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  Future<void> updateCartItem(String cartItemId, int qty) async {
    final res = await _put(
      Uri.parse('$baseUrl/api/cart/$cartItemId'),
      headers: _headers,
      body: jsonEncode({'quantity': qty}),
    );
    _processResponse(res);
  }

  Future<void> clearCart() async {
    final res = await _delete(Uri.parse('$baseUrl/api/cart'), headers: _headers);
    _processResponse(res);
  }



  Future<void> placeOrder(String branchId) async {
    final res = await _post(
      Uri.parse('$baseUrl/api/orders'),
      headers: _headers,
      body: jsonEncode({'branch_id': branchId}),
    );
    _processResponse(res);
  }

  Future<List<dynamic>> getMyOrders() async {
    final res = await _get(Uri.parse('$baseUrl/api/orders'), headers: _headers);
    final data = _processResponse(res);
    return data['data'] as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> getBranchOrders() async {
    final res = await _get(Uri.parse('$baseUrl/api/orders/branch'), headers: _headers);
    final data = _processResponse(res);
    return data['data'] as List<dynamic>? ?? [];
  }

  Future<void> scanQrOrder(String qrToken) async {
    final res = await _post(
      Uri.parse('$baseUrl/api/orders/scan-qr'),
      headers: _headers,
      body: jsonEncode({'qr_token': qrToken}),
    );
    _processResponse(res);
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    final res = await _put(
      Uri.parse('$baseUrl/api/orders/$orderId/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    _processResponse(res);
  }

  Future<void> rateProduct(String productId, double rating) async {
    final res = await _post(
      Uri.parse('$baseUrl/api/products/$productId/ratings'),
      headers: _headers,
      body: jsonEncode({'rating': rating}),
    );
    _processResponse(res);
  }

  // --- Device Tokens (OneSignal) ---

  Future<void> registerDeviceToken(String osId) async {
    if (_token == null) return;
    try {
      await _post(
        Uri.parse('$baseUrl/api/device-tokens'),
        headers: _headers,
        body: jsonEncode({
          'onesignal_id': osId,
          'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'
        }),
      );
    } catch (_) {}
  }

  Map<String, dynamic> _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic>) {
        if (json['success'] == false) {
          final msg = json['message']?.toString() ?? 'Sunucu islemi reddetti';
          throw ApiException(msg, response.statusCode);
        }
        if (json.containsKey('data')) {
          final data = json['data'];
          if (data is Map<String, dynamic>) {
            if (json.containsKey('message')) data['__message'] = json['message'];
            return data;
          }
          if (data is List) {
            return {'data': data};
          }
        }
        return json;
      }
      return {};
    }
    String msg = 'Sunucu hatası: ';
    if (response.statusCode == 400 || response.statusCode == 401) {
      msg = 'E-posta veya şifre hatalı.';
    } else if (response.statusCode == 429) {
      msg = 'Çok fazla deneme yaptınız. 15 dakika bekleyin.';
    } else if (response.statusCode >= 500) {
      msg = 'Sunucu hatası. Lütfen tekrar deneyin.';
    }
    List<dynamic>? errors;
    try {
      final err = jsonDecode(response.body);
      if (err is Map<String, dynamic>) {
        if (err['message'] != null) {
          msg = err['message'];
        }
        errors = err['errors'] as List<dynamic>?;
      }
    } catch (_) {}
    throw ApiException(msg, response.statusCode, errors: errors);
}
}
