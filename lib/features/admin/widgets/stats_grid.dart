import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/admin_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/models/user_model.dart';
import '../../../core/animations/scroll_animations.dart';
import '../screens/admin_metric_detail_screen.dart';

class StatsGrid extends StatelessWidget {
  const StatsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();
    final authController = Get.find<AuthController>();

    return Obx(() {
      final isSuperAdmin = authController.currentUser.value?.role == UserRole.superAdmin;
      final width = MediaQuery.sizeOf(context).width;
      final cards = <Widget>[
        if (isSuperAdmin)
          _buildGlassStatCard(
            context,
            title: 'إجمالي التبرعات',
            value: controller.totalDonations.value,
            suffix: ' دج',
            icon: Icons.account_balance_wallet_rounded,
            color: AppTheme.goldAccent,
            delay: 100,
            onTap: () => Get.to(() => AdminMetricDetailScreen(
              type: MetricType.donations,
              title: 'إحصائيات التبرعات',
              color: AppTheme.goldAccent,
            )),
          ),
        _buildGlassStatCard(
          context,
          title: 'طلبات معلقة',
          value: controller.pendingRequests.value,
          icon: Icons.pending_actions_rounded,
          color: AppTheme.primaryGreen,
          delay: 200,
          onTap: () => Get.to(() => AdminMetricDetailScreen(
            type: MetricType.requests,
            title: 'طلبات الميدان العالقة',
            color: AppTheme.primaryGreen,
          )),
        ),
        _buildGlassStatCard(
          context,
          title: 'مشاريع نشطة',
          value: controller.activeProjects.value,
          icon: Icons.volunteer_activism_rounded,
          color: AppTheme.urgentColor,
          delay: 300,
          onTap: () => Get.to(() => AdminMetricDetailScreen(
            type: MetricType.projects,
            title: 'تحليل المشاريع النشطة',
            color: AppTheme.urgentColor,
          )),
        ),
        _buildGlassStatCard(
          context,
          title: 'الفريق الميداني',
          value: controller.availableWorkers.value,
          icon: Icons.engineering_rounded,
          color: Colors.blue,
          delay: 400,
          onTap: () => Get.to(() => AdminMetricDetailScreen(
            type: MetricType.team,
            title: 'إحصائيات الميدانيين',
            color: Colors.blue,
          )),
        ),
      ];

      final int crossAxisCount;
      final double childAspectRatio;

      if (isSuperAdmin) {
        crossAxisCount = 2;
        childAspectRatio = width < 430 ? 1.15 : 1.35;
      } else {
        // منع فيضان البطاقات على الشاشات المتوسطة والصغيرة
        crossAxisCount = width < 1050 ? 2 : 3;
        childAspectRatio = crossAxisCount == 2 ? 1.22 : 1.0;
      }

      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
        children: cards,
      );
    });
  }

  Widget _buildGlassStatCard(
    BuildContext context, {
    required String title,
    required num value,
    String? suffix,
    required IconData icon,
    required Color color,
    required int delay,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeInUp(
      delay: Duration(milliseconds: delay),
      duration: const Duration(milliseconds: 600),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? color.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
              width: 1.5
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.05 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Icon(Icons.trending_up_rounded, color: color.withValues(alpha: 0.5), size: 16),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScrollAnimations.numberCounter(
                    value: value,
                    suffix: suffix ?? '',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
