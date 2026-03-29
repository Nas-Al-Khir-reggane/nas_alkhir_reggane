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
import '../../../data/services/notification_service.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  final WorkerController workerController = Get.find<WorkerController>();
  final AuthController authController = Get.find<AuthController>();
  final NotificationService notificationService = Get.find<NotificationService>();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
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
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeTab(),
            const UpdateTaskScreen(),
            _buildSupportTab(), // استبدال الدردشة الجماعية بتبويب التواصل الخاص
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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
          const SizedBox(height: 40),
          // Custom AppBar
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('أهلاً,', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
                  Obx(() => Text(
                        workerController.currentWorker.value?.name ?? 'المتطوع',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w700),
                      )),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    child: Obx(() => Text(
                          workerController.currentWorker.value?.workerRole ?? 'متطوع',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12),
                        )),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.primary, size: 28),
                onPressed: () => Get.toNamed('/profile'),
              ),
              const SizedBox(width: 8),
              Obx(() => ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: workerController.isAvailable.value 
                      ? Theme.of(context).colorScheme.primary 
                      : Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                    foregroundColor: workerController.isAvailable.value 
                      ? Theme.of(context).colorScheme.onPrimary 
                      : Theme.of(context).colorScheme.error,
                    elevation: workerController.isAvailable.value ? 2 : 0,
                  ),
                  label: Text(workerController.isAvailable.value ? 'متاح الآن' : 'غير متاح'),
                  icon: Icon(workerController.isAvailable.value ? Icons.check_circle_outline : Icons.do_not_disturb_on),
                  onPressed: () => workerController.toggleAvailability(),
                )),
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

          const SizedBox(height: 20),

          // KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildWorkerKPI(
                  'مهامي الحالية',
                  workerController.currentTasksCount,
                  Icons.pending_actions,
                  const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWorkerKPI(
                  'المنجزة',
                  workerController.completedTasksCount,
                  Icons.task_alt,
                  LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)]),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          
          // حث المتطوع على التواصل الخاص عند الحاجة
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('لأي استفسار بخصوص المهام، يرجى مراسلة أحد المدراء بشكل خاص.', 
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => setState(() => _currentIndex = 2),
                  child: Text('تواصل الآن', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

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
                    border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
                  ),
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      Icon(Icons.task_alt, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5), size: 40),
                      const SizedBox(height: 12),
                      Text('لا توجد مهام حالية', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)), textAlign: TextAlign.center),
                    ],
                  ),
                )
              : Column(
                  children: workerController.myTasks.map((request) => _buildTaskCard(request)).toList(),
                )),

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
                        Text('الدردشة مع جميع أعضاء الفريق', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7), fontSize: 12, fontFamily: 'Tajawal')),
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
              stream: FirebaseFirestore.instance.collection('users').where('role', whereIn: ['admin', 'superAdmin']).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final admin = UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          backgroundImage: (admin.profileImage != null && admin.profileImage!.isNotEmpty) ? CachedNetworkImageProvider(admin.profileImage!) as ImageProvider : null,
                          child: (admin.profileImage == null || admin.profileImage!.isEmpty) ? Text(admin.name[0], style: TextStyle(color: Theme.of(context).colorScheme.primary)) : null,
                        ),
                        title: Text(admin.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                        subtitle: Text(admin.role == UserRole.superAdmin ? 'مدير عام' : 'مدير إداري', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
                        trailing: Icon(Icons.chat_bubble_outline, color: Theme.of(context).colorScheme.primary),
                        onTap: () => Get.toNamed('/chat/private', arguments: {'userId': admin.id, 'userName': admin.name}),
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


  Widget _buildWorkerKPI(String label, dynamic value, IconData icon, Gradient gradient) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(value.toString(), style: GoogleFonts.tajawal(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildTaskCard(ServiceRequestModel request) {
    Color urgencyColor = Theme.of(context).colorScheme.primary;
    if (request.urgency == 'urgent') urgencyColor = Colors.orange;
    if (request.urgency == 'emergency') urgencyColor = Theme.of(context).colorScheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: urgencyColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: urgencyColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(10),
                  child: Icon(Icons.airport_shuttle, color: Theme.of(context).colorScheme.primary, size: 22),
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
                  decoration: BoxDecoration(color: urgencyColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(request.urgency, style: TextStyle(color: urgencyColor, fontSize: 10, fontWeight: FontWeight.bold)),
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
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Get.to(() => const UpdateTaskScreen()),
                  child: Text('تحديث حالة المهمة', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
