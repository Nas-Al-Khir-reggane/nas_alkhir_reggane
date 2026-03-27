import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
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

  final List<Map<String, dynamic>> _vehicleTypesList = [
    {'name': 'نقل إسعاف', 'icon': Icons.local_hospital_rounded},
    {'name': 'نقل موتى (جنائز)', 'icon': Icons.airport_shuttle_rounded},
    {'name': 'نقل مواد عينية', 'icon': Icons.local_shipping_rounded},
    {'name': 'سيارة إدارية', 'icon': Icons.directions_car_rounded},
    {'name': 'أخرى', 'icon': Icons.car_rental_rounded},
  ];

  IconData _getIconForType(String type) {
    for (var item in _vehicleTypesList) {
      if (item['name'] == type) return item['icon'];
    }
    return Icons.directions_car_rounded;
  }

  void _showAddVehicleDialog() {
    final plateCtl = TextEditingController();
    final modelCtl = TextEditingController();
    String? selectedType = _vehicleTypesList[0]['name'];
    final formKey = GlobalKey<FormState>();

    Get.bottomSheet(
      StatefulBuilder(builder: (context, setSheetState) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20)],
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("إضافة سيارة جديدة", style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: plateCtl,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: AppTheme.inputDecoration("رقم اللوحة", Icons.branding_watermark_outlined),
                  validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: AppTheme.darkSurface,
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryGreen),
                      value: selectedType,
                      items: _vehicleTypesList.map((type) {
                        return DropdownMenuItem<String>(
                          value: type['name'],
                          child: Row(
                            children: [
                              Icon(type['icon'], color: AppTheme.primaryGreen, size: 20),
                              const SizedBox(width: 10),
                              Text(type['name'], style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Tajawal')),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setSheetState(() => selectedType = val),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: modelCtl,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: AppTheme.inputDecoration("الموديل (اختياري)", Icons.directions_car_filled_outlined),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppTheme.glassBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Get.back(),
                        child: const Text("إلغاء", style: TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTheme.gradientButton(
                        text: "حفظ وإضافة",
                        icon: Icons.add_circle_outline,
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            FirebaseFirestore.instance.collection('vehicles').add({
                              'plateNumber': plateCtl.text.trim(),
                              'type': selectedType,
                              'model': modelCtl.text.trim(),
                              'status': 'ready',
                              'isAvailable': true,
                              'totalTrips': 0,
                              'totalKm': 0,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                            Get.back();
                            Get.snackbar("نجاح", "تمت إضافة السيارة بنجاح", 
                                snackPosition: SnackPosition.BOTTOM, 
                                backgroundColor: AppTheme.successColor.withValues(alpha: 0.8), 
                                colorText: Colors.white);
                          }
                        },
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      }),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );
  }

  void _showDeleteDialog(VehicleModel vehicle) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppTheme.glassBorder)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text("تأكيد الحذف", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
          ],
        ),
        content: Text("هل أنت متأكد من حذف السيارة ذات اللوحة ${vehicle.plateNumber}؟ السجلات المرتبطة بها قد تتأثر.",
            style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Tajawal')),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("إلغاء", style: TextStyle(color: AppTheme.textHint))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              FirebaseFirestore.instance.collection('vehicles').doc(vehicle.id).delete();
              Get.back();
            },
            child: const Text("حذف نهائي", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('vehicles').orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
                  if (snapshot.hasError) return const Center(child: Text('حدث خطأ في تحميل البيانات', style: TextStyle(color: AppTheme.errorColor)));
                  
                  var docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) return _buildEmptyState();

                  return ListView.builder(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 90),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      VehicleModel v = VehicleModel.fromMap(data, docs[index].id);

                      return FadeInUp(
                        delay: Duration(milliseconds: 100 * (index % 5)),
                        child: _buildVehicleCard(v),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FadeInUp(
        child: FloatingActionButton.extended(
          onPressed: _showAddVehicleDialog,
          backgroundColor: AppTheme.primaryGreen,
          icon: const Icon(Icons.add, color: Colors.black),
          label: const Text("إضافة سيارة", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                color: AppTheme.textPrimary,
                onPressed: () => Get.back(),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إدارة السيارات', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
                  Text('إدارة أسطول العمل الخيري', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.airport_shuttle_rounded, color: AppTheme.primaryGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return FadeIn(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_filled_outlined, size: 80, color: AppTheme.textHint.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text("أسطول السيارات فارغ", style: TextStyle(color: AppTheme.textHint, fontSize: 16, fontWeight: FontWeight.bold)),
            Text("قم بإضافة سيارتك الأولى لتبدأ إدارة الأسطول", style: TextStyle(color: AppTheme.textHint.withValues(alpha: 0.7), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(VehicleModel v) {
    bool isAvail = v.isAvailable;
    Color statusColor = isAvail ? AppTheme.successColor : AppTheme.warningColor;
    String statusText = isAvail ? 'متـاحة' : 'مشغـولة';
    IconData icon = _getIconForType(v.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: isAvail ? 0.05 : 0.15),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ],
      ),
      child: Stack(
        children: [
          // Background abstract icon
          Positioned(
            left: -10,
            bottom: -15,
            child: Icon(icon, size: 100, color: Colors.white.withValues(alpha: 0.03)),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [statusColor.withValues(alpha: 0.2), statusColor.withValues(alpha: 0.05)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                          ),
                          child: Icon(icon, color: statusColor, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.type,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle, boxShadow: [
                                    BoxShadow(color: statusColor.withValues(alpha: 0.5), blurRadius: 4, spreadRadius: 1)
                                  ]),
                                ),
                                const SizedBox(width: 6),
                                Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    PopupMenuButton<String>(
                      color: AppTheme.darkSurface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: AppTheme.glassBorder)),
                      icon: Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
                      onSelected: (val) {
                        if (val == 'delete') _showDeleteDialog(v);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: AppTheme.errorColor, size: 18), const SizedBox(width: 8), Text("حذف السيارة", style: TextStyle(color: AppTheme.errorColor))])),
                      ],
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: AppTheme.glassBorder, height: 1),
                ),
                Row(
                  children: [
                    _buildInfoChip(Icons.branding_watermark_outlined, "اللوحة", v.plateNumber),
                    const SizedBox(width: 12),
                    _buildInfoChip(Icons.directions_car_filled_outlined, "الموديل", v.model?.isNotEmpty == true ? v.model! : 'غير محدد'),
                    const SizedBox(width: 12),
                    _buildInfoChip(Icons.route_outlined, "الرحلات", "${v.totalTrips}"),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    FirebaseFirestore.instance.collection('vehicles').doc(v.id).update({'isAvailable': !isAvail});
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isAvail ? AppTheme.darkBg : AppTheme.successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isAvail ? AppTheme.glassBorder : AppTheme.successColor.withValues(alpha: 0.5)),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isAvail ? Icons.lock_clock_outlined : Icons.lock_open_outlined, 
                            color: isAvail ? AppTheme.textSecondary : AppTheme.successColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          isAvail ? "تعيين كـ مشغولة" : "تحرير وتعيين كـ متاحة",
                          style: TextStyle(
                            color: isAvail ? AppTheme.textSecondary : AppTheme.successColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
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

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: AppTheme.darkBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.textHint, size: 16),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppTheme.textHint, fontSize: 10)),
            Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold), 
                 maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
