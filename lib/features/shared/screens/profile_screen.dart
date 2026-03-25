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
import '../../../core/utils/default_avatars.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthController authController = Get.find<AuthController>();

  UserModel? get displayUser {
    if (Get.arguments is UserModel) return Get.arguments as UserModel;
    if (Get.arguments is String) return null; // We'll fetch it below if it's just an ID
    return authController.currentUser.value;
  }

  bool get isOwnProfile {
    final user = displayUser;
    if (user == null && Get.arguments is String) return Get.arguments == authController.currentUser.value?.id;
    if (user == null) return true;
    return user.id == authController.currentUser.value?.id;
  }

  @override
  void initState() {
    super.initState();
    if (authController.currentUser.value == null && Get.arguments == null) {
      authController.refreshUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = displayUser;
      final bool ownProfile = isOwnProfile;

      // If we only have an ID, fetch the user data
      if (user == null && Get.arguments is String) {
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(Get.arguments as String).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Scaffold(appBar: AppBar(), body: const Center(child: Text("المستخدم غير موجود")));
            }
            final fetchedUser = UserModel.fromMap(snapshot.data!.data() as Map<String, dynamic>, snapshot.data!.id);
            return _buildScaffold(fetchedUser, ownProfile);
          },
        );
      }

      return _buildScaffold(user, ownProfile);
    });
  }

  Widget _buildScaffold(UserModel? user, bool ownProfile) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ownProfile ? "الملف الشخصي" : "ملف المستخدم", style: GoogleFonts.tajawal()),
        elevation: 0,
        actions: [
          if (ownProfile)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                if (user != null) {
                  _showEditProfileDialog();
                } else {
                  Get.snackbar('تنبيه', 'جاري تحميل بيانات المستخدم...');
                }
              },
            ),
          IconButton(
            icon: Icon(Get.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => AppConstants.toggleTheme(),
          ),
        ],
      ),
      body: user == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off_outlined, color: AppTheme.textHint, size: 60),
                  const SizedBox(height: 16),
                  const Text("جاري جلب بيانات المستخدم...", style: TextStyle(color: AppTheme.textHint)),
                  const SizedBox(height: 24),
                  if (authController.isLoading.value)
                    const CircularProgressIndicator(color: AppTheme.primaryGreen)
                  else
                    TextButton.icon(
                      onPressed: () => authController.refreshUser(),
                      icon: const Icon(Icons.refresh, color: AppTheme.primaryGreen),
                      label: const Text('تحديث البيانات', style: TextStyle(color: AppTheme.primaryGreen)),
                    )
                ],
              ),
            )
          : _buildProfileContent(user, ownProfile),
    );
  }

  Widget _buildProfileContent(UserModel user, bool ownProfile) {
    final isWorker = user.role == UserRole.worker;
    final canChat = !ownProfile && (user.role == UserRole.admin || user.role == UserRole.superAdmin || user.role == UserRole.worker);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: ownProfile ? _showEditProfileDialog : null,
              child: Stack(
                children: [
                  Hero(
                    tag: 'profile_${user.id}',
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      backgroundImage: (user.profileImage != null && user.profileImage!.isNotEmpty)
                          ? NetworkImage(user.profileImage!)
                          : null,
                      child: (user.profileImage == null || user.profileImage!.isEmpty)
                          ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                              style: GoogleFonts.tajawal(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen))
                          : null,
                    ),
                  ),
                  if (ownProfile)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(user.name, style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(user.role.displayName, style: GoogleFonts.tajawal(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
          
          if (canChat) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Get.toNamed('/chat/private', arguments: {'userId': user.id, 'userName': user.name}),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: Text(
                  user.role == UserRole.worker ? "مراسلة المتطوع" : "تواصل مع الإدارة",
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
          ],

          if (isWorker) ...[
            const SizedBox(height: 20),
            _buildWorkerStatsCard(user),
          ],
          const SizedBox(height: 24),
          Column(
            children: [
              _buildProfileItem(context, Icons.email_outlined, "البريد الإلكتروني", user.email),
              _buildProfileItem(context, Icons.phone_outlined, "رقم الهاتف", user.phone),
              _buildProfileItem(context, Icons.location_on_outlined, "الولاية", user.wilaya),
              _buildProfileItem(context, Icons.home_outlined, "العنوان", user.address),
            ],
          ),
          const SizedBox(height: 32),
          if (ownProfile)
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
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkerStatsCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Get.theme.cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('أداء المتطوع', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (user.rating) >= 4 ? AppTheme.successColor.withValues(alpha: 0.1) : AppTheme.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text('${user.rating}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('المهام', '${user.completedTasks}', Icons.assignment_turned_in_outlined),
              _statItem('الرحلات', '${user.totalTrips}', Icons.local_shipping_outlined),
              _statItem('الحالة', user.isAvailable ? 'متاح' : 'مشغول', Icons.circle,
                  color: user.isAvailable ? AppTheme.successColor : AppTheme.warningColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? AppTheme.primaryGreen, size: 26),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: GoogleFonts.tajawal(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  Widget _buildProfileItem(BuildContext context, IconData icon, String title, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Get.theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGreen),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.tajawal(fontSize: 12, color: Colors.grey)),
                Text(value.isEmpty ? '—' : value, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final user = displayUser;
    if (user == null) return;

    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);
    final wilayaCtrl = TextEditingController(text: user.wilaya);
    final addressCtrl = TextEditingController(text: user.address);
    String? selectedImageUrl = user.profileImage;
    bool isUploadingInDialog = false;

    Get.bottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      StatefulBuilder(builder: (context, setStateDialog) {
        return Container(
          height: Get.height * 0.85,
          decoration: BoxDecoration(
            color: Get.theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تعديل الملف الشخصي', style: GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                          backgroundImage: (selectedImageUrl != null && selectedImageUrl!.isNotEmpty)
                              ? NetworkImage(selectedImageUrl!)
                              : null,
                          child: (selectedImageUrl == null || selectedImageUrl!.isEmpty)
                              ? Icon(Icons.person, size: 50, color: AppTheme.primaryGreen)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextField(
                        controller: nameCtrl,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: AppTheme.inputDecoration('الاسم الكامل', Icons.person_outline),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneCtrl,
                        style: TextStyle(color: AppTheme.textPrimary),
                        keyboardType: TextInputType.phone,
                        decoration: AppTheme.inputDecoration('رقم الهاتف', Icons.phone_outlined),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: wilayaCtrl,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: AppTheme.inputDecoration('الولاية', Icons.location_on_outlined),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressCtrl,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: AppTheme.inputDecoration('العنوان التفصيلي', Icons.home_outlined),
                      ),
                      const SizedBox(height: 24),
                      Text('تغيير الصورة (أرفع صورة أو اختر رمز):',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 75,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
                                if (picked == null) return;

                                setStateDialog(() => isUploadingInDialog = true);
                                try {
                                  final ref = FirebaseStorage.instance.ref('profile_images/${user.id}.jpg');
                                  await ref.putFile(File(picked.path));
                                  final url = await ref.getDownloadURL();
                                  setStateDialog(() {
                                    selectedImageUrl = url;
                                    isUploadingInDialog = false;
                                  });
                                } catch (e) {
                                  setStateDialog(() => isUploadingInDialog = false);
                                  Get.snackbar('خطأ', 'فشل رفع الصورة');
                                }
                              },
                              child: Container(
                                width: 60,
                                height: 60,
                                margin: const EdgeInsets.only(left: 12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                  border: Border.all(color: AppTheme.primaryGreen, width: 1),
                                ),
                                child: isUploadingInDialog
                                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.add_a_photo_outlined, color: AppTheme.primaryGreen),
                              ),
                            ),
                            ...DefaultAvatars.getAvatarsForRole(user.role).map((avatarUrl) {
                              final isSelected = selectedImageUrl == avatarUrl;
                              return GestureDetector(
                                onTap: () => setStateDialog(() => selectedImageUrl = avatarUrl),
                                child: Container(
                                  margin: const EdgeInsets.only(left: 12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: isSelected ? AppTheme.primaryGreen : Colors.transparent, width: 2),
                                  ),
                                  child: CircleAvatar(
                                    radius: 30,
                                    backgroundColor: AppTheme.darkCard,
                                    backgroundImage: NetworkImage(avatarUrl),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('حفظ التغييرات', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            if (nameCtrl.text.trim().isEmpty) {
                              Get.snackbar('تنبيه', 'الاسم مطلوب');
                              return;
                            }
                            try {
                              await FirebaseFirestore.instance.collection('users').doc(user.id).update({
                                'name': nameCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                                'wilaya': wilayaCtrl.text.trim(),
                                'address': addressCtrl.text.trim(),
                                'profileImage': selectedImageUrl,
                              });
                              await authController.refreshUser();
                              Get.back();
                              Get.snackbar('نجاح', 'تم تحديث البيانات بنجاح',
                                  backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
                                  colorText: AppTheme.successColor);
                            } catch (e) {
                              Get.snackbar('خطأ', 'فشل التحديث: $e',
                                  backgroundColor: AppTheme.errorColor, colorText: Colors.white);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Center(child: Text('إلغاء', style: TextStyle(color: Colors.grey))),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
