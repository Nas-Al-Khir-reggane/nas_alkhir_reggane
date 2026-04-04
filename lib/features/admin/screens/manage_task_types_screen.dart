import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../data/models/task_type_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../controllers/admin_controller.dart';

class ManageTaskTypesScreen extends StatelessWidget {
  const ManageTaskTypesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('task_types').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return AppTheme.loadingState();
                if (snapshot.hasError) return AppTheme.errorState('حدث خطأ في تحميل البيانات');
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return AppTheme.emptyState('لا توجد أنواع مهام مضافة', icon: Icons.task_alt_rounded);
                }

                var docs = snapshot.data!.docs;
                var types = docs.map((doc) => TaskTypeModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

                return ListView.separated(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
                  itemCount: types.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final type = types[index];
                    return _buildTaskCard(context, type, controller);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: AppTheme.glassBorder)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Row(
              children: [
                _buildCircularButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Get.back(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📋 أنواع المهام',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                              fontFamily: 'Tajawal')),
                      Text('إدارة وتصنيف مهام المتطوعين',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              label: 'إضافة نوع مهمة جديد',
              icon: Icons.add_task_rounded,
              isPrimary: true,
              onTap: () => _showEditTaskDialog(context, null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, TaskTypeModel type, AdminController controller) {
    final icon = AppConstants.getIconFromName(type.icon);
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryGreen, size: 22),
        ),
        title: Text(type.name,
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal')),
        subtitle: Text(
          'النوع التقني: ${type.id}',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSmallIconBtn(Icons.edit_outlined, Colors.blue, () => _showEditTaskDialog(context, type)),
            const SizedBox(width: 8),
            _buildSmallIconBtn(Icons.delete_outline_rounded, AppTheme.errorColor, () => _showDeleteConfirm(type.id, controller)),
          ],
        ),
      ),
    );
  }

  void _showEditTaskDialog(BuildContext context, TaskTypeModel? type) {
    final nameController = TextEditingController(text: type?.name ?? '');
    final RxString selectedIcon = (type?.icon ?? 'volunteer').obs;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: Get.isDarkMode ? 0.5 : 0.1), blurRadius: 40, spreadRadius: 5)],
        ),
        child: Column(
          children: [
            Container(
              width: 50, height: 5,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: AppTheme.glassBorder, borderRadius: BorderRadius.circular(10)),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type == null ? '➕ مهمة تطويرية جديدة' : '⚙️ تحديث نوع المهمة',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Tajawal')),
                    const SizedBox(height: 24),
                    
                    _buildLabel('المسمى الوظيفي للمهمة'),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: AppTheme.inputDecoration('مثال: سائق إسعاف، غسال...', Icons.work_outline_rounded),
                    ),
                    const SizedBox(height: 24),

                    _buildLabel('اختر الرمز المناسب'),
                    Obx(() => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.glassBorder),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: AppConstants.charityIcons.map((item) {
                          bool isSelected = selectedIcon.value == item['name'];
                          return GestureDetector(
                            onTap: () => selectedIcon.value = item['name'],
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder, width: 2),
                              ),
                              child: Icon(item['icon'], color: isSelected ? Colors.white : AppTheme.textSecondary, size: 24),
                            ),
                          );
                        }).toList(),
                      ),
                    )),
                    const SizedBox(height: 40),
                    _buildActionButton(
                      label: type == null ? 'إضافة النوع الآن' : 'حفظ التعديلات',
                      icon: Icons.check_circle_rounded,
                      isPrimary: true,
                      onTap: () async {
                        if (nameController.text.isEmpty) return;
                        
                        final data = {
                          'name': nameController.text,
                          'icon': selectedIcon.value,
                          'updatedAt': FieldValue.serverTimestamp(),
                        };

                        if (type == null) {
                          await FirebaseFirestore.instance.collection('task_types').add({
                            ...data,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        } else {
                          await Get.find<AdminController>().updateTaskType(type.id, data);
                        }
                        Get.back();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showDeleteConfirm(String id, AdminController controller) {
    Get.defaultDialog(
      title: 'حذف نوع المهمة',
      middleText: 'هل أنت متأكد؟ سيتم إزالة هذا التصنيف من خيارات تكليف المتطوعين.',
      textConfirm: 'حذف نهائي',
      textCancel: 'إلغاء',
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.errorColor,
      onConfirm: () {
        controller.deleteTaskType(id);
        Get.back();
      },
    );
  }

  Widget _buildSmallIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildCircularButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 20),
      ),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required bool isPrimary, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: isPrimary ? AppTheme.primaryGradient : null,
          color: isPrimary ? null : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: isPrimary ? null : Border.all(color: AppTheme.glassBorder),
          boxShadow: isPrimary ? AppTheme.greenGlow : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isPrimary ? Colors.black : AppTheme.textPrimary, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isPrimary ? Colors.black : AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12.0, end: 4),
      child: Text(text, style: TextStyle(color: AppTheme.textPrimary.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Tajawal')),
    );
  }
}
