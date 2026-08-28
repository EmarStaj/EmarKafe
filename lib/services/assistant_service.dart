import '../data/catalog.dart';
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
        final pId = map['id']?.toString() ?? '';
        final localProd = Catalog.instance.products.where((item) => item.id == pId || item.name.toLowerCase() == map['name']?.toString().toLowerCase()).firstOrNull;
        if (localProd != null) return localProd;

        return Product(
          id: pId,
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
      return _localBaristaFallback(userMessage);
    }
  }

  static ChatTurn _localBaristaFallback(String userMessage) {
    final q = userMessage.toLowerCase();
    final all = Catalog.instance.products;
    String reply = '';
    final List<Product> suggested = [];
    List<String> quickReplies = ['☕ Ne içmeliyim?', '🍰 Tatlı öner', '⚡ Sert bir kahve', '🧊 Soğuk kahve'];

    // 1. Sert / Uykusuzluk / Enerji
    if (q.contains('sert') || q.contains('uyku') || q.contains('enerji') || q.contains('ayıl') || q.contains('yoğun')) {
      reply = 'Uykunu anında açacak ve sana enerji verecek sert bir kahve arıyorsan, kesinlikle **Doppio** (çift shot espresso) veya sütlü ama sert olan **Flat White** öneririm! ⚡';
      final p1 = all.where((p) => p.name.toLowerCase().contains('doppio') || p.name.toLowerCase().contains('espresso')).firstOrNull;
      final p2 = all.where((p) => p.name.toLowerCase().contains('flat white') || p.name.toLowerCase().contains('cortado')).firstOrNull;
      if (p1 != null) suggested.add(p1);
      if (p2 != null) suggested.add(p2);
      quickReplies = ['🍰 Yanına tatlı öner', '🧊 Soğuk bir şey var mı?', '☕ Filtre kahve nasıl?'];
    }
    // 2. Tatlı / Pasta / Çikolata
    else if (q.contains('tatlı') || q.contains('pasta') || q.contains('çikolata') || q.contains('açım') || q.contains('kek') || q.contains('brownie')) {
      reply = 'Tatlı krizine birebir! Fırından yeni çıkmış sıcacık yoğun çikolatalı **Brownie** veya enfes akışkan kremasıyla **San Sebastian Cheesecake** kahvenin yanına harika gider 🍰✨';
      final p1 = all.where((p) => p.name.toLowerCase().contains('brownie')).firstOrNull;
      final p2 = all.where((p) => p.name.toLowerCase().contains('sebastian') || p.name.toLowerCase().contains('cheesecake') || p.name.toLowerCase().contains('macaron')).firstOrNull;
      if (p1 != null) suggested.add(p1);
      if (p2 != null) suggested.add(p2);
      quickReplies = ['☕ Hangi kahveyle gider?', '🍰 Başka tatlı var mı?', '🎁 Kampanya var mı?'];
    }
    // 3. Soğuk Kahve / Ferahlatıcı
    else if (q.contains('soğuk') || q.contains('sıcak') || q.contains('ice') || q.contains('ferah') || q.contains('yaz')) {
      reply = 'Ferahlamak için 18 saat soğuk demlenmiş kadifemsi **Cold Brew** veya tatlı karamel dokunuşlu **Iced Karamel Macchiato** tam sana göre! 🧊';
      final p1 = all.where((p) => p.name.toLowerCase().contains('cold brew')).firstOrNull;
      final p2 = all.where((p) => p.name.toLowerCase().contains('karamel') || p.name.toLowerCase().contains('iced') || p.name.toLowerCase().contains('frappe')).firstOrNull;
      if (p1 != null) suggested.add(p1);
      if (p2 != null) suggested.add(p2);
      quickReplies = ['☕ Sıcak kahve öner', '🍰 Yanına tatlı ne gider?', '📍 Şubede var mı?'];
    }
    // 4. Hafif / Sütlü / Yumuşak İçim
    else if (q.contains('hafif') || q.contains('sütlü') || q.contains('yumuşak') || q.contains('tatlımsı') || q.contains('latte')) {
      reply = 'Yumuşak ve kremamsı bir lezzet istiyorsan, ipeksi süt köpüğüyle **Latte** veya aromatik baharat dokunuşlu **Chai Latte** harika bir seçim olur ☕';
      final p1 = all.where((p) => p.name.toLowerCase().contains('latte')).firstOrNull;
      final p2 = all.where((p) => p.name.toLowerCase().contains('cappuccino') || p.name.toLowerCase().contains('mocha')).firstOrNull;
      if (p1 != null) suggested.add(p1);
      if (p2 != null) suggested.add(p2);
      quickReplies = ['⚡ Daha sert bir şey', '🍰 Tatlı öner', '🎁 Sadakat durumum'];
    }
    // 5. Sipariş / Kasa Durumu
    else if (q.contains('sipariş') || q.contains('nerede') || q.contains('hazır') || q.contains('durum')) {
      reply = 'Sipariş durumunu ve kalan hazırlık süresini Profil > Sipariş Geçmişi sekmesinden canlı olarak takip edebilirsin. Siparişin hazır olduğunda telefonuna bildirim göndereceğiz! 📦🔔';
      quickReplies = ['☕ Yeni kahve öner', '🎁 Kaç yıldızım var?', '💳 Cüzdan bakiye'];
    }
    // 6. Sadakat / Bedava Kahve
    else if (q.contains('yıldız') || q.contains('bedava') || q.contains('sadakat') || q.contains('hediye') || q.contains('puan')) {
      reply = 'EMAR Kafe Sadakat Programı ile her 5 kahve siparişinde 1 kahve bizden hediye! 🎁 Profil sekmesinden kaç yıldızın kaldığını görebilir, sepette "1x Bedava Kahve Kullan" seçeneğini aktif edebilirsin.';
      quickReplies = ['☕ Kahve öner', '🍰 Tatlı öner', '📦 Sipariş ver'];
    }
    // 7. Genel Selamlama
    else {
      reply = 'Merhaba! Ben EMAR Kafe AI Baristanım ☕ Sana en uygun kahveyi seçebilir, tatlı eşleşmeleri önerebilir veya menümüz hakkında merak ettiğin her şeyi yanıtlayabilirim. Bugün damak tadın nasıl bir şey istiyor?';
      final p1 = all.where((p) => p.name.toLowerCase().contains('filtre')).firstOrNull ?? all.firstOrNull;
      final p2 = all.where((p) => p.name.toLowerCase().contains('latte')).firstOrNull;
      if (p1 != null) suggested.add(p1);
      if (p2 != null) suggested.add(p2);
    }

    return ChatTurn(
      fromUser: false,
      text: reply,
      suggestedProducts: suggested,
      quickReplies: quickReplies,
    );
  }
}
