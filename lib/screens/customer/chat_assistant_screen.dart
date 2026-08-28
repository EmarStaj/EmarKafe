import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../services/assistant_service.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/pressable_scale.dart';

class ChatAssistantScreen extends StatefulWidget {
  const ChatAssistantScreen({super.key});

  @override
  State<ChatAssistantScreen> createState() => _ChatAssistantScreenState();
}

class _ChatAssistantScreenState extends State<ChatAssistantScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ChatTurn> _turns = [
    const ChatTurn(
      fromUser: false,
      text:
          'Merhaba! Ben EMAR Kafe AI Baristanım ☕ Sana en uygun kahveyi önerebilir, tatlı eşleştirmeleri yapabilir ve siparişine yardımcı olabilirim. Bugün nasıl bir tat arıyorsun?',
      quickReplies: ['☕ Ne içmeliyim?', '⚡ Sert bir kahve', '🍰 Tatlı öner', '🧊 Soğuk kahve', '🎁 Kaç yıldızım var?'],
    ),
  ];
  bool _sending = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? customText]) async {
    final text = (customText ?? _inputCtrl.text).trim();
    if (text.isEmpty || _sending) return;

    final app = context.read<AppState>();
    final history = List<ChatTurn>.from(_turns);

    setState(() {
      _turns.add(ChatTurn(fromUser: true, text: text));
      if (customText == null) _inputCtrl.clear();
      _sending = true;
    });
    _scrollToBottom();

    try {
      final responseTurn = await AssistantService.sendMessage(
        api: app.api,
        history: history,
        userMessage: text,
        branchId: app.selectedBranchId,
      );
      setState(() => _turns.add(responseTurn));
    } catch (_) {
      setState(
        () => _turns.add(
          const ChatTurn(
            fromUser: false,
            text: 'Bağlantıda küçük bir aksaklık oldu ama sana lezzetli bir Filtre Kahve veya Latte önerebilirim! ☕',
          ),
        ),
      );
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastTurn = _turns.lastOrNull;
    final quickReplies = (!_sending && lastTurn != null && !lastTurn.fromUser && lastTurn.quickReplies.isNotEmpty)
        ? lastTurn.quickReplies
        : const ['☕ Ne içmeliyim?', '⚡ Sert kahve', '🍰 Tatlı öner', '🧊 Soğuk kahve'];

    return Scaffold(
      backgroundColor: EmarColors.oat,
      body: Column(
        children: [
          // Top Header Bar
          Container(
            width: double.infinity,
            color: EmarColors.espresso,
            padding: EdgeInsets.fromLTRB(
              8,
              MediaQuery.of(context).padding.top + 4,
              20,
              14,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: EmarColors.surface),
                ),
                const SizedBox(width: 4),
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: EmarColors.moss,
                  child: Text('☕', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EMAR AI Barista',
                        style: TextStyle(
                          color: EmarColors.surface,
                          fontFamily: 'Georgia',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: EmarColors.moss,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Çevrimiçi · Kahve Danışmanı',
                            style: TextStyle(
                              color: EmarColors.surface.withValues(alpha: 0.7),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _turns.length + (_sending ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= _turns.length) return const _TypingBubble();
                return _ChatBubble(turn: _turns[i]);
              },
            ),
          ),

          // Quick Replies Chips
          if (!_sending && quickReplies.isNotEmpty)
            Container(
              height: 38,
              margin: const EdgeInsets.only(bottom: 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: quickReplies.map((q) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      backgroundColor: EmarColors.surface,
                      elevation: 1,
                      side: BorderSide(color: EmarColors.espresso.withValues(alpha: 0.1)),
                      label: Text(q, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: EmarColors.espresso)),
                      onPressed: () => _send(q),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Input Bar
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      enabled: !_sending,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Bir şey sor ya da öneri iste...',
                        hintStyle: TextStyle(fontSize: 13, color: EmarColors.espresso.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: EmarColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PressableScale(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: _sending ? null : () => _send(),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _sending
                              ? EmarColors.espresso.withValues(alpha: 0.3)
                              : EmarColors.paprika,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_upward,
                          color: EmarColors.surface,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatTurn turn;
  const _ChatBubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    final mine = turn.fromUser;
    final app = context.read<AppState>();

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: mine ? EmarColors.paprika : EmarColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine
              ? null
              : Border.all(color: EmarColors.espresso.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              turn.text,
              style: TextStyle(
                color: mine ? EmarColors.surface : EmarColors.espresso,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            if (!mine && turn.suggestedProducts.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ...turn.suggestedProducts.map((p) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: EmarColors.oatDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: EmarColors.espresso.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      Text(p.icon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            Text('${p.price.toStringAsFixed(0)}₺', style: const TextStyle(fontSize: 11, color: EmarColors.paprika, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EmarColors.espresso,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          elevation: 0,
                        ),
                        onPressed: () {
                          app.cart.addToCart(p.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${p.name} sepete eklendi! 🛒'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Text('+ Sepete Ekle', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: EmarColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: EmarColors.espresso.withValues(alpha: 0.08)),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(t, 0.0),
                const SizedBox(width: 4),
                _dot(t, 0.2),
                const SizedBox(width: 4),
                _dot(t, 0.4),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dot(double t, double offset) {
    final shift = ((t + offset) % 1.0) * 2;
    final scale = shift > 1.0 ? 2.0 - shift : shift;
    return Transform.scale(
      scale: 0.6 + 0.4 * scale,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: EmarColors.paprika,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
