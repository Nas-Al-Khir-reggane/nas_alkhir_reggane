import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/animations/micro_interactions.dart';
import '../controllers/admin_controller.dart';
import '../../chat/controllers/chat_controller.dart';
import '../../../core/animations/scroll_animations.dart';
import '../../../core/animations/visual_effects.dart';
import '../../../core/animations/sound_manager.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/notification_service.dart';
import '../../chat/screens/admin_inbox_screen.dart';
import 'service_requests_screen.dart' as real_requests;
import 'projects_screen.dart';
import 'workers_screen.dart';
import 'package:nas_al_kheir/core/widgets/geometric_progress.dart';
import '../../../core/widgets/app_logo.dart';
import 'project_detail_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  final AdminController controller = Get.put(AdminController());
  final AuthController authController = Get.find<AuthController>();
  final NotificationService notificationService = Get.find<NotificationService>();

  Future<bool> _onWillPop() async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
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
    final List<Widget> screens = [
      _buildHomeTab(),
      const real_requests.ServiceRequestsScreen(),
      ProjectsScreen(),
      const WorkersScreen(),
      const AdminInboxScreen(),
      _buildManagementTab(),
    ];

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
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: VisualEffects.ambientBackground(
          isDark: Theme.of(context).brightness == Brightness.dark,
          child: Scaffold(
            backgroundColor: Colors.transparent, // Allow ambient to show
            body: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
            bottomNavigationBar: _buildBottomBar(),
            floatingActionButton: _shouldShowFAB() ? _buildFAB() : null,
          ),
        ),
      ),
    );
  }

  bool _shouldShowFAB() {
    if (_currentIndex != 0) return false;
    final role = authController.currentUser.value?.role;
    return role == UserRole.superAdmin || role == UserRole.admin;
  }

  // Inbox tab is index 4
  static const int _inboxIndex = 4;

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.75), blurRadius: 10, offset: const Offset(0, -2))
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            SoundManager.to.playNavigation();
            if (index == 1) controller.markAllUrgentAsSeen();
          },
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 11),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard_outlined),
              activeIcon: MicroInteractions.navIcon(isActive: true, child: const Icon(Icons.dashboard)),
              label: 'الرئيسية'),
            BottomNavigationBarItem(
              icon: Obx(() => Badge(
                    label: Text(controller.unseenUrgentCount.value.toString()),
                    isLabelVisible: controller.unseenUrgentCount.value > 0,
                    child: const Icon(Icons.assignment_outlined),
                  )),
              activeIcon: MicroInteractions.navIcon(isActive: true, child: const Icon(Icons.assignment)),
              label: 'الطلبات'),
            BottomNavigationBarItem(
              icon: const Icon(Icons.folder_outlined),
              activeIcon: MicroInteractions.navIcon(isActive: true, child: const Icon(Icons.folder)),
              label: 'المشاريع'),
            BottomNavigationBarItem(
              icon: const Icon(Icons.group_outlined),
              activeIcon: MicroInteractions.navIcon(isActive: true, child: const Icon(Icons.group)),
              label: 'الفريق'),
            BottomNavigationBarItem(
              icon: Obx(() {
                final chatController = Get.find<ChatController>();
                return Badge(
                  label: Text(chatController.totalUnreadCount.value.toString()),
                  isLabelVisible: chatController.totalUnreadCount.value > 0,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  textColor: Theme.of(context).colorScheme.onPrimary,
                  child: const Icon(Icons.inbox_outlined),
                );
              }),
              activeIcon: MicroInteractions.navIcon(isActive: true, child: const Icon(Icons.inbox)),
              label: 'الرسائل'),
            BottomNavigationBarItem(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              activeIcon: MicroInteractions.navIcon(isActive: true, child: const Icon(Icons.admin_panel_settings)),
              label: 'الإدارة'),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      child: VisualEffects.magneticButton(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withValues(alpha: 0.9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () => _showActionMenu(),
            backgroundColor: Colors.transparent,
            elevation: 0,
            highlightElevation: 0,
            hoverElevation: 0,
            focusElevation: 0,
            extendedPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            icon: Icon(Icons.add_box_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 22),
            label: Text(
              'إجراء سريع',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showActionMenu() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('إجراءات سريعة', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Tajawal')),
            const SizedBox(height: 16),
            _buildActionItem(Icons.volunteer_activism, 'تسجيل تبرع جديد', () {
              Get.back();
              _showAdminDonationDialog();
            }),
            _buildActionItem(Icons.add_task, 'إضافة طلب خدمة', () {
              Get.back();
              Get.toNamed('/beneficiary/new-request');
            }),
            _buildActionItem(Icons.create_new_folder, 'إضافة مشروع جديد', () {
              Get.back();
              ProjectsScreen.showAddProjectSheet(context);
            }),
            _buildActionItem(Icons.person_add, 'إضافة متطوع جديد', () {
              Get.back();
              WorkersScreen.showAddWorkerSheet(context);
            }),
            _buildActionItem(Icons.settings_backup_restore_rounded, 'استعادة الخدمات الافتراضية', () {
              Get.back();
              controller.seedDefaultServices();
            }),
          ],
        ),
      ),
    );
  }

  void _showAdminDonationDialog() {
    final donorNameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String selectedMethod = 'cash';
    String selectedProject = 'general';
    String selectedProjectName = 'تبرع عام للجمعية';

    Get.dialog(
      StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('تسجيل تبرع جديد',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: donorNameCtrl,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: AppTheme.inputDecoration('اسم المتبرع *', Icons.person_outline),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: AppTheme.inputDecoration('المبلغ (دج) *', Icons.attach_money),
                ),
                const SizedBox(height: 12),
                Obx(() {
                  final projects = controller.activeProjectsList;
                  return DropdownButtonFormField<String>(
                    dropdownColor: Theme.of(context).cardColor,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Tajawal'),
                    decoration: AppTheme.inputDecoration('المشروع', Icons.folder_outlined),
                    initialValue: selectedProject,
                    items: [
                      const DropdownMenuItem(value: 'general', child: Text('تبرع عام للجمعية')),
                      ...projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedProject = val;
                          selectedProjectName = val == 'general'
                              ? 'تبرع عام للجمعية'
                              : projects.firstWhere((p) => p.id == val).name;
                        });
                      }
                    },
                  );
                }),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: Theme.of(context).cardColor,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Tajawal'),
                  decoration: AppTheme.inputDecoration('طريقة الدفع', Icons.payment),
                  initialValue: selectedMethod,
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('نقداً')),
                    DropdownMenuItem(value: 'bank', child: Text('تحويل بنكي')),
                    DropdownMenuItem(value: 'online', child: Text('دفع إلكتروني')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedMethod = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
            AppTheme.gradientButton(
              text: 'تسجيل',
              icon: Icons.save,
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (donorNameCtrl.text.isEmpty || amount <= 0) {
                  Get.snackbar('تنبيه', 'يرجى ملء جميع الحقول');
                  return;
                }
                try {
                  final primaryColor = Theme.of(context).colorScheme.primary;
                  final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
                  await FirebaseFirestore.instance.collection('donations').add({
                    'donorId': 'admin_registered',
                    'donorName': donorNameCtrl.text,
                    'amount': amount,
                    'projectId': selectedProject,
                    'projectName': selectedProjectName,
                    'method': selectedMethod,
                    'isAnonymous': false,
                    'status': 'confirmed',
                    'registeredByAdmin': true,
                    'date': FieldValue.serverTimestamp(),
                  });
                  if (selectedProject != 'general') {
                    await FirebaseFirestore.instance
                        .collection('projects')
                        .doc(selectedProject)
                        .update({
                          'collected': FieldValue.increment(amount),
                          'donorsCount': FieldValue.increment(1),
                        });
                  }
                  Get.back();
                  Get.snackbar('✅ تم', 'تم تسجيل التبرع بنجاح',
                      backgroundColor: primaryColor.withValues(alpha: 0.15),
                      colorText: onSurfaceColor);
                } catch (e) {
                  Get.snackbar('خطأ', 'فشل تسجيل التبرع: $e');
                }
              },
            ),
          ],
        );
      }),
    );
  }


  Widget _buildActionItem(IconData icon, String title, VoidCallback onTap) {
    return MicroInteractions.bouncingButton(
      onTap: onTap,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
      ),
    );
  }

  Widget _buildHeaderButton({required Widget child, required VoidCallback onTap}) {
    return MicroInteractions.bouncingButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.75)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.75), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: () => controller.loadDashboardData(),
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 55),
            
            // --- Masterpiece Luxurious Header ---
            Row(
              children: [
                // 1. Manager Identity (Right Side - Expanded for long names)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('مرحباً،', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, letterSpacing: 0.5)),
                      Obx(() => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                              authController.currentUser.value?.name ?? 'المدير',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w900, height: 1.2),
                              maxLines: 1,
                            ),
                      )),
                      Obx(() => Text(
                        authController.currentUser.value?.role.displayName ?? '',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w700),
                      )),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // 2. Crystal Control Center (Middle)
                FadeInDown(
                  duration: const Duration(milliseconds: 800),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHeaderButton(
                        onTap: () => Get.toNamed('/profile'),
                        child: Obx(() {
                          final user = authController.currentUser.value;
                          return Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75), width: 1.5),
                            ),
                            child: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                              backgroundImage: (user?.profileImage != null && user!.profileImage!.isNotEmpty)
                                  ? CachedNetworkImageProvider(user.profileImage!) as ImageProvider
                                  : null,
                              child: (user?.profileImage == null || user!.profileImage!.isEmpty)
                                  ? Icon(Icons.person, color: Theme.of(context).colorScheme.primary, size: 14)
                                  : null,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 6),
                      _buildHeaderButton(
                        onTap: () {
                          AppConstants.toggleTheme();
                          SoundManager.to.playToggle(!Get.isDarkMode);
                        },
                        child: Icon(ThemeService().themeIcon, color: Theme.of(context).colorScheme.primary, size: 18),
                      ),
                      const SizedBox(width: 6),
                      _buildHeaderButton(
                        onTap: () => Get.toNamed('/notifications'),
                        child: Obx(() => Stack(
                          children: [
                            Icon(Icons.notifications_none_rounded, color: Theme.of(context).colorScheme.onSurface, size: 18),
                            if (notificationService.unreadCount.value > 0)
                              Positioned(
                                right: 0, top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.error, shape: BoxShape.circle),
                                  constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                                  child: Text(
                                    notificationService.unreadCount.value.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold),
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

                // 3. Corner Majesty (Left Side)
                FadeInLeft(
                  duration: const Duration(milliseconds: 1000),
                  child: AppLogo(
                    size: 72,
                    color: Get.isDarkMode 
                        ? AppTheme.goldAccent.withValues(alpha: 0.15) 
                        : AppTheme.primaryGreen.withValues(alpha: 0.75), // جعل اللون خافتاً وناعماً
                    showGlow: Get.isDarkMode,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 25),
            
            // --- Urgent Banner ---
            Obx(() => controller.unseenUrgentCount.value > 0
                ? FadeIn(
                    child: GestureDetector(
                      onTap: () => setState(() => _currentIndex = 1),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFD50000), Color(0xFFFF6D00)]),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.75), blurRadius: 15, offset: const Offset(0, 5))],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${controller.urgentRequests.length} طلب طارئ ينتظر',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                                const Text('اضغط للمعالجة الفورية الآن', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink()),
            
            const SizedBox(height: 25),
            Text('نظرة عامة', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 17, fontWeight: FontWeight.w800, fontFamily: 'Tajawal')),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.4,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              children: [
                _buildKPICard('إجمالي التبرعات', controller.totalDonations, Icons.volunteer_activism, AppTheme.goldGradient, 'دج', onTap: () => Get.toNamed('/admin/donations')),
                _buildKPICard('الطلبات المعلقة', controller.pendingRequests, Icons.pending_actions,
                    const LinearGradient(colors: [Colors.orange, Colors.deepOrange]), '', onTap: () => setState(() => _currentIndex = 1)),
                _buildKPICard('المشاريع النشطة', controller.activeProjects, Icons.folder_open, AppTheme.primaryGradient, '', onTap: () => setState(() => _currentIndex = 2)),
                _buildKPICard('المتطوعون المتاحون', controller.availableWorkers, Icons.engineering,
                    const LinearGradient(colors: [Colors.blue, Colors.indigo]), '', onTap: () => setState(() => _currentIndex = 3)),
                _buildKPICard('السيارات المتاحة', controller.availableVehicles, Icons.airport_shuttle,
                    const LinearGradient(colors: [Colors.teal, Colors.cyan]), '', onTap: () => Get.toNamed('/admin/vehicles')),
                _buildKPICard('المستفيدون', controller.totalBeneficiaries, Icons.people,
                    const LinearGradient(colors: [Colors.purple, Colors.deepPurple]), '', onTap: () => Get.toNamed('/admin/users')),
              ],
            ),
            const SizedBox(height: 24),
            Obx(() => controller.urgentRequests.isNotEmpty
                ? Column(
                    children: [
                      _buildSectionHeader('🚨 طلبات تحتاج تدخلاً', 'عرض الكل', onTap: () => setState(() => _currentIndex = 1)),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: controller.urgentRequests.length > 3 ? 3 : controller.urgentRequests.length,
                        itemBuilder: (context, index) => _buildUrgentRequestCard(controller.urgentRequests[index]),
                      ),
                    ],
                  )
                : const SizedBox.shrink()),
            const SizedBox(height: 24),
            _buildSectionHeader('📈 التبرعات آخر 6 أشهر', ''),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Get.toNamed('/admin/reports'),
              child: Container(
                decoration: AppTheme.glassDecoration,
                padding: const EdgeInsets.all(16),
                height: 200,
                child: Obx(() {
                  if (controller.donationsLastSixMonths.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.query_stats, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.75), size: 40),
                          const SizedBox(height: 8),
                          Text('لا توجد بيانات تبرعات كافية', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontFamily: 'Tajawal')),
                        ],
                      ),
                    );
                  }
                  return LineChart(
                        LineChartData(
                          gridData: FlGridData(
                              show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.75), strokeWidth: 1)),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, _) {
                                  final index = v.toInt();
                                  if (index < 0 || index >= controller.donationsLastSixMonths.length) return const SizedBox.shrink();
                                  return Text(
                                    controller.donationsLastSixMonths[index]['month'],
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10));
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                getTitlesWidget: (v, _) => Text('${v.toInt()}k', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10)),
                              ),
                            ),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: controller.donationsLastSixMonths
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(e.key.toDouble(), (e.value['amount'] ?? 0.0).toDouble()))
                                  .toList(),
                              isCurved: true,
                              color: Theme.of(context).colorScheme.primary,
                              barWidth: 3,
                              belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75)),
                              dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, bar, index) =>
                                      FlDotCirclePainter(radius: 4, color: Theme.of(context).colorScheme.primary, strokeColor: Theme.of(context).colorScheme.surface, strokeWidth: 2)),
                            )
                          ],
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (spots) => spots
                                  .map((s) => LineTooltipItem('${s.y.toInt()} دج',
                                      TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Tajawal', fontWeight: FontWeight.w600)))
                                  .toList(),
                            ),
                          ),
                        ),
                      );
                }),
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('🥧 توزيع الخدمات', ''),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _currentIndex = 1),
              child: Container(
                decoration: AppTheme.glassDecoration,
                padding: const EdgeInsets.all(16),
                height: 220,
                child: Row(
                  children: [
                    Expanded(
                      child: Obx(() {
                        if (controller.serviceTypeDistribution.isEmpty || 
                            (controller.serviceTypeDistribution.length == 1 && controller.serviceTypeDistribution[0]['name'] == 'لا يوجد')) {
                          return Center(child: Icon(Icons.pie_chart_outline, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.75), size: 50));
                        }
                        return PieChart(PieChartData(
                            sections: controller.serviceTypeDistribution
                                .map((item) => PieChartSectionData(
                                      value: (item['count'] ?? 0).toDouble(),
                                      color: item['color'],
                                      title: '${item['percentage']}%',
                                      radius: 60,
                                      titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Tajawal'),
                                    ))
                                .toList(),
                            centerSpaceRadius: 40,
                            sectionsSpace: 3,
                            pieTouchData: PieTouchData(enabled: true),
                          ));
                      })),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Obx(() => SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: controller.serviceTypeDistribution
                              .map((item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      children: [
                                        Container(width: 12, height: 12, decoration: BoxDecoration(color: item['color'], borderRadius: BorderRadius.circular(3))),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(AppConstants.translateServiceType(item['name']), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontFamily: 'Tajawal'), overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                      )),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('📊 طلبات هذا الشهر', ''),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _currentIndex = 1),
              child: Container(
                decoration: AppTheme.glassDecoration,
                padding: const EdgeInsets.all(16),
                height: 180,
                child: Obx(() => BarChart(BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      barGroups: controller.monthlyRequests
                          .map((item) => BarChartGroupData(
                                x: item['day'],
                                barRods: [
                                  BarChartRodData(
                                    toY: item['count'].toDouble(),
                                    gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withValues(alpha: 0.9)]),
                                    width: 8,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                  )
                                ],
                              ))
                          .toList(),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, meta) {
                                  if (v.toInt() % 5 != 0 && v.toInt() != 1) return const SizedBox.shrink();
                                  return Text('${v.toInt()}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 9));
                                },
                            ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                              '${rod.toY.toInt()} طلب', TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Tajawal', fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ))),
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('📁 تقدم المشاريع', 'عرض الكل', onTap: () => setState(() => _currentIndex = 2)),
            const SizedBox(height: 12),
            Obx(() => Column(
                  children: controller.activeProjectsList
                      .take(3)
                      .map((project) {
                        final progress = project.budget > 0 ? project.collected / project.budget : 0.0;
                        return GestureDetector(
                              onTap: () => Get.to(() => ProjectDetailScreen(project: project)),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: AppTheme.glassDecoration,
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    HexagonalProgressIndicator(
                                      progress: progress,
                                      size: 55,
                                      label: 'التقدم',
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            project.name,
                                            style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurface,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                fontFamily: 'Tajawal'
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Text(
                                                '${project.collected.toInt()} دج',
                                                style: TextStyle(
                                                    color: Theme.of(context).colorScheme.primary,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600
                                                )
                                              ),
                                              const Spacer(),
                                              Text(
                                                'من ${project.budget.toInt()} دج',
                                                style: TextStyle(
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                    fontSize: 11
                                                )
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            height: 3,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                            child: FractionallySizedBox(
                                              alignment: Alignment.centerRight,
                                              widthFactor: progress.clamp(0.0, 1.0),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75), size: 14),
                                  ],
                                ),
                              ),
                            );
                      })
                      .toList(),
                )),
            const SizedBox(height: 16),
            _buildSectionHeader('🔧 تحديثات ميدانية', ''),
            const SizedBox(height: 12),
            Obx(() => Column(
                  children: controller.fieldUpdates
                      .take(5)
                      .map((update) => GestureDetector(
                            onTap: () {
                               if (update.projectId != null) {
                                  try {
                                    final project = controller.activeProjectsList.firstWhere((p) => p.id == update.projectId);
                                    Get.to(() => ProjectDetailScreen(project: project));
                                  } catch (e) {
                                    debugPrint('❌ [AdminDashboard] field update navigation error: $e');
                                  }
                               } else if (update.requestId != null) {
                                  Get.toNamed('/admin/request-detail', arguments: update.requestId);
                               }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border(right: BorderSide(color: Theme.of(context).colorScheme.primary, width: 3))),
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Obx(() {
                                    final imageUrl = controller.workerAvatarsCache[update.workerId];
                                    return CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                      backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? CachedNetworkImageProvider(imageUrl) as ImageProvider : null,
                                      child: (imageUrl == null || imageUrl.isEmpty)
                                        ? Text(update.workerName.isNotEmpty ? update.workerName[0] : '?',
                                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700))
                                        : null,
                                    );
                                  }),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(update.workerName, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13)),
                                        Text(update.description, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12), maxLines: 2),
                                        Text(_timeAgo(update.createdAt), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.75), fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  if (update.imageUrl != null)
                                    ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(imageUrl: update.imageUrl!, width: 50, height: 50, fit: BoxFit.cover)),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                )),
            const SizedBox(height: 16),
            _buildSectionHeader('💚 آخر التبرعات', ''),
            const SizedBox(height: 12),
            Obx(() => Column(
                  children: controller.recentDonations
                      .take(5)
                      .map((donation) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              onTap: () {
                                try {
                                  final project = controller.activeProjectsList.firstWhere((p) => p.id == donation.projectId);
                                  Get.to(() => ProjectDetailScreen(project: project));
                                } catch (e) {
                                  debugPrint('❌ [AdminDashboard] donation navigation error: $e');
                                }
                              },
                              leading: donation.donorId.isEmpty || donation.donorId == 'anonymous'
                                  ? Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.goldGradient),
                                      child: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Theme.of(context).colorScheme.surface,
                                        child: Icon(Icons.volunteer_activism, color: Theme.of(context).colorScheme.secondary, size: 20),
                                      ),
                                    )
                                  : StreamBuilder<DocumentSnapshot>(
                                      stream: FirebaseFirestore.instance.collection(AppConstants.usersCollection).doc(donation.donorId).snapshots(),
                                      builder: (context, userSnap) {
                                        String? imageUrl;
                                        if (userSnap.hasData && userSnap.data!.exists) {
                                          imageUrl = (userSnap.data!.data() as Map<String, dynamic>)['profileImage'];
                                        }
                                        return Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary),
                                          child: CircleAvatar(
                                            radius: 20,
                                            backgroundColor: Theme.of(context).colorScheme.surface,
                                            backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? CachedNetworkImageProvider(imageUrl) as ImageProvider : null,
                                            child: (imageUrl == null || imageUrl.isEmpty)
                                              ? Icon(Icons.volunteer_activism, color: Theme.of(context).colorScheme.primary, size: 20)
                                              : null,
                                          ),
                                        );
                                      }
                                    ),
                              title: Text(donation.donorName, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                              subtitle: Text(donation.projectName, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                              trailing: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${donation.amount.toInt()} دج', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
                                  Text(intl.DateFormat('MM/dd').format(donation.date), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10)),
                                ],
                              ),
                              tileColor: Theme.of(context).cardColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ))
                      .toList(),
                )),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICard(String label, RxInt value, IconData icon, Gradient gradient, String suffix, {VoidCallback? onTap}) {
    return VisualEffects.glassMorphism(
      borderRadius: BorderRadius.circular(20),
      opacity: 0.1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                  if (suffix.isNotEmpty) Text(suffix, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Obx(() => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: ScrollAnimations.numberCounter(
                    value: value.value,
                    isCurrency: suffix == 'دج',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              )),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUrgentRequestCard(ServiceRequestModel request) {
    final color = request.urgency == 'emergency' ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => Get.toNamed('/admin/request-detail', arguments: request),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.75), width: 1.5),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.75), blurRadius: 10)]),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.75), shape: BoxShape.circle),
                child: Icon(Icons.emergency_outlined, color: color, size: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                      Row(
                        children: [
                          Flexible(child: Text(AppConstants.translateServiceType(request.type), style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface, fontSize: 13), overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          AppTheme.statusBadge(request.urgency),
                        ],
                      ),
                  const SizedBox(height: 4),
                  Text(request.requesterName, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                  Text('${request.wilaya} - ${_timeAgo(request.createdAt)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.75), fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.primary, size: 16),
              onPressed: () => Get.toNamed('/admin/request-detail', arguments: request)
            )
          ],
        ),
      ),
    );
  }


  Widget _buildSectionHeader(String title, String actionText, {VoidCallback? onTap}) {
    return Row(
      children: [
        Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
        const Spacer(),
        if (actionText.isNotEmpty)
          TextButton(onPressed: onTap, child: Text(actionText, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12))),
      ],
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return 'منذ ${diff.inDays} يوم';
    if (diff.inHours > 0) return 'منذ ${diff.inHours} ساعة';
    if (diff.inMinutes > 0) return 'منذ ${diff.inMinutes} دقيقة';
    return 'الآن';
  }

  Widget _buildManagementTab() {
    final user = authController.currentUser.value;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
          decoration: BoxDecoration(
            gradient: Theme.of(context).brightness == Brightness.dark
              ? LinearGradient(colors: [Theme.of(context).scaffoldBackgroundColor, Theme.of(context).cardColor], begin: Alignment.topCenter, end: Alignment.bottomCenter)
              : LinearGradient(
                  colors: [Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), Theme.of(context).colorScheme.surface],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                backgroundImage: (user?.profileImage != null && user!.profileImage!.isNotEmpty)
                    ? CachedNetworkImageProvider(user.profileImage!) as ImageProvider
                    : null,
                child: (user?.profileImage == null || user!.profileImage!.isEmpty)
                    ? Text(user != null && user.name.isNotEmpty ? user.name[0] : 'A',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 28, fontWeight: FontWeight.w800))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? 'المدير', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(user?.role.displayName ?? '', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                    Text(user?.email ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Get.toNamed('/profile'),
                icon: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (user?.role.name == 'superAdmin')
          _buildSettingsTile(Icons.people, 'إدارة المستخدمين', 'موافقة وإدارة الحسابات', () => Get.toNamed('/admin/users')),
        _buildSettingsTile(Icons.miscellaneous_services, 'أنواع الخدمات', 'إضافة وتعديل أنواع الخدمات', () => Get.toNamed('/admin/service-types')),
        _buildSettingsTile(Icons.task, 'أنواع المهام', 'إضافة وتعديل أنواع المهام', () => Get.toNamed('/admin/task-types')),
        _buildSettingsTile(Icons.airport_shuttle, 'سيارات الجنازة', 'إدارة الأسطول', () => Get.toNamed('/admin/vehicles')),
        _buildSettingsTile(Icons.bar_chart, 'التقارير', 'تقارير شهرية وسنوية PDF', () => Get.toNamed('/admin/reports')),
        _buildSettingsTile(Icons.campaign_rounded, 'إعلان عام', 'إرسال تنبيه لجميع المشتركين', () => _showGlobalAnnouncementDialog()),
        const SizedBox(height: 12),
        _buildSettingsTile(Icons.inbox_rounded, 'صندوق الرسائل', 'جميع محادثاتك الخاصة والجماعية', () => setState(() => _currentIndex = _inboxIndex)),
        const SizedBox(height: 12),
        Divider(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.75), indent: 24, endIndent: 24),
        _buildSettingsTile(ThemeService().themeIcon, 'مظهر التطبيق', ThemeService().themeModeName, () => AppConstants.toggleTheme()),
        Divider(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.75), indent: 24, endIndent: 24),
        _buildSettingsTile(Icons.logout, 'تسجيل الخروج', 'الخروج من الحساب', () => _showLogoutConfirmation(), isDestructive: true),
        const SizedBox(height: 50),
      ],
    );
  }

  void _showLogoutConfirmation() {
    Get.dialog(
      AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تأكيد تسجيل الخروج',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
        content: Text('هل أنت متأكد من أنك تريد تسجيل الخروج من الحساب؟',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: 'Tajawal')),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Get.back(),
                  child: Text('إلغاء', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: 'Tajawal')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Get.back();
                    authController.logout();
                  },
                  child: Text('خروج', style: TextStyle(color: Theme.of(context).colorScheme.onError, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, VoidCallback onTap,
      {bool isDestructive = false, bool showToggle = false}) {
    final color = isDestructive ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: TextStyle(color: isDestructive ? color : Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
        subtitle: subtitle.isNotEmpty ? Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)) : null,
        trailing: showToggle
            ? Switch(value: Theme.of(context).brightness == Brightness.dark, onChanged: (v) => AppConstants.toggleTheme())
            : Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.75), size: 14),
        onTap: onTap,
      ),
    );
  }

  // Removed duplicate chat tile — chat is now accessed via the dedicated Inbox tab in the bottom bar.
  void _showGlobalAnnouncementDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    Get.dialog(
      AlertDialog(
        backgroundColor: Theme.of(Get.context!).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إرسال إعلان عام 📢',
            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: TextStyle(color: Theme.of(Get.context!).colorScheme.onSurface),
                decoration: AppTheme.inputDecoration('عنوان الإعلان...', Icons.title_rounded),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                maxLines: 4,
                style: TextStyle(color: Theme.of(Get.context!).colorScheme.onSurface),
                decoration: AppTheme.inputDecoration('محتوى الرسالة...', Icons.description_outlined),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          Obx(() => controller.isLoading.value
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : AppTheme.gradientButton(
                  text: 'إرسال للكل',
                  icon: Icons.send_rounded,
                  onPressed: () {
                    if (titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) {
                      Get.snackbar('تنبيه', 'يرجى ملء جميع الحقول');
                      return;
                    }
                    Get.back();
                    controller.sendGlobalAnnouncement(
                      title: titleCtrl.text,
                      body: bodyCtrl.text,
                    );
                  },
                )),
        ],
      ),
    );
  }
}

