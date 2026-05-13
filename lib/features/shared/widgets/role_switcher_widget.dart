import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/models/user_model.dart';

class RoleSwitcherWidget extends StatelessWidget {
  const RoleSwitcherWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final user = authController.currentUser.value;
      if (user == null) return const SizedBox.shrink();

      // إخفاء الويجت للمدراء والمدير العام كما طلب المستخدم
      if (user.role == UserRole.superAdmin || user.role == UserRole.admin) {
        return const SizedBox.shrink();
      }

      final List<UserRole> availableRoles = _getAvailableRoles(user);
      if (availableRoles.length <= 1) return const SizedBox.shrink();

      final currentRole = authController.currentActiveRole;

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.glassDecoration.copyWith(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.primaryGreen.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.swap_horizontal_circle_outlined, 
                    color: AppTheme.primaryGreen, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'تبديل وضع الحساب',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'يمكنك التنقل بين أدوارك المختلفة لاستخدام ميزات التطبيق المخصصة لكل دور.',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                fontSize: 12,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 20),
            
            // قائمة الأدوار المتاحة بتصميم مدمج واحترافي
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: availableRoles.map((role) {
                  final isSelected = currentRole == role;
                  
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => authController.switchActiveRole(role),
                      child: AnimatedContainer(
                        duration: 300.ms,
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? AppTheme.primaryGreen 
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                              spreadRadius: 1,
                            )
                          ] : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getRoleIcon(role),
                              color: isSelected ? Colors.black : (isDark ? Colors.white70 : AppTheme.textSecondaryLight),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                role.displayName,
                                style: TextStyle(
                                  color: isSelected ? Colors.black : (isDark ? Colors.white70 : AppTheme.textSecondaryLight),
                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                  fontSize: 12,
                                  fontFamily: 'Tajawal',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    });
  }

  List<UserRole> _getAvailableRoles(UserModel user) {
    Set<UserRole> roles = {user.role};
    
    // فحص الصلاحيات الإضافية
    if (user.additionalRoles.contains('canDonate')) {
      roles.add(UserRole.donor);
    }
    if (user.additionalRoles.contains('canRequestService')) {
      roles.add(UserRole.beneficiary);
    }
    
    // بالنسبة للمدراء، يمكنهم رؤية كل شيء، لكن هنا نركز على الأدوار النشطة
    if (user.role == UserRole.superAdmin || user.role == UserRole.admin) {
      roles.add(UserRole.donor);
      roles.add(UserRole.beneficiary);
      roles.add(UserRole.worker);
    }

    return roles.toList();
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.worker:
        return Icons.engineering_rounded;
      case UserRole.donor:
        return Icons.favorite_rounded;
      case UserRole.beneficiary:
        return Icons.person_search_rounded;
      case UserRole.chatModerator:
        return Icons.chat_rounded;
    }
  }
}
