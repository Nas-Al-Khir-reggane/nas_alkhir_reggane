import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_routes.dart';
import '../../chat/controllers/chat_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../controllers/worker_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/user_model.dart';
import './update_task_screen.dart';
import './task_detail_screen.dart';
import '../../admin/screens/dar_al_sabil_management_screen.dart';

import '../../../data/services/notification_service.dart';
import '../../shared/widgets/community_pulse_card.dart';
import '../../../core/animations/scroll_animations.dart';
import '../../../core/animations/sound_manager.dart';
import '../../../core/widgets/update_banner.dart';


class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  final WorkerController workerController = Get.find<WorkerController>();
  final AuthController authController = Get.find<AuthController>();
  final NotificationService notificationService = Get.find<NotificationService>();
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

  Future<void> _openDirectAdminChat(UserModel admin) async {
    final myId = authController.currentUser.value?.id ?? '';
    if (myId.isEmpty || admin.id.isEmpty) {
      Get.snackbar(
        'تعذر فتح المحادثة',
        'الرجاء إعادة تسجيل الدخول ثم المحاولة مرة أخرى',
        backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.15),
        colorText: Theme.of(context).colorScheme.error,
      );
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
                  const UpdateTaskScreen(),
                  if (authController.currentUser.value?.canManageDarSabil ?? false)
                    const DarSabilManagementScreen(),
                  _buildSupportTab(),
                ],
              ),
            ),
            const UpdateBanner(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
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
            unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'مهامي',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_outline),
                activeIcon: Icon(Icons.add_circle),
                label: 'تحديث',
              ),
              if (authController.currentUser.value?.canManageDarSabil ?? false)
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_work_outlined),
                  activeIcon: Icon(Icons.home_work),
                  label: 'دار السبيل',
                ),
              BottomNavigationBarItem(
                icon: Obx(() {
                  final chatController = Get.find<ChatController>();
                  return Badge(
                    label: Text(chatController.totalUnreadCount.value.toString()),
                    isLabelVisible: chatController.totalUnreadCount.value > 0,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    textColor: Theme.of(context).colorScheme.onPrimary,
                    child: const Icon(Icons.support_agent_outlined),
                  );
                }),
                activeIcon: const Icon(Icons.support_agent),
                label: 'الإدارة',
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
        children: [
          const SizedBox(height: 20),
          // Custom AppBar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('أهلاً,', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
                    Obx(() => Text(
                          workerController.currentWorker.value?.name ?? 'المتطوع',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      child: Obx(() => Text(
                            workerController.currentWorker.value?.workerRole ?? 'متطوع',
                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11),
                          )),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.primary, size: 26),
                onPressed: () => Get.toNamed('/profile'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Obx(() => FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: workerController.isAvailable.value 
                        ? Theme.of(context).colorScheme.primary 
                        : Theme.of(context).colorScheme.error.withValues(alpha: 0.15),
                      foregroundColor: workerController.isAvailable.value 
                        ? Theme.of(context).colorScheme.onPrimary 
                        : Theme.of(context).colorScheme.error,
                      elevation: workerController.isAvailable.value ? 2 : 0,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    label: Text(workerController.isAvailable.value ? 'متاح الآن' : 'غير متاح', style: const TextStyle(fontSize: 12)),
                    icon: Icon(workerController.isAvailable.value ? Icons.check_circle_outline : Icons.do_not_disturb_on, size: 18),
                    onPressed: () => workerController.toggleAvailability(),
                  ),
                )),
              ),
              Obx(() => Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    onPressed: () => Get.toNamed('/notifications'),
                  ),
                  if (notificationService.unreadCount.value > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.error, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                        child: Text(
                          notificationService.unreadCount.value.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                ],
              )),
            ],
          ),

          const CommunityPulseCard(),
          const SizedBox(height: 8),

          // KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildWorkerKPI(
                  'مهامي الحالية',
                  workerController.currentTasksCount,
                  Icons.pending_actions,
                  const LinearGradient(colors: [Colors.orange, AppTheme.urgentColor]),
                  onTap: _showAllTasks,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWorkerKPI(
                  'المنجزة',
                  workerController.completedTasksCount,
                  Icons.task_alt,
                  LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withValues(alpha: 0.9)]),
                  onTap: _showCompletedTasks,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Obx(() {
            final completed = workerController.completedTasks.length;
            const tasksPerLevel = 5;
            final currentLevel = (completed ~/ tasksPerLevel) + 1;
            final progress = (completed % tasksPerLevel) / tasksPerLevel;
            final remaining = tasksPerLevel - (completed % tasksPerLevel);

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.workspace_premium_rounded, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'مستوى المتطوع $currentLevel',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    remaining == tasksPerLevel
                        ? 'أكمل $tasksPerLevel مهام للانتقال إلى المستوى التالي'
                        : 'متبقي $remaining مهام للمستوى التالي',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 24),
          
          // My Tasks Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('📋 مهامي الحالية', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700)),
              TextButton(
                onPressed: _showAllTasks,
                child: Text('عرض الكل', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Obx(() => workerController.myTasks.isEmpty
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
                      Icon(Icons.task_alt, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.15), size: 40),
                      const SizedBox(height: 12),
                      Text('لا توجد مهام حالية', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                    ],
                  ),
                )
              : Column(
                  children: workerController.myTasks.map((request) => _buildTaskCard(request)).toList(),
                )),

          // ======== 🆕 قسم الخدمات الإضافية ========
          Obx(() {
            final user = workerController.currentWorker.value;
            if (user == null || user.additionalRoles.isEmpty) return const SizedBox.shrink();

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
                
                if (user.additionalRoles.contains('canDonate')) ...[
                  _buildExtraServiceCard(
                    title: 'تبرع بالدم',
                    subtitle: 'تصفح نداءات الطوارئ وسجل تبرعك',
                    icon: Icons.bloodtype,
                    color: Colors.redAccent,
                    onTap: () => authController.switchActiveRole(UserRole.donor),
                  ),
                  const SizedBox(height: 12),
                  _buildExtraServiceCard(
                    title: 'التبرع المالي والدعم',
                    subtitle: 'تصفح المشاريع وساهم في الخير',
                    icon: Icons.favorite_rounded,
                    color: Colors.pinkAccent,
                    onTap: () => Get.toNamed(AppRoutes.donorDonate),
                  ),
                  const SizedBox(height: 10),
                ],
                
                if (user.additionalRoles.contains('canRequestService')) ...[
                  _buildExtraServiceCard(
                    title: 'طلب خدمة / مساعدة',
                    subtitle: 'طلب دعم من الجمعية أو خدمة معينة',
                    icon: Icons.handshake,
                    color: Colors.orange,
                    onTap: () => authController.switchActiveRole(UserRole.beneficiary),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          }),
          // ===========================================

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSupportTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text('🛡️ التواصل مع الإدارة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          Text('اختر مديراً لمراسلته بخصوص عملك أو تقديم تقرير', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 16),
          // Group team chat button
          GestureDetector(
            onTap: () => Get.toNamed(AppRoutes.chatGroup, arguments: {
              'chatId': 'group_team',
              'groupName': 'غرفة الفريق الجماعية',
            }),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.groups_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('غرفة الفريق الجماعية', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 15, fontFamily: 'Tajawal')),
                        Text('الدردشة مع جميع أعضاء الفريق', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.15), fontSize: 12, fontFamily: 'Tajawal')),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.onPrimary, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('💬 تواصل مباشر مع الإدارة', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _adminsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final admins = snapshot.data!.docs
                    .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
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
                    child: Text(
                      'لا يوجد مدراء متاحون حالياً للتواصل',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: admins.length,
                  itemBuilder: (context, index) {
                    final admin = admins[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          backgroundImage: (admin.profileImage != null && admin.profileImage!.isNotEmpty) ? CachedNetworkImageProvider(admin.profileImage!) as ImageProvider : null,
                          child: (admin.profileImage == null || admin.profileImage!.isEmpty) ? Text(admin.name[0], style: TextStyle(color: Theme.of(context).colorScheme.primary)) : null,
                        ),
                        title: Text(admin.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                        subtitle: Text(admin.role == UserRole.superAdmin ? 'مدير عام' : 'مدير إداري', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
                        trailing: Icon(Icons.chat_bubble_outline, color: Theme.of(context).colorScheme.primary),
                        onTap: () => _openDirectAdminChat(admin),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAllTasks() {
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
                Text('جميع مهامي',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 16),
                Expanded(
                  child: Obx(() => workerController.myTasks.isEmpty
                      ? Center(
                          child: Text('لا توجد مهام حالياً',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: workerController.myTasks.length,
                          itemBuilder: (context, index) {
                            final task = workerController.myTasks[index];
                            return _buildTaskCard(task);
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

  void _showCompletedTasks() {
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
                Text('المهام المنجزة ✅',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 16),
                Expanded(
                  child: Obx(() => workerController.completedTasks.isEmpty
                      ? Center(
                          child: Text('لم تقم بإنجاز أي مهام بعد',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: workerController.completedTasks.length,
                          itemBuilder: (context, index) {
                            final task = workerController.completedTasks[index];
                            return _buildTaskCard(task, isCompleted: true);
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


  Widget _buildWorkerKPI(String label, dynamic value, IconData icon, Gradient gradient, {VoidCallback? onTap}) {
    final card = Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: gradient.colors.first.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 12),
          ScrollAnimations.numberCounter(
            value: value is num ? value : num.tryParse(value.toString()) ?? 0,
            style: GoogleFonts.tajawal(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          Text(label, style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: card,
      ),
    );
  }

  Widget _buildTaskCard(ServiceRequestModel request, {bool isCompleted = false}) {
    Color urgencyColor = isCompleted ? AppTheme.primaryGreen : Theme.of(context).colorScheme.primary;
    if (!isCompleted) {
      if (request.urgency == 'urgent') urgencyColor = Colors.orange;
      if (request.urgency == 'emergency') urgencyColor = Theme.of(context).colorScheme.error;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Get.to(() => TaskDetailScreen(task: request)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: urgencyColor.withValues(alpha: 0.15)),
        ),
        child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: urgencyColor.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(10),
                  child: Icon(AppConstants.getServiceIcon(request.type), color: Theme.of(context).colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppConstants.translateServiceType(request.type), style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 15)),
                      Text('#${request.id.substring(0, 8)}', style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: urgencyColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(isCompleted ? 'مكتملة' : request.urgency, style: TextStyle(color: urgencyColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 16),
                    const SizedBox(width: 6),
                    Text(request.requesterName, style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 16),
                    const SizedBox(width: 6),
                    Text('${request.wilaya} - ${request.address}', style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
                const Divider(height: 20),
                if (!isCompleted)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Get.to(() => const UpdateTaskScreen(), arguments: request),
                    child: Text('تحديث حالة المهمة', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Get.to(() => TaskDetailScreen(task: request)),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('عرض التفاصيل كاملة'),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    ),
    );
  }

  Widget _buildExtraServiceCard({
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
