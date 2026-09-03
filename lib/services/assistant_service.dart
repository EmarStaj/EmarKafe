import 'dart:convert';
import 'package:http/http.dart' as http;

import '../data/catalog.dart';
import '../models/campaign.dart';
import '../models/order_record.dart';
import '../models/product.dart';
import 'api_service.dart';

class ChatActionItem {
  final String label;
  final String icon;
  final String query;

  const ChatActionItem({
    required this.label,
    required this.icon,
    required this.query,
  });
}

/// Sohbetteki tek bir mesaj (kullanıcı ya da asistan).
class ChatTurn {
  final bool fromUser;
  final String text;
  final List<Product> suggestedProducts;
  final List<String> quickReplies;
  final List<ChatActionItem> actionButtons;

  const ChatTurn({
    required this.fromUser,
    required this.text,
    this.suggestedProducts = const [],
    this.quickReplies = const [],
    this.actionButtons = const [],
  });
}

/// AI Barista için Müşteri Context Modeli
class UserContext {
  final String userName;
  final String branchName;
  final int loyaltyStars;
  final int freeCoffees;
  final double walletBalance;
  final OrderRecord? activeOrder;
  final List<Campaign> campaigns;

  const UserContext({
    required this.userName,
    required this.branchName,
    required this.loyaltyStars,
    required this.freeCoffees,
    required this.walletBalance,
    this.activeOrder,
    this.campaigns = const [],
  });
}

/// Kafe asistanı servisi.
class AssistantService {
  static bool get isConfigured => true;

  static const _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  static final List<ChatActionItem> defaultActionButtons = [
    const ChatActionItem(icon: '☕', label: 'Bana Özel Kahve Öner', query: 'Bana damak zevkime göre güzel bir kahve öner'),
    const ChatActionItem(icon: '🍰', label: 'Tatlı Menüsü & Eşleşmeler', query: 'Kahvenin yanına hangi tatlılar var?'),
    const ChatActionItem(icon: '🎁', label: 'Kaç Yıldızım & Hediye Kahvem Var?', query: 'Kaç yıldızım ve hediye kahvem var?'),
    const ChatActionItem(icon: '💳', label: 'Cüzdan Bakiyemi Göster', query: 'Cüzdanımda ne kadar bakiye var?'),
    const ChatActionItem(icon: '📦', label: 'Son Siparişim Ne Durumda?', query: 'Siparişim ne durumda, hazır mı?'),
    const ChatActionItem(icon: '🎉', label: 'Aktif Kampanyalar & Fırsatlar', query: 'Şu an hangi kampanyalar var?'),
  ];

  static Future<ChatTurn> sendMessage({
    required ApiService api,
    required List<ChatTurn> history,
    required String userMessage,
    String? branchId,
    UserContext? userContext,
  }) async {
    final q = userMessage.toLowerCase().trim();

    // 0. Dedicated Capability / Actions Menu Check (Alt alta butonlar)
    if (q == 'neler yapabilirsin?' || q == 'neler yapabilirsin' || q == 'yetenekler' || q == 'ne yapabilirsin' || q == 'ne yapabilirsin?' || q == 'yardım') {
      return ChatTurn(
        fromUser: false,
        text: 'Sana EMAR Kafe\'de pek çok konuda yardımcı olabilirim! Aşağıdaki butonlardan birini seçerek hemen başlayabilirsin: ✨',
        suggestedProducts: const [],
        actionButtons: defaultActionButtons,
        quickReplies: const ['☕ Kahve Öner', '🍰 Tatlılar', '🎁 Yıldızlarım', '💳 Cüzdanım'],
      );
    }

    // 1. Try Gemini 3.5 Flash-Lite directly if key is configured
    if (_geminiApiKey.isNotEmpty) {
      try {
        return await _callDirectGemini(history, userMessage, userContext);
      } catch (_) {
        // Fall back to backend
      }
    }

    // 2. Try backend endpoint
    try {
      final historyPayload = history.map((t) => {
          'role': t.fromUser ? 'user' : 'model',
          'content': t.text,
        }).toList();

        final res = await api.sendChatMessage(
          message: userMessage,
          history: historyPayload,
          branchId: branchId,
        );

        if (res.containsKey('reply') && res['reply'] != null) {
          final reply = res['reply'] as String;
          final quickReplies = (res['quickReplies'] as List<dynamic>?)
                  ?.map((q) => q.toString())
                  .toList() ??
              const ['☕ Sıcak Kahve', '🍰 Tatlılar', '📦 Siparişim nerede?'];

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
        }
    } catch (_) {}

    // 3. Fallback to rich local coffee sommelier
    return _localBaristaFallback(userMessage, userContext);
  }

  static Future<ChatTurn> _callDirectGemini(List<ChatTurn> history, String userMessage, UserContext? ctx) async {
    final products = Catalog.instance.products;
    final activeOrderInfo = ctx?.activeOrder != null
        ? 'Sipariş #${ctx!.activeOrder!.id.length >= 6 ? ctx.activeOrder!.id.substring(0, 6) : ctx.activeOrder!.id} (${ctx.activeOrder!.status})'
        : 'Yok';

    final campaignsInfo = (ctx?.campaigns.isNotEmpty ?? false)
        ? ctx!.campaigns.map((c) => "${c.title} (${c.badge}: ${c.subtitle})").join('; ')
        : 'Her 5 kahveye 1 kahve hediye!';

    final systemInstruction = '''Sen EMAR Kafe'nin samimi, nazik ve bilgili AI Baristasısın ☕.
Müşterinin adı: ${ctx?.userName ?? 'Değerli Müşterimiz'}.
Seçili şubesi: ${ctx?.branchName ?? 'Talas Şubesi'}.

CANLI MÜŞTERİ BİLGİLERİ:
- Sadakat Yıldız Sayacı: ${ctx?.loyaltyStars ?? 0}/5 yıldız (Her 5 yıldızda 1 bedava kahve kazanır).
- Kullanılabilir Bedava Kahvesi: ${ctx?.freeCoffees ?? 0} adet hediye kahve.
- Cüzdan Bakiyesi: ${ctx?.walletBalance.toStringAsFixed(0) ?? '0'}₺.
- Aktif Siparişi: $activeOrderInfo.
- Aktif Kampanyalar: $campaignsInfo.

ÖNEMLİ KURALLAR:
1. DOĞAL VE KİBAR TON: Sıcak, güler yüzlü ve profesyonel ol. Zorlama espri yapma; samimi ve ölçülü ol.
2. ÇOK KISA VE ÖZ (1-2 CÜMLE): Yanıtların en fazla 1-2 cümle (20-30 kelime) olsun.
3. KULLANICI BİLGİLERİNİ KULLAN: Kullanıcı "kaç yıldızım var?", "bedava kahvem var mı?", "cüzdanım ne kadar?", "siparişim ne durumda?", "kampanyalar ne?" diye sorduğunda YUKARIDAKİ CANLI BİLGİLERLE doğrudan doğruya net cevap ver.
4. SOHBETİ BİTİRME & NEZAKET: Kullanıcı "teşekkürler", "sağ ol", "tamamdır", "eyvallah", "görüşürüz", "kolay gelsin", "hoşça kal" dediğinde ASLA yeni ürün satmaya/önermeye çalışma! Nazikçe sohbeti kapat:
   Örn: "Rica ederim ${ctx?.userName != null ? ctx!.userName : ''}, şimdiden afiyet olsun! ☕ Her zaman buradayım ✨"
   Bu durumda suggestedProductNames mutlaka boş liste [] olsun.
5. MENÜDEN ÖNER: Ürün tavsiye ederken menümüzdeki tam adları kullan.
Menümüzdeki ürünler:
${products.map((p) => "- ${p.name} (${p.category.label}): ${p.price.toStringAsFixed(0)}₺").join('\n')}

6. JSON ÇIKTISI: Yanıtının EN SONUNA mutlaka şu formatta JSON bloğunu ekle:
```json
{"suggestedProductNames": ["Doppio", "Brownie"], "quickReplies": ["☕ Sıcak Kahve", "🍰 Tatlılar", "📦 Siparişim nerede?"]}
```
''';

    final contents = [
      {
        'role': 'user',
        'parts': [{'text': systemInstruction}]
      },
      {
        'role': 'model',
        'parts': [{'text': 'Anladım! Müşterimize canlı verileriyle harika ve net bir servis sunmaya hazırım ☕'}]
      },
      ...history.take(6).map((h) => {
        'role': h.fromUser ? 'user' : 'model',
        'parts': [{'text': h.text}]
      }),
      {
        'role': 'user',
        'parts': [{'text': userMessage}]
      }
    ];

    final response = await http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=$_geminiApiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': contents,
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 500,
        },
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Gemini HTTP error ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    final parts = candidates?.firstOrNull?['content']?['parts'] as List<dynamic>?;
    final rawText = parts?.firstOrNull?['text']?.toString() ?? '';

    String reply = rawText;
    List<String> suggestedNames = [];
    List<String> quickReplies = ['☕ Sıcak Kahve', '🧊 Soğuk Kahve', '🍰 Tatlılar', '🎁 Kaç yıldızım var?'];

    final jsonRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
    final match = jsonRegex.firstMatch(rawText);
    if (match != null) {
      try {
        final parsed = jsonDecode(match.group(1)!) as Map<String, dynamic>;
        if (parsed['suggestedProductNames'] is List) {
          suggestedNames = (parsed['suggestedProductNames'] as List).map((e) => e.toString().toLowerCase()).toList();
        }
        if (parsed['quickReplies'] is List) {
          quickReplies = (parsed['quickReplies'] as List).map((e) => e.toString()).toList();
        }
        reply = rawText.replaceAll(jsonRegex, '').trim();
      } catch (_) {}
    }

    final List<Product> matchedProducts = [];
    for (final name in suggestedNames) {
      final p = products.where((item) => item.name.toLowerCase().contains(name) || name.contains(item.name.toLowerCase())).firstOrNull;
      if (p != null && !matchedProducts.contains(p)) {
        matchedProducts.add(p);
      }
    }

    return ChatTurn(
      fromUser: false,
      text: reply.isNotEmpty ? reply : 'Bugün sana taze demlenmiş harika bir kahve hazırlayabilirim! ☕',
      suggestedProducts: matchedProducts,
      quickReplies: quickReplies,
    );
  }

  static ChatTurn _localBaristaFallback(String userMessage, UserContext? ctx) {
    final q = userMessage.toLowerCase();
    final all = Catalog.instance.products;
    String reply = '';
    final List<Product> suggested = [];
    List<String> quickReplies = ['☕ Ne içmeliyim?', '🍰 Tatlı öner', '🎁 Kaç yıldızım var?', '💳 Cüzdanım'];

    // 0. Teşekkür / Veda / Kapanış
    if (q.contains('teşekkür') || q.contains('sağol') || q.contains('sağ ol') || q.contains('eyvallah') || q.contains('tamam') || q.contains('görüşürüz') || q.contains('kolay gelsin') || q.contains('hoşça kal') || q.contains('bay bay') || q.contains('bye') || q.contains('ellerine sağlık')) {
      reply = 'Rica ederim ${ctx?.userName != null ? ctx!.userName : ''}, şimdiden afiyet olsun! ☕ Her zaman buradayım, keyifli ve güzel bir gün dilerim ✨';
      return ChatTurn(
        fromUser: false,
        text: reply,
        suggestedProducts: const [],
        quickReplies: const ['☕ Yeni kahve öner', '🍰 Tatlılar', '📦 Siparişim nerede?'],
      );
    }

    // 1. Sadakat / Bedava Kahve
    if (q.contains('yıldız') || q.contains('bedava') || q.contains('sadakat') || q.contains('hediye') || q.contains('puan')) {
      final stars = ctx?.loyaltyStars ?? 0;
      final free = ctx?.freeCoffees ?? 0;
      if (free > 0) {
        reply = 'Tebrikler! Hesabınızda **$free adet kullanılabilir bedava kahveniz** bulunuyor 🎉 Sepette ödülünüzü afiyetle kullanabilirsiniz.';
      } else {
        reply = 'Şu an **$stars/5 yıldızınız** var. ${5 - stars} kahve daha sipariş ettiğinizde bir sonraki kahveniz bizden hediye! 🎁';
      }
      return ChatTurn(fromUser: false, text: reply, quickReplies: const ['☕ Kahve öner', '🍰 Tatlı öner', '📦 Sipariş ver']);
    }

    // 2. Cüzdan / Bakiye
    if (q.contains('cüzdan') || q.contains('bakiye') || q.contains('param')) {
      final bal = ctx?.walletBalance ?? 0.0;
      reply = 'Cüzdan bakiyeniz şu anda **${bal.toStringAsFixed(0)}₺**\'dir 💳 Profilim sekmesinden kolayca bakiye yükleyebilirsiniz.';
      return ChatTurn(fromUser: false, text: reply, quickReplies: const ['☕ Kahve öner', '🎁 Sadakat durumum']);
    }

    // 3. Sipariş Durumu
    if (q.contains('sipariş') || q.contains('nerede') || q.contains('hazır') || q.contains('durum')) {
      if (ctx?.activeOrder != null) {
        final o = ctx!.activeOrder!;
        final s = o.status == 'ready' ? 'Hazır, teslim alabilirsiniz!' : (o.status == 'preparing' ? 'Hazırlanıyor ☕' : 'Alındı');
        reply = '${ctx.branchName} şubesindeki #${o.id.length >= 6 ? o.id.substring(0, 6) : o.id} numaralı siparişiniz: **$s** 📦';
      } else {
        reply = 'Şu an aktif bir siparişiniz görünmüyor. Profil > Sipariş Geçmişi sekmesinden geçmiş siparişlerinizi inceleyebilirsiniz 📋';
      }
      return ChatTurn(fromUser: false, text: reply, quickReplies: const ['☕ Yeni kahve öner', '🍰 Tatlı öner']);
    }

    // 4. Kampanyalar
    if (q.contains('kampanya') || q.contains('fırsat') || q.contains('indirim')) {
      if (ctx?.campaigns.isNotEmpty ?? false) {
        final cList = ctx!.campaigns.map((c) => '**${c.title}** (${c.badge})').join(', ');
        reply = 'Şu an aktif kampanyalarımız: $cList 🎉 Kampanyalar sekmesinden tüm detaylara ulaşabilirsiniz.';
      } else {
        reply = 'Her 5 kahveye 1 hediye kahve kampanyamız tüm hızıyla devam ediyor! 🎁';
      }
      return ChatTurn(fromUser: false, text: reply, quickReplies: const ['☕ Kahve öner', '🍰 Tatlı öner']);
    }

    // 5. Sert / Uykusuzluk / Enerji
    if (q.contains('sert') || q.contains('uyku') || q.contains('enerji') || q.contains('ayıl') || q.contains('yoğun')) {
      reply = 'Uykunu açacak yoğun bir lezzet için çift shot **Doppio** veya dengeli sertliğiyle **Flat White** harika bir tercih olur ☕⚡';
      final p1 = all.where((p) => p.name.toLowerCase().contains('doppio') || p.name.toLowerCase().contains('espresso')).firstOrNull;
      final p2 = all.where((p) => p.name.toLowerCase().contains('flat white') || p.name.toLowerCase().contains('cortado')).firstOrNull;
      if (p1 != null) suggested.add(p1);
      if (p2 != null) suggested.add(p2);
      quickReplies = ['🍰 Yanına tatlı öner', '🧊 Soğuk bir şey var mı?', '☕ Filtre kahve nasıl?'];
    }
    // 6. Tatlı / Pasta / Çikolata
    else if (q.contains('tatlı') || q.contains('pasta') || q.contains('çikolata') || q.contains('açım') || q.contains('kek') || q.contains('brownie')) {
      reply = 'Kahvenin yanına taze fırından sıcacık **Brownie** veya ipeksi kremasıyla **San Sebastian Cheesecake** çok yakışır 🍰✨';
      final p1 = all.where((p) => p.name.toLowerCase().contains('brownie')).firstOrNull;
      final p2 = all.where((p) => p.name.toLowerCase().contains('sebastian') || p.name.toLowerCase().contains('cheesecake') || p.name.toLowerCase().contains('macaron')).firstOrNull;
      if (p1 != null) suggested.add(p1);
      if (p2 != null) suggested.add(p2);
      quickReplies = ['☕ Hangi kahveyle gider?', '🍰 Başka tatlı var mı?', '🎁 Kampanya var mı?'];
    }
    // 7. Soğuk Kahve / Ferahlatıcı
    else if (q.contains('soğuk') || q.contains('sıcak') || q.contains('ice') || q.contains('ferah') || q.contains('yaz')) {
      reply = 'Ferahlamak için 18 saat soğuk demlenen kadifemsi **Cold Brew** veya karamel aromalı **Iced Karamel Macchiato** tam aradığın lezzet 🧊';
      final p1 = all.where((p) => p.name.toLowerCase().contains('cold brew')).firstOrNull;
      final p2 = all.where((p) => p.name.toLowerCase().contains('karamel') || p.name.toLowerCase().contains('iced') || p.name.toLowerCase().contains('frappe')).firstOrNull;
      if (p1 != null) suggested.add(p1);
      if (p2 != null) suggested.add(p2);
      quickReplies = ['☕ Sıcak kahve öner', '🍰 Yanına tatlı ne gider?', '📍 Şubede var mı?'];
    }
    // 8. Genel Selamlama
    else {
      reply = 'Merhaba ${ctx?.userName != null ? ctx!.userName : ''}! Ben EMAR Kafe Baristanım ☕ Bugün canın sert, sütlü ya da soğuk nasıl bir kahve çekiyor?';
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
