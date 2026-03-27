import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' as intl;
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_model.dart';
import '../controllers/worker_management_controller.dart';

class WorkerDetailScreen extends StatelessWidget {
  final UserModel worker;

  const WorkerDetailScreen({super.key, required this.worker});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<WorkerManagementController>();
    final roleData = WorkerManagementController.workerRoles.firstWhere(
      (r) => r['id'] == worker.workerRole,
      orElse: () => {'name': 'غير محدد', 'icon': Icons.person, 'color': Colors.grey},
    );
    final roleName = roleData['name'] as String;
    final roleIcon = roleData['icon'] as IconData; // ignore: unused_local_variable
    final roleColor = roleData['color'] as Color;

    double completionRate = 0;
    if (worker.completedTasks + worker.currentTasksCount > 0) {
      completionRate = (worker.completedTasks / (worker.completedTasks + worker.currentTasksCount)) * 100;
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppTheme.darkBgGradient),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 45,
                                  backgroundColor: roleColor.withValues(alpha: 0.3),
                                  backgroundImage: (worker.profileImage != null && worker.profileImage!.isNotEmpty)
                                      ? NetworkImage(worker.profileImage!)
                                      : null,
                                  child: (worker.profileImage == null || worker.profileImage!.isEmpty)
                                      ? Text(worker.name.isNotEmpty ? worker.name[0] : '?',
                                          style: TextStyle(color: roleColor, fontSize: 36, fontWeight: FontWeight.w800))
                                      : null,
                                ),
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: worker.isAvailable ? AppTheme.successColor : AppTheme.warningColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppTheme.darkBg, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(worker.name,
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                  const SizedBox(height: 4),
                                  Container(
                                    decoration: BoxDecoration(
                                        color: roleColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    child: Text(roleName,
                                        style: TextStyle(color: roleColor, fontWeight: FontWeight.w600, fontSize: 12)),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, color: AppTheme.textHint, size: 14),
                                      const SizedBox(width: 4),
                                      Text(worker.wilaya,
                                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.phone, color: AppTheme.successColor),
                onPressed: () async {
                  final url = 'tel:${worker.phone}';
                  if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
                },
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryGreen),
                onPressed: () => Get.toNamed('/chat', arguments: {'workerId': worker.id, 'workerName': worker.name}),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppTheme.textPrimary),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('تعديل البيانات')),
                  PopupMenuItem(value: 'toggle_avail', child: Text(worker.isAvailable ? 'تعيين مشغول' : 'تعيين متاح')),
                  const PopupMenuItem(value: 'rate', child: Text('تقييم العامل')),
                  PopupMenuItem(
                      value: 'disable',
                      child: Text(worker.isActive ? 'تعطيل الحساب' : 'تفعيل الحساب',
                          style: TextStyle(color: worker.isActive ? AppTheme.errorColor : AppTheme.successColor))),
                ],
                onSelected: (val) {
                  if (val == 'toggle_avail') {
                    controller.toggleAvailability(worker.id, worker.isAvailable);
                  } else if (val == 'disable') {
                    controller.toggleWorkerStatus(worker.id, worker.isActive);
                  }
                  // More actions can be implemented here
                },
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // إحصائات الأداء - Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.5,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _buildPerformanceStat('المهام المنجزة', worker.completedTasks.toString(), Icons.task_alt, AppTheme.successColor),
                    _buildPerformanceStat('نسبة الإنجاز', '${completionRate.toStringAsFixed(1)}%', Icons.trending_up, AppTheme.primaryGreen),
                    if (worker.workerRole == 'funeral_driver')
                      _buildPerformanceStat('إجمالي الرحلات', worker.totalTrips.toString(), Icons.airport_shuttle, const Color(0xFF4A148C)),
                    _buildPerformanceStat('مدة العضوية', _getMembershipDuration(worker.createdAt), Icons.calendar_month, AppTheme.goldAccent),
                  ],
                ),

                const SizedBox(height: 16),

                // التقييم بالنجوم
                Container(
                  decoration: AppTheme.glassDecoration,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Text(worker.rating.toStringAsFixed(1),
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 36, fontWeight: FontWeight.w800)),
                          const Text('من 5.0', style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                              children: List.generate(
                                  5,
                                  (index) => Icon(
                                        index < worker.rating.floor() ? Icons.star : Icons.star_border,
                                        color: Colors.amber,
                                        size: 22,
                                      ))),
                          const SizedBox(height: 4),
                          Text('${worker.ratingCount} تقييم',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ],
                      ),
                      const Spacer(),
                      AppTheme.gradientButton(
                        text: 'تقييم',
                        icon: Icons.star,
                        onPressed: () => _showRateDialog(context, worker, controller),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // معلومات شخصية
                _buildSection('📋 المعلومات الشخصية', [
                  _buildInfoRow(Icons.phone, 'الهاتف', worker.phone),
                  _buildInfoRow(Icons.email, 'البريد', worker.email),
                  _buildInfoRow(Icons.location_on, 'الولاية', worker.wilaya),
                  _buildInfoRow(Icons.home, 'العنوان', worker.address.isNotEmpty ? worker.address : 'غير محدد'),
                  _buildInfoRow(Icons.calendar_today, 'تاريخ الانضمام', intl.DateFormat('yyyy/MM/dd').format(worker.createdAt)),
                  _buildInfoRow(Icons.update, 'آخر نشاط', worker.lastActivity != null ? timeago.format(worker.lastActivity!, locale: 'ar') : 'غير متوفر'),
                ]),

                const SizedBox(height: 16),

                // آخر تحديث ميداني
                _buildSection('🔧 آخر تحديث ميداني', [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('field_updates')
                        .where('workerId', isEqualTo: worker.id)
                        .orderBy('createdAt', descending: true)
                        .limit(1)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                            child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('لا توجد تحديثات ميدانية بعد',
                              style: TextStyle(color: AppTheme.textHint, fontSize: 14)),
                        ));
                      }
                      final update = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(14)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.history, color: AppTheme.primaryGreen, size: 16),
                                const SizedBox(width: 8),
                                Text(timeago.format((update['createdAt'] as Timestamp).toDate(), locale: 'ar'),
                                    style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(update['description'] ?? '',
                                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                          ],
                        ),
                      );
                    },
                  ),
                ]),

                const SizedBox(height: 16),

                // سجل المهام
                _buildSection('📜 سجل المهام', [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('service_requests')
                        .where('assignedTo', isEqualTo: worker.id)
                        .orderBy('updatedAt', descending: true)
                        .limit(10)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      if (snapshot.data!.docs.isEmpty) {
                        return const Center(
                            child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('لا توجد مهام مسجلة', style: TextStyle(color: AppTheme.textHint)),
                        ));
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final request = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: Container(
                                decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.all(8),
                                child: const Icon(Icons.assignment, color: AppTheme.primaryGreen, size: 18),
                              ),
                              title: Text(AppConstants.translateServiceType(request['serviceName'] ?? request['type'] ?? 'طلب خدمة'),
                                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
                              subtitle: Text('${request['requesterName'] ?? ''} - ${request['wilaya'] ?? ''}',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                              trailing: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AppTheme.statusBadge(request['status'] ?? 'pending'),
                                  const SizedBox(height: 4),
                                  Text(
                                      request['updatedAt'] != null
                                          ? timeago.format((request['updatedAt'] as Timestamp).toDate(), locale: 'ar')
                                          : '',
                                      style: TextStyle(color: AppTheme.textHint, fontSize: 10)),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ]),

                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceStat(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(title,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGreen, size: 18),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const Spacer(),
          Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _getMembershipDuration(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    if (difference.inDays >= 365) {
      final years = (difference.inDays / 365).floor();
      return 'عضو منذ $years سنة';
    } else {
      final months = (difference.inDays / 30).floor();
      return months > 0 ? 'عضو منذ $months شهر' : 'عضو جديد';
    }
  }

  void _showRateDialog(BuildContext context, UserModel worker, WorkerManagementController controller) {
    double selectedRating = 5.0;
    Get.dialog(
      StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('تقييم ${worker.name}', style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('اختر التقييم', style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final star = index + 1;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedRating = star.toDouble()),
                    child: Icon(
                      star <= selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                selectedRating >= 5 ? 'ممتاز' : selectedRating >= 4 ? 'جيد جداً' : selectedRating >= 3 ? 'جيد' : 'مقبول',
                style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
            AppTheme.gradientButton(
              text: 'حفظ',
              onPressed: () => controller.rateWorker(worker.id, selectedRating),
            ),
          ],
        );
      }),
    );
  }
}
