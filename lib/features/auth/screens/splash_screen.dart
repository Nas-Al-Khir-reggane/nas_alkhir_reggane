import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/widgets/app_logo.dart';
import '../controllers/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_routes.dart';
import 'onboarding_screen.dart';

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
    await Future.delayed(const Duration(milliseconds: 4000));
    
    // تحقق إذا كانت هذه أول مرة — اعرض شاشة الترحيب
    final seenOnboarding = await OnboardingScreen.hasSeenOnboarding();
    if (!seenOnboarding) {
      Get.offAllNamed(AppRoutes.onboarding);
      return;
    }
    
    _authController.checkAuthState();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Get.isDarkMode;
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. الخلفية الفاخرة بتدرج ناعم جداً
            AnimatedContainer(
              duration: const Duration(seconds: 1),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: isDark 
                    ? [
                        const Color(0xFF0D2519), 
                        const Color(0xFF05100B), 
                      ] 
                    : [
                        const Color(0xFFFFFFFF),
                        const Color(0xFFF1F8F1), // تدرج أخضر باهت جداً للفخامة
                      ],
                ),
              ),
            ),

            // 2. العناصر الزخرفية (دوائر شفافة جداً)
            Positioned(
              top: -size.height * 0.15,
              right: -size.width * 0.2,
              child: FadeIn(
                duration: const Duration(seconds: 3),
                child: Container(
                  width: size.width * 0.9,
                  height: size.width * 0.9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [
                        AppTheme.primaryGreen.withValues(alpha: 0.04), // شفافية خفيفة جداً
                        AppTheme.primaryGreen.withValues(alpha: 0.01),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: -size.height * 0.1,
              left: -size.width * 0.1,
              child: FadeIn(
                duration: const Duration(seconds: 3),
                child: Container(
                  width: size.width * 0.6,
                  height: size.width * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryGreen.withValues(alpha: 0.03),
                  ),
                ),
              ),
            ),

            // 3. المحتوى الرئيسي
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeInDown(
                  duration: const Duration(milliseconds: 1500),
                  child: ZoomIn(
                    duration: const Duration(milliseconds: 1000),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: isDark 
                              ? AppTheme.primaryGreen.withValues(alpha: 0.08) 
                              : Colors.black.withValues(alpha: 0.04),
                            blurRadius: 80,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: AppLogo(
                        size: 140, 
                        showGlow: false,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),

                FadeInUp(
                  duration: const Duration(milliseconds: 1000),
                  delay: const Duration(milliseconds: 500),
                  child: Column(
                    children: [
                      Text(
                        'جمعية ناس الخير',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0A2E14),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 1.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, AppTheme.goldAccent.withValues(alpha: 0.5), Colors.transparent],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: AppTheme.goldAccent.withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                          color: AppTheme.goldAccent.withValues(alpha: 0.05),
                        ),
                        child: const Text(
                          'رقّان',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.goldAccent,
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                FadeIn(
                  duration: const Duration(seconds: 2),
                  delay: const Duration(milliseconds: 1500),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), endIndent: 15)),
                        Text(
                          'معاً نبني .. معاً نرحم',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF4A7456),
                          ),
                        ),
                        Expanded(child: Divider(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), indent: 15)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            Positioned(
              bottom: 60,
              child: FadeInUp(
                delay: const Duration(seconds: 2),
                child: Column(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 2,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryGreen.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'الجمعية في خدمتك',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.black38,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
