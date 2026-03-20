import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/auth_controller.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
        children: [
          // خلفية زخرفية
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryGreen.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryGreen.withValues(alpha: 0.05),
              ),
            ),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeInDown(
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      size: 80,
                      color: AppTheme.warningColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeInDown(
                    delay: const Duration(milliseconds: 200),
                    child: const Text(
                      'جارٍ مراجعة طلبك',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeInDown(
                    delay: const Duration(milliseconds: 300),
                    child: const Text(
                      'سيتم إشعارك فور موافقة الإدارة على حسابك',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassDecoration,
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppTheme.primaryGreen),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'يمكنك طلب خدمة بدون حساب في الوقت الحالي',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeInUp(
                    delay: const Duration(milliseconds: 500),
                    child: SizedBox(
                      width: double.infinity,
                      child: AppTheme.gradientButton(
                        text: 'طلب خدمة الآن',
                        onPressed: () => Get.toNamed('/guest/request'),
                        icon: Icons.add_circle_outline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInUp(
                    delay: const Duration(milliseconds: 600),
                    child: TextButton(
                      onPressed: () => authController.logout(),
                      child: const Text(
                        'تسجيل الخروج',
                        style: TextStyle(
                          color: AppTheme.errorColor,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
