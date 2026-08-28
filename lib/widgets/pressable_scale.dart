import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dokunulduğunda anlık olarak küçülen, bırakılınca yumuşakça geri dönen sarmalayıcı.
/// AnimationController tabanlı olduğu için AnimatedScale'in 1-frame gecikmesi yoktur.
/// Ham pointer olaylarını dinler — gesture arena'ya girmez, içindeki butonlar normal çalışır.
class PressableScale extends StatefulWidget {
  final Widget child;
  final double scale;
  final bool haptic;
  const PressableScale({
    super.key,
    required this.child,
    this.scale = 0.94,
    this.haptic = false,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 160),
      lowerBound: 0,
      upperBound: 1,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDown(PointerDownEvent _) {
    if (widget.haptic) HapticFeedback.selectionClick();
    _ctrl.forward();
  }

  void _onUp(PointerEvent _) => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onDown,
      onPointerUp: _onUp,
      onPointerCancel: _onUp,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: widget.child,
      ),
    );
  }
}

