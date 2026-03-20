import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/admin_controller.dart';
import '../../../core/constants/app_constants.dart';
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
    final driverCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    Get.defaultDialog(
      title: "إضافة سيارة جديدة",
      content: Form(
        key: formKey,
        child: Column(
          children: [
            TextFormField(
              controller: plateCtl,
              decoration: const InputDecoration(labelText: "رقم اللوحة", border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: typeCtl,
              decoration: const InputDecoration(labelText: "نوع السيارة (إسعاف، شاحنة...)", border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: driverCtl,
              decoration: const InputDecoration(labelText: "اسم السائق (المسؤول)", border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'مطلوب' : null,
            ),
          ],
        ),
      ),
      textConfirm: "حفظ",
      textCancel: "إلغاء",
      confirmTextColor: Colors.white,
      onConfirm: () {
        if (formKey.currentState!.validate()) {
          VehicleModel vehicle = VehicleModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            plateNumber: plateCtl.text.trim(),
            type: typeCtl.text.trim(),
            assignedDriverId: driverCtl.text.trim(),
            isAvailable: true,
            totalKm: 0.0,
            totalTrips: 0,
          );
          _adminCtl.addVehicle(vehicle);
          Get.back();
        }
      },
    );
  }

  void _changeVehicleStatus(VehicleModel v) {
    bool newStatus = !v.isAvailable;
    _adminCtl.updateVehicle(v.copyWith(isAvailable: newStatus));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة السيارات"),
        actions: [
          IconButton(
            icon: Icon(Get.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => AppConstants.toggleTheme(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(AppConstants.vehiclesCollection).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("لا توجد سيارات مسجلة"));

          var docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              VehicleModel v = VehicleModel.fromMap(docs[index].data() as Map<String, dynamic>);
              bool isAvailable = v.isAvailable;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("${v.type} | ${v.plateNumber}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: (isAvailable ? Colors.green : Colors.orange).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                            child: Text(isAvailable ? "متاحة" : "في مهمة", style: TextStyle(color: isAvailable ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text("السائق: ${v.assignedDriverId ?? 'غير محدد'}", style: const TextStyle(fontWeight: FontWeight.w500))),
                          Row(
                            children: [
                              const Icon(Icons.speed, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text("${v.totalKm} كم", style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => _changeVehicleStatus(v),
                          icon: const Icon(Icons.sync_alt),
                          label: Text(isAvailable ? "تحويل إلى في مهمة" : "تحويل إلى متاحة"),
                        ),
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
        child: const Icon(Icons.add),
      ),
    );
  }
}
