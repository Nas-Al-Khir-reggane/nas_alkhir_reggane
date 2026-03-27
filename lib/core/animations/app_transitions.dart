import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppTransitions {
  // المدة المثالية للانتقالات بين 280ms و 450ms
  static const Duration duration = Duration(milliseconds: 350);
  
  // المنحنى المفضل: cubic-bezier(0.4, 0, 0.2, 1) ليعطي شعور بفيزياء ارتدادية مرنة
  static const Curve curve = Cubic(0.4, 0.0, 0.2, 1.0);

  // 1. Fade + Scale (تلاشي مع تصغير خفيف عند الخروج والدخول)
  // يُستخدم لشاشات البداية والدخول
  static CustomTransition get fadeScale => CustomFadeScaleTransition();

  // 2. Directional Slide (انزلاق موجه حسب الاتجاه للتنقل الأمامي والخلفي)
  // يُستخدم للتنقل لصفحات التفاصيل أو الصفحات العميقة
  static CustomTransition get directionalSlide => CustomDirectionalSlideTransition();

  // 3. Crossfade Overlap (تداخل الشاشتين)
  // يُستخدم لتبديلات ה-Dashboard والتبويبات
  static CustomTransition get crossfadeOverlap => CustomCrossfadeTransition();
}

class CustomFadeScaleTransition extends CustomTransition {
  @override
  Widget buildTransition(
      BuildContext context,
      Curve? curve,
      Alignment? alignment,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    
    var curveAnimation = CurvedAnimation(parent: animation, curve: AppTransitions.curve);
    var reverseCurveAnimation = CurvedAnimation(parent: secondaryAnimation, curve: AppTransitions.curve);
    
    return FadeTransition(
      opacity: curveAnimation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1.0).animate(curveAnimation),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(reverseCurveAnimation),
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 0.96).animate(reverseCurveAnimation),
            child: child,
          ),
        ),
      ),
    );
  }
}

class CustomDirectionalSlideTransition extends CustomTransition {
  @override
  Widget buildTransition(
      BuildContext context,
      Curve? curve,
      Alignment? alignment,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    
    var curveAnimation = CurvedAnimation(parent: animation, curve: AppTransitions.curve);
    var reverseCurveAnimation = CurvedAnimation(parent: secondaryAnimation, curve: AppTransitions.curve);
    
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-0.35, 0.0), // الدخول من اليسار إلى اليمين بطريقة تناسب RTL
        end: Offset.zero,
      ).animate(curveAnimation),
      child: FadeTransition(
        opacity: curveAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(0.15, 0.0), // إزاحة الشاشة السابقة قليلاً بعيداً
          ).animate(reverseCurveAnimation),
          child: FadeTransition(
            opacity: Tween<double>(begin: 1.0, end: 0.0).animate(reverseCurveAnimation),
            child: child,
          ),
        ),
      ),
    );
  }
}

class CustomCrossfadeTransition extends CustomTransition {
  @override
  Widget buildTransition(
      BuildContext context,
      Curve? curve,
      Alignment? alignment,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    
    var curveAnimation = CurvedAnimation(parent: animation, curve: AppTransitions.curve);
    var reverseCurveAnimation = CurvedAnimation(parent: secondaryAnimation, curve: AppTransitions.curve);
    
    return FadeTransition(
      opacity: curveAnimation,
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.0).animate(reverseCurveAnimation),
        child: child,
      ),
    );
  }
}
