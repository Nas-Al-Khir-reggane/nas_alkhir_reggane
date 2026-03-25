import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/donation_model.dart';
import '../../../data/models/worker_update_model.dart';
import '../controllers/project_controller.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class ProjectDetailScreen extends StatelessWidget {
  final ProjectModel project;
  final ProjectController projectController = Get.find<ProjectController>();

  ProjectDetailScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final cat = ProjectController.categories.firstWhere(
      (c) => c['id'] == project.category,
      orElse: () => ProjectController.categories.last,
    );
    final categoryColor = cat['color'] as Color;
    final categoryIcon = cat['icon'] as IconData;
    final categoryName = cat['name'] as String;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: CustomScrollView(
        slivers: [
          // SliverAppBar مع تدرج الفئة
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [categoryColor.withValues(alpha: 0.4), AppTheme.darkBg],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Icon(categoryIcon, color: categoryColor, size: 36),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    project.name,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      AppTheme.statusBadge(project.status),
                                      const SizedBox(width: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: categoryColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        child: Text(
                                          categoryName,
                                          style: TextStyle(
                                            color: categoryColor,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () => projectController.shareProject(project),
              ),
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'edit') {
                    // _showEditProjectSheet(context, project);
                  } else if (val == 'toggle') {
                    projectController.toggleProjectStatus(project.id, project.status);
                  } else if (val == 'delete') {
                    // _showDeleteConfirmDialog(context, project);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(project.status == 'active' ? 'إيقاف' : 'تفعيل'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('حذف')),
                ],
              ),
            ],
          ),

          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // شريط التقدم الكبير
                    Container(
                      decoration: AppTheme.glassDecoration,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text('نسبة الإنجاز', style: TextStyle(color: AppTheme.textSecondary)),
                              const Spacer(),
                              Text(
                                '${project.progressPercentage.toInt()}%',
                                style: const TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(
                              value: project.budget > 0 ? project.collected / project.budget : 0,
                              minHeight: 16,
                              backgroundColor: AppTheme.darkSurface,
                              valueColor: AlwaysStoppedAnimation(_getProgressColor(project.progressPercentage)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('المجموع', style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                                  Text(
                                    '${projectController.formatNumber(project.collected)} دج',
                                    style: const TextStyle(
                                      color: AppTheme.primaryGreen,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text('المتبقي', style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                                  Text(
                                    '${projectController.formatNumber(project.budget - project.collected)} دج',
                                    style: const TextStyle(
                                      color: AppTheme.warningColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('الهدف', style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                                  Text(
                                    '${projectController.formatNumber(project.budget)} دج',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Grid إحصائيات
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.8,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        _buildStatCard('المتبرعون', project.donorsCount.toString(), Icons.people, AppTheme.primaryGreen),
                        _buildStatCard('العمال', project.assignedWorkers.length.toString(), Icons.engineering, Colors.blue),
                        _buildStatCard('أيام متبقية', projectController.daysLeft(project.deadline), Icons.timer, AppTheme.warningColor),
                        _buildStatCard('بداية المشروع', DateFormat('yyyy/MM/dd').format(project.createdAt), Icons.update, AppTheme.textSecondary),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // الوصف
                    _buildSection(
                      '📋 تفاصيل المشروع',
                      Text(
                        project.description,
                        style: TextStyle(color: AppTheme.textSecondary, height: 1.6),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // أزرار الإجراءات
                    Row(
                      children: [
                        Expanded(
                          child: AppTheme.gradientButton(
                            text: 'إضافة تبرع',
                            icon: Icons.volunteer_activism,
                            onPressed: () => Get.toNamed('/donor/donate', arguments: project),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showAssignWorkerSheet(context),
                            icon: const Icon(Icons.person_add),
                            label: const Text('إسناد عامل'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryGreen,
                              side: const BorderSide(color: AppTheme.primaryGreen),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // قائمة المتبرعين
                    _buildSection(
                      '💚 المتبرعون',
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection(AppConstants.donationsCollection)
                            .where('projectId', isEqualTo: project.id)
                            .orderBy('amount', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Text('لا يوجد متبرعون لهذا المشروع بعد',
                                    style: TextStyle(color: AppTheme.textHint)),
                              ),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: snapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              final donation = DonationModel.fromMap(
                                snapshot.data!.docs[index].data() as Map<String, dynamic>,
                              );
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance.collection(AppConstants.usersCollection).doc(donation.donorId).snapshots(),
                                  builder: (context, userSnap) {
                                    String? imageUrl;
                                    if (userSnap.hasData && userSnap.data!.exists) {
                                      imageUrl = (userSnap.data!.data() as Map<String, dynamic>)['profileImage'];
                                    }
                                    return CircleAvatar(
                                      backgroundColor: AppTheme.goldAccent.withValues(alpha: 0.2),
                                      backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
                                      child: (imageUrl == null || imageUrl.isEmpty)
                                          ? Text(
                                              donation.donorName.isNotEmpty ? donation.donorName[0] : '?',
                                              style: const TextStyle(color: AppTheme.goldAccent),
                                            )
                                          : null,
                                    );
                                  }
                                ),
                                title: Text(donation.donorName, style: TextStyle(color: AppTheme.textPrimary)),
                                subtitle: Text(
                                  DateFormat('yyyy/MM/dd').format(donation.date),
                                  style: TextStyle(color: AppTheme.textHint, fontSize: 11),
                                ),
                                trailing: Text(
                                  '${projectController.formatNumber(donation.amount)} دج',
                                  style: TextStyle(color: AppTheme.goldAccent, fontWeight: FontWeight.w700),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // سجل التحديثات الميدانية
                    _buildSection(
                      '🔧 التحديثات الميدانية',
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('worker_updates')
                            .where('projectId', isEqualTo: project.id)
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Text('لا توجد تحديثات ميدانية بعد',
                                    style: TextStyle(color: AppTheme.textHint)),
                              ),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: snapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              var update = WorkerUpdate.fromMap(
                                snapshot.data!.docs[index].data() as Map<String, dynamic>,
                                snapshot.data!.docs[index].id,
                              );
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkCard,
                                  borderRadius: BorderRadius.circular(14),
                                  border: const Border(right: BorderSide(color: AppTheme.primaryGreen, width: 3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        StreamBuilder<DocumentSnapshot>(
                                          stream: FirebaseFirestore.instance.collection(AppConstants.usersCollection).doc(update.workerId).snapshots(),
                                          builder: (context, userSnap) {
                                            String? imageUrl;
                                            if (userSnap.hasData && userSnap.data!.exists) {
                                              imageUrl = (userSnap.data!.data() as Map<String, dynamic>)['profileImage'];
                                            }
                                            return CircleAvatar(
                                              radius: 16,
                                              backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                                              backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
                                              child: (imageUrl == null || imageUrl.isEmpty)
                                                  ? Text(update.workerName.isNotEmpty ? update.workerName[0] : 'W',
                                                      style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 12))
                                                  : null,
                                            );
                                          }
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(update.workerName,
                                                style: const TextStyle(
                                                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                            Text(timeago.format(update.createdAt, locale: 'ar'),
                                                style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(update.description,
                                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
                                    if (update.imageUrl != null) ...[
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(update.imageUrl!,
                                            height: 150, width: double.infinity, fit: BoxFit.cover),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(label, style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassDecoration,
          child: content,
        ),
      ],
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 100) return AppTheme.successColor;
    if (percentage >= 75) return AppTheme.primaryGreen;
    if (percentage >= 40) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  void _showAssignWorkerSheet(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.darkBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('إسناد عامل للمشروع', 
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(AppConstants.usersCollection)
                    .where('role', isEqualTo: 'worker')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var worker = snapshot.data!.docs[index];
                      bool isAssigned = project.assignedWorkers.contains(worker.id);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                          child: Text(worker['name'][0], style: const TextStyle(color: AppTheme.primaryGreen)),
                        ),
                        title: Text(worker['name'], style: TextStyle(color: AppTheme.textPrimary)),
                        trailing: isAssigned 
                          ? const Icon(Icons.check_circle, color: AppTheme.primaryGreen)
                          : const Icon(Icons.add_circle_outline, color: AppTheme.textHint),
                        onTap: () {
                          if (isAssigned) {
                            projectController.unassignWorkerFromProject(project.id, worker.id);
                          } else {
                            projectController.assignWorkerToProject(project.id, worker.id);
                          }
                          Get.back();
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
