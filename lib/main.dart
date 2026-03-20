import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_routes.dart';
import 'core/bindings/initial_binding.dart';
import 'firebase_options.dart';
import 'core/constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const NasAlKheirApp());
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
      themeMode: ThemeMode.dark, // جعل الوضع المظلم هو الافتراضي
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
