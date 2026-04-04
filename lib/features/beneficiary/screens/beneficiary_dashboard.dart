import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/beneficiary_controller.dart';
import '../../chat/controllers/chat_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import 'new_request_screen.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/notification_service.dart';
import '../../shared/widgets/community_pulse_card.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/animations/sound_manager.dart';


class BeneficiaryDashboard extends StatefulWidget {
  const BeneficiaryDashboard({super.key});

  @override
  State<BeneficiaryDashboard> createState() => _BeneficiaryDashboardState();
}

class _BeneficiaryDashboardState extends State<BeneficiaryDashboard> {
  final BeneficiaryController controller = Get.put(BeneficiaryController());
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
      Get.snackbar('تعذر فتح المحادثة', 'الرجاء إعادة تسجيل الدخول ثم المحاولة مرة أخرى');
      return;
    }

    final sortedIds = [myId, admin.id]..sort();
    final chatId = '${sortedIds[0]}_${sortedIds[1]}';

    Get.toNamed('/chat/private', arguments: {
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeTab(),
            const NewRequestScreen(),
            _buildActivitiesTab(),
            _buildContactTab(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, -2))
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
                label: 'الرئيسية',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_outline),
                activeIcon: Icon(Icons.add_circle),
                label: 'طلب جديد',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.newspaper_outlined),
                activeIcon: Icon(Icons.newspaper),
                label: 'الأنشطة',
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
                label: 'تواصل',
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
          const SizedBox(height: 10),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('أهلاً,',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
                  Obx(() => Text(
                        controller.currentBeneficiary.value?.name ?? 'المستفيد',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                      )),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                onPressed: () => Get.toNamed('/profile'),
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
                          style: TextStyle(color: Theme.of(context).colorScheme.onError, fontSize: 10, fontWeight: FontWeight.w900, height: 1),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary, size: 20),
                      const SizedBox(width: 6),
                      Text('طلب جديد',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
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
              gradient: LinearGradient(colors: [Theme.of(context).cardColor, Theme.of(context).colorScheme.surface]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
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
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('نحن هنا لمساعدتك\nلا تتردد في طلب أي خدمة',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.volunteer_activism, color: Theme.of(context).colorScheme.primary, size: 50),
                ],
              ),
            ),
          ),
          const CommunityPulseCard(),
          const SizedBox(height: 12),
          _buildSectionHeader('📋 طلباتي', 'عرض الكل', onTap: _showAllRequests),
          const SizedBox(height: 12),
          Obx(() => controller.myRequests.isEmpty
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
                      Icon(Icons.inbox, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 40),
                      const SizedBox(height: 12),
                      Text('لا توجد طلبات بعد',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
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
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))
                          ],
                          border: Border.all(
                              color: _urgencyBorderColor(request.urgency, context).withValues(alpha: 0.15)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: _serviceTypeColor(request.type, context).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Icon(_serviceTypeIcon(request.type),
                                  color: _serviceTypeColor(request.type, context), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_serviceTypeName(request.type),
                                      style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  _buildRequestProgressBar(request.status, context),
                                  const SizedBox(height: 4),
                                  Text(_timeAgo(request.createdAt),
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildStatusBadge(request.status, context),
                                if (request.status == 'completed' &&
                                    request.toMap()['rating'] == null)
                                  GestureDetector(
                                    onTap: () => _showRateServiceDialog(request),
                                    child: Container(
                                      margin: const EdgeInsets.only(top: 6),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Text('قيّم الخدمة ⭐',
                                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
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
            child: Text('عذراً، تعذر جلب الأنشطة', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          );
        }
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
        }
        final projects = snapshot.data!.docs;
        if (projects.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.volunteer_activism, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 60),
                const SizedBox(height: 16),
                Text('لا توجد أنشطة حالية', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
            final categoryColor = Theme.of(context).colorScheme.primary;

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    categoryColor.withValues(alpha: 0.15),
                    Theme.of(context).cardColor,
                    Theme.of(context).cardColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: categoryColor.withValues(alpha: 0.15), width: 1.5),
                boxShadow: [
                  BoxShadow(color: categoryColor.withValues(alpha: 0.15), blurRadius: 18, offset: const Offset(0, 7)),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [categoryColor.withValues(alpha: 0.15), categoryColor.withValues(alpha: 0.9)],
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
                            color: categoryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: categoryColor.withValues(alpha: 0.15)),
                          ),
                          child: Icon(Icons.volunteer_activism, color: categoryColor, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 16)),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: categoryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('نشط', style: TextStyle(color: categoryColor, fontSize: 12, fontWeight: FontWeight.w800)),
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
                            painter: _BenefArcPainter(
                              progress: progress, 
                              backgroundColor: Theme.of(context).colorScheme.surface,
                              activeColor: categoryColor,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('$progressPercent%',
                                      style: TextStyle(color: categoryColor, fontWeight: FontWeight.w900, fontSize: 24, height: 1)),
                                  Text('اكتمل', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600)),
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
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 10),
                              _activityStatRow(context, 'جُمع', '${collected.toInt()} دج', categoryColor),
                              const SizedBox(height: 5),
                              _activityStatRow(context, 'الهدف', '${goal.toInt()} دج', Theme.of(context).colorScheme.onSurfaceVariant),
                              const SizedBox(height: 5),
                              _activityStatRow(context, 'المتبقى', '${remaining.toInt()} دج', Theme.of(context).colorScheme.error),
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
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Divider(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: GestureDetector(
                      onTap: () {
                        final shareText =
                            'مشروع: $name\n'
                            'التقدم: $progressPercent%\n'
                            'جُمع: ${collected.toInt()} دج\n'
                            'الهدف: ${goal.toInt()} دج\n'
                            'ادعمنا في جمعية ناس الخير.\n\n'
                            'لتحميل التطبيق: https://nas-al-khir-reggane.github.io/nas_alkhir_reggane/';
                        Share.share(shareText, subject: 'مشروع $name - ناس الخير');
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.share_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 16),
                            const SizedBox(width: 6),
                            Text('شارك هذا المشروع', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14)),
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

  Widget _activityStatRow(BuildContext context, String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w800, fontSize: 14)),
      ],
    );
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

  void _showAllRequests() {
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('جميع طلباتي',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface)),
                    AppTheme.gradientButton(
                      text: 'طلب جديد',
                      icon: Icons.add,
                      onPressed: () {
                        Get.back();
                        setState(() => _currentIndex = 1);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const CommunityPulseCard(),
                const SizedBox(height: 12),
                Expanded(
                  child: Obx(() => controller.myRequests.isEmpty
                      ? Center(
                          child: Text('لا توجد طلبات بعد',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))
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
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: _urgencyBorderColor(request.urgency, context)
                                          .withValues(alpha: 0.15)),
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: _serviceTypeColor(request.type, context)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(_serviceTypeIcon(request.type),
                                          color: _serviceTypeColor(request.type, context),
                                          size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_serviceTypeName(request.type),
                                              style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  fontWeight: FontWeight.w600)),
                                          Text(_timeAgo(request.createdAt),
                                              style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildRequestProgressBar(String status, BuildContext context) {
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
                  color: isReached ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: isReached ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
                ),
                child: isReached
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.onPrimary, size: 10)
                    : null,
              ),
              if (s != 'completed')
                Expanded(
                  child: Container(
                    height: 2,
                    color: (idx < currentStageIndex) ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
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
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('كيف كانت الخدمة؟', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [1, 2, 3, 4, 5].map((s) => GestureDetector(
                  onTap: () => setModalState(() => selectedRating = s),
                  child: Icon(
                    s <= selectedRating ? Icons.star : Icons.star_border,
                    color: AppTheme.goldAccent,
                    size: 36,
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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

  Color _urgencyBorderColor(String urgency, BuildContext context) {
    switch (urgency) {
      case 'emergency': return Theme.of(context).colorScheme.error;
      case 'urgent': return Theme.of(context).colorScheme.primary.withValues(alpha: 0.15);
      default: return Theme.of(context).colorScheme.primary;
    }
  }

  Color _serviceTypeColor(String typeId, BuildContext context) {
    return AppConstants.getServiceColor(typeId);
  }

  IconData _serviceTypeIcon(String typeId) {
    return AppConstants.getServiceIcon(typeId);
  }

  String _serviceTypeName(String typeId) {
    final service = controller.availableServices.firstWhereOrNull((s) => s.id == typeId);
    return service?.name ?? AppConstants.translateServiceType(typeId);
  }

  String _timeAgo(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);
    if (duration.inDays > 0) return 'منذ ${duration.inDays} يوم';
    if (duration.inHours > 0) return 'منذ ${duration.inHours} ساعة';
    if (duration.inMinutes > 0) return 'منذ ${duration.inMinutes} دقيقة';
    return 'الآن';
  }

  Widget _buildContactTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 50),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تواصل مع الإدارة',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontFamily: 'Tajawal')),
              Text('لأي استفسار عن طلبك، راسل أحد المدراء مباشرة',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, fontFamily: 'Tajawal')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _adminsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text('لا يوجد مدراء متاحون حالياً',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: 'Tajawal')),
                );
              }
              final admins = snapshot.data!.docs
                  .map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                  .where((u) => u.isActive)
                  .where((u) => u.role == UserRole.admin || u.role == UserRole.superAdmin)
                  .toList();

              // ترتيب: المدير العام أولاً ثم البقية أبجدياً
              admins.sort((a, b) {
                if (a.role == UserRole.superAdmin && b.role != UserRole.superAdmin) return -1;
                if (a.role != UserRole.superAdmin && b.role == UserRole.superAdmin) return 1;
                return a.name.compareTo(b.name);
              });

              if (admins.isEmpty) {
                return Center(
                  child: Text('لا يوجد مدراء متاحون حالياً',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: 'Tajawal')),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        backgroundImage: (admin.profileImage != null && admin.profileImage!.isNotEmpty)
                            ? CachedNetworkImageProvider(admin.profileImage!) as ImageProvider
                            : null,
                        child: (admin.profileImage == null || admin.profileImage!.isEmpty)
                            ? Text(admin.name.isNotEmpty ? admin.name[0] : 'A',
                                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold))
                            : null,
                      ),
                      title: Text(admin.name,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                      subtitle: Text(
                          admin.role == UserRole.superAdmin ? 'مدير عام' : 'مدير إداري',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontFamily: 'Tajawal')),
                      trailing: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.chat_bubble_outline, color: Theme.of(context).colorScheme.primary, size: 20),
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

  Widget _buildStatusBadge(String status, BuildContext context) {
    Color color;
    switch (status) {
      case 'completed': color = Theme.of(context).colorScheme.primary; break;
      case 'rejected': color = Theme.of(context).colorScheme.error; break;
      case 'in_progress': color = Theme.of(context).colorScheme.secondary; break;
      default: color = Theme.of(context).colorScheme.primary.withValues(alpha: 0.15);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        AppConstants.translateStatus(status),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}


class _BenefArcPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color activeColor;
  const _BenefArcPainter({required this.progress, required this.backgroundColor, required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 9.0;
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
        ..color = activeColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle * progress, false, fgPaint);

      final glowPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.15)
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
