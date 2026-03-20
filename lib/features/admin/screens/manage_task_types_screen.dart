import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/task_type_model.dart';
import '../../../core/theme/app_theme.dart';

class ManageTaskTypesScreen extends StatelessWidget {
  const ManageTaskTypesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة أنواع المهام"),
        actions: [
          IconButton(
            icon: Icon(Get.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => AppConstants.toggleTheme(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(AppConstants.taskTypesCollection).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var types = snapshot.data!.docs.map((doc) => TaskTypeModel.fromMap(doc.data() as Map<String, dynamic>)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: types.length,
            itemBuilder: (context, index) {
              final type = types[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.task_alt, color: AppTheme.primaryGreen),
                  title: Text(type.name),
                  subtitle: Text(type.description),
                  trailing: Switch(
                    value: type.isActive,
                    onChanged: (val) {
                      FirebaseFirestore.instance
                          .collection(AppConstants.taskTypesCollection)
                          .doc(snapshot.data!.docs[index].id)
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
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddTaskTypeDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("إضافة نوع مهمة جديد"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "اسم المهمة")),
            TextField(controller: descController, decoration: const InputDecoration(labelText: "الوصف")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance.collection(AppConstants.taskTypesCollection).add({
                'name': nameController.text,
                'description': descController.text,
                'isActive': true,
              });
              Navigator.pop(context);
            },
            child: const Text("حفظ"),
          ),
        ],
      ),
    );
  }
}
