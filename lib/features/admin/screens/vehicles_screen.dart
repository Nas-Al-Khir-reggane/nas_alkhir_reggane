import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../data/services/cloudinary_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:latlong2/latlong.dart';
import 'full_screen_map_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicle_model.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
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
    final nicknameCtl = TextEditingController();
    String? selectedType = _vehicleTypesList[0]['name'];
    final formKey = GlobalKey<FormState>();

    Get.bottomSheet(
      StatefulBuilder(builder: (context, setSheetState) {
        return Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.15), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20)],
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
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
                TextFormField(
                  controller: nicknameCtl,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: AppTheme.inputDecoration("الاسم الرمزي (مثلاً: نسر 01)", Icons.stars_outlined),
                  validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: AppTheme.surfaceColor,
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          side: const BorderSide(color: AppTheme.glassBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Get.back(),
                        child: Text("إلغاء", style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Tajawal')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppTheme.gradientButton(
                        text: "حفظ وإضافة",
                        horizontalPadding: 12,
                        icon: Icons.add_circle_outline,
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            FirebaseFirestore.instance.collection('vehicles').add({
                              'plateNumber': plateCtl.text.trim(),
                              'type': selectedType,
                              'model': modelCtl.text.trim(),
                              'nickname': nicknameCtl.text.trim(),
                              'status': 'ready',
                              'isAvailable': true,
                              'totalTrips': 0,
                              'totalKm': 0,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                            Get.back();
                            Get.snackbar("نجاح", "تمت إضافة السيارة بنجاح", 
                                snackPosition: SnackPosition.BOTTOM, 
                                backgroundColor: AppTheme.successColor.withValues(alpha: 0.15), 
                                colorText: Colors.white);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
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
        backgroundColor: AppTheme.surfaceColor,
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
          TextButton(onPressed: () => Get.back(), child: Text("إلغاء", style: TextStyle(color: AppTheme.textHint))),
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
                    padding: const EdgeInsetsDirectional.only(start: 20, end: 20, top: 10, bottom: 90),
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

  Widget _buildVehicleCard(VehicleModel v) {
    final bool isOnline = v.isAvailable;
    final IconData typeIcon = _getIconForType(v.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.glassBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          // الجزء العلوي: معلومات السيارة
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryGreen.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                // أيقونة السيارة مع خلفية متدرجة أو الصورة المختارة
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: v.imageUrl == null ? LinearGradient(
                      colors: [
                        AppTheme.primaryGreen.withValues(alpha: 0.2),
                        AppTheme.primaryGreen.withValues(alpha: 0.05),
                      ],
                    ) : null,
                    shape: BoxShape.circle,
                    image: v.imageUrl != null ? DecorationImage(image: CachedNetworkImageProvider(v.imageUrl!), fit: BoxFit.cover) : null,
                    border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                  ),
                  child: v.imageUrl == null ? Icon(typeIcon, color: AppTheme.primaryGreen, size: 28) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.nickname ?? 'مركبة غير مسماة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.tajawal(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              v.plateNumber,
                              style: const TextStyle(
                                color: AppTheme.primaryGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              v.type,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // حالة السيارة
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isOnline ? Colors.green.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isOnline ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOnline ? 'جاهزة' : 'في مهمة',
                              style: TextStyle(
                                color: isOnline ? Colors.green : Colors.red,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_note_rounded, color: AppTheme.textHint, size: 24),
                          onPressed: () => _showEditVehicleDialog(v),
                          tooltip: 'تعديل',
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_sweep_outlined, color: AppTheme.errorColor, size: 24),
                          onPressed: () => _showDeleteDialog(v),
                          tooltip: 'حذف',
                        ),
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),

          // قسم تتبع الموقع (نسخة خفيفة للأداء)
          if (v.currentLocation != null)
            GestureDetector(
              onTap: () => Get.to(() => FullScreenMapScreen(
                targetLocation: LatLng(v.currentLocation!.latitude, v.currentLocation!.longitude),
                title: 'تتبع الحافلة: ${v.plateNumber}',
                initialZoom: 16,
              ), transition: Transition.fadeIn),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.satellite_alt_rounded, color: AppTheme.primaryGreen, size: 24),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('آخر موقع مرصود للحافلة', 
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')
                          ),
                          const SizedBox(height: 4),
                          Text('إحداثيات: ${v.currentLocation!.latitude.toStringAsFixed(4)}, ${v.currentLocation!.longitude.toStringAsFixed(4)}', 
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontFamily: 'Tajawal')
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.3), blurRadius: 8)],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.map_outlined, color: Colors.black, size: 16),
                          SizedBox(width: 6),
                          Text('تتبع', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
               height: 100,
               margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
               decoration: BoxDecoration(
                 color: Colors.black26,
                 borderRadius: BorderRadius.circular(18),
                 border: Border.all(color: AppTheme.glassBorder, style: BorderStyle.solid),
               ),
               child: Center(
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Icon(Icons.location_off_rounded, color: AppTheme.textHint.withValues(alpha: 0.3), size: 30),
                     const SizedBox(height: 8),
                     Text('لا تتوفر إحداثيات تتبع حالياً', style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                   ],
                 ),
               ),
            ),

          // الإحصائيات السريعة في الأسفل
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('الرحلات', v.totalTrips.toString(), Icons.route_rounded),
                _buildStatItem('المسافة', '${v.totalKm.toStringAsFixed(1)} كم', Icons.speed_rounded),
                _buildStatItem('الموديل', v.model?.isNotEmpty == true ? v.model! : '-', Icons.calendar_today_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.textHint, size: 18),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(color: AppTheme.textHint, fontSize: 10)),
      ],
    );
  }

  void _showEditVehicleDialog(VehicleModel v) {
    final plateCtl = TextEditingController(text: v.plateNumber);
    final modelCtl = TextEditingController(text: v.model);
    final nicknameCtl = TextEditingController(text: v.nickname);
    String? selectedType = v.type;
    final formKey = GlobalKey<FormState>();
    File? imageFile;
    bool isUploading = false;

    Get.bottomSheet(
      StatefulBuilder(builder: (context, setSheetState) {
        return Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 30),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.15), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20)],
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("تعديل بيانات المركبة", 
                        style: TextStyle(
                          color: AppTheme.textPrimary, 
                          fontSize: 18, 
                          fontWeight: FontWeight.bold, 
                          fontFamily: 'Tajawal'
                        )
                      ),
                      if (isUploading) 
                         const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // واجهة اختيار الصورة
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
                        if (picked != null) {
                          setSheetState(() => imageFile = File(picked.path));
                        }
                      },
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3), width: 2),
                              image: imageFile != null 
                                ? DecorationImage(image: FileImage(imageFile!), fit: BoxFit.cover)
                                : (v.imageUrl != null 
                                    ? DecorationImage(image: CachedNetworkImageProvider(v.imageUrl!), fit: BoxFit.cover)
                                    : null),
                            ),
                            child: (imageFile == null && v.imageUrl == null)
                                ? Icon(_getIconForType(selectedType ?? v.type), color: AppTheme.primaryGreen.withValues(alpha: 0.5), size: 40)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  TextFormField(
                    controller: plateCtl,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: AppTheme.inputDecoration("رقم اللوحة", Icons.branding_watermark_outlined),
                    validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nicknameCtl,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: AppTheme.inputDecoration("الاسم الرمزي", Icons.stars_outlined),
                    validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.glassBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        dropdownColor: AppTheme.surfaceColor,
                        icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryGreen),
                        value: selectedType,
                        items: _vehicleTypesList.map((type) {
                          return DropdownMenuItem<String>(
                            value: type['name'],
                            child: Row(
                              children: [
                                Icon(type['icon'], color: AppTheme.primaryGreen, size: 20),
                                const SizedBox(width: 10),
                                Text(type['name'], style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Tajawal', fontSize: 14)),
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
                    decoration: AppTheme.inputDecoration("الموديل", Icons.directions_car_filled_outlined),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            side: const BorderSide(color: AppTheme.glassBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Get.back(),
                          child: Text("إلغاء", style: TextStyle(color: AppTheme.textHint, fontFamily: 'Tajawal')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppTheme.gradientButton(
                          text: isUploading ? "جاري الرفع..." : "حفظ التعديلات",
                          horizontalPadding: 12,
                          icon: Icons.check_circle_outline,
                          onPressed: isUploading ? null : () async {
                            if (formKey.currentState!.validate()) {
                              setSheetState(() => isUploading = true);
                              
                              String? finalImageUrl = v.imageUrl;
                              
                              if (imageFile != null) {
                                try {
                                  final result = await CloudinaryService.uploadMedia(imageFile!);
                                  if (result != null) {
                                    finalImageUrl = result;
                                  }
                                } catch (e) {
                                  Get.snackbar("خطأ", "فشل رفع الصورة");
                                }
                              }

                              await FirebaseFirestore.instance.collection('vehicles').doc(v.id).update({
                                'plateNumber': plateCtl.text.trim(),
                                'type': selectedType,
                                'model': modelCtl.text.trim(),
                                'nickname': nicknameCtl.text.trim(),
                                'imageUrl': finalImageUrl,
                                'updatedAt': FieldValue.serverTimestamp(),
                              });

                              Get.back();
                              Get.snackbar("تم التحديث", "تم تحديث بيانات السيارة بنجاح", 
                                  snackPosition: SnackPosition.BOTTOM, 
                                  backgroundColor: AppTheme.successColor.withValues(alpha: 0.15), 
                                  colorText: Colors.white);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      }),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 10),
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
                  Text('إدارة السيارات', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Tajawal')),
                  Text('تتبع مباشر وتحكم في السيارات', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontFamily: 'Tajawal')),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.satellite_alt_rounded, color: AppTheme.primaryGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
     return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(Icons.car_crash_outlined, color: AppTheme.textHint.withValues(alpha: 0.2), size: 100),
           const SizedBox(height: 20),
           Text('لا توجد مركبات مسجلة', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
           Text('ابدأ بإضافة سيارات لأسطول الجمعية', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
         ],
       ),
     );
  }
}
