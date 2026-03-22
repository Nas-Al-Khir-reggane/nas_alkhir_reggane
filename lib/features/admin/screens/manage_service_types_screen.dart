import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../data/models/service_type_model.dart';
import '../../../core/theme/app_theme.dart';

class ManageServiceTypesScreen extends StatelessWidget {
  const ManageServiceTypesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("إدارة أنواع الخدمات"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('service_types').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return AppTheme.loadingState();
          if (snapshot.hasError) return AppTheme.errorState('حدث خطأ في تحميل البيانات');
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return AppTheme.emptyState('لا توجد أنواع خدمات مضافة');

          var docs = snapshot.data!.docs;
          var types = docs.map((doc) => ServiceTypeModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: types.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final type = types[index];
              return Container(
                decoration: AppTheme.cardDecoration,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.category, color: AppTheme.primaryGreen),
                  ),
                  title: Text(type.name, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  subtitle: Text("الحقول: ${type.fields.join(', ')}", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  trailing: Switch(
                    value: type.isActive,
                    activeColor: AppTheme.primaryGreen,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTypeDialog(context),
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  void _showAddTypeDialog(BuildContext context) {
    final nameController = TextEditingController();
    final fieldsController = TextEditingController();

    Get.dialog(
      AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text("إضافة نوع خدمة جديد", style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Tajawal')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController, 
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: AppTheme.inputDecoration("اسم الخدمة", Icons.label)
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fieldsController, 
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: AppTheme.inputDecoration("الحقول (مفصولة بفاصلة)", Icons.list)
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text("إلغاء", style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) return;
              final fields = fieldsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              FirebaseFirestore.instance.collection('service_types').add({
                'name': nameController.text,
                'icon': 'category',
                'isActive': true,
                'fields': fields,
                'createdAt': FieldValue.serverTimestamp(),
              });
              Get.back();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            child: const Text("حفظ", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
