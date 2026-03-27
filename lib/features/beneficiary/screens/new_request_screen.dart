import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:ui' as ui;
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/theme/app_theme.dart';
import '../controllers/beneficiary_controller.dart';
import '../../../data/models/service_type_model.dart';
import '../../../data/models/user_model.dart';

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final BeneficiaryController controller = Get.find<BeneficiaryController>();
  
  ServiceTypeModel? selectedService;
  String selectedUrgency = 'normal';
  final Map<String, TextEditingController> dynamicControllers = {};
  final TextEditingController descriptionController = TextEditingController();
  
  // Admin entry fields for other persons
  final TextEditingController beneficiaryNameController = TextEditingController();
  final TextEditingController beneficiaryPhoneController = TextEditingController();
  final TextEditingController beneficiaryAddressController = TextEditingController();

  bool get isAdmin => controller.currentBeneficiary.value?.role == UserRole.admin || 
                   controller.currentBeneficiary.value?.role == UserRole.superAdmin;

  @override
  void dispose() {
    descriptionController.dispose();
    beneficiaryNameController.dispose();
    beneficiaryPhoneController.dispose();
    beneficiaryAddressController.dispose();
    for (var ctrl in dynamicControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _onServiceSelected(ServiceTypeModel service) {
    setState(() {
      selectedService = service;
      dynamicControllers.clear();
      for (var field in service.fields) {
        dynamicControllers[field] = TextEditingController();
      }
    });
    
    _showDetailsBottomSheet();
  }

  void _submitRequest() {
    Map<String, dynamic> details = {};
    for (var entry in dynamicControllers.entries) {
      if (entry.value.text.isEmpty) {
        Get.snackbar('تنبيه', 'يرجى ملء حقل: ${entry.key}', 
          backgroundColor: AppTheme.warningColor.withValues(alpha: 0.2),
          colorText: AppTheme.warningColor);
        return;
      }
      details[entry.key] = entry.value.text;
    }

    if (selectedService!.id == 'other' && descriptionController.text.isEmpty) {
      Get.snackbar('تنبيه', 'يرجى وصف الطلب بالتفصيل', 
          backgroundColor: AppTheme.warningColor.withValues(alpha: 0.2));
      return;
    }

    Map<String, dynamic> requestData = {
      'type': selectedService!.id,
      'typeName': selectedService!.name,
      'urgency': selectedUrgency,
      'description': descriptionController.text,
      'details': details,
    };

    if (isAdmin && beneficiaryNameController.text.isNotEmpty) {
      requestData['beneficiaryName'] = beneficiaryNameController.text;
      requestData['beneficiaryPhone'] = beneficiaryPhoneController.text;
      requestData['beneficiaryAddress'] = beneficiaryAddressController.text;
    }

    controller.submitRequest(requestData);
  }

  void _showDetailsBottomSheet() {
    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setModalState) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface.withValues(alpha: 0.8),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
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
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_getIconData(selectedService!.icon), color: AppTheme.primaryGreen, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('تفاصيل الطلب', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                Text(selectedService!.name, 
                                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Get.back(),
                            icon: const Icon(Icons.close, color: AppTheme.errorColor),
                          )
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: AppTheme.glassBorder),
                      ),

                      if (isAdmin) ...[
                        Text('بيانات المستفيد (يدوي)', style: TextStyle(color: AppTheme.primaryGreen, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: beneficiaryNameController,
                          style: TextStyle(color: AppTheme.textPrimary),
                          decoration: AppTheme.inputDecoration('اسم المستفيد الكامل...', Icons.person_add_alt_1_rounded),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: beneficiaryPhoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: AppTheme.textPrimary),
                          decoration: AppTheme.inputDecoration('رقم هاتف المستفيد...', Icons.phone_android_rounded),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: beneficiaryAddressController,
                          style: TextStyle(color: AppTheme.textPrimary),
                          decoration: AppTheme.inputDecoration('عنوان المستفيد...', Icons.location_city_rounded),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(color: AppTheme.glassBorder),
                        ),
                      ],
                      
                      ...selectedService!.fields.map((field) => Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(field, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            _buildDynamicField(field, setModalState),
                          ],
                        ),
                      )),
    
                      Text('وصف إضافي أو ملاحظات', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionController,
                        maxLines: 2,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: AppTheme.inputDecoration('اكتب هنا أي تفاصيل أخرى...', Icons.description_outlined).copyWith(
                          fillColor: Colors.white.withValues(alpha: 0.03),
                        ),
                      ),
    
                      const SizedBox(height: 24),
                      Text('🚩 درجة الاستعجال', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildUrgencyChip(setModalState, 'normal', 'عادي', AppTheme.successColor),
                          const SizedBox(width: 8),
                          _buildUrgencyChip(setModalState, 'urgent', 'مستعجل', AppTheme.urgentColor),
                          const SizedBox(width: 8),
                          _buildUrgencyChip(setModalState, 'emergency', 'طوارئ', AppTheme.emergencyColor),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      Obx(() => controller.isLoading.value
                        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                        : AppTheme.gradientButton(
                            text: 'إرسال الطلب للمراجعة',
                            icon: Icons.send_rounded,
                            onPressed: _submitRequest,
                          )
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

  Widget _buildUrgencyChip(Function setModalState, String id, String label, Color color) {
    final isSelected = selectedUrgency == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setModalState(() => selectedUrgency = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSelected ? color : AppTheme.glassBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? color : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicField(String field, StateSetter setModalState) {
    bool isDateTime = field.contains('التاريخ والوقت') || (field.contains('تاريخ') && field.contains('وقت'));
    bool isDateOnly = field.contains('تاريخ') && !isDateTime;
    bool isTimeOnly = field.contains('وقت') && !isDateTime;
    bool isBloodType = field.contains('فصيلة');
    
    if (isDateTime || isDateOnly || isTimeOnly) {
      return InkWell(
        onTap: () async {
          DateTime? date;
          TimeOfDay? time;
          
          if (isDateTime || isDateOnly) {
            date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (context, child) => Theme(
                data: Get.isDarkMode 
                    ? ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.primaryGreen)) 
                    : ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.primaryGreen)),
                child: child!,
              ),
            );
            if (date == null && !isTimeOnly) return; 
          }
          
          if (isDateTime || isTimeOnly) {
            if (!mounted) return;
            time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
              builder: (context, child) => Theme(
                data: Get.isDarkMode 
                    ? ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.primaryGreen)) 
                    : ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.primaryGreen)),
                child: child!,
              ),
            );
            if (time == null && !isDateOnly) return;
          }
          
          String result = '';
          if (isDateTime && date != null && time != null) {
            final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
            result = intl.DateFormat('yyyy/MM/dd HH:mm').format(dt);
          } else if (isDateOnly && date != null) {
            result = intl.DateFormat('yyyy/MM/dd').format(date);
          } else if (isTimeOnly && time != null && mounted) {
            result = time.format(context);
          }
          
          if (result.isNotEmpty) {
            dynamicControllers[field]!.text = result;
          }
        },
        child: IgnorePointer(
          child: TextField(
            controller: dynamicControllers[field],
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: AppTheme.inputDecoration(
              isDateTime ? 'اختر التاريخ والوقت...' : (isDateOnly ? 'اختر التاريخ...' : 'اختر الوقت...'), 
              _getFieldIcon(field)
            ),
          ),
        ),
      );
    }
    
    if (isBloodType) {
      return DropdownButtonFormField<String>(
        key: ValueKey('bloodType_${dynamicControllers[field]!.text}'),
        initialValue: dynamicControllers[field]!.text.isEmpty ? null : dynamicControllers[field]!.text,
        decoration: AppTheme.inputDecoration('اختر فصيلة الدم...', _getFieldIcon(field)),
        dropdownColor: Theme.of(context).colorScheme.surface,
        style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Tajawal'),
        items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
            .map((e) => DropdownMenuItem(value: e, child: Text(e, textDirection: TextDirection.ltr)))
            .toList(),
        onChanged: (v) {
          if (v != null) dynamicControllers[field]!.text = v;
        },
      );
    }
    
    return TextField(
      controller: dynamicControllers[field],
      style: TextStyle(color: AppTheme.textPrimary),
      decoration: AppTheme.inputDecoration('أدخل $field...', _getFieldIcon(field)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.darkSurface,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('طلب خدمة جديدة', 
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryGreen.withValues(alpha: 0.2), Colors.transparent],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter
                  )
                ),
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
              onPressed: () => Get.back(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInDown(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('بوابة أبواب الخير', 
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                        Text('اختر نوع المساعدة التي تحتاجها وسنتواصل معك', 
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildServicesGrid(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesGrid() {
    return Obx(() {
      if (controller.isLoadingServices.value) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
      if (controller.availableServices.isEmpty) return AppTheme.emptyState('لا توجد خدمات متاحة حالياً');

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          childAspectRatio: 0.82,
        ),
        itemCount: controller.availableServices.length,
        itemBuilder: (context, index) {
          final service = controller.availableServices[index];
          final isSelected = selectedService?.id == service.id;
          
          return GestureDetector(
            onTap: () => _onServiceSelected(service),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.1) : AppTheme.darkSurface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.1), blurRadius: 10)] : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.15) : AppTheme.darkCard.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIconData(service.icon), 
                      color: isSelected ? AppTheme.primaryGreen : AppTheme.textHint,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    service.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                      color: isSelected ? AppTheme.textPrimary : AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'mosque': return Icons.mosque;
      case 'shopping_basket': return Icons.shopping_basket;
      case 'medication': return Icons.medication;
      case 'payments': return Icons.payments;
      case 'home_work': return Icons.home_work;
      case 'menu_book': return Icons.menu_book;
      case 'school': return Icons.school;
      case 'water_drop': return Icons.water_drop;
      case 'volunteer_activism': return Icons.volunteer_activism;
      case 'checkroom': return Icons.checkroom;
      case 'inventory': return Icons.inventory;
      case 'emergency': return Icons.emergency;
      case 'ac_unit': return Icons.ac_unit;
      case 'nightlight_round': return Icons.nightlight_round;
      case 'bloodtype': return Icons.bloodtype;
      case 'more_horiz': return Icons.more_horiz;
      default: return Icons.volunteer_activism;
    }
  }

  IconData _getFieldIcon(String fieldName) {
    if (fieldName.contains('اسم')) return Icons.person_outline;
    if (fieldName.contains('مكان') || fieldName.contains('عنوان')) return Icons.place_outlined;
    if (fieldName.contains('تاريخ') || fieldName.contains('وقت')) return Icons.calendar_today_outlined;
    if (fieldName.contains('عدد')) return Icons.numbers_rounded;
    if (fieldName.contains('فصيلة')) return Icons.bloodtype_outlined;
    if (fieldName.contains('مستشفى')) return Icons.local_hospital_outlined;
    if (fieldName.contains('مبلغ')) return Icons.attach_money_rounded;
    return Icons.edit_note_rounded;
  }
}
