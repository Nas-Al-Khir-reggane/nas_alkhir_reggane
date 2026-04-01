import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/widgets/app_logo.dart';
import '../controllers/auth_controller.dart';
import '../../../core/theme/app_theme.dart';

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
    // تم زيادة مدة الانتظار من 1.5 ثانية إلى 4 ثوانٍ لضمان قراءة النصوص
    await Future.delayed(const Duration(milliseconds: 4000));
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
            // 1. الخلفية الفاخرة
            AnimatedContainer(
              duration: const Duration(seconds: 1),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: isDark 
                    ? [
                        const Color(0xFF0D2519), 
                        const Color(0xFF05100B), 
                      ] 
                    : [
                        const Color(0xFFFFFFFF),
                        const Color(0xFFE8F5E9),
                      ],
                ),
              ),
            ),

            // 2. العناصر الزخرفية
            Positioned(
              top: -size.height * 0.1,
              left: -size.width * 0.2,
              child: FadeIn(
                duration: const Duration(seconds: 3),
                child: Container(
                  width: size.width * 0.8,
                  height: size.width * 0.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryGreen.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
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
                              ? AppTheme.primaryGreen.withValues(alpha: 0.15) 
                              : Colors.black.withValues(alpha: 0.75),
                            blurRadius: 60,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const AppLogo(size: 140, showGlow: false),
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
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0A2E14),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 60,
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, AppTheme.goldAccent, Colors.transparent],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: AppTheme.goldAccent.withValues(alpha: 0.75),
                            width: 0.8,
                          ),
                          gradient: LinearGradient(
                            colors: isDark 
                              ? [AppTheme.goldAccent.withValues(alpha: 0.15), Colors.transparent]
                              : [const Color(0xFFFDFCF0), Colors.white],
                          ),
                        ),
                        child: const Text(
                          'رقّان',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.goldAccent,
                            letterSpacing: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 50),

                // الشعار اللفظي (تم زيادة الوضوح)
                FadeIn(
                  duration: const Duration(seconds: 2),
                  delay: const Duration(milliseconds: 1500),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12, endIndent: 15, indent: 10)),
                        Text(
                          'معاً نبني .. معاً نرحم .. معاً نُغيّر',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 16,
                            fontWeight: FontWeight.w700, // خط أوضح
                            color: isDark ? Colors.white : const Color(0xFF1B3D2F),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12, indent: 15, endIndent: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // 4. مؤشر التحميل ونص "الجمعية في خدمتك" (تم تصحيح الوضوح هنا)
            Positioned(
              bottom: 60,
              child: FadeInUp(
                delay: const Duration(seconds: 2),
                child: Column(
                  children: [
                    SizedBox(
                      width: 50,
                      height: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          backgroundColor: isDark ? Colors.white10 : Colors.black12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? AppTheme.goldAccent.withValues(alpha: 0.15) : AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'الجمعية في خدمتك',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13, // تكبير الخط قليلاً
                        fontWeight: FontWeight.w600, // زيادة السمك للوضوح
                        color: isDark ? Colors.white.withValues(alpha: 0.75) : Colors.black54, // لون واضح جداً
                        letterSpacing: 2,
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

