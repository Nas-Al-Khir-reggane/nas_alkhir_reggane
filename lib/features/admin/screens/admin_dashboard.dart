import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../controllers/admin_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/notification_service.dart';
import 'service_requests_screen.dart' as real_requests;
import 'projects_screen.dart';
import 'workers_screen.dart';
import '../../shared/screens/profile_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildHomeTab(),
      const real_requests.ServiceRequestsScreen(),
      ProjectsScreen(),
      const WorkersScreen(),
      _buildManagementTab(),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: _buildBottomBar(),
        floatingActionButton: _currentIndex == 4 ? null : _buildFAB(),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppTheme.darkShadow,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: AppTheme.primaryGreen,
          unselectedItemColor: AppTheme.textHint,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 11),
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
            BottomNavigationBarItem(
              icon: Obx(() => Badge(
                    label: Text(controller.urgentRequests.length.toString()),
                    isLabelVisible: controller.urgentRequests.isNotEmpty,
                    child: const Icon(Icons.assignment_outlined),
                  )),
              activeIcon: const Icon(Icons.assignment),
              label: 'الطلبات'),
            const BottomNavigationBarItem(icon: Icon(Icons.folder_outlined), activeIcon: Icon(Icons.folder), label: 'المشاريع'),
            const BottomNavigationBarItem(icon: Icon(Icons.group_outlined), activeIcon: Icon(Icons.group), label: 'الفريق'),
            const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_outlined), activeIcon: Icon(Icons.admin_panel_settings), label: 'الإدارة'),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () => _showActionMenu(),
      backgroundColor: AppTheme.primaryGreen,
      child: const Icon(Icons.add, color: Colors.black, size: 30),
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
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            _buildActionItem(Icons.volunteer_activism, 'تسجيل تبرع جديد', () {
              Get.back();
              _showAdminDonationDialog();
            }),
            _buildActionItem(Icons.add_task, 'إضافة طلب خدمة', () {
              Get.back();
              setState(() => _currentIndex = 1);
            }),
            _buildActionItem(Icons.create_new_folder, 'إضافة مشروع جديد', () {
              Get.back();
              setState(() => _currentIndex = 2);
            }),
            _buildActionItem(Icons.person_add, 'إضافة عامل جديد', () {
              Get.back();
              setState(() => _currentIndex = 3);
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
          backgroundColor: AppTheme.darkSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('تسجيل تبرع جديد',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: donorNameCtrl,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: AppTheme.inputDecoration('اسم المتبرع *', Icons.person_outline),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: AppTheme.inputDecoration('المبلغ (دج) *', Icons.attach_money),
                ),
                const SizedBox(height: 12),
                Obx(() {
                  final projects = controller.activeProjectsList;
                  return DropdownButtonFormField<String>(
                    dropdownColor: AppTheme.darkCard,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: AppTheme.inputDecoration('المشروع', Icons.folder_outlined),
                    value: selectedProject,
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
                  dropdownColor: AppTheme.darkCard,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: AppTheme.inputDecoration('طريقة الدفع', Icons.payment),
                  value: selectedMethod,
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
                  await FirebaseFirestore.instance.collection('donations').add({
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
                        .update({'collected': FieldValue.increment(amount)});
                  }
                  Get.back();
                  Get.snackbar('✅ تم', 'تم تسجيل التبرع بنجاح',
                      backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
                      colorText: AppTheme.successColor);
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
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppTheme.primaryGreen),
      ),
      title: Text(title, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
      onTap: onTap,
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: () => controller.loadDashboardData(),
      color: AppTheme.primaryGreen,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                    Text('مرحباً،', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                    Obx(() => Text(
                          authController.currentUser.value?.name ?? 'المدير',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                        )),
                    Obx(() => Text(
                      authController.currentUser.value?.role.displayName ?? '',
                      style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.w600),
                    )),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Get.toNamed('/profile'),
                  icon: const Icon(Icons.person_outline, color: AppTheme.primaryGreen, size: 28),
                ),
                IconButton(
                  onPressed: () => AppConstants.toggleTheme(),
                  icon: Icon(Get.isDarkMode ? Icons.light_mode : Icons.dark_mode, color: AppTheme.primaryGreen),
                ),
                Obx(() => Stack(
                  children: [
                    IconButton(
                      onPressed: () => Get.toNamed('/notifications'), 
                      icon: Icon(Icons.notifications_none, color: AppTheme.textPrimary)
                    ),
                    if (notificationService.unreadCount.value > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: Text(
                            notificationService.unreadCount.value.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 8),
                          ),
                        ),
                      ),
                  ],
                )),
              ],
            ),
            const SizedBox(height: 20),
            Obx(() => controller.urgentRequests.isNotEmpty
                ? FadeIn(
                    child: GestureDetector(
                      onTap: () => setState(() => _currentIndex = 1),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFD50000), Color(0xFFFF6D00)]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 15)],
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
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                const Text('اضغط للمعالجة الفورية', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink()),
            const SizedBox(height: 20),
            Text('نظرة عامة', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildKPICard('إجمالي التبرعات', controller.totalDonations, Icons.volunteer_activism, AppTheme.goldGradient, 'دج'),
                _buildKPICard('الطلبات المعلقة', controller.pendingRequests, Icons.pending_actions,
                    const LinearGradient(colors: [Colors.orange, Colors.deepOrange]), ''),
                _buildKPICard('المشاريع النشطة', controller.activeProjects, Icons.folder_open, AppTheme.primaryGradient, ''),
                _buildKPICard('العمال المتاحون', controller.availableWorkers, Icons.engineering,
                    const LinearGradient(colors: [Colors.blue, Colors.indigo]), ''),
                _buildKPICard('السيارات المتاحة', controller.availableVehicles, Icons.airport_shuttle,
                    const LinearGradient(colors: [Colors.teal, Colors.cyan]), ''),
                _buildKPICard('المستفيدون', controller.totalBeneficiaries, Icons.people,
                    const LinearGradient(colors: [Colors.purple, Colors.deepPurple]), ''),
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
            Container(
              decoration: AppTheme.glassDecoration,
              padding: const EdgeInsets.all(16),
              height: 200,
              child: Obx(() => controller.donationsLastSixMonths.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                            show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.glassBorder, strokeWidth: 1)),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) => Text(
                                  controller.donationsLastSixMonths[v.toInt() % controller.donationsLastSixMonths.length]['month'],
                                  style: const TextStyle(color: AppTheme.textHint, fontSize: 10)),
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (v, _) => Text('${v.toInt()}k', style: const TextStyle(color: AppTheme.textHint, fontSize: 10)),
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
                                .map((e) => FlSpot(e.key.toDouble(), e.value['amount']))
                                .toList(),
                            isCurved: true,
                            color: AppTheme.primaryGreen,
                            barWidth: 3,
                            belowBarData: BarAreaData(show: true, color: AppTheme.primaryGreen.withValues(alpha: 0.15)),
                            dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) =>
                                    FlDotCirclePainter(radius: 4, color: AppTheme.primaryGreen, strokeColor: Colors.white, strokeWidth: 2)),
                          )
                        ],
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (spots) => spots
                                .map((s) => LineTooltipItem('${s.y.toInt()} دج',
                                    const TextStyle(color: AppTheme.primaryGreen, fontFamily: 'Tajawal', fontWeight: FontWeight.w600)))
                                .toList(),
                          ),
                        ),
                      ),
                    )),
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('🥧 توزيع الخدمات', ''),
            const SizedBox(height: 12),
            Container(
              decoration: AppTheme.glassDecoration,
              padding: const EdgeInsets.all(16),
              height: 220,
              child: Row(
                children: [
                  Expanded(
                    child: Obx(() => PieChart(PieChartData(
                          sections: controller.serviceTypeDistribution
                              .map((item) => PieChartSectionData(
                                    value: item['count'].toDouble(),
                                    color: item['color'],
                                    title: '${item['percentage']}%',
                                    radius: 60,
                                    titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Tajawal'),
                                  ))
                              .toList(),
                          centerSpaceRadius: 40,
                          sectionsSpace: 3,
                          pieTouchData: PieTouchData(enabled: true),
                        ))),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: controller.serviceTypeDistribution
                        .map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Container(width: 12, height: 12, decoration: BoxDecoration(color: item['color'], borderRadius: BorderRadius.circular(3))),
                                  const SizedBox(width: 8),
                                  Text(item['name'], style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                ],
                              ),
                            ))
                        .toList(),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('📊 طلبات هذا الشهر', ''),
            const SizedBox(height: 12),
            Container(
              decoration: AppTheme.glassDecoration,
              padding: const EdgeInsets.all(16),
              height: 180,
              child: Obx(() => BarChart(BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    barGroups: controller.monthlyRequests
                        .where((item) => item['day'] % 5 == 0)
                        .map((item) => BarChartGroupData(
                              x: item['day'],
                              barRods: [
                                BarChartRodData(
                                  toY: item['count'].toDouble(),
                                  gradient: AppTheme.primaryGradient,
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
                              getTitlesWidget: (v, meta) => Text('${v.toInt()}', style: const TextStyle(color: AppTheme.textHint, fontSize: 9)))),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                            '${rod.toY.toInt()} طلب', const TextStyle(color: AppTheme.primaryGreen, fontFamily: 'Tajawal', fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ))),
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('📁 تقدم المشاريع', 'عرض الكل', onTap: () => setState(() => _currentIndex = 2)),
            const SizedBox(height: 12),
            Obx(() => Column(
                  children: controller.activeProjectsList
                      .take(3)
                      .map((project) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                        child: Text(project.name,
                                            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis)),
                                    Text('${project.budget > 0 ? ((project.collected / project.budget) * 100).toInt() : 0}%',
                                        style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: project.budget > 0 ? project.collected / project.budget : 0,
                                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                                    valueColor: AlwaysStoppedAnimation(
                                      (project.budget > 0 && (project.collected / project.budget) > 0.75)
                                          ? AppTheme.successColor
                                          : (project.budget > 0 && (project.collected / project.budget) > 0.4)
                                              ? AppTheme.primaryGreen
                                              : AppTheme.warningColor,
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text('${project.collected.toInt()} دج', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                    const Spacer(),
                                    Text('من ${project.budget.toInt()} دج', style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                )),
            const SizedBox(height: 16),
            _buildSectionHeader('🔧 تحديثات ميدانية', ''),
            const SizedBox(height: 12),
            Obx(() => Column(
                  children: controller.fieldUpdates
                      .take(5)
                      .map((update) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: const Border(right: BorderSide(color: AppTheme.primaryGreen, width: 3))),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                    backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                                    radius: 20,
                                    child: Text(update.workerName.isNotEmpty ? update.workerName[0] : '?',
                                        style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w700))),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(update.workerName, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                      Text(update.description, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12), maxLines: 2),
                                      Text(_timeAgo(update.createdAt), style: const TextStyle(color: AppTheme.textHint, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                if (update.imageUrl != null)
                                  ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(update.imageUrl!, width: 50, height: 50, fit: BoxFit.cover)),
                              ],
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
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(gradient: AppTheme.goldGradient, shape: BoxShape.circle),
                                child: const Icon(Icons.volunteer_activism, color: Colors.black, size: 20),
                              ),
                              title: Text(donation.donorName, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                              subtitle: Text(donation.projectName, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              trailing: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${donation.amount.toInt()} دج', style: const TextStyle(color: AppTheme.goldAccent, fontWeight: FontWeight.w700)),
                                  Text(intl.DateFormat('MM/dd').format(donation.date), style: const TextStyle(color: AppTheme.textHint, fontSize: 10)),
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

  Widget _buildKPICard(String label, RxInt value, IconData icon, Gradient gradient, String suffix) {
    return Container(
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.darkShadow),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const Spacer(),
              if (suffix.isNotEmpty) Text(suffix, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
          const Spacer(),
          Obx(() => Text(
              value.value >= 1000000
                  ? '${(value.value / 1000000).toStringAsFixed(1)}M'
                  : value.value >= 1000
                      ? '${(value.value / 1000).toStringAsFixed(1)}k'
                      : value.value.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildUrgentRequestCard(ServiceRequestModel request) {
    final color = request.urgency == 'emergency' ? AppTheme.emergencyColor : AppTheme.urgentColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10)]),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Icon(Icons.emergency_outlined, color: color, size: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(request.type, style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const Spacer(),
                    AppTheme.statusBadge(request.urgency),
                  ],
                ),
                Text(request.requesterName, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                Text('${request.wilaya} - ${_timeAgo(request.createdAt)}', style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: AppTheme.primaryGreen, size: 16),
            onPressed: () => Get.toNamed('/admin/request-detail', arguments: request)
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String actionText, {VoidCallback? onTap}) {
    return Row(
      children: [
        Text(title, style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        const Spacer(),
        if (actionText.isNotEmpty)
          TextButton(onPressed: onTap, child: Text(actionText, style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 12))),
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
            gradient: Get.isDarkMode ? AppTheme.darkBgGradient : LinearGradient(colors: [AppTheme.primaryGreen.withValues(alpha: 0.1), AppTheme.lightBg]),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.3),
                child: Text(user != null && user.name.isNotEmpty ? user.name[0] : 'A',
                    style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 28, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? 'المدير', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(user?.role.displayName ?? '', style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
                    Text(user?.email ?? '', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Get.toNamed('/profile'),
                icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryGreen),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (user?.role == UserRole.superAdmin)
          _buildSettingsTile(Icons.people, 'إدارة المستخدمين', 'موافقة وإدارة الحسابات', () => Get.toNamed('/admin/users')),
        _buildSettingsTile(Icons.group, 'فريق العمل', 'إدارة العمال والمتطوعين', () => setState(() => _currentIndex = 3)),
        _buildSettingsTile(Icons.miscellaneous_services, 'أنواع الخدمات', 'إضافة وتعديل أنواع الخدمات', () => Get.toNamed('/admin/service-types')),
        _buildSettingsTile(Icons.task, 'أنواع المهام', 'إضافة وتعديل أنواع المهام', () => Get.toNamed('/admin/task-types')),
        _buildSettingsTile(Icons.airport_shuttle, 'سيارات الجنازة', 'إدارة الأسطول', () => Get.toNamed('/admin/vehicles')),
        _buildSettingsTile(Icons.bar_chart, 'التقارير', 'تقارير شهرية وسنوية PDF', () => Get.toNamed('/admin/reports')),
        _buildSettingsTile(Icons.chat, 'الدردشة مع الفريق', 'التواصل مع العمال', () => Get.toNamed('/chat/group')),
        const Divider(color: AppTheme.glassBorder, indent: 24, endIndent: 24),
        _buildSettingsTile(Icons.person, 'حسابي (الملف الشخصي)', 'تعديل البيانات والصورة', () => Get.toNamed('/profile')),
        _buildSettingsTile(Icons.dark_mode, 'الوضع الداكن/النهاري', 'تبديل المظهر', () => AppConstants.toggleTheme(), showToggle: true),
        const Divider(color: AppTheme.glassBorder, indent: 24, endIndent: 24),
        _buildSettingsTile(Icons.logout, 'تسجيل الخروج', 'الخروج من الحساب', () => authController.logout(), isDestructive: true),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, VoidCallback onTap,
      {bool isDestructive = false, bool showToggle = false}) {
    final color = isDestructive ? AppTheme.errorColor : AppTheme.primaryGreen;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: TextStyle(color: isDestructive ? color : AppTheme.textPrimary, fontWeight: FontWeight.w500)),
        subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(color: AppTheme.textHint, fontSize: 11)) : null,
        trailing: showToggle
            ? Switch(value: Get.isDarkMode, onChanged: (v) => AppConstants.toggleTheme())
            : Icon(Icons.arrow_forward_ios, color: AppTheme.textHint.withValues(alpha: 0.5), size: 14),
        onTap: onTap,
      ),
    );
  }
}
