import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:ui' as ui;
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/service_type_model.dart';
import '../../../data/services/connectivity_service.dart';
import '../../../data/services/offline_queue_service.dart';
import '../../../data/services/notification_service.dart';

class GuestRequestScreen extends StatefulWidget {
  const GuestRequestScreen({super.key});

  @override
  State<GuestRequestScreen> createState() => _GuestRequestScreenState();
}

class _GuestRequestScreenState extends State<GuestRequestScreen> {
  int currentStep = 1;
  bool isLoading = false;

  ConnectivityService get _connectivity => Get.find<ConnectivityService>();
  OfflineQueueService get _queue => Get.find<OfflineQueueService>();
  
  // Step 1 Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  String? selectedWilaya;
  String? selectedCommune;

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
        'commune': selectedCommune,
        'address': addressController.text,
        'type': selectedService!.id,
        'typeName': selectedService!.name,
        'urgency': selectedUrgency,
        'description': descriptionController.text,
        'status': 'pending',
        'refNumber': refNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'isGuest': true,
        'details': {},
      };

      if (selectedService!.id == 'funeral_transport') {
        requestData['details'] = {
          'deceasedName': deceasedNameController.text,
          'latitude': selectedLocation?.latitude,
          'longitude': selectedLocation?.longitude,
        };
      }

      if (!_connectivity.isOnline.value) {
        final queueData = Map<String, dynamic>.from(requestData);
        queueData['createdAt'] = '__serverTimestamp__';

        await _queue.enqueue(
          collection: 'guest_requests',
          operation: 'add',
          data: queueData,
        );

        Get.offNamed('/guest/success', arguments: {'refNumber': refNumber, 'phone': phoneController.text});
        return;
      }

      await FirebaseFirestore.instance.collection('guest_requests').add(requestData);

      await FirebaseFirestore.instance
          .collection('service_types')
          .doc(selectedService!.id)
          .update({'popularity': FieldValue.increment(1)});

      await NotificationService.notifyAllAdmins(
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('طلب خدمة (زائر)', style: TextStyle(fontFamily: 'Tajawal')),
            leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Get.back()),
            backgroundColor: scheme.surface,
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
                hint: Text('اختر الولاية', style: TextStyle(color: AppTheme.textHint, fontSize: 14)),
                isExpanded: true,
                dropdownColor: AppTheme.darkSurface,
                items: AppConstants.algeriaWilayas.map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value, style: TextStyle(color: AppTheme.textPrimary)));
                }).toList(),
                onChanged: (val) => setState(() {
                  selectedWilaya = val;
                  selectedCommune = null;
                }),
              ),
            ),
          ),
          if (selectedWilaya != null) ...[
            const SizedBox(height: 16),
            Text('البلدية *', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.glassBorder)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCommune,
                  hint: Text('اختر البلدية', style: TextStyle(color: AppTheme.textHint, fontSize: 14)),
                  isExpanded: true,
                  dropdownColor: AppTheme.darkSurface,
                  items: AppConstants.getCommunesForWilaya(selectedWilaya!).map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value, style: TextStyle(color: AppTheme.textPrimary)));
                  }).toList(),
                  onChanged: (val) => setState(() => selectedCommune = val),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildLabeledField('العنوان التفصيلي *', Icons.home_outlined, addressController, maxLines: 2),
          const SizedBox(height: 24),
          AppTheme.gradientButton(
            text: 'التالي',
            icon: Icons.arrow_forward,
            onPressed: () {
              if (nameController.text.isNotEmpty && 
                  phoneController.text.isNotEmpty && 
                  addressController.text.isNotEmpty &&
                  selectedWilaya != null &&
                  selectedCommune != null) {
                setState(() => currentStep = 2);
              } else {
                Get.snackbar('تنبيه', 'يرجى ملء جميع الحقول واختيار الولاية والبلدية', 
                  backgroundColor: AppTheme.warningColor.withValues(alpha: 0.2));
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('نوع الخدمة المطلوبة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              if (selectedService != null)
                TextButton.icon(
                  onPressed: () => _showServiceDetailsModal(selectedService!),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('تعديل التفاصيل'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.primaryGreen),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('service_types').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 40),
                        const SizedBox(height: 8),
                        Text('فشل تحميل الخدمات', style: TextStyle(color: AppTheme.errorColor)),
                        Text(snapshot.error.toString(), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(30.0),
                  child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                ));
              }

              final docs = snapshot.data?.docs ?? [];
              final services = docs.map((d) => ServiceTypeModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                                  .where((s) => s.isActive).toList();
              
              services.sort((a, b) {
                if (a.id == 'other') return 1;
                if (b.id == 'other') return -1;
                return b.popularity.compareTo(a.popularity);
              });

              if (services.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text('لا توجد خدمات متاحة حالياً', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final service = services[index];
                  final isSelected = selectedService?.id == service.id;
                  return GestureDetector(
                  onTap: () {
                    setState(() => selectedService = service);
                    _showServiceDetailsModal(service);
                  },
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.15) : AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder,
                          width: isSelected ? 2 : 1
                        ),
                        boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.2), blurRadius: 10)] : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_getIconData(service.icon), 
                            color: isSelected ? AppTheme.primaryGreen : AppTheme.textHint, 
                            size: 24),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(service.name, 
                              textAlign: TextAlign.center, 
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected ? AppTheme.textPrimary : AppTheme.textHint, 
                                fontSize: 10, 
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
          ),
          
          const SizedBox(height: 30),
          if (selectedService != null)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.glassDecoration,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(_getIconData(selectedService!.icon), color: AppTheme.primaryGreen, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(selectedService!.name, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                        Text(descriptionController.text.isNotEmpty ? descriptionController.text : 'اضغط لإضافة التفاصيل...', 
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle, color: (descriptionController.text.isNotEmpty || deceasedNameController.text.isNotEmpty) ? AppTheme.successColor : AppTheme.textHint, size: 20),
                ],
              ),
            ),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => currentStep = 1),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.glassBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text('رجوع', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTheme.gradientButton(
                  text: 'التالي',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () {
                    if (selectedService != null) {
                      if (selectedService!.id == 'funeral_transport' && deceasedNameController.text.isEmpty) {
                        Get.snackbar('تنبيه', 'يرجى إدخال اسم المتوفى', backgroundColor: AppTheme.warningColor.withValues(alpha: 0.2));
                        return;
                      }
                      if (selectedService!.id != 'funeral_transport' && descriptionController.text.isEmpty) {
                        Get.snackbar('تنبيه', 'يرجى وصف الطلب بالتفصيل', backgroundColor: AppTheme.warningColor.withValues(alpha: 0.2));
                        return;
                      }
                      setState(() => currentStep = 3);
                    } else {
                      Get.snackbar('تنبيه', 'يرجى اختيار نوع الخدمة أولاً', 
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: AppTheme.warningColor.withValues(alpha: 0.2),
                        colorText: AppTheme.warningColor);
                    }
                  }
                ),
              ),
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
                _buildSummaryRow('الولاية', selectedWilaya ?? ''),
                _buildSummaryRow('البلدية', selectedCommune ?? ''),
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
                const Icon(Icons.info_outline, color: AppTheme.primaryGreen, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('ستتلقى رسالة SMS برقم مرجعي لمتابعة طلبك فور الموافقة عليه', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4))),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => currentStep = 2),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.glassBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text('رجوع', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: isLoading 
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)) 
                  : AppTheme.gradientButton(
                      text: 'إرسال الطلب', 
                      icon: Icons.send_rounded, 
                      onPressed: submitGuestRequest
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
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

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'mosque': return Icons.mosque;
      case 'shopping_basket': return Icons.shopping_basket;
      case 'medication': return Icons.medication;
      case 'payments': return Icons.payments;
      case 'home_work': return Icons.home_work;
      case 'menu_book': return Icons.menu_book;
      case 'water_drop': return Icons.water_drop;
      case 'volunteer_activism': return Icons.volunteer_activism;
      case 'checkroom': return Icons.checkroom;
      case 'inventory': return Icons.inventory;
      case 'emergency': return Icons.emergency_outlined;
      case 'ac_unit': return Icons.ac_unit;
      case 'nightlight_round': return Icons.nightlight_round;
      case 'bloodtype': return Icons.bloodtype;
      case 'more_horiz': return Icons.more_horiz;
      // Fallbacks
      case 'medical': return Icons.medical_services_outlined;
      case 'food': return Icons.restaurant;
      case 'transport': return Icons.local_shipping_outlined;
      case 'blood': return Icons.bloodtype_outlined;
      case 'funeral': return Icons.airport_shuttle;
      case 'money': return Icons.account_balance_wallet_outlined;
      case 'other': return Icons.more_horiz;
      default: return Icons.category_outlined;
    }
  }

  void _showServiceDetailsModal(ServiceTypeModel service) {
    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setModalState) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface.withValues(alpha: 0.8),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2), width: 1.5),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(color: AppTheme.textHint.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: Icon(_getIconData(service.icon), color: AppTheme.primaryGreen, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('تفاصيل الطلب', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                Text(service.name, style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Get.back(),
                            icon: const Icon(Icons.close, color: AppTheme.errorColor),
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (service.id == 'funeral_transport') ...[
                        _buildModalField('اسم المتوفى *', Icons.person_off_outlined, deceasedNameController),
                        const SizedBox(height: 20),
                        Text('موقع الاستلام على الخريطة', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        const SizedBox(height: 8),
                        Container(
                          height: 180,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.glassBorder)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: GoogleMap(
                              initialCameraPosition: const CameraPosition(target: LatLng(26.7167, 0.1667), zoom: 12),
                              onTap: (latLng) => setModalState(() => selectedLocation = latLng),
                              markers: selectedLocation != null ? {Marker(markerId: const MarkerId('pickup'), position: selectedLocation!)} : {},
                            ),
                          ),
                        ),
                      ] else ...[
                        _buildModalField('وصف الطلب بالتفصيل *', Icons.description_outlined, descriptionController, maxLines: 4),
                      ],
                      const SizedBox(height: 24),
                      Text('درجة الاستعجال *', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildModalUrgencyOption(setModalState, 'normal', 'عادي', Icons.check_circle_outline, AppTheme.successColor),
                          _buildModalUrgencyOption(setModalState, 'urgent', 'مستعجل', Icons.warning_outlined, AppTheme.urgentColor),
                          _buildModalUrgencyOption(setModalState, 'emergency', 'طارئ', Icons.emergency_outlined, AppTheme.emergencyColor),
                        ],
                      ),
                      const SizedBox(height: 32),
                      AppTheme.gradientButton(
                        text: 'تأكيد التفاصيل',
                        icon: Icons.check_circle_outline,
                        onPressed: () {
                          setState(() {}); // Update the main UI to show details summary
                          Get.back();
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildModalField(String label, IconData icon, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: AppTheme.inputDecoration(label, icon).copyWith(
            fillColor: Colors.white.withValues(alpha: 0.03),
          ),
        ),
      ],
    );
  }

  Widget _buildModalUrgencyOption(Function setModalState, String id, String name, IconData icon, Color color) {
    final isSelected = selectedUrgency == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setModalState(() => selectedUrgency = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isSelected ? color : AppTheme.glassBorder, width: isSelected ? 2 : 1),
            boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10)] : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : AppTheme.textHint, size: 20),
              const SizedBox(height: 4),
              Text(name, style: TextStyle(color: isSelected ? color : AppTheme.textHint, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}
