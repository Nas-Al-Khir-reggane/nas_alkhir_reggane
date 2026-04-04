import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/models/user_model.dart';
import './role_switcher_widget.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // رأس القائمة (Profile Header)
          Obx(() {
            final user = authController.currentUser.value;
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withValues(alpha: 0.8)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    backgroundImage: (user?.profileImage != null && user!.profileImage!.isNotEmpty)
                        ? CachedNetworkImageProvider(user.profileImage!) as ImageProvider
                        : null,
                    child: (user?.profileImage == null || user!.profileImage!.isEmpty)
                        ? Text(user != null && user.name.isNotEmpty ? user.name[0] : 'N',
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'مستخدم ناس الخير',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user?.role.displayName ?? '',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Tajawal'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              children: [
                // مغير الأدوار (التنقل السريع)
                const RoleSwitcherWidget(),
                
                const Divider(height: 30, indent: 20, endIndent: 20),

                _buildDrawerItem(
                  icon: Icons.dashboard_outlined,
                  title: 'لوحة التحكم الرئيسية',
                  onTap: () {
                    Get.back(); // إغلاق القائمة
                    authController.refreshUser().then((_) {
                        final role = authController.currentActiveRole;
                        authController.switchActiveRole(role);
                    });
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.person_outline_rounded,
                  title: 'الملف الشخصي',
                  onTap: () {
                    Get.back();
                    Get.toNamed(AppRoutes.profile);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.notifications_none_rounded,
                  title: 'الإشعارات',
                  onTap: () {
                    Get.back();
                    Get.toNamed(AppRoutes.notifications);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.settings_outlined,
                  title: 'إعدادات الحساب',
                  onTap: () {
                    Get.back();
                    Get.toNamed(AppRoutes.profile); // Settings are inside profile
                  },
                ),
                
                const Divider(height: 30, indent: 20, endIndent: 20),

                _buildDrawerItem(
                  icon: Icons.logout_rounded,
                  title: 'تسجيل الخروج',
                  isDestructive: true,
                  onTap: () {
                    Get.back();
                    authController.logout();
                  },
                ),
              ],
            ),
          ),

          // تذييل القائمة (Footer)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Image.asset('assets/images/logo.png', height: 40, errorBuilder: (_, _, _) => const Icon(Icons.volunteer_activism, color: AppTheme.primaryGreen)),
                const SizedBox(height: 8),
                const Text(
                  'ناس الخير - رڨان',
                  style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'إصدار 2.0.1',
                  style: TextStyle(color: Colors.grey, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : AppTheme.primaryGreen, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.redAccent : null,
          fontWeight: FontWeight.w600,
          fontFamily: 'Tajawal',
          fontSize: 14,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
