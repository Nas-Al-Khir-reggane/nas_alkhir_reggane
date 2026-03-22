import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/worker_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/models/service_request_model.dart';
import '../../shared/screens/chat_screen.dart';
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
  int _unreadChatCount = 0;

  @override
  void initState() {
    super.initState();
    // تتبع عدد الرسائل غير المقروءة في مجموعة الفريق
    final userId = authController.currentUser.value?.id ?? '';
    FirebaseFirestore.instance
        .collection('chats')
        .doc('group_team')
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: userId)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _unreadChatCount = snap.docs.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          const UpdateTaskScreen(),
          const ChatScreen(isWorker: true, isGroupChat: true),
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
              icon: _unreadChatCount > 0
                  ? Badge(
                      label: Text(_unreadChatCount.toString()),
                      child: const Icon(Icons.chat_bubble_outline),
                    )
                  : const Icon(Icons.chat_bubble_outline),
              activeIcon: const Icon(Icons.chat_bubble),
              label: 'الدردشة',
            ),
          ],
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
              // Toggle Availability
              Obx(() => GestureDetector(
                    onTap: () => workerController.toggleAvailability(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: workerController.isAvailable.value ? AppTheme.successColor.withValues(alpha: 0.15) : AppTheme.warningColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: workerController.isAvailable.value ? AppTheme.successColor : AppTheme.warningColor),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: workerController.isAvailable.value ? AppTheme.successColor : AppTheme.warningColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            workerController.isAvailable.value ? 'متاح' : 'مشغول',
                            style: TextStyle(
                              color: workerController.isAvailable.value ? AppTheme.successColor : AppTheme.warningColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
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
              const SizedBox(width: 12),
              Expanded(
                child: _buildWorkerKPI(
                  'الإنجاز',
                  '${workerController.completionRate.toStringAsFixed(0)}%',
                  Icons.trending_up,
                  AppTheme.goldGradient,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Last Admin Message
          Obx(() => workerController.lastAdminMessage.value != null
              ? GestureDetector(
                  onTap: () => setState(() => _currentIndex = 2),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(16),
                      border: const Border(right: BorderSide(color: AppTheme.primaryGreen, width: 4)),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(Icons.admin_panel_settings, color: AppTheme.primaryGreen, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('رسالة من المدير', style: TextStyle(color: AppTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                workerController.lastAdminMessage.value!.message,
                                style: TextStyle(color: AppTheme.textPrimary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis
                              ),
                              const Text('منذ قليل', style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: AppTheme.textHint, size: 14),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink()),

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
                  child: Column(
                    children: [
                      const Icon(Icons.task_alt, color: AppTheme.textHint, size: 40),
                      const SizedBox(height: 12),
                      const Text('لا توجد مهام حالية', style: TextStyle(color: AppTheme.textHint), textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text('أنت متاح لاستقبال مهام جديدة', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13), textAlign: TextAlign.center),
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
                    const Spacer(),
                    const Icon(Icons.phone_outlined, color: AppTheme.primaryGreen, size: 16),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse('tel:${request.phone}')),
                      child: Text(request.phone, style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 13)),
                    ),
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

                if (request.type == 'funeral_transport' || request.type == 'نقل جنازة') ...[
                  const Divider(color: AppTheme.glassBorder, height: 20),
                  Container(
                    decoration: BoxDecoration(color: AppTheme.darkSurface, borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_off_outlined, color: AppTheme.textHint, size: 14),
                            const SizedBox(width: 6),
                            Text('المتوفى: ${request.details['deceasedName'] ?? 'غير معروف'}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.place, color: AppTheme.errorColor, size: 14),
                            const SizedBox(width: 6),
                            Expanded(child: Text('من: ${request.details['pickupLocation'] ?? request.details['pickup'] ?? ''}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.flag, color: AppTheme.primaryGreen, size: 14),
                            const SizedBox(width: 6),
                            Expanded(child: Text('إلى: ${request.details['deliveryLocation'] ?? request.details['delivery'] ?? ''}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _openMapsNavigation(request),
                          child: Container(
                            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.all(10),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.navigation, color: Colors.black, size: 18),
                                SizedBox(width: 8),
                                Text('فتح الملاحة', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Divider(color: AppTheme.glassBorder, height: 20),

                Text('تحديث سريع', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickAction(request, 'progress', 'تقدم في العمل', Icons.trending_up, AppTheme.primaryGreen),
                    _buildQuickAction(request, 'arrived', 'وصلت للموقع', Icons.location_on, Colors.blue),
                    _buildQuickAction(request, 'issue', 'مشكلة', Icons.warning_outlined, AppTheme.warningColor),
                    _buildQuickAction(request, 'complete', 'إتمام المهمة', Icons.check_circle, AppTheme.successColor),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(ServiceRequestModel request, String type, String label, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        if (type == 'complete') {
          _showCompleteConfirmDialog(request);
        } else {
          _showQuickUpdateSheet(request, type, label, icon, color);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _showCompleteConfirmDialog(ServiceRequestModel request) {
    Get.defaultDialog(
      title: "تأكيد الإتمام",
      middleText: "هل أنت متأكد من إتمام هذه المهمة؟",
      textConfirm: "نعم متأكد",
      textCancel: "إلغاء",
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.primaryGreen,
      onConfirm: () {
        workerController.completeTask(request.id);
        Get.back();
      },
    );
  }

  void _showQuickUpdateSheet(ServiceRequestModel request, String type, String label, IconData icon, Color color) {
    final TextEditingController descController = TextEditingController();
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(color: AppTheme.darkSurface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إضافة تحديث', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 10),
                  Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 3,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: AppTheme.inputDecoration('وصف التحديث...', Icons.description_outlined),
            ),
            const SizedBox(height: 16),
            Obx(() => workerController.isLoading.value
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                : AppTheme.gradientButton(
                    text: 'إرسال التحديث',
                    icon: Icons.send,
                    onPressed: () {
                      workerController.submitQuickUpdate(
                        requestId: request.id,
                        type: type,
                        description: descController.text,
                      );
                      Get.back();
                    },
                  )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _openMapsNavigation(ServiceRequestModel request) async {
    final pickup = request.details['pickupLocation'] ?? request.details['pickup'] ?? '';
    final delivery = request.details['deliveryLocation'] ?? request.details['delivery'] ?? '';
    final url = 'https://www.google.com/maps/dir/?api=1&origin=${Uri.encodeComponent(pickup)}&destination=${Uri.encodeComponent(delivery)}&travelmode=driving';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }
}
