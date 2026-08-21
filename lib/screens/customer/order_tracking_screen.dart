import 'package:emar_kafe/models/order_record.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/menu_data.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/pressable_scale.dart';

import 'package:qr_flutter/qr_flutter.dart';

class OrderTrackingScreen extends StatefulWidget {
  final OrderRecord order;
  final String? qrToken;
  const OrderTrackingScreen({super.key, required this.order, this.qrToken});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Timer? _ticker;
  String? _jwtToken;

  @override
  void initState() {
    super.initState();
    _initQrToken();
    // Durum, sipariş saatinden türetildiği için burada sadece görünümü
    // her saniye tazeliyoruz — hiçbir alanı biz mutasyona uğratmıyoruz.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (widget.order.computedStatus == OrderStatus.ready) {
        _ticker?.cancel();
      }
    });
  }

  void _initQrToken() async {
    if (widget.qrToken != null && widget.qrToken!.startsWith('ey')) {
      setState(() => _jwtToken = widget.qrToken);
      return;
    }
    if (widget.order.qrToken != null &&
        widget.order.qrToken!.startsWith('ey')) {
      setState(() => _jwtToken = widget.order.qrToken);
      return;
    }
    try {
      final token = await context.read<AppState>().generateWalletToken();
      if (token != null && token.isNotEmpty && mounted) {
        setState(() => _jwtToken = token);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatApprox(int seconds) {
    if (seconds <= 0) return 'Çok Yakında';
    final m = (seconds / 60).ceil();
    return '~$m dk';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final liveOrder = app.orderHistory.firstWhere(
      (o) => o.id == widget.order.id,
      orElse: () => widget.order,
    );
    final order = liveOrder;
    final status = order.computedStatus;
    final ready = status == OrderStatus.ready;
    final branchName = app.getBranchName(order.branch);
    final effectiveQrToken =
        _jwtToken ?? widget.qrToken ?? widget.order.qrToken ?? widget.order.id;

    return Scaffold(
      appBar: AppBar(title: Text('Sipariş ${order.shortId}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                branchName,
                style: const TextStyle(
                  color: EmarColors.espresso,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _Step(label: 'Alındı', done: true, active: false),
                  _StepLine(done: status != OrderStatus.received),
                  _Step(
                    label: 'Hazırlanıyor',
                    done: ready,
                    active: status == OrderStatus.preparing,
                  ),
                  _StepLine(done: ready),
                  _Step(label: 'Hazır', done: ready, active: false),
                ],
              ),
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOutBack,
                        ),
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: Text(
                        ready
                            ? 'Hazır! 🎉'
                            : _formatApprox(order.remainingSeconds),
                        key: ValueKey(ready),
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          color: EmarColors.espresso,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ready
                          ? (order.pickedUp
                                ? 'Teslim alındı'
                                : 'Siparişini alabilirsin')
                          : 'Siparişiniz hazır olduğunda bildirim alacaksınız',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: EmarColors.moss,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: EmarColors.oatDark,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: order.items.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${e.value}× ${productById(e.key).name}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (!ready)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: EmarColors.espresso.withValues(
                                alpha: 0.05,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: EmarColors.espresso.withValues(
                                  alpha: 0.08,
                                ),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: effectiveQrToken,
                            version: QrVersions.auto,
                            size: 160.0,
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.circle,
                              color: EmarColors.espresso,
                            ),
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.circle,
                              color: EmarColors.paprika,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SelectableText(
                            effectiveQrToken,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: EmarColors.espresso.withValues(alpha: 0.6),
                              fontFamily: 'monospace',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              PressableScale(
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Menüye Dön'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatefulWidget {
  final String label;
  final bool done;
  final bool active;
  const _Step({required this.label, required this.done, required this.active});

  @override
  State<_Step> createState() => _StepState();
}

class _StepState extends State<_Step> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Step old) {
    super.didUpdateWidget(old);
    if (widget.active && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.active) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.done
        ? EmarColors.moss
        : (widget.active ? EmarColors.paprika : EmarColors.espresso);
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final scale = widget.active ? 1 + _pulse.value * 0.28 : 1.0;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.done || widget.active
                      ? color
                      : Colors.transparent,
                  border: Border.all(
                    color: color.withValues(alpha: 0.6),
                    width: 2,
                  ),
                  boxShadow: widget.active
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35 * _pulse.value),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: TextStyle(fontSize: 10.5, color: color),
          child: Text(widget.label),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool done;
  const _StepLine({required this.done});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        color: done
            ? EmarColors.moss
            : EmarColors.espresso.withValues(alpha: 0.15),
      ),
    );
  }
}
