import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/utils/default_avatars.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_model.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/routes/app_routes.dart';

import 'package:cached_network_image/cached_network_image.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthController authController = Get.find<AuthController>();

  UserModel? get displayUser {
    if (Get.arguments is UserModel) return Get.arguments as UserModel;
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
    final user = displayUser;
    final bool ownProfile = isOwnProfile;

    if (user == null && Get.arguments is String) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(Get.arguments as String).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(body: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)));
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
  }

  Widget _buildScaffold(UserModel? user, bool ownProfile) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(ownProfile ? "الملف الشخصي" : "ملف المستخدم", style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        actions: [
          if (ownProfile)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75), shape: BoxShape.circle),
                child: Icon(Icons.edit_note_rounded, color: Theme.of(context).colorScheme.primary),
              ),
              onPressed: () {
                if (user != null) {
                  _showEditProfileDialog();
                } else {
                  Get.snackbar('تنبيه', 'جاري تحميل بيانات المستخدم...');
                }
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: user == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 60),
                  const SizedBox(height: 16),
                  Text("جاري جلب بيانات المستخدم...", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  Obx(() => authController.isLoading.value
                    ? const CircularProgressIndicator()
                    : TextButton.icon(
                      onPressed: () => authController.refreshUser(),
                      icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
                      label: Text('تحديث البيانات', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    ))
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
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          FadeInDown(
            child: Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75), width: 2),
                    ),
                    child: Hero(
                      tag: 'profile_${user.id}',
                      child: CircleAvatar(
                        radius: 55,
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        backgroundImage: user.profileImage != null && user.profileImage!.isNotEmpty
                            ? CachedNetworkImageProvider(user.profileImage!)
                            : null,
                        child: (user.profileImage == null || user.profileImage!.isEmpty)
                            ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                style: GoogleFonts.tajawal(fontSize: 35, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary))
                            : null,
                      ),
                    ),
                  ),
                  if (ownProfile)
                    GestureDetector(
                      onTap: _showEditProfileDialog,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.75), blurRadius: 8)],
                        ),
                        child: Icon(Icons.camera_alt_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 16),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeInDown(
            delay: const Duration(milliseconds: 100),
            child: Column(
              children: [
                Text(user.name, style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(user.role.displayName, style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          
          if (user.lastDonatedAt != null) 
            FadeInUp(child: _buildRestPeriodCard(user)),
          
          if (canChat) ...[
            const SizedBox(height: 20),
            FadeInUp(
              child: SizedBox(
                width: double.infinity,
                child: AppTheme.gradientButton(
                  onPressed: () => Get.toNamed(AppRoutes.chatPrivate, arguments: {'targetUserId': user.id, 'targetUserName': user.name}),
                  icon: Icons.chat_bubble_outline_rounded,
                  text: user.role == UserRole.worker ? "مراسلة المتطوع" : "تواصل مع الإدارة",
                ),
              ),
            ),
          ],

          if (isWorker) ...[
            const SizedBox(height: 20),
            FadeInUp(child: _buildWorkerStatsCard(user)),
          ],
          
          const SizedBox(height: 30),
          FadeInUp(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(25),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('بيانات الاتصال'),
                  _buildDetailTile(Icons.phone_android_rounded, "رقم الهاتف", user.phone, Colors.blue),
                  _buildDetailTile(Icons.alternate_email_rounded, "البريد الإلكتروني", user.email, Colors.red),
                  
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                  _buildSectionLabel('العنوان والموقع'),
                  _buildDetailTile(Icons.map_outlined, "المنطقة", "${user.wilaya} - ${user.commune}", Colors.orange),
                  _buildDetailTile(Icons.home_work_outlined, "العنوان", user.address, Colors.purple),
                  
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                  _buildSectionLabel('بيانات التبرع بالدم'),
                  _buildDetailTile(Icons.bloodtype_rounded, "فصيلة الدم", user.bloodType ?? "غير محدد", Colors.redAccent),
                  _buildDetailTile(Icons.event_available_rounded, "تاريخ آخر تبرع", 
                    user.lastDonatedAt != null ? intl.DateFormat('yyyy/MM/dd').format(user.lastDonatedAt!) : "لم يسبق التبرع", 
                    Colors.green),
                  _buildDetailTile(Icons.volunteer_activism_rounded, "الجاهزية الحالية", 
                    user.isDonorAvailable ? "متاح حالياً" : "غير متاح مؤقتاً", 
                    user.isDonorAvailable ? Colors.green : Colors.orange),
                ],
              ),
            ),
          ),

          if (ownProfile) ...[
            const SizedBox(height: 20),
            FadeInUp(child: _buildThemeSelector(context)),
            const SizedBox(height: 24),
            FadeInUp(
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _showLogoutConfirmation,
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  label: Text("تسجيل الخروج من الحساب", style: GoogleFonts.tajawal(color: Colors.redAccent, fontWeight: FontWeight.w800)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.redAccent, width: 0.5)),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 4),
      child: Text(text, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.tajawal(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                Text(value.isEmpty ? 'غير متوفر' : value, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestPeriodCard(UserModel user) {
    final now = DateTime.now();
    final difference = now.difference(user.lastDonatedAt!);
    final daysSince = difference.inDays;
    
    if (daysSince >= 90) return const SizedBox.shrink(); // Blood donation usually needs 3 months break
    
    final daysRemaining = 90 - daysSince;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
            child: const Icon(Icons.hourglass_bottom_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('فترة الراحة الطبية (تبرع بالدم)', style: GoogleFonts.tajawal(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 13)),
                const SizedBox(height: 2),
                Text('باقي $daysRemaining يوم لتتمكن من التبرع مرة أخرى بسلامة.', 
                  style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Icon(ThemeService().themeIcon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("مظهر التطبيق", style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w900)),
                Text(ThemeService().themeModeName, style: GoogleFonts.tajawal(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          PopupMenuButton<ThemeMode>(
            icon: const Icon(Icons.settings_display_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            onSelected: (mode) => ThemeService().saveThemeMode(mode),
            itemBuilder: (context) => [
              const PopupMenuItem(value: ThemeMode.system, child: Text("تلقائي النظام")),
              const PopupMenuItem(value: ThemeMode.light, child: Text("الوضع الفاتح")),
              const PopupMenuItem(value: ThemeMode.dark, child: Text("الوضع الداكن")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerStatsCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withValues(alpha: 0.9)]),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('إحصائيات المتطوع', style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(user.rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _workerStatItem('المهام', '${user.completedTasks}', Icons.task_alt),
              _workerStatItem('الرحلات', '${user.totalTrips}', Icons.local_shipping_outlined),
              _workerStatItem('الحالة', user.isAvailable ? 'متاح' : 'مشغول', Icons.info_outline),
            ],
          ),
        ],
      ),
    );
  }

  Widget _workerStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showEditProfileDialog() {
    final user = displayUser;
    if (user == null) return;

    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);
    final addressCtrl = TextEditingController(text: user.address);
    
    String? selectedWilaya = AppConstants.algeriaWilayas.contains(user.wilaya) ? user.wilaya : null;
    String? selectedCommune = user.commune;
    String? selectedBloodType = user.bloodType;
    bool receiveAlertsInDialog = user.receiveBloodAlerts;
    DateTime? lastDonatedAtInDialog = user.lastDonatedAt;
    bool isDonorAvailableInDialog = user.isDonorAvailable;
    String? selectedImageUrl = user.profileImage;
    bool isUploadingInDialog = false;

    Get.bottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      StatefulBuilder(builder: (context, setStateDialog) {
        return Container(
          height: Get.height * 0.9,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.symmetric(vertical: 15), width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تحديث بياناتي', style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w900)),
                      Text('أبقِ معلوماتك محدثة لسهولة التواصل', style: GoogleFonts.tajawal(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 30),
                      
                      _buildEditLabel('الصورة الشخصية'),
                      _buildAvatarPicker(user, selectedImageUrl, isUploadingInDialog, setStateDialog),
                      
                      const SizedBox(height: 24),
                      _buildEditLabel('المعلومات الأساسية'),
                      _buildEditField(nameCtrl, 'الاسم الكامل', Icons.person_outline_rounded),
                      const SizedBox(height: 12),
                      _buildEditField(phoneCtrl, 'رقم الهاتف', Icons.phone_android_rounded, keyboardType: TextInputType.phone),
                      
                      const SizedBox(height: 24),
                      _buildEditLabel('الموقع'),
                      _buildWilayaDropdown(selectedWilaya, (v) => setStateDialog(() { selectedWilaya = v; selectedCommune = null; })),
                      const SizedBox(height: 12),
                      if (selectedWilaya != null)
                        _buildCommuneDropdown(selectedWilaya!, selectedCommune, (v) => setStateDialog(() => selectedCommune = v)),
                      const SizedBox(height: 12),
                      _buildEditField(addressCtrl, 'العنوان بالتفصيل', Icons.home_work_outlined, maxLines: 2),
                      
                      const SizedBox(height: 24),
                      _buildEditLabel('بيانات التبرع بالدم (اختياري)'),
                      _buildBloodDropdown(selectedBloodType, (v) => setStateDialog(() => selectedBloodType = v)),
                      const SizedBox(height: 12),
                      _buildDonationDatePicker(lastDonatedAtInDialog, (date) => setStateDialog(() => lastDonatedAtInDialog = date)),
                      
                      const SizedBox(height: 12),
                      _buildSwitchTile('تنبيهات التبرع بالدم', 'استقبال إشعارات الحالات المستعجلة', receiveAlertsInDialog, (v) => setStateDialog(() => receiveAlertsInDialog = v)),
                      _buildSwitchTile('أنا متاح للتبرع', 'تعطيله في حال المرض أو السفر', isDonorAvailableInDialog, (v) => setStateDialog(() => isDonorAvailableInDialog = v)),

                      const SizedBox(height: 40),
                      AppTheme.gradientButton(
                        text: 'حفظ التعديلات',
                        icon: Icons.check_circle_rounded,
                        onPressed: () async {
                          if (nameCtrl.text.isEmpty) {
                             Get.snackbar('تنبيه', 'الاسم مطلوب');
                             return;
                          }
                          try {
                            await FirebaseFirestore.instance.collection('users').doc(user.id).update({
                              'name': nameCtrl.text.trim(),
                              'phone': phoneCtrl.text.trim(),
                              'wilaya': selectedWilaya,
                              'commune': selectedCommune,
                              'address': addressCtrl.text.trim(),
                              'bloodType': selectedBloodType,
                              'receiveBloodAlerts': receiveAlertsInDialog,
                              'lastDonatedAt': lastDonatedAtInDialog != null ? Timestamp.fromDate(lastDonatedAtInDialog!) : null,
                              'isDonorAvailable': isDonorAvailableInDialog,
                              'profileImage': selectedImageUrl,
                            });
                            await authController.refreshUser();
                            Get.back();
                            Get.snackbar('تم التحديث', 'تم حفظ بياناتك بنجاح ✨');
                          } catch (e) {
                            Get.snackbar('خطأ', 'حدث مشكلة أثناء الحفظ');
                          }
                        },
                      ),
                      const SizedBox(height: 50),
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

  Widget _buildEditLabel(String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)));
  }

  Widget _buildEditField(TextEditingController ctrl, String hint, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(controller: ctrl, keyboardType: keyboardType, maxLines: maxLines, decoration: AppTheme.inputDecoration(hint, icon));
  }

  Widget _buildWilayaDropdown(String? val, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: val,
      decoration: AppTheme.inputDecoration('الولاية', Icons.map_outlined),
      dropdownColor: Theme.of(context).cardColor,
      items: AppConstants.algeriaWilayas.map((w) => DropdownMenuItem(value: w, child: Text(w, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildCommuneDropdown(String wilaya, String? val, Function(String?) onChanged) {
    final communes = AppConstants.getCommunesForWilaya(wilaya);
    return DropdownButtonFormField<String>(
      initialValue: communes.contains(val) ? val : null,
      decoration: AppTheme.inputDecoration('البلدية', Icons.location_city_rounded),
      dropdownColor: Theme.of(context).cardColor,
      items: communes.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildBloodDropdown(String? val, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: val,
      decoration: AppTheme.inputDecoration('فصيلة الدم', Icons.bloodtype_outlined),
      dropdownColor: Theme.of(context).cardColor,
      items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((bt) => DropdownMenuItem(value: bt, child: Text(bt))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDonationDatePicker(DateTime? current, Function(DateTime) onPicked) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(context: context, initialDate: current ?? DateTime.now(), firstDate: DateTime(2022), lastDate: DateTime.now());
        if (date != null) onPicked(date);
      },
      child: InputDecorator(
        decoration: AppTheme.inputDecoration('تاريخ آخر تبرع', Icons.calendar_month_rounded),
        child: Text(current != null ? intl.DateFormat('yyyy/MM/dd').format(current) : 'لم يحدد بعد', style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool val, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: GoogleFonts.tajawal(fontSize: 11)),
      value: val,
      activeThumbColor: Theme.of(context).colorScheme.primary,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildAvatarPicker(UserModel user, String? selectedUrl, bool isUploading, Function setStateDialog) {
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          GestureDetector(
            onTap: () async {
              final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
              if (picked == null) return;
              setStateDialog(() => isUploading = true);
              try {
                final ref = FirebaseStorage.instance.ref('profiles/${user.id}.jpg');
                await ref.putFile(File(picked.path));
                final url = await ref.getDownloadURL();
                setStateDialog(() { selectedUrl = url; isUploading = false; });
              } catch (e) { setStateDialog(() => isUploading = false); }
            },
            child: Container(
              width: 65,
              margin: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75), shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)),
              child: isUploading ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.add_a_photo_rounded, color: Theme.of(context).colorScheme.primary),
            ),
          ),
          ...DefaultAvatars.getAvatarsForRole(user.role).map((url) {
            final isSelected = selectedUrl == url;
            return GestureDetector(
              onTap: () => setStateDialog(() => selectedUrl = url),
              child: Container(
                margin: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3)),
                child: CircleAvatar(radius: 30, backgroundImage: CachedNetworkImageProvider(url)),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    Get.dialog(
      AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تسجيل الخروج', textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontWeight: FontWeight.w900)),
        content: Text('هل أنت متأكد من رغبتك في تسجيل الخروج من تطبيق ناس الخير؟', textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 13)),
        actions: [
          Row(
            children: [
              Expanded(child: TextButton(onPressed: () => Get.back(), child: Text('إلغاء', style: GoogleFonts.tajawal(color: Colors.grey)))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () { Get.back(); authController.logout(); },
                child: Text('خروج', style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold)),
              )),
            ],
          ),
        ],
      ),
    );
  }
}

