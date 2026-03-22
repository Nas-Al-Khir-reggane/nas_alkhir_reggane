import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/admin_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicle_model.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final AdminController _adminCtl = Get.find<AdminController>();

  void _showAddVehicleDialog() {
    final typeCtl = TextEditingController();
    final plateCtl = TextEditingController();
    final modelCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text("إضافة سيارة جديدة", style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Tajawal')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: plateCtl,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: AppTheme.inputDecoration("رقم اللوحة", Icons.tag),
                validator: (v) => v!.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: typeCtl,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: AppTheme.inputDecoration("نوع السيارة", Icons.airport_shuttle),
                validator: (v) => v!.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: modelCtl,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: AppTheme.inputDecoration("الموديل", Icons.calendar_today),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text("إلغاء", style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                FirebaseFirestore.instance.collection('vehicles').add({
                  'plateNumber': plateCtl.text.trim(),
                  'type': typeCtl.text.trim(),
                  'model': modelCtl.text.trim(),
                  'status': 'ready',
                  'isAvailable': true,
                  'totalTrips': 0,
                  'totalKm': 0,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                Get.back();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            child: const Text("حفظ", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text("إدارة السيارات"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehicles').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return AppTheme.loadingState();
          if (snapshot.hasError) return AppTheme.errorState('حدث خطأ في تحميل البيانات');
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return AppTheme.emptyState('لا توجد سيارات مسجلة');

          var docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              VehicleModel v = VehicleModel.fromMap(data, docs[index].id);

              return Container(
                decoration: AppTheme.cardDecoration,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("${v.type} | ${v.plateNumber}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                          AppTheme.statusBadge(v.isAvailable ? 'normal' : 'urgent'), // Using 'normal' for available, 'urgent' for busy as placeholder
                        ],
                      ),
                      const Divider(color: AppTheme.glassBorder),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("الموديل: ${v.model ?? 'غير محدد'}", style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          Text("${v.totalTrips} رحلة", style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                FirebaseFirestore.instance.collection('vehicles').doc(v.id).update({'isAvailable': !v.isAvailable});
                              },
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryGreen)),
                              child: Text(v.isAvailable ? "تعيين كـ مشغول" : "تعيين كـ متاح", style: const TextStyle(color: AppTheme.primaryGreen)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddVehicleDialog,
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
