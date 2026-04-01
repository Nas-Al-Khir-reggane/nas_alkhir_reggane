import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class MicroInteractions {
  // 1. الأزرار (Bouncing / Press / Loading / Success)
  static Widget bouncingButton({
    required Widget child,
    required VoidCallback onTap,
    bool isLoading = false,
    bool isSuccess = false,
  }) {
    return _BouncingButton(
      onTap: onTap,
      isLoading: isLoading,
      isSuccess: isSuccess,
      child: child,
    );
  }

  // 2. حقول الإدخال (Focus Glow & Error Shake)
  static Widget animatedFocusField({
    required Widget child,
    bool isError = false,
  }) {
    return _AnimatedFocusField(
      isError: isError,
      child: child,
    );
  }

  // 3. Navigation Icon / Active Indicator Effect
  static Widget navIcon({
    required Widget child,
    required bool isActive,
    Color activeColor = Colors.green,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      padding: EdgeInsets.all(isActive ? 6 : 0),
      // تأثير Pill عند التفعيل
      decoration: isActive
          ? BoxDecoration(
              color: activeColor.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(14),
            )
          : null,
      child: AnimatedScale(
        scale: isActive ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        child: child,
      ),
    );
  }

  // 4. Hover Scale Effect
  static Widget hoverScale({
    required Widget child,
    double scale = 1.05,
    Duration duration = const Duration(milliseconds: 200),
  }) {
    return _HoverScale(
      scale: scale,
      duration: duration,
      child: child,
    );
  }
}

class _BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isSuccess;

  const _BouncingButton({
    required this.child,
    required this.onTap,
    this.isLoading = false,
    this.isSuccess = false,
  });

  @override
  State<_BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<_BouncingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100)); // استجابة سريعة جداً للضغط
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          if (!widget.isLoading && !widget.isSuccess) _controller.forward();
        },
        onTapUp: (_) {
          _controller.reverse();
          if (!widget.isLoading && !widget.isSuccess) widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            double currentScale = _scaleAnimation.value;
            // رفع العنصر قليلاً عند الـ Hover (لأجهزة الديسكتوب/الويب)
            if (_isHovered && _controller.isDismissed && !widget.isLoading) {
              currentScale = 1.02; 
            }
            return Transform.scale(
              scale: currentScale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                   AnimatedOpacity(
                     duration: const Duration(milliseconds: 200),
                     opacity: (widget.isLoading || widget.isSuccess) ? 0.0 : 1.0,
                     child: widget.child, // نخفي المحتوى ونترك الحجم كما هو
                   ),
                   if (widget.isLoading)
                     const SizedBox(
                       width: 24, height: 24,
                       child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                     ),
                   if (widget.isSuccess)
                     ZoomIn(
                       duration: const Duration(milliseconds: 400),
                       child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                     ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedFocusField extends StatefulWidget {
  final Widget child;
  final bool isError;

  const _AnimatedFocusField({required this.child, this.isError = false});

  @override
  State<_AnimatedFocusField> createState() => _AnimatedFocusFieldState();
}

class _AnimatedFocusFieldState extends State<_AnimatedFocusField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isFocused && !widget.isError
              ? [BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: 0.75), blurRadius: 15, spreadRadius: 2)]
              : widget.isError
                  ? [BoxShadow(color: Colors.redAccent.withValues(alpha: 0.75), blurRadius: 15, spreadRadius: 2)]
                  : [],
        ),
        child: widget.isError 
          ? ShakeX(duration: const Duration(milliseconds: 400), from: 4, child: widget.child)
          : widget.child,
      ),
    );
  }
}

class _HoverScale extends StatefulWidget {
  final Widget child;
  final double scale;
  final Duration duration;

  const _HoverScale({
    required this.child,
    this.scale = 1.05,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<_HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<_HoverScale> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}

