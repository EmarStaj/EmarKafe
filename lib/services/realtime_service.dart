import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef OrderRealtimeCallback = void Function(Map<String, dynamic> record);

class RealtimeService {
  SupabaseClient? _client;
  RealtimeChannel? _channel;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  bool get hasActiveSubscription => _channel != null;

  Future<void> init({String? url, String? anonKey}) async {
    final supabaseUrl = url ?? const String.fromEnvironment('SUPABASE_URL');
    final supabaseAnonKey = anonKey ?? const String.fromEnvironment('SUPABASE_ANON_KEY');

    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      try {
        if (!Supabase.instance.isInitialized) {
          await Supabase.initialize(
            url: supabaseUrl,
            anonKey: supabaseAnonKey,
          );
        }
        _client = Supabase.instance.client;
        _initialized = true;
      } catch (e) {
        debugPrint('RealtimeService initialization error: $e');
      }
    }
  }

  void setCustomClient(SupabaseClient client) {
    _client = client;
    _initialized = true;
  }

  Future<void> subscribeToUserOrders(String userId, OrderRealtimeCallback onOrderUpdated) async {
    if (_client == null || userId.isEmpty) return;
    await unsubscribe();

    try {
      _channel = _client!
          .channel('public:orders:user:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                onOrderUpdated(newRecord);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime user subscription error: $e');
    }
  }

  Future<void> subscribeToBranchOrders(String branchId, OrderRealtimeCallback onOrderUpdated) async {
    if (_client == null || branchId.isEmpty) return;
    await unsubscribe();

    try {
      _channel = _client!
          .channel('public:orders:branch:$branchId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'branch_id',
              value: branchId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                onOrderUpdated(newRecord);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime branch subscription error: $e');
    }
  }

  Future<void> unsubscribe() async {
    if (_channel != null && _client != null) {
      try {
        await _client!.removeChannel(_channel!);
      } catch (e) {
        debugPrint('Realtime unsubscribe error: $e');
      } finally {
        _channel = null;
      }
    }
  }
}
