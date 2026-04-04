import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/animations/mount_animations.dart';
// تم إزالة الاستيراد غير المستعمل
import '../../../core/theme/app_theme.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/user_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/project_controller.dart';
import 'add_project_screen.dart';

class ProjectsScreen extends StatelessWidget {
  ProjectController get projectController => Get.find<ProjectController>();
  AuthController get authController => Get.find<AuthController>();
  bool get canManageProjects => authController.currentUser.value?.role == UserRole.superAdmin;

  const ProjectsScreen({super.key});

  static void showAddProjectSheet(BuildContext context) {
    Get.to(() => const AddProjectScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          // خلفية زخرفية موحدة وفاخرة
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryGreen.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          Column(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 10),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('إدارة المشاريع',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textPrimary,
                                  fontFamily: 'Tajawal',
                                  letterSpacing: 0.5)),
                          Obx(() => Text(
                              '${projectController.totalProjects} مشروع قيد الإدارة',
                              style: TextStyle(
                                  color: AppTheme.textSecondary.withValues(alpha: 0.7), 
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500))),
                        ],
                      ),
                      const Spacer(),
                      if (canManageProjects)
                        GestureDetector(
                          onTap: () => showAddProjectSheet(context),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 4))
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Icon(Icons.add_rounded, color: Get.isDarkMode ? Colors.black : Colors.white, size: 20),
                                const SizedBox(width: 4),
                                Text('مشروع جديد',
                                    style: TextStyle(
                                        color: Get.isDarkMode ? Colors.black : Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 5))
                    ],
                  ),
                  child: TextField(
                    controller: projectController.searchController,
                    decoration: AppTheme.inputDecoration('ابحث عن مشروع أو فئة...', Icons.search_rounded),
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  ),
                ),
              ),

              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildCategoryFilter({'id': 'all', 'name': 'الكل', 'icon': Icons.grid_view_rounded}),
                    ...ProjectController.categories.map((cat) => _buildCategoryFilter(cat)),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: Obx(() {
                  if (projectController.filteredProjects.isEmpty) {
                    return AppTheme.emptyState('لا توجد نتائج مطابقة لفلتر البحث', icon: Icons.search_off_rounded);
                  }
                  return RefreshIndicator(
                    color: AppTheme.primaryGreen,
                    strokeWidth: 2,
                    onRefresh: () async => projectController.listenToProjects(),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      itemCount: projectController.filteredProjects.length,
                      itemBuilder: (context, index) {
                        final project = projectController.filteredProjects[index];
                        return MountAnimations.staggeredListEntry(
                          index: index,
                          delayMs: 60,
                          child: _buildProfessionalProjectCard(context, project),
                        );
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(Map<String, dynamic> cat) {
    return GestureDetector(
      onTap: () {
        projectController.selectedCategory.value = cat['id'];
        projectController.filterProjects();
      },
      child: Obx(() {
        final isSelected = projectController.selectedCategory.value == cat['id'];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsetsDirectional.only(end: 8),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.1) : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.3) : AppTheme.glassBorder.withValues(alpha: 0.05),
              width: 1.2
            ),
          ),
          child: Row(
            children: [
              Icon(cat['icon'] as IconData, size: 16, color: isSelected ? AppTheme.primaryGreen : AppTheme.textHint),
              const SizedBox(width: 8),
              Text(cat['name'] as String,
                  style: TextStyle(
                      color: isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600)),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildProfessionalProjectCard(BuildContext context, ProjectModel project) {
    final cat = ProjectController.categories
        .firstWhere((c) => c['id'] == project.category, orElse: () => ProjectController.categories.last);
    final categoryColor = cat['color'] as Color;
    final progress = (project.budget > 0) ? (project.collected / project.budget).clamp(0.0, 1.0) : 0.0;
    final progressPercent = (progress * 100).toInt();
    final remaining = (project.budget - project.collected).clamp(0.0, double.infinity);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: categoryColor.withValues(alpha: 0.05), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.03),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(cat['icon'] as IconData, color: categoryColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.name,
                            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 16, height: 1.2)),
                        const SizedBox(height: 4),
                        Text(cat['name'] as String,
                            style: TextStyle(color: categoryColor.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  AppTheme.statusBadge(project.status),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 18, 20),
              child: Row(
                children: [
                  SizedBox(
                    width: 90, height: 90,
                    child: CustomPaint(
                      painter: _ArcProgressPainter(
                        progress: progress, 
                        color: categoryColor, 
                        backgroundColor: categoryColor.withValues(alpha: 0.08),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$progressPercent%',
                                style: TextStyle(color: categoryColor, fontWeight: FontWeight.w900, fontSize: 20, height: 1)),
                            Text('مكتمل', style: TextStyle(color: AppTheme.textHint, fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        _buildMetricRow('المجموع المُحصّل', '${projectController.formatNumber(project.collected)} دج', categoryColor),
                        const SizedBox(height: 8),
                        _buildMetricRow('هدف المشروع', '${projectController.formatNumber(project.budget)} دج', AppTheme.textSecondary),
                        const SizedBox(height: 8),
                        _buildMetricRow('المبلغ المتبقي', '${projectController.formatNumber(remaining)} دج', AppTheme.warningColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: categoryColor.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation(categoryColor),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Divider(color: AppTheme.glassBorder.withValues(alpha: 0.05), height: 1),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.toNamed('/admin/project-detail', arguments: project),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        backgroundColor: AppTheme.backgroundColor.withValues(alpha: 0.5),
                      ),
                      child: Text('عرض التفاصيل', 
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                  if (canManageProjects) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showEditProjectQuickActions(context, project),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                          foregroundColor: AppTheme.primaryGreen,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: AppTheme.primaryGreen.withValues(alpha: 0.2))
                          ),
                        ),
                        child: const Text('إدارة سريعة', 
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textHint, fontSize: 11, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
      ],
    );
  }

  void _showEditProjectQuickActions(BuildContext context, ProjectModel project) {
    if (!canManageProjects) {
      Get.snackbar('وصول مرفوض', 'إدارة المشاريع متاحة للمدير العام فقط');
      return;
    }

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 40, offset: const Offset(0, -10))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 45, height: 4, decoration: BoxDecoration(color: AppTheme.glassBorder.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),
            Text('إجراءات المشروع',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, fontFamily: 'Tajawal')),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCircleAction(Icons.edit_rounded, 'تعديل', AppTheme.primaryGreen, () {
                  Get.back();
                  _showEditDialog(context, project);
                }),
                _buildCircleAction(
                  project.status == 'paused' ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  project.status == 'paused' ? 'استئناف' : 'إيقاف',
                  AppTheme.warningColor,
                  () {
                    Get.back();
                    projectController.toggleProjectStatus(project.id, project.status);
                  },
                ),
                _buildCircleAction(Icons.task_alt_rounded, 'إكمال', AppTheme.successColor, () {
                  Get.back();
                  Get.dialog(AlertDialog(
                    backgroundColor: AppTheme.surfaceColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    title: Text('إكمال المشروع', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                    content: Text('هل أنت متأكد من نقل هذا المشروع إلى قائمة "المكتملة"؟', style: TextStyle(color: AppTheme.textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Get.back(), child: Text('تراجع', style: TextStyle(color: AppTheme.textHint))),
                      AppTheme.gradientButton(
                        text: 'نعم، مكتمل',
                        onPressed: () {
                          Get.back();
                          projectController.updateProject(project.id, {'status': 'completed'});
                        },
                      ),
                    ],
                  ));
                }),
                _buildCircleAction(Icons.delete_outline_rounded, 'حذف', AppTheme.errorColor, () {
                  Get.back();
                  Get.dialog(AlertDialog(
                    backgroundColor: AppTheme.surfaceColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    title: Text('حذف المشروع', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                    content: Text('سيتم حذف "${project.name}" نهائياً. هل تريد المتابعة؟', style: TextStyle(color: AppTheme.textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Get.back(), child: Text('إلغاء', style: TextStyle(color: AppTheme.textHint))),
                      TextButton(
                        onPressed: () {
                          Get.back();
                          projectController.deleteProject(project.id);
                        },
                        child: const Text('نعم، حذف', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ));
                }),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, ProjectModel project) {
    final nameController = TextEditingController(text: project.name);
    final descController = TextEditingController(text: project.description);
    final budgetController = TextEditingController(text: project.budget.toStringAsFixed(0));

    Get.dialog(AlertDialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text('تعديل تفاصيل المشروع', style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Tajawal', fontWeight: FontWeight.w900, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: AppTheme.inputDecoration('اسم المشروع', Icons.title_rounded),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: descController,
              maxLines: 3,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: AppTheme.inputDecoration('وصف مختصر للمشروع', Icons.description_outlined),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: budgetController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: AppTheme.inputDecoration('الميزانية المستهدفة (دج)', Icons.account_balance_wallet_outlined),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary))),
        AppTheme.gradientButton(
          text: 'حفظ التغييرات',
          onPressed: () {
            Get.back();
            projectController.updateProject(project.id, {
              'name': nameController.text.trim(),
              'description': descController.text.trim(),
              'budget': double.tryParse(budgetController.text) ?? project.budget,
            });
          },
        ),
      ],
    ));
  }

  Widget _buildCircleAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
        ],
      ),
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
    const strokeWidth = 6.0;
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
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle * progress, false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(_ArcProgressPainter old) => old.progress != progress;
}
