import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../../core/animations/mount_animations.dart';
import '../../../core/animations/visual_effects.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/project_model.dart';
import '../controllers/project_controller.dart';
import 'add_project_screen.dart';

class ProjectsScreen extends StatelessWidget {
  ProjectController get projectController => Get.find<ProjectController>();

  ProjectsScreen({super.key});

  static void showAddProjectSheet(BuildContext context) {
    Get.to(() => const AddProjectScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryGreen.withOpacity(0.03),
              ),
            ),
          ),
          
          Column(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📁 إدارة المشاريع',
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textPrimary,
                                  fontFamily: 'Tajawal')),
                          Obx(() => Text(
                              'تتم إدارة ${projectController.totalProjects} مشروع حالياً',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 13))),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => showAddProjectSheet(context),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppTheme.greenGlow,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: const Row(
                            children: [
                              Icon(Icons.add_task_rounded, color: Colors.black, size: 20),
                              SizedBox(width: 8),
                              Text('مشروع جديد',
                                  style: TextStyle(
                                      color: Colors.black,
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
                child: VisualEffects.glassMorphism(
                  borderRadius: BorderRadius.circular(16),
                  child: TextField(
                    controller: projectController.searchController,
                    decoration: AppTheme.inputDecoration('ابحث عن مشروع أو فئة...', Icons.search_rounded),
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                ),
              ),

              SizedBox(
                height: 55,
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
                    return AppTheme.emptyState('لا توجد نتائج مطابقة', icon: Icons.search_off_rounded);
                  }
                  return RefreshIndicator(
                    color: AppTheme.primaryGreen,
                    onRefresh: () async => projectController.listenToProjects(),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      itemCount: projectController.filteredProjects.length,
                      itemBuilder: (context, index) {
                        final project = projectController.filteredProjects[index];
                        return MountAnimations.staggeredListEntry(
                          index: index,
                          delayMs: 60,
                          dropOffset: 40.0,
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
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.primaryGradient : null,
            color: !isSelected ? AppTheme.surfaceColor : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? Colors.transparent : AppTheme.glassBorder),
            boxShadow: isSelected ? AppTheme.greenGlow : null,
          ),
          child: Row(
            children: [
              Icon(cat['icon'] as IconData, size: 18, color: isSelected ? Colors.black : AppTheme.textHint),
              const SizedBox(width: 8),
              Text(cat['name'] as String,
                  style: TextStyle(
                      color: isSelected ? Colors.black : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500)),
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
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            categoryColor.withOpacity(0.15),
            AppTheme.cardColor,
            AppTheme.cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: categoryColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: categoryColor.withOpacity(0.2), blurRadius: 25, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [categoryColor.withOpacity(0.3), categoryColor.withOpacity(0.05)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: categoryColor.withOpacity(0.4)),
                  ),
                  child: Icon(cat['icon'] as IconData, color: categoryColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(project.name,
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w900, fontSize: 17, height: 1.2)),
                      const SizedBox(height: 4),
                      Text(cat['name'] as String,
                          style: TextStyle(color: categoryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                AppTheme.statusBadge(project.status),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            child: Row(
              children: [
                SizedBox(
                  width: 100, height: 100,
                  child: CustomPaint(
                    painter: _ArcProgressPainter(
                      progress: progress, 
                      color: categoryColor, 
                      backgroundColor: AppTheme.surfaceColor,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$progressPercent%',
                              style: TextStyle(color: categoryColor, fontWeight: FontWeight.w900, fontSize: 22, height: 1)),
                          Text('إنجاز', style: TextStyle(color: AppTheme.textHint, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      _buildMetricRow('جُمع', '${projectController.formatNumber(project.collected)} دج', categoryColor),
                      const SizedBox(height: 10),
                      _buildMetricRow('الهدف', '${projectController.formatNumber(project.budget)} دج', AppTheme.textSecondary),
                      const SizedBox(height: 10),
                      _buildMetricRow('المتبقي', '${projectController.formatNumber(remaining)} دج', AppTheme.warningColor),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppTheme.surfaceColor,
                valueColor: AlwaysStoppedAnimation(categoryColor),
              ),
            ),
          ),

          const SizedBox(height: 20),
          Divider(color: AppTheme.glassBorder, height: 1),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Get.toNamed('/admin/project-detail', arguments: project),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.glassBorder),
                      ),
                      child: Center(
                        child: Text('عرض التفاصيل 👁️', 
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showEditProjectQuickActions(context, project),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppTheme.greenGlow,
                      ),
                      child: const Center(
                        child: Text('تعديل سريع ⚙️', 
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13)),
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

  Widget _buildMetricRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
      ],
    );
  }

  void _showEditProjectQuickActions(BuildContext context, ProjectModel project) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.glassBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('⚙️ إجراءات إدارية سريعة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Tajawal')),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCircleAction(Icons.edit_note_rounded, 'تعديل', AppTheme.primaryGreen, () {
                  Get.back();
                  _showEditDialog(context, project);
                }),
                _buildCircleAction(
                  project.status == 'paused' ? Icons.play_circle_filled_rounded : Icons.pause_circle_filled_rounded,
                  project.status == 'paused' ? 'استئناف' : 'إيقاف',
                  AppTheme.warningColor,
                  () {
                    Get.back();
                    projectController.toggleProjectStatus(project.id, project.status);
                  },
                ),
                _buildCircleAction(Icons.check_circle_rounded, 'إكمال', AppTheme.successColor, () {
                  Get.back();
                  Get.dialog(AlertDialog(
                    backgroundColor: AppTheme.surfaceColor,
                    title: Text('تأكيد الإكمال', style: TextStyle(color: AppTheme.textPrimary)),
                    content: Text('هل تريد تغيير حالة المشروع إلى "مكتمل"؟', style: TextStyle(color: AppTheme.textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                        onPressed: () {
                          Get.back();
                          projectController.updateProject(project.id, {'status': 'completed'});
                        },
                        child: const Text('تأكيد', style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  ));
                }),
                _buildCircleAction(Icons.delete_forever_rounded, 'حذف', AppTheme.errorColor, () {
                  Get.back();
                  Get.dialog(AlertDialog(
                    backgroundColor: AppTheme.surfaceColor,
                    title: Text('تأكيد الحذف', style: TextStyle(color: AppTheme.textPrimary)),
                    content: Text('هل أنت متأكد من حذف "${project.name}"؟ لا يمكن التراجع عن هذا الإجراء.', style: TextStyle(color: AppTheme.textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                        onPressed: () {
                          Get.back();
                          projectController.deleteProject(project.id);
                        },
                        child: const Text('حذف', style: TextStyle(color: Colors.white)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('✏️ تعديل المشروع', style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Tajawal')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: AppTheme.inputDecoration('اسم المشروع', Icons.edit),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 3,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: AppTheme.inputDecoration('الوصف', Icons.description),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: budgetController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: AppTheme.inputDecoration('الميزانية (دج)', Icons.monetization_on),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
          onPressed: () {
            Get.back();
            projectController.updateProject(project.id, {
              'name': nameController.text.trim(),
              'description': descController.text.trim(),
              'budget': double.tryParse(budgetController.text) ?? project.budget,
            });
          },
          child: const Text('حفظ', style: TextStyle(color: Colors.black)),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
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
    const strokeWidth = 8.0;
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
