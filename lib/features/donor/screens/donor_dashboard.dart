import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_routes.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/animations/scroll_animations.dart';
import '../controllers/donor_controller.dart';
import '../../chat/controllers/chat_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import 'donate_screen.dart';
import 'my_subscriptions_screen.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/donation_model.dart';
import '../../admin/controllers/project_controller.dart';
import '../../../data/services/notification_service.dart';
import '../../admin/controllers/admin_controller.dart';
import '../../admin/screens/dar_al_sabil_management_screen.dart';
import '../../shared/widgets/strategic_goal_card.dart';
import '../../shared/widgets/hizb_info_dialog.dart';


import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../core/animations/sound_manager.dart';
import '../../../core/widgets/update_banner.dart';

class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  final DonorController donorController = Get.put(DonorController());
  final ProjectController projectController = Get.put(ProjectController());
  final AuthController authController = Get.find<AuthController>();
  final NotificationService notificationService = Get.find<NotificationService>();
  final AdminController adminController = Get.put(AdminController());
  late final Stream<QuerySnapshot> _adminsStream;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _adminsStream = FirebaseFirestore.instance
        .collection('users')
      .where('role', whereIn: ['admin', 'superAdmin'])
        .snapshots();
  }

  Future<void> _openProjectDetails({ProjectModel? project, String? projectId}) async {
    if (project != null) {
      Get.toNamed(AppRoutes.adminProjectDetail, arguments: project);
      return;
    }

    final id = projectId;
    if (id == null || id.isEmpty || id == 'general') {
      Get.snackbar('تنبيه', 'هذا التبرع عام للجمعية ولا يرتبط بمشروع محدد');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('projects').doc(id).get();
      if (!doc.exists) {
        Get.snackbar('تنبيه', 'تعذر العثور على تفاصيل المشروع');
        return;
      }
      final model = ProjectModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      Get.toNamed(AppRoutes.adminProjectDetail, arguments: model);
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر فتح تفاصيل المشروع: $e');
    }
  }

  Future<void> _openDirectAdminChat(UserModel admin) async {
    final myId = authController.currentUser.value?.id ?? '';
    if (myId.isEmpty || admin.id.isEmpty) {
      Get.snackbar('تعذر فتح المحادثة', 'الرجاء إعادة تسجيل الدخول ثم المحاولة مرة أخرى');
      return;
    }

    final sortedIds = [myId, admin.id]..sort();
    final chatId = '${sortedIds[0]}_${sortedIds[1]}';

    Get.toNamed(AppRoutes.chatPrivate, arguments: {
      'targetUserId': admin.id,
      'targetUserName': admin.name,
      'userId': admin.id,
      'userName': admin.name,
      'chatId': chatId,
    });
  }

  Future<bool> _onWillPop() async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تأكيد الخروج',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
        content: Text('هل أنت متأكد من أنك تريد الخروج من التطبيق؟',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: 'Tajawal')),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Get.back(result: false),
                  child: Text('إلغاء', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: 'Tajawal')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTheme.gradientButton(
                  text: 'خروج',
                  onPressed: () => Get.back(result: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        final shouldPop = await _onWillPop();
        if (shouldPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    _buildHomeTab(),
                    _buildProjectsTab(),
                    const MySubscriptionsScreen(),
                    const DonateScreen(),
                    _buildContactTab(),
                  ],
                ),
              ),
              const UpdateBanner(),
            ],
          ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
              SoundManager.to.playNavigation();
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'لوحتي',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.folder_outlined),
                activeIcon: Icon(Icons.folder),
                label: 'المشاريع',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.child_care_outlined),
                activeIcon: Icon(Icons.child_care),
                label: 'كفالاتي',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.volunteer_activism),
                label: 'تبرع الآن',
              ),
              BottomNavigationBarItem(
                icon: Obx(() {
                  final chatController = Get.find<ChatController>();
                  return Badge(
                    label: Text(chatController.totalUnreadCount.value.toString()),
                    isLabelVisible: chatController.totalUnreadCount.value > 0,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    textColor: Theme.of(context).colorScheme.onPrimary,
                    child: const Icon(Icons.chat_bubble_outline),
                  );
                }),
                activeIcon: const Icon(Icons.chat_bubble),
                label: 'تواصل معنا',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('أهلاً بطلنا،', 
                        style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
                    Obx(() => Text(
                          donorController.donorName,
                          style: GoogleFonts.tajawal(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              _buildDonorBadge(),
              const SizedBox(width: 8),
              _buildProfileIcon(),
            ],
          ),
          const SizedBox(height: 24),
          _buildImpactSummaryCard(),
          const SizedBox(height: 20),
          _buildHizbSection(),
          const SizedBox(height: 20),
          Obx(() {
            final activeReqId = authController.currentUser.value?.activeBloodRequestId;
            if (activeReqId != null && activeReqId.isNotEmpty) {
              return Column(
                children: [
                  _buildLiveTrackingBanner(activeReqId, false),
                  const SizedBox(height: 20),
                ],
              );
            }
            return const SizedBox.shrink();
          }),
          const SizedBox(height: 12),
          _buildStrategicChallengesSection(),
          const SizedBox(height: 24),
          _buildHealthTipsCarousel(),
          const SizedBox(height: 24),
          Obx(() => donorController.donationsByProject.isNotEmpty
              ? Column(
                  children: [
                    _buildSectionHeader('🥧 توزيع تبرعاتي', ''),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _showAllDonations,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: SizedBox(
                                height: 180,
                                child: PieChart(
                                  PieChartData(
                                    sections: donorController.donationsByProject.map((item) {
                                      final total = donorController.totalDonated.value;
                                      final percentage = total > 0 ? (item['total'] / total * 100) : 0;
                                      return PieChartSectionData(
                                        value: (item['total'] as num).toDouble(),
                                        color: item['color'],
                                        title: '${percentage.toStringAsFixed(0)}%',
                                        radius: 65,
                                        titleStyle: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600),
                                      );
                                    }).toList(),
                                    centerSpaceRadius: 35,
                                    sectionsSpace: 3,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: donorController.donationsByProject.map((item) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: item['color'],
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item['projectName'],
                                                  style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      fontSize: 11),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis),
                                              ScrollAnimations.numberCounter(
                                                  value: item['total'] as num,
                                                  suffix: ' دج',
                                                  style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onSurface,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink()),
          const SizedBox(height: 24),
          _buildSectionHeader('💚 آخر تبرعاتي', 'عرض الكل', onTap: _showAllDonations),
          const SizedBox(height: 12),
          Obx(() => donorController.myDonations.isEmpty
              ? Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
                  ),
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      Icon(Icons.volunteer_activism, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 40),
                      const SizedBox(height: 12),
                      Text('لم تقم بأي تبرع بعد',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => setState(() => _currentIndex = 3),
                        child: const Text('تبرع الآن'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: donorController.myDonations.take(5).map((donation) {
                    return GestureDetector(
                      onTap: () => _openProjectDetails(projectId: donation.projectId),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))
                          ],
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: donation.donorId == 'anonymous'
                                    ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.15)
                                    : Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                donation.donorId == 'anonymous'
                                    ? Icons.person_off
                                    : Icons.volunteer_activism,
                                color: donation.donorId == 'anonymous'
                                    ? Theme.of(context).colorScheme.onSurfaceVariant
                                    : Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(donation.projectName,
                                      style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                                  Row(
                                    children: [
                                      Text(
                                          donation.isAnonymous
                                            ? '${_methodLabel(donation.method)} • مجهول'
                                            : _methodLabel(donation.method),
                                          style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.15), shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                          DateFormat('yyyy/MM/dd').format(donation.date),
                                          style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    '${projectController.formatNumber(donation.amount)} دج',
                                    style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(donation.status, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 10)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                )),
          const SizedBox(height: 24),
          _buildSectionHeader('📁 المشاريع التي تبرعت فيها', ''),
          const SizedBox(height: 12),
          Obx(() => donorController.donationsByProject.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  children: donorController.donationsByProject.map((entry) {
                    final projectId = (entry['projectId'] ?? '').toString();
                    final projectName = (entry['projectName'] ?? 'مشروع سابق').toString();
                    final myTotal = (entry['total'] as num?) ?? 0;
                    final existingProject = donorController.activeProjects.firstWhereOrNull((p) => p.id == projectId);

                    return GestureDetector(
                      onTap: () => _openProjectDetails(project: existingProject, projectId: projectId),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.folder_special_rounded, color: Theme.of(context).colorScheme.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(projectName,
                                      style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontWeight: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text(
                                    existingProject == null ? 'مشروع غير نشط حالياً' : 'اضغط لعرض التفاصيل',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${projectController.formatNumber(myTotal)} دج',
                              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                )),

          Obx(() {
            final user = authController.currentUser.value;
            if (user == null) return const SizedBox.shrink();
            if (!user.canManageDarSabil && !user.additionalRoles.contains('canRequestService')) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(Icons.more_horiz_rounded, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('خدمات إضافية لك',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                
                // ✨ إضافة كرت إدارة دار السبيل للمفوضين
                if (user.canManageDarSabil) ...[
                  _buildExtraDashboardCard(
                    title: 'إدارة دار السبيل 🏠',
                    subtitle: 'إدارة النزلاء، الغرف، والمهام اليومية',
                    icon: Icons.home_work_rounded,
                    color: AppTheme.goldAccent,
                    onTap: () => Get.to(() => const DarSabilManagementScreen()),
                  ),
                  const SizedBox(height: 12),
                ],

                if (user.additionalRoles.contains('canRequestService')) ...[
                  _buildExtraDashboardCard(
                    title: 'طلب خدمة / مساعدة',
                    subtitle: 'ارفع طلباً جديداً للإدارة للتدخل',
                    icon: Icons.handshake_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    onTap: () => Get.toNamed(AppRoutes.beneficiaryDashboard),
                  ),
                ],
              ],
            );
          }),
          // ====================================================

          const SizedBox(height: 80),
        ],
      ),
    );
  }



  Widget _buildHizbSection() {
    return Obx(() {
      final user = authController.currentUser.value;
      if (user == null) return const SizedBox.shrink();
      
      final bool isMember = user.isHizbMember;
      final int memberCount = donorController.hizbMembersCount.value;

      return FadeInUp(
        delay: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: () => Get.dialog(const HizbInfoDialog()),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isMember 
                  ? [const Color(0xFFB8860B), const Color(0xFFD4AF37)] 
                  : [AppTheme.surfaceColor, AppTheme.surfaceColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppTheme.goldAccent.withValues(alpha: isMember ? 0.5 : 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.goldAccent.withValues(alpha: isMember ? 0.2 : 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: -10,
                  top: -10,
                  child: Icon(
                    Icons.stars_rounded, 
                    size: 80, 
                    color: Colors.white.withValues(alpha: isMember ? 0.1 : 0.03)
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMember ? Colors.white24 : AppTheme.goldAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isMember ? Icons.verified_user_rounded : Icons.star_outline_rounded,
                        color: isMember ? Colors.white : AppTheme.goldAccent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'حزب المائة ألف',
                                style: GoogleFonts.tajawal(
                                  color: isMember ? Colors.white : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              if (isMember) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'عضو منضم',
                                    style: GoogleFonts.tajawal(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isMember 
                              ? 'أنت أحد الأبطال المستعدين للنداء ⚡' 
                              : 'انضم لفيالق الخير المستعدة للطوارئ 🛡️',
                            style: GoogleFonts.tajawal(
                              color: isMember ? Colors.white.withValues(alpha: 0.9) : AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      children: [
                        Text(
                          memberCount.toString(),
                          style: GoogleFonts.tajawal(
                            color: isMember ? Colors.white : AppTheme.goldAccent,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        Text(
                          'عضو',
                          style: GoogleFonts.tajawal(
                            color: isMember ? Colors.white70 : AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildSectionHeader(String title, String action, {VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700)),
        if (action.isNotEmpty)
          TextButton(
            onPressed: onTap,
            child: Text(action, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
      ],
    );
  }

  Widget _buildProjectsTab() {
    return Obx(() {
      if (donorController.activeProjects.isEmpty) {
        return const PremiumEmptyState(
          title: 'لا توجد مشاريع حالياً',
          subtitle: 'لا توجد مشاريع نشطة حالياً، جزاك الله خيراً للبحث.',
          icon: Icons.volunteer_activism_outlined,
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: donorController.activeProjects.length,
        itemBuilder: (context, index) {
          final project = donorController.activeProjects[index];
          return _buildDonorProjectCard(project);
        },
      );
    });
  }

  Widget _buildProfileIcon() {
    return Obx(() {
      final user = authController.currentUser.value;
      return FadeInRight(
        child: GestureDetector(
          onTap: () => Get.toNamed(AppRoutes.profile),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              backgroundImage: (user?.profileImage != null && user!.profileImage!.isNotEmpty)
                  ? CachedNetworkImageProvider(user.profileImage!) as ImageProvider
                  : null,
              child: (user?.profileImage == null || user!.profileImage!.isEmpty)
                  ? Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.primary)
                  : null,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildDonorBadge() {
    return Obx(() {
      final user = authController.currentUser.value;
      if (user == null) return const SizedBox.shrink();
      
      final bool isReady = user.canDonateBloodSmart;
      final String bloodType = user.bloodType ?? '??';

      return FadeInRight(
        child: GestureDetector(
          onTap: () => Get.toNamed(AppRoutes.bloodDonorProfile),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: AppTheme.errorColor, shape: BoxShape.circle),
                  child: Text(bloodType, 
                    style: GoogleFonts.tajawal(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isReady ? 'جاهز للتبرع' : 'فترة استراحة', 
                      style: GoogleFonts.tajawal(color: isReady ? Colors.green : Colors.orange, fontSize: 9, fontWeight: FontWeight.w800, height: 1)),
                    const SizedBox(height: 2),
                    Text('الملف الطبي ➔',
                      style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.primary, fontSize: 8, fontWeight: FontWeight.bold, height: 1)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildImpactSummaryCard() {
    return Obx(() {
      final user = authController.currentUser.value;
      final int donationCount = user?.bloodDonationsCount ?? 0;
      final double totalCash = donorController.totalDonated.value;
      
      return FadeInUp(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFC62828), Color(0xFF880E4F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC62828).withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20, top: -20,
                child: Icon(Icons.favorite_rounded, size: 120, color: Colors.white.withValues(alpha: 0.08)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('أثرك المجتمعي التراكمي', 
                        style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                      GestureDetector(
                        onTap: () => donorController.showCertificate(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                          child: Text('شهادتي 🏅', style: GoogleFonts.tajawal(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(donationCount.toString(), 
                        style: GoogleFonts.tajawal(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, height: 1)),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('أرواح أُنقذت بفضل الله', 
                          style: GoogleFonts.tajawal(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(height: 1, width: double.infinity, color: Colors.white12),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildImpactStat('إجمالي الصدقات', '${totalCash.toInt()} دج', Icons.volunteer_activism_rounded),
                      _buildImpactStat('المشاريع المنفذة', donorController.donationsByProject.length.toString(), Icons.auto_awesome_rounded),
                      _buildImpactStat('رتبة البطل', _getRank(donationCount), Icons.military_tech_rounded),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildImpactStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white60, size: 20),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.tajawal(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          Text(label, style: GoogleFonts.tajawal(color: Colors.white38, fontSize: 9), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _getRank(int count) {
    if (count >= 15) return 'بلاتيني 💎';
    if (count >= 10) return 'ذهبي 🥇';
    if (count >= 5) return 'فضي 🥈';
    if (count >= 1) return 'برونزي 🥉';
    return 'مبادر 🌱';
  }

  Widget _buildDonorProjectCard(ProjectModel project) {
    final cat = ProjectController.categories
        .firstWhere((c) => c['id'] == project.category, orElse: () => ProjectController.categories.last);
    final categoryColor = cat['color'] as Color;
    final progress = project.progressRatio;
    final progressPercent = project.progressPercentage;
    final remaining = (project.budget - project.collected).clamp(0.0, double.infinity);

    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      child: Container(
        margin: const EdgeInsetsDirectional.only(bottom: 20),
        decoration: AppTheme.glassDecoration.copyWith(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: categoryColor.withValues(alpha: 0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: categoryColor.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
              children: [
                // Header
          GestureDetector(
            onTap: () => _openProjectDetails(project: project),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: categoryColor.withValues(alpha: 0.15)),
                    ),
                    child: Icon(cat['icon'] as IconData, color: categoryColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(project.name,
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 17, height: 1.2)),
                            ),
                            if (project.isSubscription) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.goldAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('تبرع شهري', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 2),
                                    Icon(Icons.cached_rounded, color: Colors.black, size: 12),
                                  ],
                                ),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(cat['name'] as String,
                            style: TextStyle(color: categoryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(project.status, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 10)),
                  ),
                ],
              ),
            ),
          ),

          // Circular Progress + Stats
          GestureDetector(
            onTap: () => _openProjectDetails(project: project),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 110, height: 110,
                    child: CustomPaint(
                      painter: _ArcProgressPainter(progress: progress, color: categoryColor, backgroundColor: Theme.of(context).colorScheme.surface),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${progressPercent.toStringAsFixed(1)}%',
                                style: TextStyle(color: categoryColor, fontWeight: FontWeight.w900, fontSize: 24, height: 1)),
                            Text('اكتمل', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (project.description.isNotEmpty)
                          Text(project.description,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, height: 1.4)),
                        const SizedBox(height: 12),
                        _buildStatRow('جُمع', '${projectController.formatNumber(project.collected)} دج', categoryColor),
                        const SizedBox(height: 6),
                        _buildStatRow('الهدف', '${projectController.formatNumber(project.budget)} دج', Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 6),
                        _buildStatRow('المتبقى', '${projectController.formatNumber(remaining)} دج', Theme.of(context).colorScheme.error),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Progress Track
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('شريط التقدم', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                    const Spacer(),
                    Text('${progressPercent.toStringAsFixed(1)}%', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    valueColor: AlwaysStoppedAnimation(categoryColor),
                  ),
                ),
              ],
            ),
          ),

          // Personal Contribution Detail
          Builder(builder: (ctx) {
            final myContribData = donorController.donationsByProject
                .firstWhereOrNull((d) => d['projectId'] == project.id);
            final double myAmount = (myContribData?['total'] ?? 0.0).toDouble();
            final double myPercent = project.collected > 0
                ? (myAmount / project.collected * 100).clamp(0.0, 100.0)
                : 0.0;
            
            if (myAmount <= 0) return const SizedBox.shrink();
            
            return Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 18, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: categoryColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.stars_rounded, color: categoryColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('إجمالي مساهمتك في هذا المشروع', 
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text('${projectController.formatNumber(myAmount)} دج',
                                  style: TextStyle(color: categoryColor, fontSize: 15, fontWeight: FontWeight.w900)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: categoryColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('%${myPercent.toStringAsFixed(1)}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),
          const Divider(height: 1),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final shareText =
                          'مشروع: ${project.name}\n'
                          'التقدم: ${progressPercent.toStringAsFixed(1)}%\n'
                          'جُمع: ${projectController.formatNumber(project.collected)} دج\n'
                          'الهدف: ${projectController.formatNumber(project.budget)} دج\n'
                          'انضم إلينا لدعم جمعية ناس الخير والتبرع لهذا المشروع.';
                      Share.share(shareText, subject: 'مشروع ${project.name} - ناس الخير');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
                          const SizedBox(width: 6),
                          Text('مشاركة', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () {
                      donorController.preSelectProject(project.id, project.name);
                      setState(() => _currentIndex = 3);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Theme.of(context).colorScheme.primary, AppTheme.primaryGreenDark],
                          begin: AlignmentDirectional.topStart,
                          end: AlignmentDirectional.bottomEnd,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(project.isSubscription ? Icons.repeat : Icons.volunteer_activism, color: Theme.of(context).colorScheme.onPrimary, size: 18),
                          const SizedBox(width: 6),
                          Text(project.isSubscription ? 'التزام شهري' : 'تبرع لهذا المشروع',
                              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }

  String _methodLabel(String method) {
    return DonationModel.methodLabel(method);
  }

  void _showAllDonations() {
    Get.bottomSheet(
      DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)))),
                Text('جميع تبرعاتي',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 16),
                Expanded(
                  child: Obx(() => donorController.myDonations.isEmpty
                      ? Center(child: Text('لا توجد تبرعات بعد', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: donorController.myDonations.length,
                          itemBuilder: (context, index) {
                            final donation = donorController.myDonations[index];
                            return GestureDetector(
                              onTap: () => _openProjectDetails(projectId: donation.projectId),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.all(10),
                                      child: Icon(Icons.volunteer_activism, color: Theme.of(context).colorScheme.primary, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(donation.projectName, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                                          Text(_methodLabel(donation.method), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('${projectController.formatNumber(donation.amount)} دج',
                                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                          child: Text(donation.status, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 9)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )),
                ),
              ],
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildContactTab() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تواصل معنا',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
                    Text('تواصل مع فريق إدارة ناس الخير',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('تواصل خاص مع الإدارة',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        SliverFillRemaining(
          child: StreamBuilder<QuerySnapshot>(
            stream: _adminsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ShimmerList(count: 3, height: 80);
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text('لا يوجد مدراء متاحون حالياً',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                );
              }
              final admins = snapshot.data!.docs
                  .map((d) => UserModel.fromMap(
                      d.data() as Map<String, dynamic>, d.id))
                  .where((u) => u.isActive)
                  .where((u) => u.role == UserRole.admin || u.role == UserRole.superAdmin)
                  .toList();
                  
              // ترتيب: المنسق العام أولاً ثم البقية أبجدياً
              admins.sort((a, b) {
                if (a.role == UserRole.superAdmin && b.role != UserRole.superAdmin) return -1;
                if (a.role != UserRole.superAdmin && b.role == UserRole.superAdmin) return 1;
                return a.name.compareTo(b.name);
              });

              if (admins.isEmpty) {
                return Center(
                  child: Text('لا يوجد مدراء متاحون حالياً',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: admins.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final admin = admins[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
                    ),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        backgroundImage: (admin.profileImage != null &&
                                admin.profileImage!.isNotEmpty)
                            ? CachedNetworkImageProvider(admin.profileImage!) as ImageProvider
                            : null,
                        child: (admin.profileImage == null ||
                                admin.profileImage!.isEmpty)
                            ? Text(
                                admin.name.isNotEmpty ? admin.name[0] : 'A',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold))
                            : null,
                      ),
                      title: Text(admin.name,
                          style: GoogleFonts.tajawal(
                      color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          admin.role == UserRole.superAdmin
                              ? 'مدير عام'
                              : 'مدير إداري',
                          style: GoogleFonts.tajawal(
                              color: Theme.of(context).colorScheme.primary, fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.chat_bubble_outline,
                            color: AppTheme.primaryGreen, size: 20),
                      ),
                      onTap: () => _openDirectAdminChat(admin),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHealthTipsCarousel() {
    final tips = [
      {'icon': Icons.water_drop, 'text': 'اشرب الكثير من الماء قبل التبرع للحفاظ على تدفق الدم'},
      {'icon': Icons.restaurant, 'text': 'تناول وجبة خفيفة غنية بالحديد اليوم لتعويض النقص'},
      {'icon': Icons.bed, 'text': 'تجنب الأنشطة الشاقة لمدة 24 ساعة بعد التبرع بالدم'},
      {'icon': Icons.sentiment_very_satisfied, 'text': 'ابتسامتك وعطاؤك قد تكون الأمل العظيم لعائلة كاملة'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('💡 نصائح تهمك', ''),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: tips.length,
            itemBuilder: (context, index) {
              return Container(
                width: 250,
                margin: const EdgeInsetsDirectional.only(start: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(tips[index]['icon'] as IconData, color: Theme.of(context).colorScheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tips[index]['text'] as String,
                        style: GoogleFonts.tajawal(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStrategicChallengesSection() {
    return Obx(() {
      if (adminController.activeGoals.isEmpty) return const SizedBox.shrink();
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('🎯 تحديات جمعية ناس الخير', ''),
          const SizedBox(height: 12),
          ...adminController.activeGoals.map((goal) => StrategicGoalCard(goal: goal)),
        ],
      );
    });
  }

  // ✨ زر التتبع الحي لطلب الدم
  Widget _buildLiveTrackingBanner(String requestId, bool isGuest) {
    return GestureDetector(
      onTap: () {
        Get.toNamed('/blood-emergency', arguments: {
           'requestId': requestId,
            'isGuest': isGuest,
        });
      },
      child: FadeInDown(
        duration: const Duration(milliseconds: 600),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.orangeAccent, AppTheme.urgentColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppTheme.urgentColor.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.directions_run_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أنت في مهمة إنقاذ الآن 🚑',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'انقر هنا للعودة لصفحة التتبع الحي للنداء',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExtraDashboardCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}


class _ArcProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _ArcProgressPainter({required this.progress, required this.color, required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 10.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;
    const startAngle = -2.356; 
    const sweepAngle = 4.712;  

    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, bgPaint);

    if (progress > 0) {
      final fgPaint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle * progress, false, fgPaint);

      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.15)
        ..strokeWidth = strokeWidth + 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle * progress, false, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_ArcProgressPainter old) =>
      old.progress != progress || old.color != color;
}
