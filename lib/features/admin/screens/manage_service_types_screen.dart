import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../data/models/service_type_model.dart';
import '../../../core/theme/app_theme.dart';

class ManageServiceTypesScreen extends StatelessWidget {
  const ManageServiceTypesScreen({super.key});

  IconData _getIconForService(String name, String iconKey) {
    if (name.contains('بناء') || name.contains('عمارة') || name.contains('ترميم')) return Icons.foundation;
    if (name.contains('تعليم') || name.contains('أيتام') || name.contains('كفالة')) return Icons.menu_book;
    if (name.contains('مالية') || name.contains('زكاة') || name.contains('صدقة')) return Icons.payments;
    if (name.contains('غذائية') || name.contains('إطعام') || name.contains('قفة')) return Icons.shopping_basket;
    if (name.contains('جنازة') || name.contains('موتى') || name.contains('إكرام')) return Icons.mosque;
    if (name.contains('طبية') || name.contains('علاج') || name.contains('إسعاف')) return Icons.nightlight_round;
    if (name.contains('ماء') || name.contains('سقيا') || name.contains('بئر')) return Icons.water_drop;
    return Icons.volunteer_activism;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.glassBorder),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppTheme.textPrimary, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🏷️ أنواع الخدمات',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                              fontFamily: 'Tajawal')),
                      Text('إدارة أبواب الخير الخيرية',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showAddTypeDialog(context),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppTheme.greenGlow,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: const Row(
                        children: [
                          Icon(Icons.add_rounded, color: Colors.black, size: 20),
                          SizedBox(width: 6),
                          Text('إضافة',
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
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('service_types').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return AppTheme.loadingState();
                if (snapshot.hasError) return AppTheme.errorState('حدث خطأ في تحميل البيانات');
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return AppTheme.emptyState('لا توجد أنواع خدمات مضافة', icon: Icons.category_outlined);
                }

                var docs = snapshot.data!.docs;
                var types = docs.map((doc) => ServiceTypeModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: types.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final type = types[index];
                    final icon = _getIconForService(type.name, type.icon);

                    return Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.glassBorder),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.glassBorder),
                          ),
                          child: Icon(icon, color: AppTheme.primaryGreen, size: 22),
                        ),
                        title: Text(type.name,
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Tajawal')),
                        subtitle: Text(
                          'الحقول: ${type.fields.join(', ')}',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        trailing: Switch(
                          value: type.isActive,
                          activeThumbColor: AppTheme.primaryGreen,
                          onChanged: (val) {
                            FirebaseFirestore.instance
                                .collection('service_types')
                                .doc(type.id)
                                .update({'isActive': val});
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTypeDialog(BuildContext context) {
    final nameController = TextEditingController();
    final fieldsController = TextEditingController();

    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('➕ إضافة نوع خدمة جديد',
            style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Tajawal')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المسمى (مثال: إطعام الطعام، كفالة يتيم...)',
                style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
            const SizedBox(height: 6),
            TextField(
              controller: nameController,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: AppTheme.inputDecoration('اسم الخدمة', Icons.label_rounded),
            ),
            const SizedBox(height: 14),
            Text('حقول البيانات المطلوبة من المستفيد (افصل بينها بفاصلة)',
                style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
            const SizedBox(height: 6),
            TextField(
              controller: fieldsController,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: AppTheme.inputDecoration('مثال: الوصف، العنوان، التاريخ', Icons.list_rounded),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              
              // إظهار واجهة تحميل
              Get.showOverlay(
                asyncFunction: () async {
                  final fields = fieldsController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  await FirebaseFirestore.instance.collection('service_types').add({
                    'name': nameController.text,
                    'icon': 'category',
                    'isActive': true,
                    'fields': fields,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  Get.back();
                  Get.snackbar('✅ تم', 'تمت إضافة نوع الخدمة بنجاح', 
                    backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
                    colorText: AppTheme.successColor);
                },
                loadingWidget: const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
              );
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
  }
}
