import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';

class VisualEffects {
  // 1. Ripple Effect المخصص (أمواج دائرية للضغط)
  static Widget ripple({
    required Widget child,
    required VoidCallback onTap,
    Color? splashColor,
    BorderRadius? borderRadius,
  }) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: borderRadius ?? BorderRadius.circular(16),
              splashColor: splashColor?.withValues(alpha: 0.2) ?? AppTheme.primaryGreen.withValues(alpha: 0.2),
              highlightColor: Colors.transparent,
              onTap: onTap,
            ),
          ),
        ),
      ],
    );
  }

  // 2. Magnetic Button (أزرار تنجذب لمؤشر الماوس بفيزياء مرنة)
  static Widget magneticButton({required Widget child}) {
    return _MagneticButton(child: child);
  }

  // 6. Glass Morphism (الواجهات الزجاجية الناعمة)
  static Widget glassMorphism({
    required Widget child,
    double blur = 15.0,
    double opacity = 0.05,
    Color color = Colors.white,
    BorderRadius? borderRadius,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity),
            borderRadius: borderRadius,
            border: Border.all(
              color: color.withValues(alpha: 0.1),
              width: 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  // 4. Shimmer Loading النبيل للمتصفحات والموبايل
  static Widget shimmerLoading({
    required double width,
    required double height,
    BorderRadius? borderRadius,
  }) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.withValues(alpha: 0.15),
      highlightColor: Colors.grey.withValues(alpha: 0.05),
      direction: ShimmerDirection.rtl, // توافق تام مع الاتجاه العربي
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
      ),
    );
  }

  // 5. Ambient Background (الخلفية المتنفسة اللطيفة 0.05)
  static Widget ambientBackground({required Widget child, bool isDark = false}) {
    return Builder(
      builder: (context) => Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(
          children: [
            Positioned.fill(
              child: _AnimatedAmbientGradient(isDark: isDark),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _MagneticButton extends StatefulWidget {
  final Widget child;
  const _MagneticButton({required this.child});

  @override
  State<_MagneticButton> createState() => _MagneticButtonState();
}

class _MagneticButtonState extends State<_MagneticButton> with SingleTickerProviderStateMixin {
  Offset position = Offset.zero;
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _animation = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(PointerEvent details) {
    if (!mounted) return;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final size = box.size;
    final center = Offset(size.width / 2, size.height / 2);
    final relativePosition = details.localPosition - center;
    
    // التمغنط المحدود للحفاظ على قابلية الاستخدام
    setState(() {
      position = Offset(
        (relativePosition.dx * 0.15).clamp(-20.0, 20.0),
        (relativePosition.dy * 0.15).clamp(-20.0, 20.0),
      );
      _animation = Tween<Offset>(begin: position, end: position).animate(_controller);
    });
    _controller.forward(from: 0);
  }

  void _onExit(PointerEvent details) {
    if (!mounted) return;
    setState(() {
      position = Offset.zero;
      _animation = Tween<Offset>(begin: _animation.value, end: Offset.zero).animate(
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
      );
    });
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: _onHover,
      onExit: _onExit,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.translate(
            offset: _animation.value,
            child: widget.child,
          );
        },
      ),
    );
  }
}

class _AnimatedAmbientGradient extends StatefulWidget {
  final bool isDark;
  const _AnimatedAmbientGradient({required this.isDark});
  @override
  State<_AnimatedAmbientGradient> createState() => _AnimatedAmbientGradientState();
}

class _AnimatedAmbientGradientState extends State<_AnimatedAmbientGradient> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // سرعة بطيئة جداً (15 ثانية) لعدم تشتيت الانتباه
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.8 + (_controller.value * 1.6), 0.8 - (_controller.value * 1.6)),
              radius: 2.0,
              colors: [
                widget.isDark ? AppTheme.primaryGreen.withValues(alpha: 0.03) : AppTheme.primaryGreen.withValues(alpha: 0.05),
                Colors.transparent,
                widget.isDark ? Colors.blueAccent.withValues(alpha: 0.01) : Colors.blueAccent.withValues(alpha: 0.02),
              ],
            ),
          ),
        );
      },
    );
  }
}
