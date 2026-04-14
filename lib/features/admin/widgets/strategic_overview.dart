import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_controller.dart';
import '../screens/manage_strategic_goals_screen.dart';
import 'impact_gauge.dart';
import '../../../data/models/user_model.dart';

/// ويدجت الرؤية الاستراتيجية المخصصة للمدير العام فقط.
/// تحتوي على مؤشر الأثر السنوي وزر استخراج التقارير الرسمية.
class StrategicOverview extends StatelessWidget {
  const StrategicOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Obx(() {
      final isSuper = authController.currentUser.value?.role == UserRole.superAdmin;
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStrategicHeader(context),
          
          // مؤشر الأثر يظهر فقط للمدير العام
          if (isSuper) ...[
            const SizedBox(height: 16),
            ImpactGauge(),
          ],
          
          const SizedBox(height: 12),
          
          const SizedBox(height: 12),
          // زر إدارة الأهداف الاستراتيجية (للمدير العام فقط)
          if (isSuper)
            _buildManageGoalsButton(context),
        ],
      );
    });
  }

  Widget _buildStrategicHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.star_rounded, color: AppTheme.goldAccent, size: 24),
        const SizedBox(width: 8),
        Text('مركز القيادة', 
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface, 
            fontSize: 18, 
            fontWeight: FontWeight.w900,
            fontFamily: 'Tajawal'
          )
        ),
      ],
    );
  }

  Widget _buildManageGoalsButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.to(() => const ManageStrategicGoalsScreen()),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings_suggest_rounded, color: AppTheme.primaryGreen, size: 20),
            const SizedBox(width: 8),
            Text('إدارة حملات الشهر الخيرية', 
              style: TextStyle(color: AppTheme.primaryGreen, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')
            ),
          ],
        ),
      ),
    );
  }
}
