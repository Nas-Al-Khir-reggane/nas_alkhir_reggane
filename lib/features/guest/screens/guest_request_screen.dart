import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/service_type_model.dart';
import '../../../data/services/notification_service.dart';

class GuestRequestScreen extends StatefulWidget {
  const GuestRequestScreen({super.key});

  @override
  State<GuestRequestScreen> createState() => _GuestRequestScreenState();
}

class _GuestRequestScreenState extends State<GuestRequestScreen> {
  int currentStep = 1;
  bool isLoading = false;
  
  // Step 1 Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  String selectedWilaya = "01 - أدرار";

  // Step 2 Controllers
  ServiceTypeModel? selectedService;
  String selectedUrgency = 'normal';
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController deceasedNameController = TextEditingController();
  LatLng? selectedLocation;

  final List<String> stepLabels = ['معلوماتك', 'الخدمة', 'التأكيد'];

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    descriptionController.dispose();
    deceasedNameController.dispose();
    super.dispose();
  }

  Future<void> submitGuestRequest() async {
    setState(() => isLoading = true);
    try {
      final refNumber = 'NAK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      
      Map<String, dynamic> requestData = {
        'requesterName': nameController.text,
        'phone': phoneController.text,
        'wilaya': selectedWilaya,
        'address': addressController.text,
        'type': selectedService!.id,
        'typeName': selectedService!.name,
        'urgency': selectedUrgency,
        'description': descriptionController.text,
        'status': 'pending',
        'refNumber': refNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'details': {},
      };

      if (selectedService!.id == 'funeral_transport') {
        requestData['details'] = {
          'deceasedName': deceasedNameController.text,
          'latitude': selectedLocation?.latitude,
          'longitude': selectedLocation?.longitude,
        };
      }

      await FirebaseFirestore.instance.collection('guest_requests').add(requestData);

      // Notify Admins about new guest request
      NotificationService.notifyAllAdmins(
        type: 'new_request',
        title: 'طلب خدمة جديد (زائر)',
        body: 'قام ${nameController.text} بطلب خدمة ${selectedService!.name}',
        data: {'refNumber': refNumber},
      );

      Get.offNamed('/guest/success', arguments: {'refNumber': refNumber, 'phone': phoneController.text});
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إرسال الطلب: $e', backgroundColor: AppTheme.errorColor.withValues(alpha: 0.2));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('طلب خدمة'),
            leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Get.back()),
            backgroundColor: AppTheme.darkSurface,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [1, 2, 3].map((step) => Expanded(
                    child: Row(
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                gradient: currentStep >= step ? AppTheme.primaryGradient : null,
                                color: currentStep < step ? AppTheme.darkCard : null,
                                shape: BoxShape.circle,
                                border: Border.all(color: currentStep >= step ? Colors.transparent : AppTheme.glassBorder)
                              ),
                              child: Center(
                                child: Text(step.toString(), 
                                  style: TextStyle(color: currentStep >= step ? Colors.black : AppTheme.textHint, 
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(stepLabels[step - 1], 
                              style: TextStyle(color: currentStep >= step ? AppTheme.primaryGreen : AppTheme.textHint, fontSize: 10)),
                          ],
                        ),
                        if (step < 3)
                          Expanded(
                            child: Container(
                              height: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              color: currentStep > step ? AppTheme.primaryGreen : AppTheme.glassBorder,
                            ),
                          ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (currentStep == 1) _buildStep1(),
                if (currentStep == 2) _buildStep2(),
                if (currentStep == 3) _buildStep3(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return FadeInRight(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('معلوماتك الشخصية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          Text('هذه المعلومات لمتابعة طلبك', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          _buildLabeledField('الاسم الكامل *', Icons.person_outline, nameController),
          const SizedBox(height: 16),
          _buildLabeledField('رقم الهاتف *', Icons.phone_outlined, phoneController, keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          Text('الولاية *', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.glassBorder)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedWilaya,
                isExpanded: true,
                dropdownColor: AppTheme.darkSurface,
                items: AppConstants.algeriaWilayas.map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value, style: TextStyle(color: AppTheme.textPrimary)));
                }).toList(),
                onChanged: (val) => setState(() => selectedWilaya = val!),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLabeledField('العنوان التفصيلي *', Icons.home_outlined, addressController, maxLines: 2),
          const SizedBox(height: 24),
          AppTheme.gradientButton(
            text: 'التالي',
            icon: Icons.arrow_forward,
            onPressed: () {
              if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty && addressController.text.isNotEmpty) {
                setState(() => currentStep = 2);
              } else {
                Get.snackbar('تنبيه', 'يرجى ملء جميع الحقول');
              }
            }
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return FadeInRight(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('نوع الخدمة المطلوبة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('service_types').where('isActive', isEqualTo: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final services = snapshot.data!.docs.map((d) => ServiceTypeModel.fromMap(d.data() as Map<String, dynamic>)).toList();
              
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: services.map((service) {
                  final isSelected = selectedService?.id == service.id;
                  return GestureDetector(
                    onTap: () => setState(() => selectedService = service),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.2) : AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder, width: isSelected ? 2 : 1)
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.help_outline, color: AppTheme.textHint, size: 28),
                          const SizedBox(height: 8),
                          Text(service.name, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            }
          ),
          
          const SizedBox(height: 16),
          if (selectedService?.id == 'funeral_transport') ...[
            _buildLabeledField('اسم المتوفى *', Icons.person_off_outlined, deceasedNameController),
            const SizedBox(height: 16),
            Text('تحديد موقع الاستلام على الخريطة', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.glassBorder)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(target: LatLng(28.5, -0.25), zoom: 10),
                  onTap: (latLng) => setState(() => selectedLocation = latLng),
                  markers: selectedLocation != null ? {Marker(markerId: const MarkerId('pickup'), position: selectedLocation!)} : {},
                ),
              ),
            ),
          ] else ...[
            _buildLabeledField('وصف الطلب *', Icons.description_outlined, descriptionController, maxLines: 3),
          ],

          const SizedBox(height: 20),
          Text('درجة الاستعجال *', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildUrgencyOption('normal', 'عادي', Icons.check_circle_outline, AppTheme.successColor),
              _buildUrgencyOption('urgent', 'مستعجل', Icons.warning_outlined, AppTheme.urgentColor),
              _buildUrgencyOption('emergency', 'طارئ', Icons.emergency_outlined, AppTheme.emergencyColor),
            ],
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => setState(() => currentStep = 1), child: const Text('رجوع'))),
              const SizedBox(width: 12),
              Expanded(child: AppTheme.gradientButton(
                text: 'التالي',
                icon: Icons.arrow_forward,
                onPressed: () {
                  if (selectedService != null) {
                    setState(() => currentStep = 3);
                  } else {
                    Get.snackbar('تنبيه', 'يرجى اختيار نوع الخدمة');
                  }
                }
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return FadeInRight(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('مراجعة الطلب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          Container(
            decoration: AppTheme.glassDecoration,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildSummaryRow('الاسم', nameController.text),
                _buildSummaryRow('الهاتف', phoneController.text),
                _buildSummaryRow('الولاية', selectedWilaya),
                _buildSummaryRow('الخدمة', selectedService?.name ?? ''),
                _buildSummaryRow('الاستعجال', selectedUrgency == 'normal' ? 'عادي' : selectedUrgency == 'urgent' ? 'عاجل' : 'طوارئ'),
                if (selectedService?.id == 'funeral_transport')
                  _buildSummaryRow('المتوفى', deceasedNameController.text),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3))),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryGreen, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('ستتلقى رسالة SMS برقم مرجعي لمتابعة طلبك', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => setState(() => currentStep = 2), child: const Text('رجوع'))),
              const SizedBox(width: 12),
              Expanded(child: isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : AppTheme.gradientButton(text: 'إرسال الطلب', icon: Icons.send, onPressed: submitGuestRequest)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledField(String label, IconData icon, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: AppTheme.inputDecoration(label, icon),
        ),
      ],
    );
  }

  Widget _buildUrgencyOption(String id, String name, IconData icon, Color color) {
    final isSelected = selectedUrgency == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedUrgency = id),
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : AppTheme.darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : AppTheme.glassBorder, width: isSelected ? 2 : 1)
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : AppTheme.textHint, size: 20),
              const SizedBox(height: 4),
              Text(name, style: TextStyle(color: isSelected ? color : AppTheme.textHint, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textHint)),
          Text(value, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
