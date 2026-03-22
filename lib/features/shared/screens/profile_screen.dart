import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthController authController = Get.find<AuthController>();
  bool _isUploading = false;

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final user = authController.currentUser.value;
      if (user == null) return;
      final ref = FirebaseStorage.instance.ref('profile_images/${user.id}.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(user.id).update({'profileImage': url});
      await authController.refreshUser();
      Get.snackbar('تم', 'تم تحديث الصورة الشخصية', backgroundColor: AppTheme.successColor, colorText: Colors.black);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفع الصورة', backgroundColor: AppTheme.errorColor, colorText: Colors.white);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = authController.currentUser.value;
    final isWorker = user?.role == UserRole.worker;

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
            const SizedBox(height: 16),
            // ===== Profile Photo =====
            Center(
              child: GestureDetector(
                onTap: _pickAndUploadPhoto,
                child: Stack(
                  children: [
                    Obx(() {
                      final u = authController.currentUser.value;
                      return CircleAvatar(
                        radius: 60,
                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        backgroundImage: u?.profileImage != null ? NetworkImage(u!.profileImage!) : null,
                        child: u?.profileImage == null
                            ? Text(u?.name[0].toUpperCase() ?? "?",
                                style: GoogleFonts.tajawal(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen))
                            : null,
                      );
                    }),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
                        child: _isUploading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Obx(() => Text(authController.currentUser.value?.name ?? "اسم المستخدم",
                style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.bold))),
            Obx(() => Text(authController.currentUser.value?.role.displayName ?? "",
                style: GoogleFonts.tajawal(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600))),

            // ===== Worker Rating Section =====
            if (isWorker) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.goldAccent.withValues(alpha: 0.15), AppTheme.darkCard],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.3)),
                ),
                child: Obx(() {
                  final u = authController.currentUser.value;
                  final rating = u?.rating ?? 0.0;
                  final ratingCount = u?.ratingCount ?? 0;
                  final completedTasks = u?.completedTasks ?? 0;
                  return Column(
                    children: [
                      Text('تقييمي', style: GoogleFonts.tajawal(color: AppTheme.goldAccent, fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) => Icon(
                          i < rating.round() ? Icons.star : Icons.star_border,
                          color: AppTheme.goldAccent,
                          size: 32,
                        )),
                      ),
                      const SizedBox(height: 6),
                      Text('${rating.toStringAsFixed(1)} / 5.0  ($ratingCount تقييم)',
                          style: GoogleFonts.tajawal(color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _workerStat('مهام منجزة', completedTasks.toString(), Icons.check_circle_outline),
                          _workerStat('الحالة', (u?.isAvailable ?? false) ? 'متاح' : 'مشغول',
                              (u?.isAvailable ?? false) ? Icons.circle : Icons.pause_circle,
                              color: (u?.isAvailable ?? false) ? AppTheme.successColor : AppTheme.warningColor),
                        ],
                      ),
                    ],
                  );
                }),
              ),
            ],

            const SizedBox(height: 24),
            // ===== Info Fields =====
            Obx(() {
              final u = authController.currentUser.value;
              return Column(
                children: [
                  _buildProfileItem(context, Icons.email_outlined, "البريد الإلكتروني", u?.email ?? ""),
                  _buildProfileItem(context, Icons.phone_outlined, "رقم الهاتف", u?.phone ?? ""),
                  _buildProfileItem(context, Icons.location_on_outlined, "الولاية", u?.wilaya ?? ""),
                  _buildProfileItem(context, Icons.home_outlined, "العنوان", u?.address ?? ""),
                ],
              );
            }),

            const SizedBox(height: 32),
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

  Widget _workerStat(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? AppTheme.primaryGreen, size: 26),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.tajawal(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        Text(label, style: GoogleFonts.tajawal(color: AppTheme.textHint, fontSize: 11)),
      ],
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
              Text(value.isEmpty ? '—' : value, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
