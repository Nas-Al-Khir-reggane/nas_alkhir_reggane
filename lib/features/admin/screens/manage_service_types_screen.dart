import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/service_type_model.dart';
import '../../../core/theme/app_theme.dart';

class ManageServiceTypesScreen extends StatelessWidget {
  const ManageServiceTypesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة أنواع الخدمات"),
        actions: [
          IconButton(
            icon: Icon(Get.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => AppConstants.toggleTheme(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(AppConstants.serviceTypesCollection).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var types = snapshot.data!.docs.map((doc) => ServiceTypeModel.fromMap(doc.data() as Map<String, dynamic>)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: types.length,
            itemBuilder: (context, index) {
              final type = types[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.category, color: AppTheme.primaryGreen),
                  title: Text(type.name),
                  subtitle: Text("الحقول: ${type.fields.join(', ')}"),
                  trailing: Switch(
                    value: type.isActive,
                    onChanged: (val) {
                      FirebaseFirestore.instance
                          .collection(AppConstants.serviceTypesCollection)
                          .doc(type.id.isEmpty ? snapshot.data!.docs[index].id : type.id)
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
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddTypeDialog(BuildContext context) {
    final nameController = TextEditingController();
    final fieldsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("إضافة نوع خدمة جديد"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "اسم الخدمة")),
            TextField(controller: fieldsController, decoration: const InputDecoration(labelText: "الحقول (مفصولة بفاصلة)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () {
              final fields = fieldsController.text.split(',').map((e) => e.trim()).toList();
              FirebaseFirestore.instance.collection(AppConstants.serviceTypesCollection).add({
                'name': nameController.text,
                'icon': 'default',
                'isActive': true,
                'fields': fields,
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
