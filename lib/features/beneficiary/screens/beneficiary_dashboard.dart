import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/beneficiary_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import 'new_request_screen.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/services/notification_service.dart';

class BeneficiaryDashboard extends StatefulWidget {
  const BeneficiaryDashboard({super.key});

  @override
  State<BeneficiaryDashboard> createState() => _BeneficiaryDashboardState();
}

class _BeneficiaryDashboardState extends State<BeneficiaryDashboard> {
  final BeneficiaryController controller = Get.put(BeneficiaryController());
  final AuthController authController = Get.find<AuthController>();
  final NotificationService notificationService = Get.find<NotificationService>();
  int _currentIndex = 0;

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
            const NewRequestScreen(),
            _buildActivitiesTab(),
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
                label: 'الرئيسية',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_outline),
                activeIcon: Icon(Icons.add_circle),
                label: 'طلب جديد',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.newspaper_outlined),
                activeIcon: Icon(Icons.newspaper),
                label: 'الأنشطة',
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
          const SizedBox(height: 40),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('أهلاً,',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  Obx(() => Text(
                        controller.currentBeneficiary.value?.name ?? 'المستفيد',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                      )),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.person, color: AppTheme.primaryGreen),
                onPressed: () => Get.toNamed('/profile'),
              ),
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
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                ],
              )),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _currentIndex = 1),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppTheme.greenGlow,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.add, color: Colors.black, size: 20),
                      const SizedBox(width: 6),
                      Text('طلب جديد',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.darkCard, AppTheme.darkSurface]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('جمعية ناس الخير رقان',
                          style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      SizedBox(height: 4),
                      Text('نحن هنا لمساعدتك\nلا تتردد في طلب أي خدمة',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
                    ],
                  ),
                  Spacer(),
                  Icon(Icons.volunteer_activism, color: AppTheme.primaryGreen, size: 50),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('📋 طلباتي', 'عرض الكل', onTap: _showAllRequests),
          const SizedBox(height: 12),
          Obx(() => controller.myRequests.isEmpty
              ? Container(
                  width: double.infinity,
                  decoration: AppTheme.glassDecoration,
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      const Icon(Icons.inbox, color: AppTheme.textHint, size: 40),
                      const SizedBox(height: 12),
                      Text('لا توجد طلبات بعد',
                          style: TextStyle(color: AppTheme.textHint), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      AppTheme.gradientButton(
                        text: 'اطلب خدمة الآن',
                        icon: Icons.add,
                        onPressed: () => setState(() => _currentIndex = 1),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: controller.myRequests.take(5).map((request) {
                    return GestureDetector(
                      onTap: () => Get.toNamed('/beneficiary/request-status', arguments: request),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: AppTheme.cardShadow,
                          border: Border.all(
                              color: _urgencyBorderColor(request.urgency).withValues(alpha: 0.3)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: _serviceTypeColor(request.type).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Icon(_serviceTypeIcon(request.type),
                                  color: _serviceTypeColor(request.type), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_serviceTypeName(request.type),
                                      style: TextStyle(
                                          color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  _buildRequestProgressBar(request.status),
                                  const SizedBox(height: 4),
                                  Text(_timeAgo(request.createdAt),
                                      style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                AppTheme.statusBadge(request.status),
                                if (request.status == 'completed' &&
                                    request.toMap()['rating'] == null)
                                  GestureDetector(
                                    onTap: () => _showRateServiceDialog(request),
                                    child: Container(
                                      margin: const EdgeInsets.only(top: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.goldAccent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Text('قيّم الخدمة ⭐',
                                          style: TextStyle(color: AppTheme.goldAccent, fontSize: 11)),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildActivitiesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('عذراً، تعذر جلب الأنشطة', style: TextStyle(color: AppTheme.errorColor)),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
        }
        final projects = snapshot.data!.docs;
        if (projects.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.volunteer_activism, color: AppTheme.textHint, size: 60),
                const SizedBox(height: 16),
                Text('لا توجد أنشطة حالية', style: TextStyle(color: AppTheme.textHint)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final data = projects[index].data() as Map<String, dynamic>;
            final name = data['name'] ?? 'مشروع';
            final description = (data['description'] ?? '') as String;
            final goal = (data['budget'] ?? data['goal'] ?? 0).toDouble();
            final collected = (data['collected'] ?? 0).toDouble();
            final progress = goal > 0 ? (collected / goal).clamp(0.0, 1.0) : 0.0;
            final progressPercent = (progress * 100).toInt();
            final remaining = (goal - collected).clamp(0.0, double.infinity);
            const categoryColor = AppTheme.primaryGreen;

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0x2E4CAF50),
                    Color(0xFF1C1C2E),
                    Color(0xFF1C1C2E),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: categoryColor.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(color: categoryColor.withValues(alpha: 0.2), blurRadius: 18, offset: const Offset(0, 7)),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [categoryColor.withValues(alpha: 0.3), categoryColor.withValues(alpha: 0.06)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: categoryColor.withValues(alpha: 0.5)),
                          ),
                          child: const Icon(Icons.volunteer_activism, color: categoryColor, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: categoryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('نشط', style: TextStyle(color: categoryColor, fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Circular Progress + Stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100, height: 100,
                          child: CustomPaint(
                            painter: _BenefArcPainter(progress: progress),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('$progressPercent%',
                                      style: const TextStyle(color: categoryColor, fontWeight: FontWeight.w900, fontSize: 22, height: 1)),
                                  const Text('اكتمل', style: TextStyle(color: AppTheme.textHint, fontSize: 9)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (description.isNotEmpty)
                                Text(description,
                                    maxLines: 2, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
                              const SizedBox(height: 10),
                              _activityStatRow('جُمع', '${collected.toInt()} دج', categoryColor),
                              const SizedBox(height: 5),
                              _activityStatRow('الهدف', '${goal.toInt()} دج', AppTheme.textSecondary),
                              const SizedBox(height: 5),
                              _activityStatRow('المتبقى', '${remaining.toInt()} دج', AppTheme.warningColor),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Progress bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: AppTheme.darkSurface,
                        valueColor: const AlwaysStoppedAnimation<Color>(categoryColor),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Divider(color: AppTheme.glassBorder, height: 1),

                  // Share button
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: GestureDetector(
                      onTap: () {
                        final shareText =
                            'مشروع: $name\n'
                            'التقدم: $progressPercent%\n'
                            'جُمع: ${collected.toInt()} دج\n'
                            'الهدف: ${goal.toInt()} دج\n'
                            'ادعمنا في جمعية ناس الخير.';
                        Share.share(shareText, subject: 'مشروع $name - ناس الخير');
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.glassBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.share_outlined, color: AppTheme.textSecondary, size: 16),
                            const SizedBox(width: 6),
                            Text('شارك هذا المشروع', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _activityStatRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }


  Widget _buildSectionHeader(String title, String action, {VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        if (action.isNotEmpty)
          TextButton(
            onPressed: onTap,
            child: Text(action, style: TextStyle(color: AppTheme.primaryGreen)),
          ),
      ],
    );
  }

  void _showAllRequests() {
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
                Text('جميع طلباتي',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 16),
                Expanded(
                  child: Obx(() => controller.myRequests.isEmpty
                      ? const Center(
                          child: Text('لا توجد طلبات بعد',
                              style: TextStyle(color: AppTheme.textHint)))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: controller.myRequests.length,
                          itemBuilder: (context, index) {
                            final request = controller.myRequests[index];
                            return GestureDetector(
                              onTap: () {
                                Get.back();
                                Get.toNamed('/beneficiary/request-status',
                                    arguments: request);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkCard,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: _urgencyBorderColor(request.urgency)
                                          .withValues(alpha: 0.3)),
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: _serviceTypeColor(request.type)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(_serviceTypeIcon(request.type),
                                          color: _serviceTypeColor(request.type),
                                          size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_serviceTypeName(request.type),
                                              style: TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontWeight: FontWeight.w600)),
                                          Text(_timeAgo(request.createdAt),
                                              style: TextStyle(
                                                  color: AppTheme.textHint,
                                                  fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    AppTheme.statusBadge(request.status),
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

  Widget _buildRequestProgressBar(String status) {
    final List<String> stages = ['pending', 'in_progress', 'completed'];
    int currentStageIndex = stages.indexOf(status);
    if (currentStageIndex == -1 && status == 'rejected') currentStageIndex = -1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: stages.asMap().entries.map((entry) {
        int idx = entry.key;
        String s = entry.value;
        bool isReached = idx <= currentStageIndex;

        return Expanded(
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: isReached ? AppTheme.primaryGreen : AppTheme.darkSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: isReached ? AppTheme.primaryGreen : AppTheme.glassBorder),
                ),
                child: isReached
                    ? const Icon(Icons.check, color: Colors.black, size: 10)
                    : null,
              ),
              if (s != 'completed')
                Expanded(
                  child: Container(
                    height: 2,
                    color: (idx < currentStageIndex) ? AppTheme.primaryGreen : AppTheme.glassBorder,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showRateServiceDialog(ServiceRequestModel request) {
    int selectedRating = 5;
    final commentController = TextEditingController();

    Get.dialog(
      StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('كيف كانت الخدمة؟', style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [1, 2, 3, 4, 5].map((s) => GestureDetector(
                  onTap: () => setModalState(() => selectedRating = s),
                  child: Icon(
                    s <= selectedRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 36,
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: AppTheme.inputDecoration('تعليق (اختياري)...', Icons.comment),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
            AppTheme.gradientButton(
              text: 'إرسال',
              onPressed: () => controller.rateService(request.id, selectedRating, commentController.text),
            ),
          ],
        ),
      ),
    );
  }

  Color _urgencyBorderColor(String urgency) {
    switch (urgency) {
      case 'emergency': return AppTheme.emergencyColor;
      case 'urgent': return AppTheme.urgentColor;
      default: return AppTheme.primaryGreen;
    }
  }

  Color _serviceTypeColor(String typeId) {
    final service = controller.availableServices.firstWhereOrNull((s) => s.id == typeId);
    if (service != null) {
      // يمكنك تخصيص الألوان بناءً على نوع الخدمة
      if (typeId == 'funeral_transport') return Colors.deepPurple;
      return AppTheme.primaryGreen;
    }
    return AppTheme.primaryGreen;
  }

  IconData _serviceTypeIcon(String typeId) {
    if (typeId == 'funeral_transport') return Icons.airport_shuttle;
    return Icons.help_outline;
  }

  String _serviceTypeName(String typeId) {
    final service = controller.availableServices.firstWhereOrNull((s) => s.id == typeId);
    return service?.name ?? typeId;
  }

  String _timeAgo(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);
    if (duration.inDays > 0) return 'منذ ${duration.inDays} يوم';
    if (duration.inHours > 0) return 'منذ ${duration.inHours} ساعة';
    if (duration.inMinutes > 0) return 'منذ ${duration.inMinutes} دقيقة';
    return 'الآن';
  }
}

// ===== Arc Progress Painter (Beneficiary) =====
class _BenefArcPainter extends CustomPainter {
  final double progress;
  const _BenefArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 9.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;
    const startAngle = -2.356;
    const sweepAngle = 4.712;

    final bgPaint = Paint()
      ..color = const Color(0xFF2A2A3E)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, bgPaint);

    if (progress > 0) {
      final fgPaint = Paint()
        ..color = AppTheme.primaryGreen
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle * progress, false, fgPaint);

      final glowPaint = Paint()
        ..color = AppTheme.primaryGreen.withValues(alpha: 0.25)
        ..strokeWidth = strokeWidth + 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle * progress, false, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_BenefArcPainter old) => old.progress != progress;
}
