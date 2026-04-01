import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class ScrollAnimations {
  // 1. Reveal on Scroll (تأثير الظهور عند التمرير)
  static Widget revealOnScroll({
    required Widget child,
    double delay = 0,
    bool fromLeft = false,
    bool fromRight = false,
  }) {
    if (fromLeft) return FadeInLeft(delay: Duration(milliseconds: delay.toInt()), child: child);
    if (fromRight) return FadeInRight(delay: Duration(milliseconds: delay.toInt()), child: child);
    return FadeInUp(delay: Duration(milliseconds: delay.toInt()), from: 20, child: child);
  }

  // 2. Parallax Effect (تأثير البارالاكس للخلفيات)
  static Widget parallaxBackground({
    required Widget child,
    required ScrollController scrollController,
    double speed = 0.5,
  }) {
    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, _) {
        double offset = 0.0;
        if (scrollController.hasClients) {
          offset = scrollController.offset * speed;
        }
        return Transform.translate(
          offset: Offset(0, offset),
          child: child,
        );
      },
    );
  }

  // 4. Number Counter Animation (عداد الأرقام الاحترافي)
  static Widget numberCounter({
    required num value,
    TextStyle? style,
    Duration duration = const Duration(seconds: 2),
    String prefix = '',
    String suffix = '',
    int decimals = 0,
    bool isCurrency = false,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutExpo, // الانزلاق السلس للأرقام
      builder: (context, val, child) {
        String formatted;
        if (isCurrency && val >= 1000) {
           if (val >= 1000000) {
             formatted = '${(val / 1000000).toStringAsFixed(1)}M';
           } else {
             formatted = '${(val / 1000).toStringAsFixed(1)}k';
           }
        } else {
          formatted = val.toStringAsFixed(decimals);
        }
        return Text('$prefix$formatted$suffix', style: style);
      },
    );
  }
}

