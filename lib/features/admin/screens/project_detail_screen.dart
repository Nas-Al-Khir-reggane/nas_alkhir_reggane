import 'package:nas_al_kheir/core/widgets/geometric_progress.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/donation_model.dart';
import '../../../data/models/worker_update_model.dart';
import '../controllers/project_controller.dart';
import '../../donor/controllers/donor_controller.dart';
import '../../../core/animations/scroll_animations.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/widgets/cached_image_widget.dart';

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
      backgroundColor: AppTheme.backgroundColor,
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
                    colors: [categoryColor.withValues(alpha: 0.15), AppTheme.backgroundColor],
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
                                color: categoryColor.withValues(alpha: 0.15),
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
                icon: const Icon(Icons.share, color: Colors.white),
                tooltip: 'مشاركة بطاقة احترافية',
                onPressed: () => projectController.shareProjectImage(project, categoryColor, categoryName),
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
                              ScrollAnimations.numberCounter(
                                value: project.progressPercentage.toInt(),
                                suffix: '%',
                                style: const TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          GoalGridProgress(
                            budget: project.budget,
                            collected: project.collected,
                            categoryId: project.category,
                            activeColor: categoryColor,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('المجموع', style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                                  ScrollAnimations.numberCounter(
                                    value: project.collected,
                                    suffix: ' دج',
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
                                  ScrollAnimations.numberCounter(
                                    value: project.budget - project.collected,
                                    suffix: ' دج',
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
                                  ScrollAnimations.numberCounter(
                                    value: project.budget,
                                    suffix: ' دج',
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
                        _buildStatCard('المتبرعون', project.donorsCount, Icons.people, AppTheme.primaryGreen),
                        _buildStatCard('المتطوعون', project.assignedWorkers.length, Icons.engineering, Colors.blue),
                        _buildStatCard('أيام متبقية', projectController.daysLeftNum(project.deadline), Icons.timer, AppTheme.warningColor, unit: 'يوم'),
                        _buildStatCard('بداية المشروع', DateFormat('yyyy/MM/dd').format(project.createdAt), Icons.update, AppTheme.textSecondary, isNum: false),
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
                            onPressed: () {
                              // تهيئة مشروع محدد في الـ DonorController قبل الانتقال
                              try {
                                final donorController = Get.find<DonorController>();
                                donorController.preSelectProject(project.id, project.name);
                              } catch (e) {
                                debugPrint('DonorController not initialized yet: $e');
                              }
                              Get.toNamed('/donor/donate');
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showAssignWorkerSheet(context),
                            icon: const Icon(Icons.person_add),
                            label: const Text('إسناد متطوع'),
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
                        // إزالة ORDER BY لتجنب الحاجة لفهارس (Indexes) وتعطيل العرض
                        // سنقوم بالترتيب برمجياً داخل الكود لضمان اشتغاله فوراً
                        stream: FirebaseFirestore.instance
                            .collection(AppConstants.donationsCollection)
                            .where('projectId', isEqualTo: project.id)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Text('لا يوجد متبرعون لهذا المشروع بعد',
                                    style: TextStyle(color: AppTheme.textHint)),
                              ),
                            );
                          }

                          // الترتيب اليدوي (الأحدث أولاً) لتجنب Index error
                          final docs = snapshot.data!.docs.toList();
                          docs.sort((a, b) {
                            final aDate = (a.data() as Map<String, dynamic>)['date'] as Timestamp?;
                            final bDate = (b.data() as Map<String, dynamic>)['date'] as Timestamp?;
                            if (aDate == null) return 1;
                            if (bDate == null) return -1;
                            return bDate.compareTo(aDate);
                          });

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final donation = DonationModel.fromMap(
                                docs[index].data() as Map<String, dynamic>,
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
                                      backgroundColor: AppTheme.goldAccent.withValues(alpha: 0.15),
                                      backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? CachedNetworkImageProvider(imageUrl) as ImageProvider : null,
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
                                trailing: ScrollAnimations.numberCounter(
                                  value: donation.amount,
                                  suffix: ' دج',
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
                        // إزالة ORDER BY لتجنب الحاجة لفهارس (Indexes)
                        stream: FirebaseFirestore.instance
                            .collection('worker_updates')
                            .where('projectId', isEqualTo: project.id)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Text('لا توجد تحديثات ميدانية بعد',
                                    style: TextStyle(color: AppTheme.textHint)),
                              ),
                            );
                          }

                          // الترتيب اليدوي (الأحدث أولاً)
                          final docs = snapshot.data!.docs.toList();
                          docs.sort((a, b) {
                            final aDate = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                            final bDate = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                            if (aDate == null) return 1;
                            if (bDate == null) return -1;
                            return bDate.compareTo(aDate);
                          });

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              var update = WorkerUpdate.fromMap(
                                docs[index].data() as Map<String, dynamic>,
                                docs[index].id,
                              );
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardColor,
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
                                              backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                                              backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? CachedNetworkImageProvider(imageUrl) as ImageProvider : null,
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
                                                style: TextStyle(
                                                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
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
                                        child: CachedImageWidget(imageUrl: update.imageUrl!,
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

  Widget _buildStatCard(String label, dynamic value, IconData icon, Color color, {bool isNum = true, String unit = ''}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
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
                if (isNum && value is num)
                  ScrollAnimations.numberCounter(
                    value: value,
                    suffix: unit.isNotEmpty ? ' $unit' : '',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                  )
                else
                  Text(
                    value.toString(),
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

  void _showAssignWorkerSheet(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('إسناد متطوع للمشروع',
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
                          backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                          child: Text(worker['name'][0], style: TextStyle(color: AppTheme.primaryGreen)),
                        ),
                        title: Text(worker['name'], style: TextStyle(color: AppTheme.textPrimary)),
                        trailing: isAssigned
                          ? Icon(Icons.check_circle, color: AppTheme.primaryGreen)
                          : Icon(Icons.add_circle_outline, color: AppTheme.textHint),
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

