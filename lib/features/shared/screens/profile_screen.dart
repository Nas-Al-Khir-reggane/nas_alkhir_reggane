import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;
import 'package:google_fonts/google_fonts.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/utils/default_avatars.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_model.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/routes/app_routes.dart';
import '../widgets/user_avatar.dart';
import '../../../data/services/cloudinary_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../widgets/role_switcher_widget.dart';
import '../widgets/membership_card_dialog.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/utils/share_helper.dart';
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
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
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
    final currentRole = authController.currentUser.value?.role;
    final isAdminOrSuper = currentRole == UserRole.admin || currentRole == UserRole.superAdmin;
    
    final canChat = !ownProfile && (
      user.role == UserRole.admin || 
      user.role == UserRole.superAdmin || 
      isAdminOrSuper // Admins can chat with anyone
    );
    final canViewSensitiveInfo = ownProfile || currentRole == UserRole.superAdmin;


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
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), width: 2),
                    ),
                    child: Hero(
                      tag: 'profile_${user.id}',
                      child: UserAvatar(
                        user: user,
                        size: 110,
                        showBadge: false,
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
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(user.role.displayName, style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                    if (user.memberId != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1B5E20).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.pin_rounded, color: Color(0xFF1B5E20), size: 12),
                            const SizedBox(width: 4),
                            Text(
                              user.memberId!,
                              style: GoogleFonts.tajawal(color: const Color(0xFF1B5E20), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    _buildVerificationBadge(user),
                    if (ownProfile) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Get.dialog(MembershipCardDialog(user: user)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFFFD700)]),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.3), blurRadius: 4)],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.badge_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text("بطاقة الانخراط", style: GoogleFonts.tajawal(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          if (ownProfile) 
            FadeInUp(
              delay: const Duration(milliseconds: 150),
              child: const RoleSwitcherWidget()
            ),
          if (user.lastDonatedAt != null) 
            FadeInUp(child: _buildRestPeriodCard(user)),

          // 🩸 وسام المنقذ: بطاقة تحفيزية لغير المتبرعين
          if (user.role != UserRole.donor && ownProfile) ...[
            const SizedBox(height: 16),
            FadeInUp(child: _buildRescueBadgeCard(user)),
          ],
          
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

          if (ownProfile) ...[
            const SizedBox(height: 20),
            FadeInUp(child: _buildVerificationCard(user)),
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
                  if (canViewSensitiveInfo)
                    _buildDetailTile(Icons.phone_android_rounded, "رقم الهاتف", user.phone, Colors.blue),
                  _buildDetailTile(Icons.alternate_email_rounded, "البريد الإلكتروني", user.email, Colors.red),
                  
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                  _buildSectionLabel('العنوان والموقع'),
                  _buildDetailTile(Icons.map_outlined, "المنطقة", "${user.wilaya} - ${user.commune}", Colors.orange),
                  if (canViewSensitiveInfo)
                    _buildDetailTile(Icons.home_work_outlined, "العنوان", user.address, Colors.purple),
                  
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                  _buildMedicalStatusCard(user),
                ],
              ),
            ),
          ),

          if (ownProfile) ...[
            const SizedBox(height: 20),
            FadeInUp(child: _buildThemeSelector(context)),
            const SizedBox(height: 12),
            FadeInUp(child: _buildQuickLinksCard(context)),
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
      padding: const EdgeInsetsDirectional.only(bottom: 12, end: 4),
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
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
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

  /// 🩸 بطاقة الحالة الطبية الموحدة لجميع المستخدمين
  Widget _buildMedicalStatusCard(UserModel user) {
    return FadeInUp(
      delay: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.medical_services_rounded, color: Colors.redAccent, size: 24),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الحالة الطبية والجاهزية', 
                        style: GoogleFonts.tajawal(fontWeight: FontWeight.w900, fontSize: 16)),
                      Text('بيانات التبرع بالدم الخاصة بك', 
                        style: GoogleFonts.tajawal(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                if (user.bloodType != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(user.bloodType!, 
                      style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMedicalMiniStat(
                  Icons.event_available_rounded, 
                  'آخر تبرع', 
                  user.lastDonatedAt != null ? intl.DateFormat('yyyy/MM/dd').format(user.lastDonatedAt!) : 'لم يسبق',
                  Colors.blue,
                ),
                _buildMedicalMiniStat(
                  Icons.volunteer_activism_rounded, 
                  'الجاهزية', 
                  user.isDonorAvailable ? 'متاح' : 'استراحة',
                  user.isDonorAvailable ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Get.toNamed(AppRoutes.bloodDonorProfile),
                icon: const Icon(Icons.analytics_rounded, size: 18),
                label: Text('عرض السجل الطبي الكامل', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalMiniStat(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.tajawal(fontSize: 10, color: AppTheme.textSecondary)),
            Text(value, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildRestPeriodCard(UserModel user) {
    final now = DateTime.now();
    final difference = now.difference(user.lastDonatedAt!);
    final daysSince = difference.inDays;
    
    // منطق متوافق مع UserModel: 90 يوم للنساء، 60 يوم للرجال
    final requiredDays = user.gender == 'أنثى' ? 90 : 60;
    
    if (daysSince >= requiredDays) return const SizedBox.shrink(); 
    
    final daysRemaining = requiredDays - daysSince;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.15)),
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

  /// 🩸 بطاقة وسام المنقذ - تظهر لغير المتبرعين لتحفيزهم
  Widget _buildRescueBadgeCard(UserModel user) {
    final int count = user.bloodDonationsCount;
    String rank;
    String emoji;
    Color rankColor;

    if (count >= 15) {
      rank = 'منقذ بلاتيني';
      emoji = '💎';
      rankColor = const Color(0xFF00BCD4);
    } else if (count >= 10) {
      rank = 'منقذ ذهبي';
      emoji = '🥇';
      rankColor = const Color(0xFFFFC107);
    } else if (count >= 5) {
      rank = 'منقذ فضي';
      emoji = '🥈';
      rankColor = const Color(0xFF9E9E9E);
    } else if (count >= 1) {
      rank = 'منقذ برونزي';
      emoji = '🥉';
      rankColor = const Color(0xFFFF9800);
    } else {
      rank = 'مستعد للإنقاذ';
      emoji = '🌱';
      rankColor = Theme.of(context).colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            rankColor.withValues(alpha: 0.15),
            Theme.of(context).cardColor,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: rankColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: rankColor.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'وسام المنقذ',
                  style: GoogleFonts.tajawal(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$rank $emoji • $count ${count == 1 ? "مرة" : "مرات"}',
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: rankColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count == 0
                      ? 'ساهم بالتبرع بالدم وانضم لقافلة المنقذين'
                      : 'جزاك الله خيراً على مساهمتك في إنقاذ الأرواح',
                  style: GoogleFonts.tajawal(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.water_drop_rounded, color: rankColor, size: 24),
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
        boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), blurRadius: 15, offset: const Offset(0, 8))],
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
                    const Icon(Icons.star_rounded, color: AppTheme.goldAccent, size: 16),
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
    String? selectedImageUrl = user.profileImage;
    String? currentSeed = user.avatarSeed ?? user.id;
    String currentType = user.avatarType ?? 'avataaars';

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
                      
                      _buildEditLabel('اختر صورتك الرمزية'),
                      _buildIdentityStudio(
                        user: user,
                        currentSeed: currentSeed,
                        currentType: currentType,
                        selectedUrl: selectedImageUrl,
                        onUpdate: (seed, type, url) {
                          setStateDialog(() {
                            currentSeed = seed;
                            currentType = type;
                            selectedImageUrl = url;
                          });
                        },
                      ),
                      
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
                              'profileImage': selectedImageUrl,
                              'avatarSeed': currentSeed,
                              'avatarType': currentType,
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

  Widget _buildIdentityStudio({
    required UserModel user,
    required String? currentSeed,
    required String currentType,
    required String? selectedUrl,
    required Function(String?, String, String?) onUpdate,
  }) {
    final styles = [
      {'id': 'avataaars', 'name': 'إنساني'},
      {'id': 'micah', 'name': 'فني'},
      {'id': 'bottts', 'name': 'آلي'},
      {'id': 'initials', 'name': 'رسمي'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // 1. المعاينة الحالية
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              UserAvatar(
                key: ValueKey('$currentSeed-$currentType-$selectedUrl'),
                user: user.copyWith(
                  avatarSeed: currentSeed,
                  avatarType: currentType,
                  profileImage: selectedUrl,
                ),
                size: 90,
                showBadge: true,
              ),
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      final newSeed = DateTime.now().millisecondsSinceEpoch.toString();
                      onUpdate(newSeed, currentType, null); // Shuffle clearing previous manual selection
                    },
                    icon: const Icon(Icons.shuffle_rounded, size: 20),
                    label: const Text("تغيير الشكل", style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("اضغط للحصول على شكل عشوائي", 
                    style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: 'Tajawal')),
                ],
              ),
            ],
          ),
          
          const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(height: 1)),
          
          // 2. اختيار النمط (بسيطة)
          Align(
            alignment: Alignment.centerRight,
            child: Text("نوع المظهر:", style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: styles.map((style) {
                final isSelected = currentType == style['id'] && selectedUrl == null;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(style['name']!, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) onUpdate(currentSeed, style['id']!, null);
                    },
                    selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 15),
          
          // 3. شخصيات جاهزة (Originals)
          Align(
            alignment: Alignment.centerRight,
            child: Text("شخصيات جاهزة:", style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: DefaultAvatars.getAvatarsForRole(user.role, user.gender).map((url) {
                final isSelected = selectedUrl == url;
                return GestureDetector(
                  onTap: () => onUpdate(currentSeed, currentType, url),
                  child: Container(
                    margin: const EdgeInsetsDirectional.only(end: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, 
                      border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2.5)
                    ),
                    child: CircleAvatar(
                      radius: 26, 
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      backgroundImage: CachedNetworkImageProvider(url)
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBadge(UserModel user) {
    bool isTrueVerified = user.isVerified;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isTrueVerified ? Colors.blue : Colors.grey).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (isTrueVerified ? Colors.blue : Colors.grey).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTrueVerified ? Icons.verified_rounded : Icons.info_outline_rounded,
            color: isTrueVerified ? Colors.blue : Colors.grey,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            isTrueVerified ? "موثق" : "غير موثق",
            style: GoogleFonts.tajawal(
              color: isTrueVerified ? Colors.blue : Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(UserModel user) {
    if (user.isVerified) return const SizedBox.shrink();

    final hasPendingId = user.nationalIdUrl != null && user.nationalIdUrl!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.privacy_tip_rounded, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('توثيق الهوية الرسمية', style: GoogleFonts.tajawal(fontWeight: FontWeight.w900, fontSize: 15)),
                    Text('مطلوب للحصول على رقم العضوية الموحد (ID) والمشاركة الرسمية.', 
                       style: GoogleFonts.tajawal(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (hasPendingId)
             Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('تم رفع البطاقة. بانتظار مراجعة المنسق العام لتوثيق الحساب.', style: GoogleFonts.tajawal(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold))),
                ],
              ),
            )
          else
            Column(
              children: [
                Text('⚠️ البطاقة الوطنية ضرورية لتوثيق انخراطك في الجمعية. يتم فحصها من قبل الإدارة فقط.', 
                  style: GoogleFonts.tajawal(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                AppTheme.gradientButton(
                  text: 'رفع بطاقة التعريف الوطنية',
                  icon: Icons.upload_file_rounded,
                  onPressed: _pickAndUploadNationalId,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadNationalId() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image == null) return;

      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

      final url = await CloudinaryService.uploadMedia(File(image.path));
      
      if (url != null) {
        await FirebaseFirestore.instance.collection('users').doc(authController.currentUser.value?.id).update({
          'nationalIdUrl': url,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        await authController.refreshUser();
        if (Get.isDialogOpen ?? false) Get.back();
        Get.snackbar('تم الرفع بنجاح', 'سيتم مراجعة هويتك من قبل المنسق العام قريباً ✨', 
          backgroundColor: Colors.green.withValues(alpha: 0.15));
      } else {
        if (Get.isDialogOpen ?? false) Get.back();
        Get.snackbar('خطأ', 'فشل رفع الصورة');
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar('خطأ', 'حدث خطأ أثناء عملية الرفع: $e');
    }
  }

  Widget _buildQuickLinksCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildLinkTile(
            context,
            icon: Icons.privacy_tip_rounded,
            title: 'سياسة الخصوصية',
            color: Colors.green,
            onTap: () => Get.toNamed(AppRoutes.privacyPolicy),
          ),
          Divider(height: 1, indent: 60, color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
          _buildLinkTile(
            context,
            icon: Icons.share_rounded,
            title: 'شارك التطبيق',
            color: Colors.orange,
            onTap: () => ShareHelper.shareApp(),
          ),
          Divider(height: 1, indent: 60, color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
          _buildLinkTile(
            context,
            icon: Icons.info_rounded,
            title: 'حول التطبيق',
            color: Colors.blue,
            onTap: () => Get.toNamed(AppRoutes.about),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTile(BuildContext context, {required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: GoogleFonts.tajawal(fontWeight: FontWeight.w600, fontSize: 13)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      onTap: onTap,
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

