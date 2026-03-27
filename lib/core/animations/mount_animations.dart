import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';

class MountAnimations {
  // 1. الدخول المتتالي للقوائم (Staggered List Entry)
  static Widget staggeredListEntry({
    required int index,
    required Widget child,
    double dropOffset = 30.0,
    int delayMs = 60,
  }) {
    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 400),
      delay: Duration(milliseconds: delayMs),
      child: SlideAnimation(
        verticalOffset: dropOffset,
        child: FadeInAnimation(
          child: child,
        ),
      ),
    );
  }

  // دخول الشبكات بترتيب قطري للبطاقات (Diagonal wave effect)
  static Widget staggeredGridEntry({
    required int index,
    required int columnCount,
    required Widget child,
  }) {
    return AnimationConfiguration.staggeredGrid(
      position: index,
      duration: const Duration(milliseconds: 500),
      columnCount: columnCount,
      delay: const Duration(milliseconds: 50),
      child: SlideAnimation(
        verticalOffset: 20.0,
        curve: Curves.easeOutBack, // محاكاة Spring Physics
        child: FadeInAnimation(
          child: child,
        ),
      ),
    );
  }

  // 2. دخول قسم الـ Hero 
  static Widget heroTitle({required Widget child}) {
    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      from: 15,
      child: child,
    );
  }

  static Widget heroSubtitle({required Widget child}) {
    return FadeInUp(
      duration: const Duration(milliseconds: 450),
      delay: const Duration(milliseconds: 100),
      from: 15,
      child: child,
    );
  }

  static Widget heroButton({required Widget child}) {
    return ZoomIn(
      duration: const Duration(milliseconds: 300),
      delay: const Duration(milliseconds: 200),
      child: child,
    );
  }

  // 4. Modal / Drawer Entrance
  static Widget modalEntrance({required Widget child}) {
    return FadeInZoom(
      duration: const Duration(milliseconds: 300),
      child: child,
    );
  }

  // 5. Image Loading Effect
  // تحويل Skeleton إلى صورة بضبابية وتصغير مرئي ناعم
  static Widget animatedImageLoad({
    required Widget imageWidget,
    required bool isLoading,
    double width = double.infinity,
    double height = double.infinity,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOutCirc,
      transitionBuilder: (child, animation) {
        if (child.key == const ValueKey('loading')) {
          return FadeTransition(opacity: animation, child: child);
        }
        var blurAnim = Tween<double>(begin: 8.0, end: 0.0).animate(animation);
        var scaleAnim = Tween<double>(begin: 1.02, end: 1.0).animate(animation);
        
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return Transform.scale(
              scale: scaleAnim.value,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: blurAnim.value, sigmaY: blurAnim.value),
                child: FadeTransition(opacity: animation, child: child),
              ),
            );
          },
        );
      },
      child: isLoading
          ? Shimmer.fromColors(
              key: const ValueKey('loading'),
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(width: width, height: height, color: Colors.white),
            )
          : KeyedSubtree(key: const ValueKey('image'), child: imageWidget),
    );
  }
}

// FadeInZoom (مساعد للـ Modal)
class FadeInZoom extends StatelessWidget {
  final Widget child;
  final Duration duration;
  
  const FadeInZoom({super.key, required this.child, this.duration = const Duration(milliseconds: 300)});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1.0),
      duration: duration,
      curve: Curves.easeOutBack,
      builder: (context, value, childWidget) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: ((value - 0.95) / 0.05).clamp(0.0, 1.0),
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }
}
