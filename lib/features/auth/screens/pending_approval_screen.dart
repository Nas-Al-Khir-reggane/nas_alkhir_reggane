import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/auth_controller.dart';
import '../../../data/services/notification_service.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // خلفية زخرفية موحدة (Unified Background)
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryGreen.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryGreen.withValues(alpha: 0.03),
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
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.hourglass_top_rounded,
                        size: 80,
                        color: Colors.orange.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeInDown(
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      'جارٍ مراجعة طلبك',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeInDown(
                    delay: const Duration(milliseconds: 300),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'سيتم إشعارك فور موافقة الإدارة على حسابك لنتمكن من تقديم أفضل خدمة لك.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: SizedBox(
                      width: double.infinity,
                      child: AppTheme.gradientButton(
                        text: 'الرجوع لتسجيل الدخول',
                        onPressed: () => Get.find<AuthController>().logout(),
                        icon: Icons.login_rounded,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Notifications button for pending users
          Positioned(
            top: 40,
            left: 16,
            child: Obx(() {
              final service = Get.find<NotificationService>();
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_none_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    onPressed: () => Get.toNamed('/notifications'),
                  ),
                  if (service.unreadCount.value > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.error, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(
                          service.unreadCount.value.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
