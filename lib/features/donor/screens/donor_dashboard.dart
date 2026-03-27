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
import '../controllers/donor_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import 'donate_screen.dart';
import 'my_subscriptions_screen.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/user_model.dart';
import '../../admin/controllers/project_controller.dart';
import '../../../data/services/notification_service.dart';

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
            _buildProjectsTab(),
            const MySubscriptionsScreen(),
            const DonateScreen(),
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
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'لوحتي',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.folder_outlined),
                activeIcon: Icon(Icons.folder),
                label: 'المشاريع',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.child_care_outlined),
                activeIcon: Icon(Icons.child_care),
                label: 'كفالاتي',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.volunteer_activism),
                label: 'تبرع الآن',
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
                        donorController.donorName,
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                      )),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.person_outline, color: AppTheme.primaryGreen, size: 28),
                onPressed: () => Get.toNamed('/profile'),
              ),
              GestureDetector(
                onTap: () => donorController.showCertificate(),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.goldAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.4)),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: const Row(
                    children: [
                      Icon(Icons.card_membership, color: AppTheme.goldAccent, size: 18),
                      SizedBox(width: 6),
                      Text('شهادتي',
                          style: TextStyle(
                              color: AppTheme.goldAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
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
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
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
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Obx(() => _buildDonorKPI(
                      'إجمالي تبرعاتي',
                      '${projectController.formatNumber(donorController.totalDonated.value)} دج',
                      Icons.volunteer_activism,
                      AppTheme.goldGradient,
                      onTap: _showAllDonations,
                    )),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(() => _buildDonorKPI(
                      'عدد التبرعات',
                      donorController.donationsCount.value.toString(),
                      Icons.receipt_long,
                      AppTheme.primaryGradient,
                      onTap: _showAllDonations,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildAdminTeamSection(),
          const SizedBox(height: 24),
          Obx(() => donorController.donationsByProject.isNotEmpty
              ? Column(
                  children: [
                    _buildSectionHeader('🥧 توزيع تبرعاتي', ''),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _showAllDonations,
                      child: Container(
                        decoration: AppTheme.glassDecoration,
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
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Tajawal'),
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
                                                      color: AppTheme.textSecondary,
                                                      fontSize: 11),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis),
                                              Text(
                                                  '${projectController.formatNumber(item['total'] as num)} دج',
                                                  style: TextStyle(
                                                      color: AppTheme.textPrimary,
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
                  decoration: AppTheme.glassDecoration,
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      const Icon(Icons.volunteer_activism, color: AppTheme.textHint, size: 40),
                      const SizedBox(height: 12),
                      const Text('لم تقم بأي تبرع بعد',
                          style: TextStyle(color: AppTheme.textHint), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      AppTheme.gradientButton(
                        text: 'تبرع الآن',
                        icon: Icons.favorite,
                        onPressed: () => setState(() => _currentIndex = 3),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: donorController.myDonations.take(5).map((donation) {
                    return GestureDetector(
                      onTap: () {
                        try {
                          final project = donorController.activeProjects.firstWhere((p) => p.id == donation.projectId);
                          Get.toNamed(AppRoutes.adminProjectDetail, arguments: project);
                        } catch (e) {
                          _showAllDonations();
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: donation.donorId == 'anonymous'
                                    ? AppTheme.textHint.withValues(alpha: 0.15)
                                    : AppTheme.goldAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                donation.donorId == 'anonymous'
                                    ? Icons.person_off
                                    : Icons.volunteer_activism,
                                color: donation.donorId == 'anonymous'
                                    ? AppTheme.textHint
                                    : AppTheme.goldAccent,
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
                                          color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                                  Row(
                                    children: [
                                      Text(
                                          donation.donorId == 'anonymous'
                                              ? 'مجهول'
                                              : _methodLabel(donation.method),
                                          style: TextStyle(
                                              color: AppTheme.textSecondary, fontSize: 12)),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: const BoxDecoration(
                                            color: AppTheme.textHint, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                          DateFormat('yyyy/MM/dd').format(donation.date),
                                          style: const TextStyle(
                                              color: AppTheme.textHint, fontSize: 11)),
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
                                    style: const TextStyle(
                                        color: AppTheme.goldAccent,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                                const SizedBox(height: 4),
                                AppTheme.statusBadge(donation.status),
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
                  children: donorController.activeProjects
                      .where((p) => donorController.donationsByProject
                          .any((d) => d['projectId'] == p.id))
                      .map((project) {
                    final progress = project.progressPercentage / 100;
                    return GestureDetector(
                      onTap: () => Get.toNamed(AppRoutes.adminProjectDetail, arguments: project),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(project.name,
                                      style: TextStyle(
                                          color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                                ),
                                Text('${project.progressPercentage.toInt()}%',
                                    style: const TextStyle(
                                        color: AppTheme.primaryGreen, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: AppTheme.darkSurface,
                                minHeight: 8,
                                valueColor: AlwaysStoppedAnimation(
                                  project.progressPercentage >= 80 ? AppTheme.successColor
                                    : project.progressPercentage >= 50 ? AppTheme.primaryGreen
                                    : project.progressPercentage >= 20 ? AppTheme.warningColor
                                    : AppTheme.errorColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                    '${projectController.formatNumber(project.collected)} dج',
                                    style: const TextStyle(
                                        color: AppTheme.primaryGreen, fontSize: 12)),
                                const Spacer(),
                                Text(
                                    'من ${projectController.formatNumber(project.budget)} دج',
                                    style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
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

  Widget _buildAdminTeamSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('🛡️ تواصل مع الإدارة', 'عرض الكل', onTap: () => _showAdminsList()),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', whereIn: ['admin', 'superAdmin'])
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final admins = snapshot.data!.docs;
              
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: admins.length,
                itemBuilder: (context, index) {
                  final data = admins[index].data() as Map<String, dynamic>;
                  final admin = UserModel.fromMap(data, admins[index].id);
                  return GestureDetector(
                    onTap: () => Get.toNamed('/profile', arguments: admin),
                    child: Container(
                      width: 90,
                      margin: const EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                            backgroundImage: (admin.profileImage != null && admin.profileImage!.isNotEmpty)
                                ? NetworkImage(admin.profileImage!)
                                : null,
                            child: (admin.profileImage == null || admin.profileImage!.isEmpty)
                                ? Text(admin.name[0], style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold))
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(admin.name.split(' ')[0], 
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(admin.role == UserRole.superAdmin ? 'مدير عام' : 'مدير',
                            style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 9)),
                        ],
                      ),
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

  void _showAdminsList() {
    Get.bottomSheet(
      DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(color: AppTheme.darkSurface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('الفريق الإداري', style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', whereIn: ['admin', 'superAdmin'])
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final admins = snapshot.data!.docs;
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: admins.length,
                        itemBuilder: (context, index) {
                          final admin = UserModel.fromMap(admins[index].data() as Map<String, dynamic>, admins[index].id);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                              backgroundImage: (admin.profileImage != null && admin.profileImage!.isNotEmpty) ? NetworkImage(admin.profileImage!) : null,
                              child: (admin.profileImage == null || admin.profileImage!.isEmpty) ? Text(admin.name[0], style: const TextStyle(color: AppTheme.primaryGreen)) : null,
                            ),
                            title: Text(admin.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text(admin.role == UserRole.superAdmin ? 'مدير عام' : 'مدير إداري', style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryGreen),
                              onPressed: () => Get.toNamed('/chat/private', arguments: {'userId': admin.id, 'userName': admin.name}),
                            ),
                            onTap: () => Get.toNamed('/profile', arguments: admin),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildDonorKPI(String label, String value, IconData icon, Gradient gradient, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.darkShadow,
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
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
            child: Text(action, style: const TextStyle(color: AppTheme.primaryGreen)),
          ),
      ],
    );
  }

  Widget _buildProjectsTab() {
    return Obx(() {
      if (donorController.activeProjects.isEmpty) {
        return const Center(child: Text('لا توجد مشاريع نشطة حالياً', style: TextStyle(color: AppTheme.textHint)));
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

  Widget _buildDonorProjectCard(ProjectModel project) {
    final cat = ProjectController.categories
        .firstWhere((c) => c['id'] == project.category, orElse: () => ProjectController.categories.last);
    final categoryColor = cat['color'] as Color;
    final progress = (project.budget > 0)
        ? (project.collected / project.budget).clamp(0.0, 1.0)
        : 0.0;
    final progressPercent = (progress * 100).toInt();
    final remaining = (project.budget - project.collected).clamp(0.0, double.infinity);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            categoryColor.withValues(alpha: 0.18),
            AppTheme.darkCard,
            AppTheme.darkCard,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: categoryColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: categoryColor.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () => Get.toNamed(AppRoutes.adminProjectDetail, arguments: project),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [categoryColor.withValues(alpha: 0.35), categoryColor.withValues(alpha: 0.08)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: categoryColor.withValues(alpha: 0.5)),
                    ),
                    child: Icon(cat['icon'] as IconData, color: categoryColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row( // ✨ FIXED: Added Row to avoid overlapping with name
                          children: [
                            Expanded(
                              child: Text(project.name,
                                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 17, height: 1.2)),
                            ),
                            if (project.isSubscription) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.9),
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
                  AppTheme.statusBadge(project.status),
                ],
              ),
            ),
          ),

          // Circular Progress + Stats
          GestureDetector(
            onTap: () => Get.toNamed(AppRoutes.adminProjectDetail, arguments: project),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 110, height: 110,
                    child: CustomPaint(
                      painter: _ArcProgressPainter(progress: progress, color: categoryColor, backgroundColor: AppTheme.darkSurface),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$progressPercent%',
                                style: TextStyle(color: categoryColor, fontWeight: FontWeight.w900, fontSize: 24, height: 1)),
                            Text('اكتمل', style: TextStyle(color: AppTheme.textHint, fontSize: 10)),
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
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
                        const SizedBox(height: 12),
                        _buildStatRow('جُمع', '${projectController.formatNumber(project.collected)} دج', categoryColor),
                        const SizedBox(height: 6),
                        _buildStatRow('الهدف', '${projectController.formatNumber(project.budget)} دج', AppTheme.textSecondary),
                        const SizedBox(height: 6),
                        _buildStatRow('المتبقى', '${projectController.formatNumber(remaining)} دج', AppTheme.warningColor),
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
                    Text('شريط التقدم', style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
                    const Spacer(),
                    Text('$progressPercent%', style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: AppTheme.darkSurface,
                    valueColor: AlwaysStoppedAnimation(categoryColor),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(color: AppTheme.glassBorder, height: 1),

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
                          'التقدم: $progressPercent%\n'
                          'جُمع: ${projectController.formatNumber(project.collected)} دج\n'
                          'الهدف: ${projectController.formatNumber(project.budget)} دج\n'
                          'انضم إلينا لدعم جمعية ناس الخير والتبرع لهذا المشروع.';
                      Share.share(shareText, subject: 'مشروع ${project.name} - ناس الخير');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.glassBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share_outlined, color: AppTheme.textSecondary, size: 18),
                          const SizedBox(width: 6),
                          Text('مشاركة', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
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
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppTheme.greenGlow,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(project.isSubscription ? Icons.repeat : Icons.volunteer_activism, color: Colors.black, size: 18),
                          const SizedBox(width: 6),
                          Text(project.isSubscription ? 'التزام شهري' : 'تبرع لهذا المشروع',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13)),
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
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'cash': return 'نقدي';
      case 'bank': return 'تحويل بنكي';
      case 'online': return 'إلكتروني';
      default: return method;
    }
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
            decoration: const BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppTheme.glassBorder, borderRadius: BorderRadius.circular(2)),
                  alignment: Alignment.center,
                ),
                Text('جميع تبرعاتي',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 16),
                Expanded(
                  child: Obx(() => donorController.myDonations.isEmpty
                      ? const Center(child: Text('لا توجد تبرعات بعد', style: TextStyle(color: AppTheme.textHint)))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: donorController.myDonations.length,
                          itemBuilder: (context, index) {
                            final donation = donorController.myDonations[index];
                            return GestureDetector(
                              onTap: () {
                                try {
                                  final project = donorController.activeProjects.firstWhere((p) => p.id == donation.projectId);
                                  Get.toNamed(AppRoutes.adminProjectDetail, arguments: project);
                                } catch (e) {
                                  debugPrint('❌ [DonorDashboard] donation project navigation error: $e');
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(color: AppTheme.goldAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.all(10),
                                      child: const Icon(Icons.volunteer_activism, color: AppTheme.goldAccent, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(donation.projectName, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                                          Text(_methodLabel(donation.method), style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('${projectController.formatNumber(donation.amount)} دج',
                                            style: const TextStyle(color: AppTheme.goldAccent, fontWeight: FontWeight.w700)),
                                        AppTheme.statusBadge(donation.status),
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
        ..color = color.withValues(alpha: 0.3)
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
