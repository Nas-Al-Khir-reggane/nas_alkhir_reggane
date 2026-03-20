import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../controllers/auth_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthController _authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    _startNavigation();
  }

  void _startNavigation() async {
    await Future.delayed(const Duration(seconds: 3));
    _authController.checkAuthState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.darkBgGradient,
        ),
        child: Stack(
          children: [
            // دوائر زخرفية
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryGreen.withAlpha(13), // 0.05 * 255 ≈ 13
                  border: Border.all(color: AppTheme.glassBorder),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryGreen.withAlpha(13),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
              ),
            ),
            
            // المحتوى الرئيسي
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeInDown(
                    duration: const Duration(milliseconds: 800),
                    child: const AppLogo(size: 120, showGlow: true),
                  ),
                  const SizedBox(height: 24),
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: const Text(
                      'جمعية ناس الخير',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  FadeInUp(
                    delay: const Duration(milliseconds: 600),
                    child: const Text(
                      'رقان',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeInUp(
                    delay: const Duration(milliseconds: 800),
                    child: const Text(
                      'معاً نبني .. معاً نرحم .. معاً نُغيّر',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 15,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // مؤشر التحميل
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryGreen,
                  strokeWidth: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
