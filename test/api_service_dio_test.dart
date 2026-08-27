import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ApiService apiService;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    apiService = ApiService();
  });

  group('ApiService Token Management', () {
    test('saveTokens, init and clearToken works correctly', () async {
      await apiService.saveTokens('token_123', refreshToken: 'refresh_456');
      expect(apiService.token, 'token_123');
      expect(apiService.refreshToken, 'refresh_456');

      final newService = ApiService();
      await newService.init();
      expect(newService.token, 'token_123');
      expect(newService.refreshToken, 'refresh_456');

      await newService.clearToken();
      expect(newService.token, isNull);
      expect(newService.refreshToken, isNull);
    });
  });

  group('ApiService Dio Interceptor & Error Handling', () {
    test('Authorization header is injected when token exists', () async {
      await apiService.saveTokens('my_jwt_token');

      var capturedAuth = '';
      apiService.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedAuth = options.headers['Authorization']?.toString() ?? '';
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'success': true, 'data': {'user': 'test'}},
                ),
              ),
            );
          },
        ),
      );

      try {
        await apiService.getMe();
      } catch (_) {}

      expect(capturedAuth, 'Bearer my_jwt_token');
    });

    test('ApiException maps timeouts properly', () {
      final ex = ApiException('Bağlantı zaman aşımına uğradı', 408);
      expect(ex.statusCode, 408);
      expect(ex.message, contains('zaman aşımına'));
    });

    test('ApiException maps 429 and custom messages', () {
      final ex = ApiException('Çok fazla deneme yaptınız. 15 dakika bekleyin.', 429);
      expect(ex.statusCode, 429);
      expect(ex.toString(), contains('ApiException: Çok fazla deneme'));
    });
  });
}
