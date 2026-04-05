import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_routes.dart';
import 'core/bindings/initial_binding.dart';
import 'firebase_options.dart';
import 'core/constants/app_constants.dart';
import 'data/services/notification_service.dart';
import 'core/services/theme_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // صائد أخطاء Flutter (لحل مشكلة الشاشة الحمراء)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('🛑 Flutter Error: ${details.exception}');
    debugPrint('🛑 StackTrace: ${details.stack}');
  };

  try {
    // تهيئة الخدمات
    final themeService = ThemeService();
    await themeService.init();
    
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // الاشتراك في موضوع الطوارئ لاستقبال الإشعارات الجماعية
    await messaging.subscribeToTopic('emergencies');
    print('✅ Subscribed to emergencies topic');

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

    runApp(const NasAlKheirApp());
  } catch (e, stack) {
    debugPrint('💥 Critical Startup Error: $e');
    debugPrint('💥 StackTrace: $stack');
  }
}

// دالة تجريبية لإرسال إشعار حالة طارئة
Future<void> sendEmergencyNotification() async {
  try {
    final String? deviceToken = await FirebaseMessaging.instance.getToken();
    if (deviceToken == null) {
      debugPrint('⚠️ تعذر الحصول على توكن الجهاز');
      return;
    }

    final response = await http.post(
      Uri.parse('https://nas-alkhir-reggane.onrender.com/send-emergency'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': deviceToken,
        'title': '🚨 تنبيه حالة طارئة',
        'body': 'هناك طلب استغاثة جديد في منطقتك. يرجى المساعدة إن استطعت.',
      }),
    );

    if (response.statusCode == 200) {
      debugPrint('✅ تم إرسال الإشعار بنجاح');
      Get.snackbar('نجاح', 'تم إرسال بلاغ الطوارئ بنجاح',
        backgroundColor: Colors.green, colorText: Colors.white);
    } else {
      debugPrint('❌ فشل الإرسال: ${response.body}');
      Get.snackbar('خطأ', 'فشل في إرسال البلاغ: ${response.body}',
        backgroundColor: Colors.red, colorText: Colors.white);
    }
  } catch (e) {
    debugPrint('💥 خطأ أثناء طلب الإرسال: $e');
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
      locale: const Locale('ar'),
      fallbackLocale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en')
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      textDirection: TextDirection.rtl,
      initialBinding: InitialBinding(),
      initialRoute: AppRoutes.splash,
      getPages: AppRoutes.getPages(),
      builder: (context, child) {
        return Scaffold(
          body: child,
        );
      },
    );
  }
}
