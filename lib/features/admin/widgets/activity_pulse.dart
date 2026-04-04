import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../controllers/admin_controller.dart';
import '../../../data/models/worker_update_model.dart';

class ActivityPulse extends StatelessWidget {
  const ActivityPulse({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppTheme.urgentColor, size: 20),
              const SizedBox(width: 8),
              Text('نبض الميدان (Live)', 
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface, 
                  fontSize: 16, 
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Tajawal'
                )
              ),
              const Spacer(),
              Text('آخر التحديثات', 
                style: TextStyle(
                  color: AppTheme.textSecondary, 
                  fontSize: 11,
                  fontFamily: 'Tajawal'
                )
              ),
            ],
          ),
        ),
        Obx(() => controller.fieldUpdates.isEmpty
          ? _buildEmptyState(context)
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.fieldUpdates.length,
              separatorBuilder: (context, index) => _buildDivider(context),
              itemBuilder: (context, index) {
                final update = controller.fieldUpdates[index];
                return FadeInRight(
                  delay: Duration(milliseconds: index * 100),
                  child: _buildUpdateItem(context, update, controller),
                );
              },
            )),
      ],
    );
  }

  Widget _buildUpdateItem(BuildContext context, WorkerUpdate update, AdminController controller) {
    final avatar = controller.workerAvatarsCache[update.workerId];
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. صورة المتطوع مع مؤشر الحالة
          Stack(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2), width: 2),
                ),
                child: CircleAvatar(
                  backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  backgroundImage: (avatar != null && avatar.isNotEmpty) 
                      ? CachedNetworkImageProvider(avatar) as ImageProvider 
                      : null,
                  child: (avatar == null || avatar.isEmpty) ? const Icon(Icons.person, size: 20) : null,
                ),
              ),
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 14),
          
          // 2. تفاصيل التحديث
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(update.workerName, 
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface, 
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          fontFamily: 'Tajawal'
                        )
                      ),
                    ),
                    Text(timeago.format(update.createdAt, locale: 'ar'), 
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontFamily: 'Tajawal')
                    ),
                    if (controller.isAnyAdmin)
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 16, color: Colors.grey[400]),
                        onPressed: () {
                          Get.dialog(
                            AlertDialog(
                              title: const Text('حذف التحديث', style: TextStyle(fontFamily: 'Tajawal')),
                              content: const Text('هل أنت متأكد من حذف هذا التحديث من نبض الميدان؟', style: TextStyle(fontFamily: 'Tajawal')),
                              actions: [
                                TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
                                TextButton(
                                  onPressed: () {
                                    Get.back();
                                    controller.deleteFieldUpdate(update.id);
                                  }, 
                                  child: const Text('حذف', style: TextStyle(color: Colors.red))
                                ),
                              ],
                            )
                          );
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(update.description, 
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4, fontFamily: 'Tajawal')
                ),
                
                // 3. عرض الصورة المرفقة إن وجدت
                if (update.imageUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: update.imageUrl!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
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

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 60),
      child: Divider(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1), height: 1),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.history_toggle_off_rounded, color: AppTheme.textSecondary.withValues(alpha: 0.2), size: 40),
          const SizedBox(height: 12),
          Text('لا توجد تحديثات حية حالياً', 
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontFamily: 'Tajawal')
          ),
        ],
      ),
    );
  }
}
