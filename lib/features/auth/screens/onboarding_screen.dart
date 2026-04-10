import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_routes.dart';

/// شاشة الترحيب — تظهر مرة واحدة فقط بعد التثبيت
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const String _seenKey = 'onboarding_seen';

  /// هل شاهد المستخدم الترحيب؟
  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen._seenKey, true);
    Get.offAllNamed(AppRoutes.login);
  }

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      icon: Icons.volunteer_activism_rounded,
      iconColor: Color(0xFF2E7D32),
      title: 'أهلاً بك في ناس الخير',
      subtitle: 'تطبيق خيري يجمع بين المحسنين والمحتاجين\nلنُسهّل العمل الخيري في مدينة رقان وما حولها',
    ),
    _OnboardingPage(
      icon: Icons.notifications_active_rounded,
      iconColor: Color(0xFFC62828),
      title: 'إشعارات الطوارئ',
      subtitle: 'استقبل نداءات التبرع بالدم والحالات الطارئة فوراً\nلأن كل ثانية تحسب عند إنقاذ الأرواح',
    ),
    _OnboardingPage(
      icon: Icons.track_changes_rounded,
      iconColor: Color(0xFF1976D2),
      title: 'تابع مساهماتك',
      subtitle: 'شاهد أثر تبرعاتك وتطوعك\nوتابع المشاريع الخيرية لحظة بلحظة',
    ),
    _OnboardingPage(
      icon: Icons.security_rounded,
      iconColor: Color(0xFFD4AF37),
      title: 'آمن وموثوق',
      subtitle: 'بياناتك محمية ومشفّرة\nوالتطبيق يعمل حتى بدون اتصال بالإنترنت',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // زر التخطي
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'تخطي',
                    style: GoogleFonts.tajawal(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // المحتوى
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FadeInDown(
                          key: ValueKey('icon_$index'),
                          duration: const Duration(milliseconds: 600),
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              color: page.iconColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              page.icon,
                              size: 60,
                              color: page.iconColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                        FadeInUp(
                          key: ValueKey('title_$index'),
                          duration: const Duration(milliseconds: 600),
                          delay: const Duration(milliseconds: 200),
                          child: Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FadeInUp(
                          key: ValueKey('sub_$index'),
                          duration: const Duration(milliseconds: 600),
                          delay: const Duration(milliseconds: 350),
                          child: Text(
                            page.subtitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.8,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // مؤشرات الصفحات + زر المتابعة
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: Row(
                children: [
                  // النقاط
                  Row(
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: _currentPage == i
                              ? AppTheme.primaryGreen
                              : (isDark ? Colors.white24 : Colors.black12),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // زر التالي / ابدأ
                  GestureDetector(
                    onTap: () {
                      if (_currentPage == _pages.length - 1) {
                        _completeOnboarding();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            _currentPage == _pages.length - 1 ? 28 : 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_currentPage == _pages.length - 1)
                            Text(
                              'ابدأ الآن',
                              style: GoogleFonts.tajawal(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          if (_currentPage == _pages.length - 1)
                            const SizedBox(width: 8),
                          Icon(
                            _currentPage == _pages.length - 1
                                ? Icons.rocket_launch_rounded
                                : Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
}
