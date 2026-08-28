import '../models/product.dart';
import 'api_service.dart';

/// Sohbetteki tek bir mesaj (kullanıcı ya da asistan).
class ChatTurn {
  final bool fromUser;
  final String text;
  final List<Product> suggestedProducts;
  final List<String> quickReplies;

  const ChatTurn({
    required this.fromUser,
    required this.text,
    this.suggestedProducts = const [],
    this.quickReplies = const [],
  });
}

/// Kafe asistanı servisi.
class AssistantService {
  static bool get isConfigured => true;

  static Future<ChatTurn> sendMessage({
    required ApiService api,
    required List<ChatTurn> history,
    required String userMessage,
    String? branchId,
  }) async {
    final historyPayload = history.map((t) => {
      'role': t.fromUser ? 'user' : 'model',
      'content': t.text,
    }).toList();

    try {
      final res = await api.sendChatMessage(
        message: userMessage,
        history: historyPayload,
        branchId: branchId,
      );

      final reply = res['reply'] as String? ?? 'Harika bir kahve seçimi!';
      final quickReplies = (res['quickReplies'] as List<dynamic>?)
              ?.map((q) => q.toString())
              .toList() ??
          const ['☕ Ne içmeliyim?', '🍰 Tatlı öner', '⚡ Sert kahve'];

      final rawProducts = res['suggestedProducts'] as List<dynamic>? ?? [];
      final suggested = rawProducts.map((p) {
        final map = p as Map<String, dynamic>;
        return Product(
          id: map['id']?.toString() ?? '',
          name: map['name']?.toString() ?? '',
          category: map['category'] == 'Tatlı'
              ? ProductCategory.dessert
              : (map['category'] == 'Soğuk Kahve'
                  ? ProductCategory.icedCoffee
                  : ProductCategory.hotCoffee),
          price: (map['price'] as num?)?.toDouble() ?? 0.0,
          icon: map['icon']?.toString() ?? '☕',
          rating: 4.8,
          ratingCount: 120,
          description: map['reason']?.toString(),
        );
      }).toList();

      return ChatTurn(
        fromUser: false,
        text: reply,
        suggestedProducts: suggested,
        quickReplies: quickReplies,
      );
    } catch (_) {
      return const ChatTurn(
        fromUser: false,
        text: 'Bağlantıda küçük bir aksaklık oldu ama sana her zaman taze bir filtre kahve veya leziz bir Latte öneririm! ☕',
        quickReplies: ['☕ Ne içmeliyim?', '🍰 Tatlılar', '⚡ Sert kahve'],
      );
    }
  }
}
