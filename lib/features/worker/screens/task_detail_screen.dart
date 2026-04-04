import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/models/service_request_model.dart';

class TaskDetailScreen extends StatelessWidget {
  final ServiceRequestModel task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    // تحديد اسم المهمة المترجم
    final String taskName = task.typeName.isNotEmpty 
        ? task.typeName 
        : AppConstants.translateServiceType(task.type);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('تفاصيل المهمة', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionCard(
              context,
              title: taskName, // تم التغيير هنا لاستخدام الاسم المترجم مباشرة
              icon: Icons.assignment_turned_in_outlined,
              children: [
                _row(context, 'رقم المهمة', '#${task.id.length > 8 ? task.id.substring(0, 8) : task.id}'),
                _row(context, 'حالة الطلب', AppConstants.translateStatus(task.status)),
                _row(context, 'الأولوية', AppConstants.translateStatus(task.urgency)),
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              context,
              title: 'بيانات المستفيد',
              icon: Icons.person_outline,
              children: [
                _row(context, 'الاسم', task.requesterName),
                _row(context, 'الهاتف', task.phone),
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              context,
              title: 'المكان',
              icon: Icons.location_on_outlined,
              children: [
                _row(context, 'الولاية', task.wilaya),
                if (task.commune.isNotEmpty) _row(context, 'البلدية', task.commune),
                _row(context, 'العنوان', task.address),
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              context,
              title: 'وقت الحاجة',
              icon: Icons.schedule,
              children: [
                _row(context, 'تاريخ الإنشاء', _fmt(task.createdAt)),
                _row(context, 'آخر تحديث', _fmt(task.updatedAt)),
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              context,
              title: 'ملاحظات',
              icon: Icons.notes_outlined,
              children: [
                Text(
                  task.description.isEmpty || task.description == 'لا شيء' ? 'لا توجد ملاحظات إضافية' : task.description,
                  style: GoogleFonts.tajawal(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AppTheme.gradientButton(
              text: 'تحديث حالة المهمة',
              icon: Icons.update,
              onPressed: () => Get.toNamed(AppRoutes.workerUpdateTask, arguments: task),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              '$label:',
              style: GoogleFonts.tajawal(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.tajawal(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
