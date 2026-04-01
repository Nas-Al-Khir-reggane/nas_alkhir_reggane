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
    );
  }
}

