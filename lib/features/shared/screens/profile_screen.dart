import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_model.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final user = authController.currentUser.value;
    final _ = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("الملف الشخصي", style: GoogleFonts.tajawal()),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Get.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => AppConstants.toggleTheme(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    backgroundImage: user?.profileImage != null 
                        ? NetworkImage(user!.profileImage!) 
                        : null,
                    child: user?.profileImage == null 
                        ? Text(user?.name[0].toUpperCase() ?? "?", 
                            style: GoogleFonts.tajawal(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen))
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(user?.name ?? "اسم المستخدم", 
                style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(user?.role.displayName ?? "", 
                style: GoogleFonts.tajawal(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
            const SizedBox(height: 40),
            _buildProfileItem(context, Icons.email_outlined, "البريد الإلكتروني", user?.email ?? ""),
            _buildProfileItem(context, Icons.phone_outlined, "رقم الهاتف", user?.phone ?? ""),
            _buildProfileItem(context, Icons.location_on_outlined, "الولاية", user?.wilaya ?? ""),
            _buildProfileItem(context, Icons.home_outlined, "العنوان", user?.address ?? ""),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () => authController.logout(),
                icon: const Icon(Icons.logout_rounded),
                label: Text("تسجيل الخروج", style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(BuildContext context, IconData icon, String title, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGreen),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.tajawal(fontSize: 12, color: Colors.grey)),
              Text(value, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
