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
import '../../../data/services/image_compression_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../widgets/role_switcher_widget.dart';
import '../widgets/membership_card_dialog.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/utils/share_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/services/abuse_report_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthController authController = Get.find<AuthController>();

  UserModel? get displayUser {
    if (Get.arguments is UserModel) return Get.arguments as UserModel;
    if (Get.arguments is String) return null;
    return authController.currentUser.value;
  }

  bool get isOwnProfile {
    final args = Get.arguments;
    if (args is String) return args == authController.currentUser.value?.id;
    if (args is UserModel) return args.id == authController.currentUser.value?.id;
    return true;
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
    if (user == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 60),
              const SizedBox(height: 16),
              Text("جاري جلب بيانات المستخدم...", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: 'Tajawal')),
              const SizedBox(height: 24),
              Obx(() => authController.isLoading.value
                ? const CircularProgressIndicator()
                : TextButton.icon(
                    onPressed: () => authController.refreshUser(),
                    icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
                    label: Text('تحديث البيانات', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Tajawal')),
                  ))
            ],
          ),
        ),
      );
    }
    return _buildProfilePage(user, ownProfile);
  }

  // =====================================================================
  // الصفحة الرئيسية الجديدة بـ CustomScrollView + SliverAppBar
  // =====================================================================
  Widget _buildProfilePage(UserModel user, bool ownProfile) {
    final isWorker = user.role == UserRole.worker;
    final currentRole = authController.currentUser.value?.role;
    final isAdminOrSuper = currentRole == UserRole.admin || currentRole == UserRole.superAdmin;
    final canChat = !ownProfile && (user.role == UserRole.admin || user.role == UserRole.superAdmin || isAdminOrSuper);
    final canViewSensitiveInfo = ownProfile || currentRole == UserRole.superAdmin;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── رأس الصفحة الفاخر ─────────────────────────────────────
          _buildSliverHeader(user, ownProfile),

          // ─── المحتوى ───────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // شريط التحويل بين الأدوار
                if (ownProfile) ...[
                  FadeInUp(delay: const Duration(milliseconds: 50), child: const RoleSwitcherWidget()),
                  const SizedBox(height: 16),
                ],

                // ─── تذكير دوري برفع بطاقة الهوية ───────────────────
                if (ownProfile && !user.isVerified && (user.nationalIdUrl == null || user.nationalIdUrl!.isEmpty)) ...[
                  FadeInUp(
                    delay: const Duration(milliseconds: 60),
                    child: _buildIdVerificationReminderBanner(),
                  ),
                  const SizedBox(height: 14),
                ],

                // ─── تلميح للمتطوع بتغيير الصفة ──────────────────────
                if (ownProfile && user.role == UserRole.worker) ...[
                  FadeInUp(
                    delay: const Duration(milliseconds: 70),
                    child: _buildWorkerRoleHintBanner(),
                  ),
                  const SizedBox(height: 14),
                ],

                // تنبيه فترة الراحة
                if (user.lastDonatedAt != null) ...[
                  FadeInUp(delay: const Duration(milliseconds: 80), child: _buildRestPeriodBanner(user)),
                ],

                // ─── القسم الأول: بطاقة الهوية والاتصال ──────────────
                FadeInUp(
                  delay: const Duration(milliseconds: 100),
                  child: _buildSectionCard(
                    icon: Icons.contact_page_outlined,
                    title: 'الهوية والتواصل',
                    children: [
                      if (canViewSensitiveInfo)
                        _buildInfoRow(Icons.phone_android_rounded, 'الهاتف', user.phone, Colors.blue),
                      _buildInfoRow(Icons.alternate_email_rounded, 'البريد', user.email, Colors.red),
                      _buildInfoRow(Icons.map_outlined, 'المنطقة', '${user.wilaya} - ${user.commune}', Colors.orange),
                      if (canViewSensitiveInfo && user.address.isNotEmpty)
                        _buildInfoRow(Icons.home_work_outlined, 'العنوان', user.address, Colors.purple, isLast: true),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ─── القسم الثاني: الحالة الطبية ─────────────────────
                FadeInUp(
                  delay: const Duration(milliseconds: 150),
                  child: _buildMedicalCard(user),
                ),
                const SizedBox(height: 14),

                // ─── القسم الثالث: إحصائيات المتطوع (للعمال فقط) ─────
                if (isWorker) ...[
                  FadeInUp(
                    delay: const Duration(milliseconds: 180),
                    child: _buildWorkerStatsCard(user),
                  ),
                  const SizedBox(height: 14),
                ],

                // ─── وسام الإنقاذ ─────────────────────────────────────
                if (ownProfile) ...[
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: _buildRescueBadgeCard(user),
                  ),
                  const SizedBox(height: 14),
                ],

                // ─── زر التواصل ───────────────────────────────────────
                if (canChat) ...[
                  FadeInUp(
                    delay: const Duration(milliseconds: 220),
                    child: SizedBox(
                      width: double.infinity,
                      child: AppTheme.gradientButton(
                        onPressed: () => Get.toNamed(AppRoutes.chatPrivate, arguments: {
                          'targetUserId': user.id,
                          'targetUserName': user.name,
                        }),
                        icon: Icons.chat_bubble_outline_rounded,
                        text: user.role == UserRole.worker ? 'مراسلة المتطوع' : 'تواصل مع الإدارة',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ─── توثيق الهوية ─────────────────────────────────────
                if (ownProfile) ...[
                  FadeInUp(
                    delay: const Duration(milliseconds: 240),
                    child: _buildVerificationCard(user),
                  ),
                  const SizedBox(height: 14),
                ],

                // ─── الإعدادات (للملف الشخصي فقط) ───────────────────
                if (ownProfile) ...[
                  FadeInUp(
                    delay: const Duration(milliseconds: 260),
                    child: _buildSettingsCard(context),
                  ),
                  const SizedBox(height: 14),

                  // زر تسجيل الخروج
                  FadeInUp(
                    delay: const Duration(milliseconds: 280),
                    child: _buildLogoutButton(),
                  ),
                  const SizedBox(height: 14),

                  // زر حذف الحساب
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: _buildDeleteAccountButton(),
                  ),
                ],

                // ─── الإبلاغ عن مستخدم ─────────────────────────────────
                if (!ownProfile) ...[
                  FadeInUp(
                    delay: const Duration(milliseconds: 320),
                    child: _buildReportUserButton(user),
                  ),
                  const SizedBox(height: 14),
                ],

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // SliverAppBar - رأس الصفحة الفاخر
  // =====================================================================
  Widget _buildSliverHeader(UserModel user, bool ownProfile) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Get.back(),
      ),
      actions: [
        if (ownProfile)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
            ),
            onPressed: () => _showEditProfileDialog(),
          ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // خلفية التدرج
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, AppTheme.primaryGreenDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // دوائر زخرفية
            Positioned(top: -30, right: -30, child: _buildDecorCircle(140, 0.06)),
            Positioned(bottom: -20, left: -40, child: _buildDecorCircle(160, 0.05)),
            // المحتوى
            Positioned.fill(
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 30),
                    // صورة المستخدم
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          child: Hero(
                            tag: 'profile_${user.id}',
                            child: UserAvatar(user: user, size: 96, showBadge: false),
                          ),
                        ),
                        if (ownProfile)
                          GestureDetector(
                            onTap: _showEditProfileDialog,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppTheme.goldAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // الاسم
                    Text(
                      user.name,
                      style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // شريط الشارات
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildHeaderChip(user.role.displayName, Icons.badge_outlined),
                        if (user.isVerified) _buildHeaderChip('موثق', Icons.verified_rounded, color: Colors.lightBlue),
                        if (user.bloodType != null) _buildHeaderChip(user.bloodType!, Icons.water_drop_rounded, color: Colors.redAccent),
                        if (user.memberId != null) _buildHeaderChip(user.memberId!, Icons.pin_rounded, color: AppTheme.goldAccent),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // بطاقة الانخراط
                    if (isOwnProfile)
                      GestureDetector(
                        onTap: () => Get.dialog(MembershipCardDialog(user: user)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFA67C00)]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.credit_card_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text('بطاقة الانخراط', style: GoogleFonts.tajawal(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecorCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }

  Widget _buildHeaderChip(String label, IconData icon, {Color color = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.tajawal(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // =====================================================================
  // بطاقة قسم عامة (Section Card)
  // =====================================================================
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس القسم
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: Theme.of(context).dividerColor, height: 1),
          // المحتوى
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  // ─── صف المعلومة ──────────────────────────────────────────────────────
  Widget _buildInfoRow(IconData icon, String label, String value, Color color, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GoogleFonts.tajawal(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    Text(
                      value.isEmpty ? 'غير متوفر' : value,
                      style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.5), height: 1),
      ],
    );
  }

  // =====================================================================
  // بطاقة الحالة الطبية المبسّطة
  // =====================================================================
  Widget _buildMedicalCard(UserModel user) {
    return _buildSectionCard(
      icon: Icons.medical_services_outlined,
      title: 'الحالة الطبية',
      children: [
        Row(
          children: [
            Expanded(child: _buildMedStatTile(
              Icons.water_drop_rounded,
              'فصيلة الدم',
              user.bloodType ?? '—',
              Colors.redAccent,
            )),
            Container(width: 1, height: 60, color: Theme.of(context).dividerColor),
            Expanded(child: _buildMedStatTile(
              Icons.volunteer_activism_rounded,
              'الجاهزية',
              user.isDonorAvailable ? 'متاح' : 'استراحة',
              user.isDonorAvailable ? Colors.green : Colors.orange,
            )),
            Container(width: 1, height: 60, color: Theme.of(context).dividerColor),
            Expanded(child: _buildMedStatTile(
              Icons.event_available_rounded,
              'آخر تبرع',
              user.lastDonatedAt != null
                  ? intl.DateFormat('MM/yyyy').format(user.lastDonatedAt!)
                  : 'لم يسبق',
              Colors.blue,
            )),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Get.toNamed(AppRoutes.bloodDonorProfile),
            icon: const Icon(Icons.analytics_rounded, size: 16),
            label: Text('السجل الطبي الكامل', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedStatTile(IconData icon, String label, String value, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: GoogleFonts.tajawal(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  // =====================================================================
  // بطاقة إحصائيات المتطوع
  // =====================================================================
  Widget _buildWorkerStatsCard(UserModel user) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, AppTheme.primaryGreenDark]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.greenGlow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('إحصائيات التطوع', style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  const Icon(Icons.star_rounded, color: AppTheme.goldAccent, size: 16),
                  const SizedBox(width: 4),
                  Text(user.rating.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _workerStatItem(Icons.task_alt_rounded, '${user.completedTasks}', 'المهام'),
                Container(width: 1, color: Colors.white24),
                _workerStatItem(Icons.local_shipping_outlined, '${user.totalTrips}', 'الرحلات'),
                Container(width: 1, color: Colors.white24),
                _workerStatItem(
                  user.isAvailable ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                  user.isAvailable ? 'متاح' : 'مشغول',
                  'الحالة',
                  statusColor: user.isAvailable ? Colors.greenAccent : Colors.orangeAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _workerStatItem(IconData icon, String value, String label, {Color statusColor = Colors.white}) {
    return Column(children: [
      Icon(icon, color: statusColor, size: 26),
      const SizedBox(height: 6),
      Text(value, style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontFamily: 'Tajawal')),
    ]);
  }

  // =====================================================================
  // بطاقة وسام المنقذ
  // =====================================================================
  Widget _buildRescueBadgeCard(UserModel user) {
    final int count = user.bloodDonationsCount;
    String rank; String emoji; Color rankColor;

    if (count >= 15)      { rank = 'منقذ بلاتيني'; emoji = '💎'; rankColor = const Color(0xFF00BCD4); }
    else if (count >= 10) { rank = 'منقذ ذهبي';   emoji = '🥇'; rankColor = const Color(0xFFFFC107); }
    else if (count >= 5)  { rank = 'منقذ فضي';    emoji = '🥈'; rankColor = const Color(0xFF9E9E9E); }
    else if (count >= 1)  { rank = 'منقذ برونزي'; emoji = '🥉'; rankColor = const Color(0xFFFF9800); }
    else                  { rank = 'مستعد للإنقاذ'; emoji = '🌱'; rankColor = Theme.of(context).colorScheme.primary; }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: rankColor.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            color: rankColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('وسام المنقذ', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w800)),
          Text('$rank • $count تبرع', style: GoogleFonts.tajawal(fontSize: 12, color: rankColor, fontWeight: FontWeight.w700)),
          Text(
            count == 0 ? 'ساهم في إنقاذ الأرواح بالتبرع بدمك' : 'جزاك الله خيراً على مساهمتك',
            style: GoogleFonts.tajawal(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ])),
        Icon(Icons.water_drop_rounded, color: rankColor, size: 22),
      ]),
    );
  }

  // =====================================================================
  // بانر فترة الراحة
  // =====================================================================
  Widget _buildRestPeriodBanner(UserModel user) {
    final daysSince = DateTime.now().difference(user.lastDonatedAt!).inDays;
    final requiredDays = user.gender == 'أنثى' ? 90 : 60;
    if (daysSince >= requiredDays) return const SizedBox.shrink();
    final daysRemaining = requiredDays - daysSince;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.hourglass_bottom_rounded, color: Colors.orange, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(
          'فترة راحة تبرع الدم · يتبقى $daysRemaining يوم',
          style: GoogleFonts.tajawal(color: Colors.orange, fontWeight: FontWeight.w700, fontSize: 12),
        )),
      ]),
    );
  }

  // =====================================================================
  // بطاقة توثيق الهوية
  // =====================================================================
  Widget _buildVerificationCard(UserModel user) {
    if (user.isVerified) return const SizedBox.shrink();
    final hasPendingId = user.nationalIdUrl != null && user.nationalIdUrl!.isNotEmpty;

    return _buildSectionCard(
      icon: Icons.verified_user_outlined,
      title: 'توثيق الهوية الرسمية',
      children: [
        if (hasPendingId)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.timer_outlined, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'تم رفع البطاقة · بانتظار المراجعة',
                style: GoogleFonts.tajawal(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
              )),
            ]),
          )
        else ...[
          Text(
            'ارفع بطاقتك الوطنية للحصول على رقم العضوية والتوثيق الرسمي.',
            style: GoogleFonts.tajawal(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AppTheme.gradientButton(
              text: 'رفع بطاقة التعريف الوطنية',
              icon: Icons.upload_file_rounded,
              onPressed: _pickAndUploadNationalId,
            ),
          ),
        ],
      ],
    );
  }

  // =====================================================================
  // بطاقة الإعدادات الموحدة
  // =====================================================================
  Widget _buildSettingsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(children: [
        // مظهر التطبيق
        AppTheme.listItem(
          icon: ThemeService().themeIcon,
          title: 'مظهر التطبيق',
          subtitle: ThemeService().themeModeName,
          trailing: PopupMenuButton<ThemeMode>(
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            onSelected: (mode) => ThemeService().saveThemeMode(mode),
            itemBuilder: (_) => [
              const PopupMenuItem(value: ThemeMode.system, child: Text('تلقائي', style: TextStyle(fontFamily: 'Tajawal'))),
              const PopupMenuItem(value: ThemeMode.light, child: Text('فاتح', style: TextStyle(fontFamily: 'Tajawal'))),
              const PopupMenuItem(value: ThemeMode.dark, child: Text('داكن', style: TextStyle(fontFamily: 'Tajawal'))),
            ],
          ),
        ),
        AppTheme.listItem(
          icon: Icons.privacy_tip_rounded,
          iconColor: Colors.green,
          title: 'سياسة الخصوصية',
          onTap: () => Get.toNamed(AppRoutes.privacyPolicy),
        ),
        AppTheme.listItem(
          icon: Icons.share_rounded,
          iconColor: Colors.orange,
          title: 'شارك التطبيق',
          onTap: () => ShareHelper.shareApp(),
        ),
        AppTheme.listItem(
          icon: Icons.info_rounded,
          iconColor: Colors.blue,
          title: 'حول التطبيق',
          showDivider: false,
          onTap: () => Get.toNamed(AppRoutes.about),
        ),
      ]),
    );
  }

  // =====================================================================
  // زر تسجيل الخروج
  // =====================================================================
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showLogoutConfirmation,
        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
        label: Text('تسجيل الخروج', style: GoogleFonts.tajawal(color: Colors.redAccent, fontWeight: FontWeight.w800, fontSize: 14)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Colors.redAccent, width: 0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // =====================================================================
  // شاشة تعديل الملف الشخصي (Bottom Sheet)
  // =====================================================================
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
              Container(
                margin: const EdgeInsets.symmetric(vertical: 15),
                width: 50, height: 5,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
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
                          setStateDialog(() { currentSeed = seed; currentType = type; selectedImageUrl = url; });
                        },
                      ),

                      const SizedBox(height: 24),
                      _buildEditLabel('المعلومات الأساسية'),
                      _buildEditField(nameCtrl, 'الاسم الكامل', Icons.person_outline_rounded),
                      const SizedBox(height: 12),
                      _buildEditField(phoneCtrl, 'رقم الهاتف', Icons.phone_android_rounded, keyboardType: TextInputType.phone),

                      const SizedBox(height: 24),
                      _buildEditLabel('الموقع'),
                      LayoutBuilder(builder: (context, constraints) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _buildWilayaDropdown(
                                selectedWilaya,
                                (v) => setStateDialog(() { selectedWilaya = v; selectedCommune = null; }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 6,
                              child: selectedWilaya != null
                                ? _buildCommuneDropdown(
                                    selectedWilaya!,
                                    selectedCommune,
                                    (v) => setStateDialog(() => selectedCommune = v),
                                  )
                                : _buildDisabledCommuneField(),
                            ),
                          ],
                        );
                      }),
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
                      SizedBox(
                        width: double.infinity,
                        child: AppTheme.gradientButton(
                          text: 'حفظ التعديلات',
                          icon: Icons.check_circle_rounded,
                          onPressed: () async {
                            if (nameCtrl.text.isEmpty) { Get.snackbar('تنبيه', 'الاسم مطلوب'); return; }
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

  // =====================================================================
  // مساعدات Bottom Sheet
  // =====================================================================
  Widget _buildEditLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
    );
  }

  Widget _buildEditField(TextEditingController ctrl, String hint, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(controller: ctrl, keyboardType: keyboardType, maxLines: maxLines, decoration: AppTheme.inputDecoration(hint, icon));
  }

  Widget _buildWilayaDropdown(String? val, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: val,
      decoration: AppTheme.inputDecoration('الولاية', Icons.map_outlined).copyWith(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      dropdownColor: Theme.of(context).cardColor,
      items: AppConstants.algeriaWilayas.map((w) => DropdownMenuItem(
        value: w, 
        child: Text(w, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
      )).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildCommuneDropdown(String wilaya, String? val, Function(String?) onChanged) {
    final communes = AppConstants.getCommunesForWilaya(wilaya);
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: communes.contains(val) ? val : null,
      decoration: AppTheme.inputDecoration('البلدية', Icons.location_city_rounded).copyWith(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      dropdownColor: Theme.of(context).cardColor,
      items: communes.map((c) => DropdownMenuItem(
        value: c, 
        child: Text(c, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
      )).toList(),
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
        final date = await showDatePicker(
          context: context,
          initialDate: current ?? DateTime.now(),
          firstDate: DateTime(2022),
          lastDate: DateTime.now(),
        );
        if (date != null) onPicked(date);
      },
      child: InputDecorator(
        decoration: AppTheme.inputDecoration('تاريخ آخر تبرع', Icons.calendar_month_rounded),
        child: Text(
          current != null ? intl.DateFormat('yyyy/MM/dd').format(current) : 'لم يحدد بعد',
          style: const TextStyle(fontSize: 14),
        ),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            UserAvatar(
              key: ValueKey('$currentSeed-$currentType-$selectedUrl'),
              user: user.copyWith(avatarSeed: currentSeed, avatarType: currentType, profileImage: selectedUrl),
              size: 90,
              showBadge: true,
            ),
            Column(children: [
              ElevatedButton.icon(
                onPressed: () {
                  final newSeed = DateTime.now().millisecondsSinceEpoch.toString();
                  onUpdate(newSeed, currentType, null);
                },
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: const Text('تغيير الشكل', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 6),
              Text('للحصول على شكل عشوائي', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: 'Tajawal')),
            ]),
          ],
        ),
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
        Align(
          alignment: Alignment.centerRight,
          child: Text('نوع المظهر:', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
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
                  onSelected: (selected) { if (selected) onUpdate(currentSeed, style['id']!, null); },
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
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: Text('شخصيات جاهزة:', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        ),
        const SizedBox(height: 8),
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
                    border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2.5),
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    backgroundImage: CachedNetworkImageProvider(url),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  // =====================================================================
  // بانر تذكير رفع بطاقة الهوية الوطنية (دوري)
  // =====================================================================
  Widget _buildIdVerificationReminderBanner() {
    return GestureDetector(
      onTap: () async {
        // التمرير إلى قسم التوثيق أو تشغيل رفع البطاقة مباشرة
        _pickAndUploadNationalId();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF4444)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.badge_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ حسابك لم يُوثَّق بعد',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'ارفع بطاقتك الوطنية للحصول على رقم العضوية والتوثيق الرسمي. اضغط هنا للرفع الآن.',
                    style: GoogleFonts.tajawal(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.upload_rounded, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // تلميح المتطوع بإمكانية تغيير الصفة
  // =====================================================================
  Widget _buildWorkerRoleHintBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.swap_horiz_rounded, color: AppTheme.primaryGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تغيير الصفة متاح',
                  style: GoogleFonts.tajawal(
                    color: AppTheme.primaryGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'يمكنك التبديل بين صفة "متطوع" و"مستفيد" من شريط الأدوار أعلاه في أي وقت.',
                  style: GoogleFonts.tajawal(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.info_outline_rounded, color: AppTheme.primaryGreen.withValues(alpha: 0.5), size: 18),
        ],
      ),
    );
  }

  // =====================================================================
  // حقل بلدية معطّل (قبل اختيار الولاية)
  // =====================================================================
  Widget _buildDisabledCommuneField() {
    return InputDecorator(
      decoration: AppTheme.inputDecoration('البلدية', Icons.location_city_rounded).copyWith(
        filled: true,
        fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        enabled: false,
      ),
      child: Text(
        'اختر الولاية أولاً',
        style: GoogleFonts.tajawal(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  // =====================================================================
  // رفع بطاقة الهوية الوطنية
  // =====================================================================
  Future<void> _pickAndUploadNationalId() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

      // 1. ضغط الصورة قبل الرفع
      final File? compressedFile = await ImageCompressionService.compressImage(File(image.path));
      if (compressedFile == null) {
        if (Get.isDialogOpen ?? false) Get.back();
        Get.snackbar('خطأ', 'فشل ضغط الصورة');
        return;
      }

      // 2. رفع الملف المضغوط
      final url = await CloudinaryService.uploadMedia(compressedFile);
      if (url != null) {
        await FirebaseFirestore.instance.collection('users').doc(authController.currentUser.value?.id).update({
          'nationalIdUrl': url,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await authController.refreshUser();
        if (Get.isDialogOpen ?? false) Get.back();
        Get.snackbar('تم الرفع', 'سيتم مراجعة هويتك قريباً ✨', backgroundColor: Colors.green.withValues(alpha: 0.15));
      } else {
        if (Get.isDialogOpen ?? false) Get.back();
        Get.snackbar('خطأ', 'فشل رفع الصورة');
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar('خطأ', 'حدث خطأ أثناء الرفع: $e');
    }
  }

  // =====================================================================
  // حوار تأكيد الخروج
  // =====================================================================
  void _showLogoutConfirmation() {
    Get.dialog(
      AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تسجيل الخروج', textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontWeight: FontWeight.w900)),
        content: Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟', textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 13)),
        actions: [
          Row(children: [
            Expanded(child: TextButton(onPressed: () => Get.back(), child: Text('إلغاء', style: GoogleFonts.tajawal(color: Colors.grey)))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () { Get.back(); authController.logout(); },
              child: Text('خروج', style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold)),
            )),
          ]),
        ],
      ),
    );
  }

  // =====================================================================
  // الإبلاغ وحذف الحساب (Google Play Requirements)
  // =====================================================================
  
  Widget _buildDeleteAccountButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _showDeleteAccountConfirmation,
        icon: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
        label: Text('حذف الحساب نهائياً', style: GoogleFonts.tajawal(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  void _showDeleteAccountConfirmation() {
    Get.dialog(
      AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text('حذف الحساب', style: GoogleFonts.tajawal(fontWeight: FontWeight.w900, color: Colors.red)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف حسابك نهائياً؟ هذا الإجراء سيقوم بمسح كافة بياناتك ولا يمكن التراجع عنه.',
          style: GoogleFonts.tajawal(fontSize: 13),
        ),
        actions: [
          Row(children: [
            Expanded(child: TextButton(onPressed: () => Get.back(), child: Text('إلغاء', style: GoogleFonts.tajawal(color: Colors.grey)))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                Get.back();
                authController.deleteAccount();
              },
              child: Text('حذف نهائي', style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold)),
            )),
          ]),
        ],
      ),
    );
  }

  Widget _buildReportUserButton(UserModel targetUser) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showReportUserDialog(targetUser),
        icon: const Icon(Icons.report_problem_outlined, color: Colors.orange, size: 20),
        label: Text('الإبلاغ عن المستخدم', style: GoogleFonts.tajawal(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Colors.orange, width: 0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  void _showReportUserDialog(UserModel targetUser) {
    final reasonCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('الإبلاغ عن ${targetUser.name}', style: GoogleFonts.tajawal(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('يرجى توضيح سبب الإبلاغ عن هذا المستخدم:', style: GoogleFonts.tajawal(fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: AppTheme.inputDecoration('سبب الإبلاغ', Icons.description_outlined),
            ),
          ],
        ),
        actions: [
          Row(children: [
            Expanded(child: TextButton(onPressed: () => Get.back(), child: Text('إلغاء', style: GoogleFonts.tajawal(color: Colors.grey)))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (reasonCtrl.text.trim().isEmpty) {
                  Get.snackbar('تنبيه', 'الرجاء كتابة سبب الإبلاغ');
                  return;
                }
                Get.back();
                Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
                try {
                  await AbuseReportService.submitReport(
                    reportedType: 'user',
                    reportedId: targetUser.id,
                    reason: reasonCtrl.text.trim(),
                  );
                  Get.back();
                  Get.snackbar('تم الإرسال', 'تم إرسال بلاغك وسنقوم بمراجعته قريباً.', backgroundColor: Colors.green.withValues(alpha: 0.15));
                } catch (e) {
                  Get.back();
                  Get.snackbar('خطأ', 'فشل إرسال البلاغ. الرجاء المحاولة لاحقاً.');
                }
              },
              child: Text('إرسال البلاغ', style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold)),
            )),
          ]),
        ],
      ),
    );
  }
}
