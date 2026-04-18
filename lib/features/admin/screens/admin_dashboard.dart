import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart' as intl;
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/strategic_goal_card.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/animations/scroll_animations.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/animations/micro_interactions.dart';
import '../controllers/admin_controller.dart';
import '../../chat/controllers/chat_controller.dart';
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
import '../widgets/stats_grid.dart';
import '../widgets/operational_overview.dart';
import '../widgets/prayer_post_generator.dart';
import 'manage_strategic_goals_screen.dart';
import '../widgets/mission_control_map.dart';
import '../widgets/activity_pulse.dart';
import '../../../core/widgets/role_guard.dart';
import 'project_detail_screen.dart';
import 'dar_al_sabil_management_screen.dart';
import '../widgets/dashboard_header.dart';
import '../../shared/widgets/community_pulse_card.dart';
import '../../../core/widgets/update_banner.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  final AdminController controller = Get.put(AdminController());
  final AuthController authController = Get.find<AuthController>();
  final NotificationService notificationService =
      Get.find<NotificationService>();
  final intl.NumberFormat _dzdFormat = intl.NumberFormat('#,##0');

  String _formatDzd(num amount) => '${_dzdFormat.format(amount)} دج';

  Future<bool> _onWillPop() async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تأكيد الخروج',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
          ),
        ),
        content: Text(
          'هل أنت متأكد من أنك تريد الخروج من التطبيق؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontFamily: 'Tajawal',
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Get.back(result: false),
                  child: Text(
                    'إلغاء',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontFamily: 'Tajawal',
                    ),
                  ),
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
            body: IndexedStack(index: _currentIndex, children: screens),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [_buildBottomBar(), const UpdateBanner()],
            ),
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

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
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
          selectedLabelStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
          ),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard_outlined),
              activeIcon: MicroInteractions.navIcon(
                isActive: true,
                child: const Icon(Icons.dashboard),
              ),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Obx(
                () => Badge(
                  label: Text(controller.unseenUrgentCount.value.toString()),
                  isLabelVisible: controller.unseenUrgentCount.value > 0,
                  child: const Icon(Icons.assignment_outlined),
                ),
              ),
              activeIcon: MicroInteractions.navIcon(
                isActive: true,
                child: const Icon(Icons.assignment),
              ),
              label: 'الطلبات',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.folder_outlined),
              activeIcon: MicroInteractions.navIcon(
                isActive: true,
                child: const Icon(Icons.folder),
              ),
              label: 'المشاريع',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.group_outlined),
              activeIcon: MicroInteractions.navIcon(
                isActive: true,
                child: const Icon(Icons.group),
              ),
              label: 'الفريق',
            ),
            BottomNavigationBarItem(
              icon: Obx(() {
                final chatController = Get.find<ChatController>();
                final badge = Badge(
                  label: Text(chatController.totalUnreadCount.value.toString()),
                  isLabelVisible: chatController.totalUnreadCount.value > 0,
                  backgroundColor: AppTheme.emergencyColor,
                  textColor: Colors.white,
                  child: const Icon(Icons.inbox_outlined),
                );
                return MicroInteractions.pulse(
                  enabled: chatController.totalUnreadCount.value > 0,
                  child: badge,
                );
              }),
              activeIcon: MicroInteractions.navIcon(
                isActive: true,
                child: const Icon(Icons.inbox),
              ),
              label: 'الرسائل',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              activeIcon: MicroInteractions.navIcon(
                isActive: true,
                child: const Icon(Icons.admin_panel_settings),
              ),
              label: 'الإدارة',
            ),
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
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            heroTag: 'admin_dashboard_fab',
            onPressed: () => _showActionMenu(),
            backgroundColor: Colors.transparent,
            elevation: 0,
            highlightElevation: 0,
            hoverElevation: 0,
            focusElevation: 0,
            extendedPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            icon: Icon(
              Icons.add_box_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 22,
            ),
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'إجراءات سريعة',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 16),
            _buildActionItem(Icons.volunteer_activism, 'تسجيل تبرع جديد', () {
              Get.back();
              _showAdminDonationDialog();
            }),
            _buildActionItem(Icons.add_task, 'إضافة طلب خدمة', () {
              Get.back();
              Get.toNamed('/beneficiary/new-request');
            }),
            if (controller.isSuperAdmin)
              _buildActionItem(Icons.create_new_folder, 'إضافة مشروع جديد', () {
                Get.back();
                ProjectsScreen.showAddProjectSheet(context);
              }),
            _buildActionItem(Icons.person_add, 'إضافة متطوع جديد', () {
              Get.back();
              WorkersScreen.showAddWorkerSheet(context);
            }),
          ],
        ),
      ),
    );
  }

  void _showAdminDonationDialog() {
    final donorNameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final prayerTargetCtrl = TextEditingController(); // جديد
    final prayerMessageCtrl = TextEditingController();
    String selectedMethod = 'cash';
    String selectedProject = 'general';
    String selectedProjectName = 'تبرع عام للجمعية';
    const int maxPrayerMessageWords = 20;

    int wordCount(String text) {
      return text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    }

    String trimToWordLimit(String text, int maxWords) {
      final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (words.length <= maxWords) return text.trim();
      return words.take(maxWords).join(' ');
    }
    
    // متغيرات حالة الدعاء
    bool requestPrayerPost = false;
    String selectedPrayerType = 'deceased';
    String selectedPrayerColor = 'emerald';
    String selectedPrayerAction = 'dua'; // جديد (dua أو request)

    final List<Map<String, dynamic>> prayerTypes = [
      {'id': 'deceased', 'name': 'صدقة جارية عن متوفى', 'icon': Icons.church},
      {'id': 'healing', 'name': 'دعاء بالشفاء وعافية', 'icon': Icons.healing},
      {'id': 'barakah', 'name': 'دعاء بالرزق والبركة', 'icon': Icons.account_balance_wallet},
      {'id': 'parents', 'name': 'دعاء للوالدين والمودة', 'icon': Icons.family_restroom},
      {'id': 'general', 'name': 'شكر ودعاء عام بالخير', 'icon': Icons.auto_awesome},
    ];

    final List<Map<String, dynamic>> prayerColors = [
      {'id': 'emerald', 'color': const Color(0xFF004D40)},
      {'id': 'sapphire', 'color': const Color(0xFF0D47A1)},
      {'id': 'gold', 'color': const Color(0xFF5D4037)},
      {'id': 'rose', 'color': const Color(0xFF880E4F)},
      {'id': 'slate', 'color': const Color(0xFF263238)},
    ];

    Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'تسجيل تبرع جديد',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: donorNameCtrl,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: AppTheme.inputDecoration(
                      'اسم المتبرع *',
                      Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: AppTheme.inputDecoration(
                      'المبلغ (دج) *',
                      Icons.attach_money,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Obx(() {
                    final projects = controller.activeProjectsList;
                    return DropdownButtonFormField<String>(
                      dropdownColor: Theme.of(context).cardColor,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFamily: 'Tajawal',
                      ),
                      decoration: AppTheme.inputDecoration(
                        'المشروع',
                        Icons.folder_outlined,
                      ),
                      initialValue: selectedProject,
                      items: [
                        const DropdownMenuItem(
                          value: 'general',
                          child: Text('تبرع عام للجمعية'),
                        ),
                        ...projects.map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        ),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontFamily: 'Tajawal',
                    ),
                    decoration: AppTheme.inputDecoration(
                      'طريقة الدفع',
                      Icons.payment,
                    ),
                    initialValue: selectedMethod,
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('نقداً')),
                      DropdownMenuItem(
                        value: 'bank',
                        child: Text('تحويل بنكي'),
                      ),
                      DropdownMenuItem(
                        value: 'online',
                        child: Text('دفع إلكتروني'),
                      ),
                    ],
                    onChanged: (val) =>
                        setDialogState(() => selectedMethod = val!),
                  ),
                  
                  // --- قسم طلب الدعاء (جديد) ---
                  const SizedBox(height: 20),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('طلب منشور دعاء ✨', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('توليد بطاقة احترافية للمشاركة', style: TextStyle(fontSize: 11)),
                    value: requestPrayerPost,
                    activeThumbColor: AppTheme.goldAccent,
                    onChanged: (v) => setDialogState(() => requestPrayerPost = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (requestPrayerPost) ...[
                    const SizedBox(height: 10),
                    Text('نوع الدعاء:', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: prayerTypes.map((type) {
                        final isSelected = selectedPrayerType == type['id'];
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedPrayerType = type['id'] as String),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.goldAccent.withValues(alpha: 0.1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSelected ? AppTheme.goldAccent : Colors.grey.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(type['icon'] as IconData, size: 14, color: isSelected ? AppTheme.goldAccent : Colors.grey),
                                const SizedBox(width: 4),
                                Text(type['name'] as String, style: TextStyle(fontSize: 10, color: isSelected ? AppTheme.goldAccent : Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 15),
                    Text('الهدف من المنشور:', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => selectedPrayerAction = 'dua'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedPrayerAction == 'dua' ? AppTheme.goldAccent.withValues(alpha: 0.1) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: selectedPrayerAction == 'dua' ? AppTheme.goldAccent : Colors.grey.withValues(alpha: 0.3)),
                              ),
                              child: Center(
                                child: Text(
                                  'دعاء وشكر للمتبرع',
                                  style: TextStyle(fontSize: 10, color: selectedPrayerAction == 'dua' ? AppTheme.goldAccent : Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => selectedPrayerAction = 'request'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedPrayerAction == 'request' ? AppTheme.goldAccent.withValues(alpha: 0.1) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: selectedPrayerAction == 'request' ? AppTheme.goldAccent : Colors.grey.withValues(alpha: 0.3)),
                              ),
                              child: Center(
                                child: Text(
                                  'طلب دعاء من المؤمنين',
                                  style: TextStyle(fontSize: 10, color: selectedPrayerAction == 'request' ? AppTheme.goldAccent : Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: prayerTargetCtrl,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                      decoration: AppTheme.inputDecoration('اسم الشخص المعني بالدعاء...', Icons.favorite_border),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: prayerMessageCtrl,
                      maxLines: 3,
                      onChanged: (value) {
                        final trimmed = trimToWordLimit(value, maxPrayerMessageWords);
                        if (trimmed != value.trim()) {
                          prayerMessageCtrl.value = TextEditingValue(
                            text: trimmed,
                            selection: TextSelection.collapsed(offset: trimmed.length),
                          );
                        }
                        setDialogState(() {});
                      },
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                      decoration: AppTheme.inputDecoration('النص الظاهر في البطاقة (اختياري)', Icons.edit_note),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${wordCount(prayerMessageCtrl.text)}/$maxPrayerMessageWords كلمة',
                        style: TextStyle(
                          fontSize: 11,
                          color: wordCount(prayerMessageCtrl.text) >= maxPrayerMessageWords
                              ? Colors.orange
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text('ثيم البطاقة:', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: prayerColors.map((colorItem) {
                        final isSelected = selectedPrayerColor == colorItem['id'];
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedPrayerColor = colorItem['id'] as String),
                          child: Container(
                            margin: const EdgeInsetsDirectional.only(end: 10),
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: colorItem['color'] as Color,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                              boxShadow: isSelected ? [BoxShadow(color: (colorItem['color'] as Color).withValues(alpha: 0.5), blurRadius: 5)] : null,
                            ),
                            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('إلغاء'),
              ),
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
                    final onSurfaceColor = Theme.of(
                      context,
                    ).colorScheme.onSurface;
                    await controller.registerAdminDonation(
                      donorName: donorNameCtrl.text,
                      amount: amount,
                      method: selectedMethod,
                      projectId: selectedProject,
                      projectName: selectedProjectName,
                      requestPrayerPost: requestPrayerPost,
                      prayerType: selectedPrayerType,
                      prayerTarget: prayerTargetCtrl.text,
                      prayerColor: selectedPrayerColor,
                      prayerAction: selectedPrayerAction,
                      prayerCustomMessage: trimToWordLimit(prayerMessageCtrl.text, maxPrayerMessageWords).isEmpty
                          ? null
                          : trimToWordLimit(prayerMessageCtrl.text, maxPrayerMessageWords),
                    );
                    Get.back();
                    Get.snackbar(
                      '✅ تم',
                      'تم تسجيل التبرع بنجاح',
                      backgroundColor: primaryColor.withValues(alpha: 0.15),
                      colorText: onSurfaceColor,
                    );
                  } catch (e) {
                    Get.snackbar('خطأ', 'فشل تسجيل التبرع: $e');
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String title, VoidCallback onTap) {
    return MicroInteractions.bouncingButton(
      onTap: onTap,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontFamily: 'Tajawal',
          ),
        ),
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

            const DashboardHeader(),

            const SizedBox(height: 25),

            // --- Urgent Banner (Moved to top for visibility) ---
            Obx(
              () => controller.unseenUrgentCount.value > 0
                  ? FadeIn(
                      child: GestureDetector(
                        onTap: () => setState(() => _currentIndex = 1),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 25),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD50000), Color(0xFFFF6D00)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.15),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${controller.urgentRequests.length} طلب طارئ ينتظر',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Text(
                                    'اضغط للمعالجة الفورية الآن',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // --- Verification Pending Banner ---
            Obx(
              () =>
                  controller.pendingVerificationsCount.value > 0 &&
                      controller.isSuperAdmin
                  ? FadeIn(
                      child: GestureDetector(
                        onTap: () {
                          // Navigate to Manage Users
                          Get.toNamed(AppRoutes.adminUsers);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 25),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00796B), Color(0xFF00ACC1)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withValues(alpha: 0.15),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.vignette_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${controller.pendingVerificationsCount.value} طلب توثيق هوية',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Text(
                                    'يرجى مراجعة وتوثيق بطاقات التعريف',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const RepaintBoundary(child: CommunityPulseCard()),
            const SizedBox(height: 12),

            const RoleGuard(
              allowedRoles: [UserRole.superAdmin],
              child: Padding(
                padding: EdgeInsets.only(bottom: 25),
                child: OperationalOverview(), // تم تغيير المسمى تقنياً
              ),
            ),

            // --- Humanity Challenges Section ---
            _buildHumanityChallengesSection(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المؤشرات الخيرية والميزانية',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Tajawal',
                  ),
                ),
                if (controller.isSuperAdmin)
                  Obx(
                    () => controller.isLoading.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: Icon(
                              Icons.sync_rounded,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.7),
                              size: 20,
                            ),
                            tooltip: 'إعادة مزامنة الإحصائيات',
                            onPressed: () =>
                                controller.recalculateGlobalDonations(),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const RepaintBoundary(child: StatsGrid()),

            const SizedBox(height: 24),

            // --- Mission Control Map ---
            const RepaintBoundary(child: MissionControlMap()),

            const SizedBox(height: 24),
            Obx(
              () => controller.urgentRequests.isNotEmpty
                  ? Column(
                      children: [
                        _buildSectionHeader(
                          '🚨 طلبات تحتاج تدخلاً',
                          'عرض الكل',
                          onTap: () => setState(() => _currentIndex = 1),
                        ),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: controller.urgentRequests.length > 3
                              ? 3
                              : controller.urgentRequests.length,
                          itemBuilder: (context, index) =>
                              _buildUrgentRequestCard(
                                controller.urgentRequests[index],
                              ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // --- Charity Analytics (Super Admin Only) ---
            RoleGuard(
              allowedRoles: const [UserRole.superAdmin],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('📈 اتجاهات العطاء الإنساني', ''),
                  const SizedBox(height: 12),
                  Container(
                    decoration: AppTheme.glassDecoration,
                    padding: const EdgeInsets.all(16),
                    height: 200,
                    child: Obx(() {
                      if (controller.donationsLastSixMonths.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.query_stats,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.15),
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'لا توجد بيانات تبرعات كافية',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return RepaintBoundary(
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (_) => FlLine(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.15),
                                strokeWidth: 1,
                              ),
                            ),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, _) {
                                    final index = v.toInt();
                                    if (index < 0 ||
                                        index >=
                                            controller
                                                .donationsLastSixMonths
                                                .length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Text(
                                      controller
                                          .donationsLastSixMonths[index]['month'],
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontSize: 10,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  getTitlesWidget: (v, _) => Text(
                                    '${v.toInt()}k',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: controller.donationsLastSixMonths
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) => FlSpot(
                                        e.key.toDouble(),
                                        (e.value['amount'] ?? 0.0).toDouble(),
                                      ),
                                    )
                                    .toList(),
                                isCurved: true,
                                color: Theme.of(context).colorScheme.primary,
                                barWidth: 3,
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.15),
                                ),
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, bar, index) =>
                                      FlDotCirclePainter(
                                        radius: 4,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        strokeColor: Theme.of(
                                          context,
                                        ).colorScheme.surface,
                                        strokeWidth: 2,
                                      ),
                                ),
                              ),
                            ],
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (spots) => spots
                                    .map(
                                      (s) => LineTooltipItem(
                                        '${s.y.toInt()} دج',
                                        TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontFamily: 'Tajawal',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                ],
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
                            (controller.serviceTypeDistribution.length == 1 &&
                                controller.serviceTypeDistribution[0]['name'] ==
                                    'لا يوجد')) {
                          return Center(
                            child: Icon(
                              Icons.pie_chart_outline,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.15),
                              size: 50,
                            ),
                          );
                        }
                        return PieChart(
                          PieChartData(
                            sections: controller.serviceTypeDistribution
                                .map(
                                  (item) => PieChartSectionData(
                                    value: (item['count'] ?? 0).toDouble(),
                                    color: item['color'],
                                    title: '${item['percentage']}%',
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                )
                                .toList(),
                            centerSpaceRadius: 40,
                            sectionsSpace: 3,
                            pieTouchData: PieTouchData(enabled: true),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Obx(
                        () => SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: controller.serviceTypeDistribution
                                .map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: item['color'],
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item['name'],
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                              fontSize: 11,
                                              fontFamily: 'Tajawal',
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
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
                child: Obx(
                  () => BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      barGroups: controller.monthlyRequests
                          .map(
                            (item) => BarChartGroupData(
                              x: item['day'],
                              barRods: [
                                BarChartRodData(
                                  toY: item['count'].toDouble(),
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
                                      Theme.of(context).colorScheme.secondary,
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                  width: 14,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8),
                                  ),
                                  backDrawRodData: BackgroundBarChartRodData(
                                    show: true,
                                    toY:
                                        (controller.monthlyRequests.isEmpty
                                                ? 1.0
                                                : controller.monthlyRequests
                                                          .map(
                                                            (e) =>
                                                                (e['count']
                                                                        as num)
                                                                    .toDouble(),
                                                          )
                                                          .reduce(
                                                            (a, b) =>
                                                                a > b ? a : b,
                                                          ) +
                                                      1)
                                            .toDouble(),
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.1),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (v, meta) {
                              if (v.toInt() % 5 != 0 && v.toInt() != 1) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '${v.toInt()}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                              BarTooltipItem(
                                '${rod.toY.toInt()} طلب',
                                TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionHeader(
              '📁 تقدم المشاريع',
              'عرض الكل',
              onTap: () => setState(() => _currentIndex = 2),
            ),
            const SizedBox(height: 12),
            Obx(
              () => Column(
                children: controller.activeProjectsList.take(3).map((project) {
                  final progress = project.progressRatio;
                  return GestureDetector(
                    onTap: () =>
                        Get.to(() => ProjectDetailScreen(project: project)),
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    fontFamily: 'Tajawal',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    ScrollAnimations.numberCounter(
                                      value: project.collected.toDouble(),
                                      style: GoogleFonts.tajawal(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'من ${_formatDzd(project.budget)}',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 3,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerRight,
                                    widthFactor: progress.clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.15),
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            const ActivityPulse(),
            const SizedBox(height: 16),
            _buildSectionHeader('💚 آخر التبرعات', ''),
            const SizedBox(height: 12),
            Obx(
              () => Column(
                children: controller.recentDonations
                    .take(5)
                    .map(
                      (donation) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () {
                            try {
                              final project = controller.activeProjectsList
                                  .firstWhere(
                                    (p) => p.id == donation.projectId,
                                  );
                              Get.to(
                                () => ProjectDetailScreen(project: project),
                              );
                            } catch (e) {
                              debugPrint(
                                '❌ [AdminDashboard] donation navigation error: $e',
                              );
                            }
                          },
                          leading:
                              donation.donorId.isEmpty ||
                                  donation.donorId == 'anonymous'
                              ? Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppTheme.goldGradient,
                                  ),
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    child: Icon(
                                      Icons.volunteer_activism,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                      size: 20,
                                    ),
                                  ),
                                )
                              : StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection(AppConstants.usersCollection)
                                      .doc(donation.donorId)
                                      .snapshots(),
                                  builder: (context, userSnap) {
                                    String? imageUrl;
                                    if (userSnap.hasData &&
                                        userSnap.data!.exists) {
                                      imageUrl =
                                          (userSnap.data!.data()
                                              as Map<
                                                String,
                                                dynamic
                                              >)['profileImage'];
                                    }
                                    return Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      child: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.surface,
                                        backgroundImage:
                                            (imageUrl != null &&
                                                imageUrl.isNotEmpty)
                                            ? CachedNetworkImageProvider(
                                                    imageUrl,
                                                  )
                                                  as ImageProvider
                                            : null,
                                        child:
                                            (imageUrl == null ||
                                                imageUrl.isEmpty)
                                            ? Icon(
                                                Icons.volunteer_activism,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                size: 20,
                                              )
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                          title: Text(
                            donation.donorName,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            donation.projectName,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _formatDzd(donation.amount),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    intl.DateFormat(
                                      'MM/dd',
                                    ).format(donation.date),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              if (donation.proofImageUrl != null &&
                                  donation.proofImageUrl!.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.receipt_long,
                                    color: AppTheme.goldAccent,
                                    size: 20,
                                  ),
                                  onPressed: () => _showProofImage(
                                    context,
                                    donation.id,
                                    donation.proofImageUrl!,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                              if (donation.requestPrayerPost == true) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.auto_awesome,
                                    color: AppTheme.goldAccent,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      PrayerPostGenerator.sharePrayerPost(
                                        donation,
                                        context,
                                      ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                              if (controller.isSuperAdmin) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_forever_rounded,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    Get.dialog(
                                      AlertDialog(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).cardColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        title: const Text(
                                          'تأكيد الحذف ⚠️',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Tajawal',
                                          ),
                                        ),
                                        content: Text(
                                          'هل أنت متأكد من حذف تبرع بقيمة ${_formatDzd(donation.amount)}؟ سيتم تحديث كافة الإحصائيات تلقائياً.',
                                          style: const TextStyle(
                                            fontFamily: 'Tajawal',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Get.back(),
                                            child: const Text('إلغاء'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.redAccent,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () {
                                              Get.back();
                                              controller.deleteDonation(
                                                donation,
                                              );
                                            },
                                            child: const Text(
                                              'حذف نهائي',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                          tileColor: Theme.of(context).cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentRequestCard(ServiceRequestModel request) {
    final color = request.urgency == 'emergency'
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => Get.toNamed('/admin/request-detail', arguments: request),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 10),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.emergency_outlined, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          AppConstants.translateServiceType(request.type),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppTheme.statusBadge(request.urgency),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.requesterName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${request.wilaya} - ${_timeAgo(request.createdAt)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.primary,
                size: 16,
              ),
              onPressed: () =>
                  Get.toNamed('/admin/request-detail', arguments: request),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHumanityChallengesSection() {
    return Obx(() {
      final role = authController.currentUser.value?.role;
      final isAdminOrSuper =
          role == UserRole.superAdmin || role == UserRole.admin;
      if (!isAdminOrSuper) return const SizedBox.shrink();
      if (controller.activeGoals.isEmpty) return const SizedBox.shrink();
      final canManage = role == UserRole.superAdmin;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            '🎯 أهدافنا الإنسانية الكبرى',
            canManage ? 'تعديل' : '',
            onTap: canManage
                ? () => Get.to(() => ManageStrategicGoalsScreen())
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            'ساهم وكن جزءاً من مسيرة الخير والنمو بجمعيتنا',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 16),
          ...controller.activeGoals.map(
            (goal) => StrategicGoalCard(goal: goal),
          ),
          const SizedBox(height: 24),
        ],
      );
    });
  }

  Widget _buildSectionHeader(
    String title,
    String actionText, {
    VoidCallback? onTap,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (actionText.isNotEmpty)
          TextButton(
            onPressed: onTap,
            child: Text(
              actionText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
              ),
            ),
          ),
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
    return Obx(() {
      final user = authController.currentUser.value;

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 60, 24, 30),
            decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? LinearGradient(
                      colors: [
                        Theme.of(context).scaffoldBackgroundColor,
                        Theme.of(context).cardColor,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : LinearGradient(
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.15),
                        Theme.of(context).colorScheme.surface,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.15),
                  backgroundImage:
                      (user?.profileImage != null &&
                          user!.profileImage!.isNotEmpty)
                      ? CachedNetworkImageProvider(user.profileImage!)
                            as ImageProvider
                      : null,
                  child:
                      (user?.profileImage == null ||
                          user!.profileImage!.isEmpty)
                      ? Text(
                          user != null && user.name.isNotEmpty
                              ? user.name[0]
                              : 'A',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'المدير',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        user?.role.displayName ?? '',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Get.toNamed('/profile'),
                  icon: Icon(
                    Icons.edit_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // حصر ميزات المدير العام بشكل صارم ورياكتيف
          if (controller.isSuperAdmin) ...[
            _buildSettingsTile(
              Icons.radar_rounded,
              'رادار البث التفاعلي 📡',
              'مراقبة المشاهدات والتفاعل مع الإعلانات',
              () => Get.toNamed(AppRoutes.adminBroadcastMonitor),
            ),
            _buildSettingsTile(
              Icons.campaign_rounded,
              'إعلان عام 📢',
              'إرسال نداء فوري جديد لجميع المستخدمين',
              _showGlobalAnnouncementDialog,
            ),
            const SizedBox(height: 12),
            _buildSettingsTile(
              Icons.people,
              'إدارة المستخدمين',
              'موافقة وإدارة الحسابات',
              () => Get.toNamed('/admin/users'),
            ),
            _buildSettingsTile(
              Icons.miscellaneous_services,
              'أنواع الخدمات',
              'إضافة وتعديل أنواع الخدمات',
              () => Get.toNamed('/admin/service-types'),
            ),
            _buildSettingsTile(
              Icons.task,
              'أنواع المهام',
              'إضافة وتعديل أنواع المهام',
              () => Get.toNamed('/admin/task-types'),
            ),
            _buildSettingsTile(
              Icons.track_changes_outlined,
              'الأهداف الخيرية',
              'تعديل أوامر الجمعية',
              () => Get.toNamed(AppRoutes.adminStrategicGoals),
            ),
            _buildSettingsTile(
              Icons.bar_chart,
              'التقارير وإحصائيات المردود',
              'تقارير شهرية وسنوية شاملة ومفصلة PDF',
              () => Get.toNamed('/admin/reports'),
            ),
            _buildSettingsTile(
              Icons.group_work_rounded,
              'إدارة حزب المائة ألف 🛡️',
              'متابعة المشتركين وسجل النداءات التفاعلية',
              () => Get.toNamed(AppRoutes.adminHizbManagement),
            ),
          ],

          // ✨ إدارة دار السبيل تظهر للمنسق العام ولأي مدير مفوض
          if (controller.isSuperAdmin ||
              (user?.canManageDarSabil ?? false)) ...[
            _buildSettingsTile(
              Icons.bed_rounded,
              'إدارة دار السبيل 🏠',
              'تعيين المسيرين ومتابعة المهام والنزلاء',
              () => Get.to(() => const DarSabilManagementScreen()),
            ),
          ],

          _buildSettingsTile(
            Icons.airport_shuttle,
            'سيارات الجنازة',
            'إدارة السيارات',
            () => Get.toNamed('/admin/vehicles'),
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            Icons.inbox_rounded,
            'صندوق الرسائل',
            'جميع محادثاتك الخاصة والجماعية',
            () => setState(() => _currentIndex = 4),
          ), // Index 4 is Inbox
          const SizedBox(height: 12),
          Divider(
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.15),
            indent: 24,
            endIndent: 24,
          ),
          _buildSettingsTile(
            ThemeService().themeIcon,
            'مظهر التطبيق',
            ThemeService().themeModeName,
            () => AppConstants.toggleTheme(),
          ),
          Divider(
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.15),
            indent: 24,
            endIndent: 24,
          ),
          _buildSettingsTile(
            Icons.logout,
            'تسجيل الخروج',
            'الخروج من الحساب',
            () => _showLogoutConfirmation(),
            isDestructive: true,
          ),
          const SizedBox(height: 50),
        ],
      );
    });
  }

  void _showLogoutConfirmation() {
    Get.dialog(
      AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تأكيد تسجيل الخروج',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
          ),
        ),
        content: Text(
          'هل أنت متأكد من أنك تريد تسجيل الخروج من الحساب؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontFamily: 'Tajawal',
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Get.back(),
                  child: Text(
                    'إلغاء',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Get.back();
                    authController.logout();
                  },
                  child: Text(
                    'خروج',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onError,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool isDestructive = false,
    bool showToggle = false,
  }) {
    final color = isDestructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive
                ? color
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              )
            : null,
        trailing: showToggle
            ? Switch(
                value: Theme.of(context).brightness == Brightness.dark,
                onChanged: (v) => AppConstants.toggleTheme(),
              )
            : Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                size: 14,
              ),
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
        title: Column(
          children: [
            const Text(
              'إرسال نداء عام تفاعلي 📢',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'سيتم تتبع المشاهدات وظهورها في الرادار',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(Get.context!).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: TextStyle(
                  color: Theme.of(Get.context!).colorScheme.onSurface,
                ),
                decoration: AppTheme.inputDecoration(
                  'عنوان النداء (مثلاً: نداء استغاثة عاجل)',
                  Icons.title_rounded,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                maxLines: 4,
                style: TextStyle(
                  color: Theme.of(Get.context!).colorScheme.onSurface,
                ),
                decoration: AppTheme.inputDecoration(
                  'محتوى النداء وتوجيهات للمجتمع...',
                  Icons.description_outlined,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    Get.context!,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      Get.context!,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Theme.of(Get.context!).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'هذا نظام لا يرسل إشعارات PUSH هادئة، بل يظهر كبطاقة تفاعلية داخل التطبيق.',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(Get.context!).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          Obx(
            () => controller.isLoading.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : AppTheme.gradientButton(
                    text: 'نشر النداء وتفعيل الرادار',
                    icon: Icons.rocket_launch_rounded,
                    onPressed: () async {
                      if (titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) {
                        Get.snackbar('تنبيه', 'يرجى ملء جميع الحقول');
                        return;
                      }
                      Get.back();
                      await controller.sendGlobalBroadcast(
                        title: titleCtrl.text,
                        body: bodyCtrl.text,
                      );
                      // فتح الرادار تلقائياً بعد الإرسال
                      Get.toNamed(AppRoutes.adminBroadcastMonitor);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showProofImage(BuildContext context, String donationId, String url) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: CachedNetworkImage(
                imageUrl: url,
                placeholder: (context, url) => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.error),
                fit: BoxFit.contain,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                    label: const Text(
                      'إغلاق',
                      style: TextStyle(fontFamily: 'Tajawal'),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Get.back();
                      Get.dialog(
                        AlertDialog(
                          title: const Text(
                            'حذف الإثبات؟',
                            style: TextStyle(fontFamily: 'Tajawal'),
                          ),
                          content: const Text(
                            'سيتم حذف الصورة نهائياً لتوفير المساحة. هل أنت متأكد؟',
                            style: TextStyle(fontFamily: 'Tajawal'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back(),
                              child: const Text('إلغاء'),
                            ),
                            TextButton(
                              onPressed: () {
                                Get.back();
                                controller.clearDonationProof(donationId);
                              },
                              child: const Text(
                                'حذف الإثبات',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      foregroundColor: Colors.red,
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: const Text(
                      'مسح الإثبات',
                      style: TextStyle(fontFamily: 'Tajawal'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
