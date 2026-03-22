import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../data/models/task_type_model.dart';
import '../../../core/theme/app_theme.dart';

class ManageTaskTypesScreen extends StatelessWidget {
  const ManageTaskTypesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("إدارة أنواع المهام"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('task_types').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return AppTheme.loadingState();
          if (snapshot.hasError) return AppTheme.errorState('حدث خطأ في تحميل البيانات');
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return AppTheme.emptyState('لا توجد أنواع مهام مضافة');

          var docs = snapshot.data!.docs;
          var types = docs.map((doc) => TaskTypeModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

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
                    child: const Icon(Icons.task_alt, color: AppTheme.primaryGreen),
                  ),
                  title: Text(type.name, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  subtitle: Text(type.description, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  trailing: Switch(
                    value: type.isActive,
                    activeColor: AppTheme.primaryGreen,
                    onChanged: (val) {
                      FirebaseFirestore.instance
                          .collection('task_types')
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
        onPressed: () => _showAddTaskTypeDialog(context),
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  void _showAddTaskTypeDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    Get.dialog(
      AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text("إضافة نوع مهمة جديد", style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Tajawal')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController, 
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: AppTheme.inputDecoration("اسم المهمة", Icons.task)
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController, 
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: AppTheme.inputDecoration("الوصف", Icons.description)
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text("إلغاء", style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) return;
              FirebaseFirestore.instance.collection('task_types').add({
                'name': nameController.text,
                'description': descController.text,
                'isActive': true,
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
