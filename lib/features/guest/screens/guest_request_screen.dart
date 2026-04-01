import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:ui' as ui;
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/service_type_model.dart';
import '../../../data/services/connectivity_service.dart';
import '../../../data/services/offline_queue_service.dart';
import '../../../data/services/notification_service.dart';
import '../../auth/controllers/auth_controller.dart';

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
  final TextEditingController pickupLocationController = TextEditingController();
  final TextEditingController burialLocationController = TextEditingController();
  
  // Funeral Washing Specific ✨
  String? deceasedGender;
  final TextEditingController washingLocationController = TextEditingController();
  final TextEditingController suppliesController = TextEditingController();
  
  Set<String> selectedSubOptions = {};

  final Map<String, List<String>> _serviceSubOptions = {
    'الرعاية الطبية': ['أدوية', 'تحاليل طبية', 'أشعة', 'نقل مريض', 'عملية جراحية', 'علاج فيزيائي', 'معدات أكسجين'],
    'مساعدة طبية': ['أدوية', 'تحاليل طبية', 'أشعة', 'نقل مريض', 'عملية جراحية', 'علاج فيزيائي', 'معدات أكسجين'],
    'إطعام الطعام': ['قفة الفاهم', 'وجبة ساخنة', 'إفطار صائم', 'لحوم/عقيقة'],
    'مساعدات غذائية': ['قفة الفاهم', 'وجبة ساخنة', 'إفطار صائم', 'لحوم/عقيقة'],
    'ترميم بيوت الله والفقراء': ['مواد بناء', 'صيانة كهرباء/سباكة', 'تأثيث مسجد', 'تأثيث منزل فقير'],
    'بناء وتعمير': ['مواد بناء', 'صيانة كهرباء/سباكة', 'تأثيث مسجد', 'تأثيث منزل فقير'],
    'تعليم وكفالة طالب': ['أدوات مدرسية', 'محفظة مدرسية', 'دروس دعم', 'ملابس دخول مدرسي'],
    'تعليم وكفالة أيتام': ['أدوات مدرسية', 'محفظة مدرسية', 'دروس دعم', 'ملابس دخول مدرسي'],
    'كفالة اليتيم': ['كفالة مادية (شهرية)', 'كفالة طبية', 'كفالة مدرسية'],
    'كفالة أيتام': ['كفالة مادية (شهرية)', 'كفالة طبية', 'كفالة مدرسية'],
    'سقيا الماء': ['المساهمة في بئر', 'توصيل شبكة مياه', 'تعبئة صهريج ماء', 'مبرد ماء لمسجد'],
    'سقي الماء': ['المساهمة في بئر', 'توصيل شبكة مياه', 'تعبئة صهريج ماء', 'مبرد ماء لمسجد'],
    'حملة دفء الشتاء': ['أغطية (بطانيات)', 'ملابس شتوية', 'مدفأة كهربائية/غاز', 'ترميم سقف'],
    'كسوة العيد والفقراء': ['ملابس أطفال', 'ملابس كبار', 'أحذية'],
    'تفريج كربة (مالي)': ['إيجار متأخر', 'ديون صيدلية', 'ديون بقالة', 'فاتورة كهرباء/ماء'],
    'مساعدات مالية': ['إيجار متأخر', 'ديون صيدلية', 'ديون بقالة', 'فاتورة كهرباء/ماء'],
    'إغاثة بقطرة دم': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
    'التبرع بالدم': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
    'تغسيل الموتى': ['كفن كامل شامل', 'أدوات غسل فقط', 'لا أحتاج (متوفرة)', 'أحتاج متطوع فقط'],
    'نقل الجنائز': ['توفير سيارة إسعاف', 'سيارة نقل موتى جنائز', 'لا أحتاج (متوفرة)'],
  };

  final List<String> stepLabels = ['معلوماتك', 'الخدمة', 'التأكيد'];

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    descriptionController.dispose();
    deceasedNameController.dispose();
    pickupLocationController.dispose();
    burialLocationController.dispose();
    washingLocationController.dispose();
    suppliesController.dispose();
    super.dispose();
  }

  Future<void> submitGuestRequest() async {
    setState(() => isLoading = true);
    try {
      final refNumber = 'NAK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final normalizedPhone = phoneController.text.trim().replaceAll(' ', '');
      
      Map<String, dynamic> requestData = {
        'requesterName': nameController.text,
        'phone': normalizedPhone,
        'wilaya': selectedWilaya,
        'commune': selectedCommune,
        'address': addressController.text,
        'type': selectedService!.id,
        'typeName': selectedService!.name,
        'urgency': selectedUrgency,
        'description': selectedSubOptions.isNotEmpty 
            ? 'الخيارات: ${selectedSubOptions.join('، ')}\n${descriptionController.text.isNotEmpty ? 'ملاحظات: ${descriptionController.text}' : ''}'.trim()
            : descriptionController.text,
        'status': 'pending',
        'refNumber': refNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'isGuest': true,
        'details': {},
      };

      if (selectedService!.id == 'funeral_transport' || selectedService!.name == 'نقل الجنائز') {
        requestData['details'] = {
          'deceasedName': deceasedNameController.text,
          'pickupLocation': pickupLocationController.text,
          'burialLocation': burialLocationController.text,
        };
      } else if (selectedService!.id == 'funeral_ghusl' || selectedService!.name == 'تغسيل الموتى') {
        requestData['details'] = {
          'deceasedGender': deceasedGender ?? '',
          'washingLocation': washingLocationController.text,
          'supplies': selectedSubOptions.join('، '),
        };
      } else if (selectedService!.id == 'blood_donation' || selectedService!.name.contains('دم')) {
        // إذا كان طلب تبرع بالدم، نضع الفصيلة في حقل خاص ليتعرف عليها النظام
        final bloodType = selectedSubOptions.firstWhere((opt) => 
          ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].contains(opt), orElse: () => '');
        
        requestData['details'] = {
          'فصيلة الدم': bloodType,
          'المستشفى': addressController.text, // كافتراض للزوار، أو يمكنهم كتابتها في الملاحظات
          'رقم التواصل': normalizedPhone,
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

        Get.offNamed('/guest/success', arguments: {'refNumber': refNumber, 'phone': normalizedPhone});
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

      Get.offNamed('/guest/success', arguments: {'refNumber': refNumber, 'phone': normalizedPhone});
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إرسال الطلب: $e', backgroundColor: AppTheme.errorColor.withValues(alpha: 0.15));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          CustomScrollView(
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
                                color: currentStep < step ? AppTheme.cardColor : null,
                                shape: BoxShape.circle,
                                border: Border.all(color: currentStep >= step ? Colors.transparent : AppTheme.glassBorder)
                              ),
                              child: Center(
                                child: Text(step.toString(), 
                                  style: TextStyle(color: currentStep >= step ? (Get.isDarkMode ? Colors.black : Colors.white) : AppTheme.textHint, 
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(stepLabels[step - 1], 
                              style: TextStyle(color: currentStep >= step ? AppTheme.primaryGreen : AppTheme.textHint, fontSize: 12, fontWeight: FontWeight.w600)),
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
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: (currentStep == 2 && selectedService != null) ? 180 : 30),
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
      if (currentStep == 2 && selectedService != null)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: Container(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 30),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor.withValues(alpha: 0.75),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.75), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: (Get.isDarkMode ? Colors.black : Colors.grey).withValues(alpha: 0.75),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(12),
                        decoration: AppTheme.glassDecoration.copyWith(
                          color: AppTheme.textPrimary.withValues(alpha: 0.75),
                          border: Border.all(color: AppTheme.glassBorder, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.75), shape: BoxShape.circle),
                              child: Icon(AppConstants.getIconFromName(selectedService!.icon), color: AppTheme.primaryGreen, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(selectedService!.name, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                                  Text((descriptionController.text.isNotEmpty || selectedSubOptions.isNotEmpty) 
                                        ? [if (selectedSubOptions.isNotEmpty) selectedSubOptions.join('، '), if (descriptionController.text.isNotEmpty) descriptionController.text].join(' - ')
                                        : 'اضغط للتعديل...', 
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_note, color: AppTheme.primaryGreen),
                              onPressed: () => _showServiceDetailsModal(selectedService!),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: OutlinedButton(
                              onPressed: () => setState(() => currentStep = 1),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: AppTheme.glassBorder),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              child: Text('رجوع', style: TextStyle(color: AppTheme.textPrimary)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: AppTheme.gradientButton(
                              text: 'التالي',
                              icon: Icons.arrow_forward_rounded,
                              onPressed: () {
                                if (selectedService!.id == 'funeral_transport' || selectedService!.name == 'نقل الجنائز') {
                                  if (deceasedNameController.text.isEmpty || pickupLocationController.text.isEmpty || burialLocationController.text.isEmpty) {
                                    Get.snackbar('تنبيه', 'يرجى ملء جميع معلومات الدفن والنقل', backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15));
                                    return;
                                  }
                                }
                                if (selectedService!.id == 'funeral_ghusl' || selectedService!.name == 'تغسيل الموتى') {
                                  if (deceasedGender == null || washingLocationController.text.isEmpty) {
                                    Get.snackbar('تنبيه', 'يرجى اختيار جنس المتوفى ومكان الغسل', backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15));
                                    return;
                                  }
                                }
                                if (selectedService!.id != 'funeral_transport' && 
                                    selectedService!.name != 'نقل الجنائز' &&
                                    selectedService!.id != 'funeral_ghusl' && 
                                    selectedService!.name != 'تغسيل الموتى' &&
                                    descriptionController.text.isEmpty && 
                                    selectedSubOptions.isEmpty) {
                                  Get.snackbar('تنبيه', 'يرجى وصف الطلب أو تحديد نوع المساعدة', backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15));
                                  return;
                                }
                                setState(() => currentStep = 3);
                              }
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ),
        // Guest support chat button — shown on steps 1 & 2
        if (currentStep != 3)
          Positioned(
            bottom: (currentStep == 2 && selectedService != null) ? 180 : 24,
            left: 20,
            child: GestureDetector(
              onTap: _showGuestChatSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: AppTheme.greenGlow,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.support_agent, color: Colors.black, size: 18),
                    SizedBox(width: 6),
                    Text('💬 دردشة مع الدعم',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            fontFamily: 'Tajawal')),
                  ],
                ),
              ),
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
          Text('هذه المعلومات لمتابعة طلبك', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),
          _buildLabeledField('الاسم الكامل *', Icons.person_outline, nameController),
          const SizedBox(height: 16),
          _buildLabeledField('رقم الهاتف *', Icons.phone_outlined, phoneController, keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          Text('الولاية *', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.glassBorder)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedWilaya,
                hint: Text('اختر الولاية', style: TextStyle(color: AppTheme.textHint, fontSize: 14)),
                isExpanded: true,
                dropdownColor: AppTheme.surfaceColor,
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
              decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.glassBorder)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCommune,
                  hint: Text('اختر البلدية', style: TextStyle(color: AppTheme.textHint, fontSize: 14)),
                  isExpanded: true,
                  dropdownColor: AppTheme.surfaceColor,
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
                  backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15));
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
                        Text(snapshot.error.toString(), style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
                    setState(() {
                      if (selectedService?.id != service.id) {
                        selectedSubOptions.clear();
                        descriptionController.clear();
                      }
                      selectedService = service;
                    });
                    _showServiceDetailsModal(service);
                  },
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.75) : AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder,
                          width: isSelected ? 2 : 1
                        ),
                        boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.75), blurRadius: 10)] : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(AppConstants.getIconFromName(service.icon), 
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
                                fontSize: 12, 
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600)),
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
                if (selectedService?.id == 'funeral_transport' || selectedService?.name == 'نقل الجنائز') ...[
                  _buildSummaryRow('المتوفى', deceasedNameController.text),
                  _buildSummaryRow('مكان النقل', pickupLocationController.text),
                  _buildSummaryRow('الوجهة/المقبرة', burialLocationController.text),
                ],
                if (selectedService?.id == 'funeral_ghusl' || selectedService?.name == 'تغسيل الموتى') ...[
                  _buildSummaryRow('جنس المتوفى', deceasedGender ?? ''),
                  _buildSummaryRow('مكان الغسل', washingLocationController.text),
                  _buildSummaryRow('المستلزمات', selectedSubOptions.join('، ')),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.75))),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.primaryGreen, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('ستتلقى رسالة SMS برقم مرجعي لمتابعة طلبك فور الموافقة عليه', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4, fontWeight: FontWeight.w500))),
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



  void _showGuestChatSheet() {
    final guestNameCtrl = TextEditingController(text: nameController.text);
    final guestPhoneCtrl = TextEditingController(text: phoneController.text);
    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setState) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor.withValues(alpha: 0.75),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.75), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.glassBorder, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 20),
                    const Text('💬 دردشة مع الدعم', style: TextStyle(color: AppTheme.primaryGreen, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                    const SizedBox(height: 6),
                    Text('سيتواصل معك أحد المدراء في أقرب وقت', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontFamily: 'Tajawal')),
                    const SizedBox(height: 20),
                    TextField(
                      controller: guestNameCtrl,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: AppTheme.inputDecoration('اسمك (مطلوب)', Icons.person_outline),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: guestPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: AppTheme.inputDecoration('رقم هاتفك (مطلوب)', Icons.phone_outlined),
                    ),
                    const SizedBox(height: 20),
                    AppTheme.gradientButton(
                      text: 'بدء المحادثة',
                      icon: Icons.send_rounded,
                      onPressed: () async {
                        if (guestNameCtrl.text.isEmpty || guestPhoneCtrl.text.isEmpty) {
                          Get.snackbar('تنبيه', 'يرجى إدخال الاسم ورقم الهاتف', backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15));
                          return;
                        }
                        
                        final normalizedPhone = guestPhoneCtrl.text.trim().replaceAll(' ', '');
                        final chatId = 'guest_$normalizedPhone';
                        
                        // ✨ الخطوة الحاسمة: تسجيل الدخول المجهول لتجنب PERMISSION_DENIED
                        final auth = Get.find<AuthController>();
                        if (FirebaseAuth.instance.currentUser == null) {
                          debugPrint('🔐 GuestRequestScreen: Starting Anonymous Login...');
                          await auth.signInAnonymously();
                        }
                        
                        try {
                          final currentUid = FirebaseAuth.instance.currentUser?.uid ?? chatId;
                          await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
                          'type': 'guest',
                          'guestName': guestNameCtrl.text,
                          'guestPhone': normalizedPhone,
                          'participants': FieldValue.arrayUnion([currentUid, 'support']),
                          'lastMessage': 'محادثة جديدة من زائر',
                          'lastMessageAt': FieldValue.serverTimestamp(),
                          'createdAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));

                        // Add Welcome Message
                        await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
                          'senderId': 'support',
                          'senderName': 'الدعم الفني',
                          'message': 'مرحباً بك في جمعية ناس الخير بك بمدينة رقان، كيف يمكننا مساعدتك؟',
                          'createdAt': FieldValue.serverTimestamp(),
                          'isRead': false,
                        });

                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('guest_name', guestNameCtrl.text);
                        await prefs.setString('guest_phone', normalizedPhone);

                        // Notify Admins
                        try {
                          await NotificationService.notifyAllAdmins(
                            type: 'guest_message',
                            title: 'محادثة جديدة من زائر 💬',
                            body: 'قام ${guestNameCtrl.text} ببدء محادثة جديدة',
                            data: {
                              'chatId': chatId,
                              'senderName': guestNameCtrl.text,
                              'senderPhone': normalizedPhone,
                            },
                          );
                          } catch (e) {
                            debugPrint('❌ Error notifying admins of new guest chat: $e');
                          }
                        } catch (e) {
                           debugPrint('⚠️ Firestore/Permission Error: $e');
                           // إذا فشل الإشعار أو الكتابة الأولية، سنحاول المتابعة للشاشة التالية
                           // فالدردشة ستحاول تهيئة نفسها مرة أخرى هناك
                        }

                        Get.back(); // close bottom sheet
                        // Navigate to chat
                        Get.toNamed(AppRoutes.chatPrivate, arguments: {
                          'chatId': chatId,
                          'userName': 'الدعم الفني',
                          'userId': 'support', // Explicitly set support as target
                        });
                        Get.snackbar(
                          'تم ✅',
                          'سيتواصل معك المدير على رقم $normalizedPhone',
                          backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                          duration: const Duration(seconds: 4),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
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
                  color: AppTheme.surfaceColor.withValues(alpha: 0.75),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.75), width: 1.5),
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
                          decoration: BoxDecoration(color: AppTheme.textHint.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.75), shape: BoxShape.circle),
                            child: Icon(AppConstants.getIconFromName(service.icon), color: AppTheme.primaryGreen, size: 24),
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
                        const SizedBox(height: 16),
                        _buildModalField('مكان التواجد (مستشفى، منزل...) *', Icons.location_on_outlined, pickupLocationController),
                        const SizedBox(height: 16),
                        _buildModalField('الوجهة (المقبرة أو مكان آخر) *', Icons.account_balance_outlined, burialLocationController),
                      ] else if (service.id == 'funeral_ghusl' || service.name == 'تغسيل الموتى') ...[
                        Text('جنس المتوفى *', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildGenderChip(setModalState, 'ذكر', Icons.male_rounded),
                            const SizedBox(width: 12),
                            _buildGenderChip(setModalState, 'أنثى', Icons.female_rounded),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildModalField('مكان الغسل (المنزل، المسجد، المستشفى) *', Icons.location_on_outlined, washingLocationController),
                        const SizedBox(height: 20),
                        if (_serviceSubOptions.containsKey(service.name)) ...[
                           Text('المستلزمات المطلوبة (اختياري)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                           const SizedBox(height: 12),
                           _buildSubOptionsChips(service.name, setModalState),
                        ],
                      ] else ...[
                        if (_serviceSubOptions.containsKey(service.name)) ...[
                          Text('حدد نوع المساعدة المطلوبة *', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _serviceSubOptions[service.name]!.map((option) {
                              final isSelected = selectedSubOptions.contains(option);
                              return ChoiceChip(
                                label: Text(option),
                                selected: isSelected,
                                selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                                backgroundColor: AppTheme.textPrimary.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  color: isSelected ? AppTheme.primaryGreen : AppTheme.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                side: BorderSide(
                                  color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder,
                                ),
                                onSelected: (selected) {
                                  setModalState(() {
                                    if (selected) {
                                      selectedSubOptions.add(option);
                                    } else {
                                      selectedSubOptions.remove(option);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          _buildModalField('ملاحظات إضافية (اختياري)', Icons.description_outlined, descriptionController, maxLines: 3),
                        ] else ...[
                          _buildModalField('وصف الطلب بالتفصيل *', Icons.description_outlined, descriptionController, maxLines: 4),
                        ],
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
            fillColor: AppTheme.textPrimary.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderChip(Function setModalState, String gender, IconData icon) {
    final isSelected = deceasedGender == gender;
    return Expanded(
      child: GestureDetector(
        onTap: () => setModalState(() => deceasedGender = gender),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.75) : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder, width: isSelected ? 2 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? AppTheme.primaryGreen : AppTheme.textHint, size: 18),
              const SizedBox(width: 8),
              Text(gender, style: TextStyle(color: isSelected ? AppTheme.textPrimary : AppTheme.textHint, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubOptionsChips(String serviceName, Function setModalState) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _serviceSubOptions[serviceName]!.map((option) {
        final isSelected = selectedSubOptions.contains(option);
        return ChoiceChip(
          label: Text(option),
          selected: isSelected,
          selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
          backgroundColor: AppTheme.textPrimary.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
          side: BorderSide(color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder),
          onSelected: (selected) {
            setModalState(() {
              if (selected) {
                selectedSubOptions.add(option);
              } else {
                selectedSubOptions.remove(option);
              }
            });
          },
        );
      }).toList(),
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
            color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.textPrimary.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isSelected ? color : AppTheme.glassBorder, width: isSelected ? 2 : 1),
            boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.75), blurRadius: 10)] : null,
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

