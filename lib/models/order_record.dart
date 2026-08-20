import 'package:emar_kafe/models/product.dart';
import 'package:emar_kafe/data/catalog.dart';
enum OrderStatus { created, received, preparing, ready, completed, cancelled }

class OrderRecord {
  final String id;
  final String shortId;
  final String userId;
  final String? branchId;
  final Map<String, int> items;
  final double totalPrice;
  double get total => totalPrice;
  String? get branch => branchId;
  String? customerName;
  final DateTime createdAt;
  final String status;
  final OrderStatus manualStatus;
  final String? qrToken;

  OrderRecord({
    required this.id,
    required this.shortId,
    required this.userId,
    this.branchId,
    required this.items,
    required this.totalPrice,
    required this.createdAt,
    required this.status,
    required this.manualStatus,
    this.qrToken,
  });

  bool get pickedUp => manualStatus == OrderStatus.completed || manualStatus == OrderStatus.cancelled;
  OrderStatus get computedStatus => manualStatus;
  bool get isPendingQR => status == 'pending_qr';
  int get remainingSeconds => 300;

  factory OrderRecord.fromJson(Map<String, dynamic> db) {
    final Map<String, int> itemsMap = {};
    if (db['items'] != null && db['items'] is Map) {
      final map = db['items'] as Map;
      for (var key in map.keys) {
        itemsMap[key.toString()] = (map[key] as num).toInt();
      }
    } else if (db['order_items'] != null && db['order_items'] is List) {
      final list = db['order_items'] as List;
      for (var item in list) {
        if (item is Map) {
          final pid = item['product_id']?.toString() ?? '';
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
          if (pid.isNotEmpty) itemsMap[pid] = qty;
        }
      }
    }
    
    final statusStr = db['status']?.toString().toLowerCase() ?? 'created';
    OrderStatus parsedStatus = OrderStatus.created;
    for (var s in OrderStatus.values) {
      if (s.name == statusStr) {
        parsedStatus = s;
        break;
      }
    }

    String id = db['id']?.toString() ?? '';
    String short = id;
    if (id.length >= 8) short = id.substring(0, 8).toUpperCase();

    return OrderRecord(
      id: id,
      shortId: short,
      userId: db['user_id']?.toString() ?? '',
      branchId: db['branch_id']?.toString(),
      items: itemsMap,
      totalPrice: (db['total_price'] as num?)?.toDouble() ?? 0.0,
      createdAt: db['created_at'] != null ? DateTime.parse(db['created_at']).toLocal() : DateTime.now(),
      status: statusStr,
      manualStatus: parsedStatus,
      qrToken: db['qr_token']?.toString() ?? db['qrToken']?.toString(),
    )..customerName = db['customer_name']?.toString();
  }

  static int computePrep(Map<String, int> items, DateTime at) {
    if (items.isEmpty) return 0;
    
    int coffeeQty = 0;
    int dessertQty = 0;
    
    for (final entry in items.entries) {
      try {
        final prod = Catalog.instance.byId(entry.key);
        if (prod.isCoffee) coffeeQty += entry.value;
        if (prod.category == ProductCategory.dessert) dessertQty += entry.value;
      } catch (_) {}
    }
    
    final beforeSix = at.hour < 18;
    int basePrep = 0;
    
    if (coffeeQty > 0 && dessertQty == 0) {
      basePrep = beforeSix ? 2 : 3;
    } else if (coffeeQty == 0 && dessertQty > 0) {
      basePrep = beforeSix ? 3 : 5;
    } else if (coffeeQty > 0 && dessertQty > 0) {
      basePrep = beforeSix ? 4 : 6;
    }
    
    final totalItems = coffeeQty + dessertQty;
    if (totalItems > 2) {
      basePrep += ((totalItems - 2) / 2).floor();
    }
    
    return basePrep;
  }
}
