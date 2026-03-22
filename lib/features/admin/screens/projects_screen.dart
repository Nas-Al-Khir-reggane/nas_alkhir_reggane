import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/project_model.dart';
import '../controllers/project_controller.dart';
import 'package:intl/intl.dart';

class ProjectsScreen extends StatelessWidget {
  final ProjectController projectController = Get.put(ProjectController());

  ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // AppBar مخصص
          Container(
            decoration: BoxDecoration(
              gradient: Get.isDarkMode ? AppTheme.darkBgGradient : LinearGradient(colors: [AppTheme.primaryGreen.withValues(alpha: 0.1), AppTheme.lightBg]),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('المشاريع',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary)),
                        Obx(() => Text(
                            '${projectController.totalProjects} مشروع | ${projectController.activeCount} نشط',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13))),
                      ],
                    ),
                    const Spacer(),
                    // زر إضافة مشروع
                    GestureDetector(
                      onTap: () => _showAddProjectSheet(context),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppTheme.greenGlow,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.add, color: Colors.black, size: 20),
                              const SizedBox(width: 6),
                              const Text('مشروع جديد',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // إحصائيات سريعة
          Obx(() => SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildQuickStat(context, 'نشطة', projectController.activeCount,
                    AppTheme.primaryGreen, Icons.play_circle),
                _buildQuickStat(context, 'مكتملة', projectController.completedCount,
                    AppTheme.successColor, Icons.check_circle),
                _buildQuickStat(context, 'موقوفة', projectController.pausedCount,
                    AppTheme.warningColor, Icons.pause_circle),
                _buildQuickStat(
                    context,
                    'إجمالي جُمع',
                    '${projectController.formatNumber(projectController.totalCollected)}دج',
                    AppTheme.goldAccent,
                    Icons.volunteer_activism),
              ],
            ),
          )),

          // شريط البحث
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: projectController.searchController,
              decoration: AppTheme.inputDecoration('ابحث عن مشروع...', Icons.search),
              style: TextStyle(color: AppTheme.textPrimary),
            ),
          ),

          // فلتر الفئات
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryFilter(context,
                    {'id': 'all', 'name': 'الكل', 'icon': Icons.apps}),
                ...ProjectController.categories
                    .map((cat) => _buildCategoryFilter(context, cat)),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // فلتر الحالة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['all', 'active', 'paused', 'completed'].map((s) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      projectController.selectedStatus.value = s;
                      projectController.filterProjects();
                    },
                    child: Obx(() => Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: projectController.selectedStatus.value == s
                                ? _getStatusColor(s).withValues(alpha: 0.2)
                                : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: projectController.selectedStatus.value == s
                                    ? _getStatusColor(s)
                                    : AppTheme.glassBorder),
                          ),
                          child: Center(
                            child: Text(_statusLabel(s),
                                style: TextStyle(
                                    color: projectController.selectedStatus.value == s
                                        ? _getStatusColor(s)
                                        : AppTheme.textHint,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                          ),
                        )),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // قائمة المشاريع
          Expanded(
            child: Obx(() {
              if (projectController.filteredProjects.isEmpty) {
                return _buildEmptyState(context);
              }
              return RefreshIndicator(
                onRefresh: () async => projectController.listenToProjects(),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: projectController.filteredProjects.length,
                  itemBuilder: (context, index) {
                    final project = projectController.filteredProjects[index];
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          child: _buildProjectCard(context, project),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(BuildContext context, String label, dynamic value, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value.toString(),
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              Text(label,
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(BuildContext context, Map<String, dynamic> cat) {
    return GestureDetector(
      onTap: () {
        projectController.selectedCategory.value = cat['id'];
        projectController.filterProjects();
      },
      child: Obx(() {
        final isSelected = projectController.selectedCategory.value == cat['id'];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.primaryGradient : null,
            color: !isSelected ? Theme.of(context).cardColor : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isSelected ? Colors.transparent : AppTheme.glassBorder),
          ),
          child: Row(
            children: [
              Icon(cat['icon'] as IconData,
                  size: 16,
                  color: isSelected ? Colors.black : AppTheme.textHint),
              const SizedBox(width: 6),
              Text(cat['name'] as String,
                  style: TextStyle(
                      color: isSelected ? Colors.black : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildProjectCard(BuildContext context, ProjectModel project) {
    final cat = ProjectController.categories
        .firstWhere((c) => c['id'] == project.category, orElse: () => ProjectController.categories.last);
    final categoryColor = cat['color'] as Color;
    final progress = (project.budget > 0) ? (project.collected / project.budget).clamp(0.0, 1.0) : 0.0;
    final progressPercent = (progress * 100).toInt();

    return GestureDetector(
      onTap: () => Get.toNamed('/admin/project-detail', arguments: project),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(
              color: project.status == 'active'
                  ? AppTheme.glassBorder
                  : project.status == 'paused'
                      ? AppTheme.warningColor.withValues(alpha: 0.3)
                      : AppTheme.successColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            // رأس البطاقة
            Container(
              height: 90,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(cat['icon'], color: categoryColor, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(project.name,
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                height: 1.2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(cat['name'],
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  _buildStatusBadge(project.status),
                ],
              ),
            ),

            // المحتوى
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('التقدم المحرز',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      Text('$progressPercent%',
                          style: TextStyle(
                              color: progress > 0.8
                                  ? AppTheme.successColor
                                  : AppTheme.primaryGreen,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      valueColor: AlwaysStoppedAnimation(
                          progress > 0.8 ? AppTheme.successColor : AppTheme.primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildMiniInfo(Icons.monetization_on,
                          '${projectController.formatNumber(project.collected)} دج'),
                      const Spacer(),
                      _buildMiniInfo(Icons.flag,
                          '${projectController.formatNumber(project.budget)} دج'),
                    ],
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 24),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: AppTheme.textHint, size: 14),
                      const SizedBox(width: 6),
                      Text('تنتهي في: ${project.deadline != null ? DateFormat('yyyy-MM-dd').format(project.deadline!) : 'غير محدد'}',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.people, color: AppTheme.textHint, size: 14),
                          const SizedBox(width: 4),
                          Text('${project.assignedWorkers.length}',
                              style: TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 16),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(_statusLabel(status),
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppTheme.primaryGreen;
      case 'paused':
        return AppTheme.warningColor;
      case 'completed':
        return AppTheme.successColor;
      default:
        return AppTheme.textHint;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'all':
        return 'الكل';
      case 'active':
        return 'نشط';
      case 'paused':
        return 'موقوف';
      case 'completed':
        return 'مكتمل';
      default:
        return status;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open,
              size: 80, color: AppTheme.textHint.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('لا توجد مشاريع حالياً',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 18)),
        ],
      ),
    );
  }

  void _showAddProjectSheet(BuildContext context) {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();
    final descriptionController = TextEditingController();
    final Rx<String> selectedCat = 'food'.obs;
    final Rx<DateTime> selectedDate = DateTime.now().add(const Duration(days: 30)).obs;

    Get.bottomSheet(
      isScrollControlled: true,
      Container(
        height: Get.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('مشروع جديد',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary)),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Get.back(), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 32),
              Text('اسم المشروع *',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                  controller: nameController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: AppTheme.inputDecoration('أدخل اسم المشروع', Icons.edit)),
              const SizedBox(height: 20),
              Text('فئة المشروع *',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              SizedBox(
                height: 45,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: ProjectController.categories.map((c) {
                    return Obx(() => GestureDetector(
                          onTap: () => selectedCat.value = c['id'],
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: selectedCat.value == c['id']
                                  ? (c['color'] as Color).withValues(alpha: 0.2)
                                  : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: selectedCat.value == c['id']
                                      ? (c['color'] as Color)
                                      : AppTheme.glassBorder),
                            ),
                            child: Row(
                              children: [
                                Icon(c['icon'] as IconData,
                                    size: 16,
                                    color: selectedCat.value == c['id']
                                        ? (c['color'] as Color)
                                        : AppTheme.textHint),
                                const SizedBox(width: 8),
                                Text(c['name'],
                                    style: TextStyle(
                                        color: selectedCat.value == c['id']
                                            ? (c['color'] as Color)
                                            : AppTheme.textSecondary,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ));
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              Text('وصف المشروع',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: AppTheme.inputDecoration(
                      'وصف مختصر للمشروع...', Icons.description)),
              const SizedBox(height: 20),
              Text('الميزانية المطلوبة (دج) *',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [10000, 50000, 100000, 500000].map((amount) {
                  return ChoiceChip(
                    label: Text('${amount / 1000}k'),
                    selected: budgetController.text == amount.toString(),
                    onSelected: (v) => budgetController.text = amount.toString(),
                  );
                }).toList(),
              ),
              TextField(
                  controller: budgetController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: AppTheme.inputDecoration(
                      'أو أدخل المبلغ', Icons.monetization_on)),
              const SizedBox(height: 20),
              Text('تاريخ الانتهاء المتوقع *',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Obx(() => ListTile(
                    tileColor: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppTheme.glassBorder)),
                    leading: const Icon(Icons.calendar_month,
                        color: AppTheme.primaryGreen),
                    title: Text(
                        DateFormat('yyyy-MM-dd').format(selectedDate.value),
                        style: TextStyle(color: AppTheme.textPrimary)),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate.value,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (date != null) selectedDate.value = date;
                    },
                  )),
              const SizedBox(height: 40),
              AppTheme.gradientButton(
                  text: 'إنشاء المشروع',
                  icon: Icons.check,
                  onPressed: () {
                    if (nameController.text.isNotEmpty &&
                        budgetController.text.isNotEmpty) {
                      projectController.addProject(
                        name: nameController.text.trim(),
                        category: selectedCat.value,
                        description: descriptionController.text.trim(),
                        budget: double.parse(budgetController.text),
                        endDate: selectedDate.value,
                      );
                      Get.back();
                    } else {
                      Get.snackbar('خطأ', 'يرجى ملء الحقول المطلوبة',
                          backgroundColor: AppTheme.errorColor,
                          colorText: Colors.white);
                    }
                  }),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
