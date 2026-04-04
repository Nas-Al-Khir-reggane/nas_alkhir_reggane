import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/animations/sound_manager.dart';
import '../../../core/widgets/app_logo.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/notification_service.dart';
import '../controllers/admin_controller.dart';
import '../../shared/widgets/user_avatar.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final notificationService = Get.find<NotificationService>();
    final adminController = Get.find<AdminController>();

    return Row(
      children: [
        // 1. هوية المدير ورتبته (مع دعم الرتب الجديدة)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('مرحباً، 👋', 
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant, 
                  fontSize: 13, 
                  letterSpacing: 0.5,
                  fontFamily: 'Tajawal'
                )
              ),
              Obx(() => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  authController.currentUser.value?.name ?? 'المدير',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface, 
                    fontSize: 20, 
                    fontWeight: FontWeight.w900, 
                    height: 1.2,
                    fontFamily: 'Tajawal'
                  ),
                  maxLines: 1,
                ),
              )),
              Obx(() => Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: adminController.isSuperAdmin 
                      ? AppTheme.goldAccent.withValues(alpha: 0.1)
                      : AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: adminController.isSuperAdmin 
                        ? AppTheme.goldAccent.withValues(alpha: 0.3)
                        : AppTheme.primaryGreen.withValues(alpha: 0.3),
                    width: 0.5
                  ),
                ),
                child: Text(
                  authController.currentUser.value?.role.displayName ?? '',
                  style: TextStyle(
                    color: adminController.isSuperAdmin ? AppTheme.goldAccent : AppTheme.primaryGreen, 
                    fontSize: 10, 
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Tajawal'
                  ),
                ),
              )),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // 2. مركز التحكم الكريستالي
        FadeInDown(
          duration: const Duration(milliseconds: 800),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHeaderButton(
                context,
                onTap: () => Get.toNamed('/profile'),
                child: Obx(() {
                  final user = authController.currentUser.value;
                  return UserAvatar(
                    user: user ?? UserModel(
                        id: 'guest', name: 'جاري التحميل', email: '', phone: '', 
                        wilaya: '', commune: '', address: '', role: UserRole.beneficiary, 
                        createdAt: DateTime.now()
                    ),
                    size: 28,
                    showBadge: true,
                  );
                }),
              ),
              const SizedBox(width: 8),
              _buildHeaderButton(
                context,
                onTap: () {
                  AppConstants.toggleTheme();
                  SoundManager.to.playToggle(!Get.isDarkMode);
                },
                child: Icon(ThemeService().themeIcon, color: Theme.of(context).colorScheme.primary, size: 18),
              ),
              const SizedBox(width: 8),
              _buildHeaderButton(
                context,
                onTap: () => Get.toNamed('/notifications'),
                child: Obx(() => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.notifications_none_rounded, color: Theme.of(context).colorScheme.onSurface, size: 20),
                    if (notificationService.unreadCount.value > 0)
                      Positioned(
                        right: -2, top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.error, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                          child: Text(
                            notificationService.unreadCount.value.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                )),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // 3. شعار التطبيق (Corner Majesty)
        FadeInLeft(
          duration: const Duration(milliseconds: 1000),
          child: AppLogo(
            size: 64, 
            showGlow: false, 
            color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.white 
              : Theme.of(context).colorScheme.primary
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderButton(BuildContext context, {required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: child,
      ),
    );
  }
}
