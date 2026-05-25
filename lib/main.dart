import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_routes.dart';
import 'core/bindings/initial_binding.dart';
import 'firebase_options.dart';
import 'core/constants/app_constants.dart';
import 'data/services/notification_service.dart';
// Note: BatteryOptimizerService, AppUpdateService, and ReviewPromptService imports removed as they are now handled in AuthController
import 'core/services/theme_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_messaging/firebase_messaging.dart';

/// مثيل Firebase Analytics عام
final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ دعم Android 15 - Edge-to-Edge Display
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  // تهيئة Firebase أولاً لتفعيل Crashlytics
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // تفعيل Crashlytics لالتقاط كل الأعطال
  FlutterError.onError = (details) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    debugPrint('🛑 Flutter Error: ${details.exception}');
  };
  
  // التقاط أخطاء Dart غير المُعالجة
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  try {
    // تهيئة الخدمات
    final themeService = ThemeService();
    await themeService.init();
    
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    
    // Firebase تم تهيئته مسبقاً قبل runApp
    
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // الاشتراك في موضوع الطوارئ لاستقبال الإشعارات الجماعية
    await messaging.subscribeToTopic('emergencies');
    debugPrint('✅ Subscribed to emergencies topic');

    try {
      final String? fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint('🔥 FCM Token: $fcmToken');
    } catch (e) {
      debugPrint('⚠️ قراءة توكن FCM فشلت: $e');
    }

    // تشغيل الإشعارات في الخلفية لضمان عدم تعليق الواجهة
    NotificationService.init().catchError((e) {
      debugPrint('⚠️ Notification Init Failed: $e');
    });

    // تم نقل فحوصات التشغيل (البطارية، التحديثات، التقييم) إلى AuthController

    runApp(const NasAlKheirApp());

    // تم نقل فحوصات التشغيل (البطارية، التحديثات، التقييم) إلى AuthController
    // لضمان ظهور الحوارات بعد استقرار الواجهة وانتهاء شاشة البداية
  } catch (e, stack) {
    debugPrint('💥 Critical Startup Error: $e');
    debugPrint('💥 StackTrace: $stack');
  }
}

// دالة تجريبية لإرسال إشعار حالة طارئة عبر الخدمة المدمجة
Future<void> sendEmergencyNotification() async {
  try {
    await NotificationService.notifyAll(
      type: 'blood_emergency',
      title: '🚨 تنبيه حالة طارئة',
      body: 'هناك طلب استغاثة جديد في منطقتك. يرجى المساعدة إن استطعت.',
    );

    debugPrint('✅ تم إرسال الإشعار بنجاح');
    Get.snackbar('نجاح', 'تم إرسال بلاغ الطوارئ بنجاح',
      backgroundColor: Colors.green, colorText: Colors.white);
  } catch (e) {
    debugPrint('💥 خطأ أثناء طلب الإرسال: $e');
    Get.snackbar('خطأ', 'فشل في إرسال البلاغ: $e',
      backgroundColor: Colors.red, colorText: Colors.white);
  }
}

class NasAlKheirApp extends StatelessWidget {
  const NasAlKheirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeService().themeMode,
      locale: Locale('ar'),
      fallbackLocale: Locale('ar'),
      supportedLocales: [
        Locale('ar'),
        Locale('en')
      ],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      textDirection: TextDirection.rtl,
      initialBinding: InitialBinding(),
      initialRoute: AppRoutes.splash,
      getPages: AppRoutes.getPages(),
      builder: (context, child) {
        // ✅ دعم Edge-to-Edge: لا نستخدم Scaffold لتجنب التعارض مع شريط الحالة
        // تقييد حجم الخط بين 0.85 و 1.15 لضمان ثبات الواجهة
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaler.scale(1.0).clamp(0.85, 1.15),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
