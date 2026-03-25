import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/worker_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/user_model.dart';
import '../../chat/screens/chat_screen.dart';
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
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تأكيد الخروج',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
        content: Text('هل أنت متأكد من أنك تريد الخروج من التطبيق؟',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Tajawal')),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Get.back(result: false),
                  child: const Text('إلغاء', style: TextStyle(color: AppTheme.textHint, fontFamily: 'Tajawal')),
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
        final shouldPop = await _onWillPop();
        if (shouldPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.darkBg,
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
            color: AppTheme.darkSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: AppTheme.darkShadow,
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: AppTheme.primaryGreen,
            unselectedItemColor: AppTheme.textHint,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'مهامي',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_outline),
                activeIcon: Icon(Icons.add_circle),
                label: 'تحديث',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.support_agent_outlined),
                activeIcon: Icon(Icons.support_agent),
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
                  Text('أهلاً,', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  Obx(() => Text(
                        workerController.currentWorker.value?.name ?? 'المتطوع',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                      )),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    child: Obx(() => Text(
                          workerController.currentWorker.value?.workerRole ?? 'متطوع',
                          style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 12),
                        )),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.person_outline, color: AppTheme.primaryGreen, size: 28),
                onPressed: () => Get.toNamed('/profile'),
              ),
              const SizedBox(width: 8),
              Obx(() => Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_outlined, color: AppTheme.textSecondary),
                    onPressed: () => Get.toNamed('/notifications'),
                  ),
                  if (notificationService.unreadCount.value > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AppTheme.errorColor, shape: BoxShape.circle),
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
                  AppTheme.primaryGradient,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          
          // حث المتطوع على التواصل الخاص عند الحاجة
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.primaryGreen),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('لأي استفسار بخصوص المهام، يرجى مراسلة أحد المدراء بشكل خاص.', 
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => setState(() => _currentIndex = 2),
                  child: const Text('تواصل الآن', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // My Tasks Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('📋 مهامي الحالية', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              TextButton(
                onPressed: _showAllTasks,
                child: const Text('عرض الكل', style: TextStyle(color: AppTheme.primaryGreen)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Obx(() => workerController.myTasks.isEmpty
              ? Container(
                  width: double.infinity,
                  decoration: AppTheme.glassDecoration,
                  padding: const EdgeInsets.all(30),
                  child: const Column(
                    children: [
                      Icon(Icons.task_alt, color: AppTheme.textHint, size: 40),
                      SizedBox(height: 12),
                      Text('لا توجد مهام حالية', style: TextStyle(color: AppTheme.textHint), textAlign: TextAlign.center),
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
          const Text('🛡️ التواصل مع الإدارة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const Text('اختر مديراً لمراسلته بخصوص عملك أو تقديم تقرير', style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('role', whereIn: ['admin', 'superAdmin']).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final admins = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: admins.length,
                  itemBuilder: (context, index) {
                    final admin = UserModel.fromMap(admins[index].data() as Map<String, dynamic>, admins[index].id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                          backgroundImage: (admin.profileImage != null && admin.profileImage!.isNotEmpty) ? NetworkImage(admin.profileImage!) : null,
                          child: (admin.profileImage == null || admin.profileImage!.isEmpty) ? Text(admin.name[0], style: const TextStyle(color: AppTheme.primaryGreen)) : null,
                        ),
                        title: Text(admin.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(admin.role == UserRole.superAdmin ? 'مدير عام' : 'مدير إداري', style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 12)),
                        trailing: const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryGreen),
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
            decoration: const BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('جميع مهامي',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 16),
                Expanded(
                  child: Obx(() => workerController.myTasks.isEmpty
                      ? const Center(
                          child: Text('لا توجد مهام حالياً',
                              style: TextStyle(color: AppTheme.textHint)))
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
        boxShadow: AppTheme.darkShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(value.toString(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildTaskCard(ServiceRequestModel request) {
    Color urgencyColor = AppTheme.primaryGreen;
    if (request.urgency == 'urgent') urgencyColor = AppTheme.urgentColor;
    if (request.urgency == 'emergency') urgencyColor = AppTheme.emergencyColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: urgencyColor.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: urgencyColor.withValues(alpha: 0.15), blurRadius: 12)],
      ),
      child: Column(
        children: [
          // Card Header
          Container(
            decoration: BoxDecoration(
              color: urgencyColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(10),
                  child: const Icon(Icons.airport_shuttle, color: AppTheme.primaryGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.type, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                      Text('#${request.id.substring(0, 8)}', style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
                    ],
                  ),
                ),
                AppTheme.statusBadge(request.urgency),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, color: AppTheme.textHint, size: 16),
                    const SizedBox(width: 6),
                    Text(request.requesterName, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: AppTheme.textHint, size: 16),
                    const SizedBox(width: 6),
                    Text('${request.wilaya} - ${request.address}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
                const Divider(color: AppTheme.glassBorder, height: 20),
                AppTheme.gradientButton(
                  text: 'تحديث حالة المهمة',
                  onPressed: () => Get.to(() => const UpdateTaskScreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
