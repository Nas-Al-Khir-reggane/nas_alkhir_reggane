import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:ui' as ui;
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
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
  
  final TextEditingController beneficiaryNameController = TextEditingController();
  final TextEditingController beneficiaryPhoneController = TextEditingController();
  final TextEditingController beneficiaryAddressController = TextEditingController();

  String? selectedWilaya;
  bool isReordering = false;

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
    if (isReordering) return;
    setState(() {
      selectedService = service;
      selectedWilaya = null;
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
          backgroundColor: Colors.orange.withValues(alpha: 0.2),
          colorText: Colors.orange);
        return;
      }
      details[entry.key] = entry.value.text;
    }

    if (selectedService!.id == 'other' && descriptionController.text.isEmpty) {
      Get.snackbar('تنبيه', 'يرجى وصف الطلب بالتفصيل', 
          backgroundColor: Colors.orange.withValues(alpha: 0.15));
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2), width: 1.5),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))
                              ],
                            ),
                            child: Icon(AppConstants.getIconFromName(selectedService!.icon), color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('نموذج طلب الخدمة', 
                                  style: TextStyle(color: AppTheme.primaryGreen, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                Text(selectedService!.name, 
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: () => Get.back(),
                            icon: const Icon(Icons.close, size: 20),
                            style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.1), foregroundColor: Theme.of(context).colorScheme.error),
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      if (isAdmin) ...[
                        _buildSectionHeader('بيانات المستفيد (إدخال إداري)', Icons.admin_panel_settings_rounded),
                        const SizedBox(height: 12),
                        _buildPremiumTextField(beneficiaryNameController, 'اسم المستفيد الكامل', Icons.person_add_alt_1_rounded),
                        const SizedBox(height: 12),
                        _buildPremiumTextField(beneficiaryPhoneController, 'رقم هاتف التواصل', Icons.phone_android_rounded, keyboardType: TextInputType.phone),
                        const SizedBox(height: 12),
                        _buildPremiumTextField(beneficiaryAddressController, 'عنوان السكن الحالي', Icons.location_on_rounded),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Divider(height: 1),
                        ),
                      ],
                      
                      _buildSectionHeader('المعلومات المطلوبة للطلب', Icons.assignment_rounded),
                      const SizedBox(height: 16),

                      ...selectedService!.fields.map((field) => Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(field, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            _buildSmartField(field, setModalState),
                          ],
                        ),
                      )),
    
                      _buildSectionHeader('وصف إضافي أو ملاحظات', Icons.note_alt_rounded),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        decoration: AppTheme.inputDecoration('أضف أي تفاصيل أخرى تساعدنا في فهم طلبك بشكل أفضل...', Icons.description_outlined).copyWith(
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                      ),
    
                      const SizedBox(height: 24),
                      _buildSectionHeader('درجة استعجال الطلب', Icons.bolt_rounded),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildUrgencyOption(setModalState, 'normal', 'عادي', Colors.green),
                          const SizedBox(width: 10),
                          _buildUrgencyOption(setModalState, 'urgent', 'مستعجل', Colors.orange),
                          const SizedBox(width: 10),
                          _buildUrgencyOption(setModalState, 'emergency', 'طوارئ', AppTheme.errorColor),
                        ],
                      ),
                      
                      const SizedBox(height: 35),
                      Obx(() => controller.isLoading.value
                        ? const Center(child: CircularProgressIndicator())
                        : AppTheme.gradientButton(
                            text: 'تأكيد وإرسال الطلب الآن',
                            icon: Icons.send_rounded,
                            onPressed: _submitRequest,
                          )
                      ),
                      const SizedBox(height: 30),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryGreen),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: AppTheme.primaryGreen.withValues(alpha: 0.1))),
        ],
      ),
    );
  }

  Widget _buildPremiumTextField(TextEditingController ctrl, String hint, IconData icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: AppTheme.inputDecoration(hint, icon).copyWith(
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildUrgencyOption(Function setModalState, String id, String label, Color color) {
    final isSelected = selectedUrgency == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setModalState(() => selectedUrgency = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? color : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))] : null,
          ),
          child: Column(
            children: [
              Icon(
                id == 'normal' ? Icons.check_circle_outline : (id == 'urgent' ? Icons.priority_high_rounded : Icons.warning_amber_rounded),
                color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmartField(String field, StateSetter setModalState) {
    final text = field.toLowerCase();
    
    if (text.contains('التاريخ والوقت') || (text.contains('تاريخ') && text.contains('وقت'))) {
      return _buildPickerField(field, false, false, true);
    }
    if (text.contains('تاريخ')) return _buildPickerField(field, true, false, false);
    if (text.contains('وقت')) return _buildPickerField(field, false, true, false);

    if (text.contains('ولاية')) {
      return _buildDropdownField(field, AppConstants.algeriaWilayas, 'اختر الولاية...', (val) {
        setModalState(() {
          selectedWilaya = val;
          dynamicControllers[field]!.text = val ?? '';
        });
      });
    }

    if (text.contains('بلدية')) {
      List<String> communes = selectedWilaya != null ? AppConstants.getCommunesForWilaya(selectedWilaya!) : [];
      return _buildDropdownField(field, communes, selectedWilaya == null ? 'اختر الولاية أولاً' : 'اختر البلدية...', (val) => dynamicControllers[field]!.text = val ?? '', enabled: selectedWilaya != null);
    }

    if (text.contains('فصيلة')) {
      return _buildDropdownField(field, ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'], 'اختر فصيلة الدم...', (val) => dynamicControllers[field]!.text = val ?? '');
    }

    if (text.contains('جنس')) return _buildChoiceChips(field, ['ذكر', 'أنثى'], setModalState);

    if (text.contains('مكان الغسل')) {
      return _buildDropdownField(field, ['المنزل', 'المسجد', 'مغسلة المستشفى', 'أخرى'], 'اختر مكان الغسل...', (val) => dynamicControllers[field]!.text = val ?? '');
    }

    if (text.contains('المستلزمات')) {
      return _buildDropdownField(field, ['كفن كامل شامل', 'أدوات غسل فقط', 'لا أحتاج (متوفرة)', 'أحتاج متطوع فقط'], 'هل تحتاج مستلزمات؟', (val) => dynamicControllers[field]!.text = val ?? '');
    }

    if (text.contains('عدد') || text.contains('كمية') || text.contains('مبلغ')) {
      bool isAmount = text.contains('مبلغ');
      return TextField(
        controller: dynamicControllers[field],
        keyboardType: TextInputType.number,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: AppTheme.inputDecoration(isAmount ? 'أدخل المبلغ بالدينار...' : 'أدخل $field...', _getFieldIcon(field)).copyWith(
          suffixText: isAmount ? 'د.ج' : null,
          suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
        ),
      );
    }

    if (text.contains('هاتف') || text.contains('جوال')) {
      return TextField(
        controller: dynamicControllers[field],
        keyboardType: TextInputType.phone,
        maxLength: 10,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: AppTheme.inputDecoration('0XXXXXXXXX', _getFieldIcon(field)).copyWith(counterText: ''),
      );
    }
    
    return TextField(
      controller: dynamicControllers[field],
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: AppTheme.inputDecoration('أدخل $field...', _getFieldIcon(field)),
    );
  }

  Widget _buildPickerField(String field, bool isDateOnly, bool isTimeOnly, bool isDateTime) {
    return InkWell(
      onTap: () async {
        DateTime? date;
        TimeOfDay? time;
        if (isDateTime || isDateOnly) {
          date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), locale: const Locale('ar'));
          if (date == null && !isTimeOnly) return; 
        }
        if (isDateTime || isTimeOnly) {
          if (!mounted) return;
          time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
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
        if (result.isNotEmpty) setState(() => dynamicControllers[field]!.text = result);
      },
      child: IgnorePointer(
        child: TextField(
          controller: dynamicControllers[field],
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: AppTheme.inputDecoration(isDateTime ? 'اختر التاريخ والوقت...' : (isDateOnly ? 'اختر التاريخ...' : 'اختر الوقت...'), _getFieldIcon(field)).copyWith(
            suffixIcon: const Icon(Icons.touch_app_rounded, size: 20, color: AppTheme.primaryGreen),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(String field, List<String> items, String hint, Function(String?) onChanged, {bool enabled = true}) {
    return DropdownButtonFormField<String>(
      value: dynamicControllers[field]!.text.isEmpty ? null : dynamicControllers[field]!.text,
      decoration: AppTheme.inputDecoration(hint, _getFieldIcon(field)),
      dropdownColor: Theme.of(context).colorScheme.surface,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryGreen),
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Tajawal', fontSize: 14),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: enabled ? (v) {
        onChanged(v);
        setState(() {});
      } : null,
    );
  }

  Widget _buildChoiceChips(String field, List<String> options, StateSetter setModalState) {
    return Wrap(
      spacing: 12,
      children: options.map((opt) {
        final isSelected = dynamicControllers[field]!.text == opt;
        return ChoiceChip(
          label: Text(opt),
          selected: isSelected,
          onSelected: (selected) => setModalState(() => dynamicControllers[field]!.text = selected ? opt : ''),
          selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
          checkmarkColor: AppTheme.primaryGreen,
          labelStyle: TextStyle(color: isSelected ? AppTheme.primaryGreen : Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: isSelected ? AppTheme.primaryGreen : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1))),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.primaryGreenDark,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
              ),
              onPressed: () => Get.back(),
            ),
            actions: [
              if (isAdmin)
                IconButton(
                  onPressed: () => setState(() => isReordering = !isReordering),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isReordering ? Colors.white : Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle
                    ),
                    child: Icon(
                      isReordering ? Icons.check_rounded : Icons.reorder_rounded, 
                      color: isReordering ? AppTheme.primaryGreen : Colors.white, 
                      size: 20
                    ),
                  ),
                ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text('تقديم طلب مساعدة', 
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, 
                shadows: [Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 2))])),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryGreenDark, AppTheme.primaryGreen],
                        begin: Alignment.topRight, end: Alignment.bottomLeft
                      )
                    ),
                  ),
                  Positioned(
                    right: -50, top: -50,
                    child: Opacity(
                      opacity: 0.1,
                      child: Icon(Icons.mosque, size: 250, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    left: -30, bottom: -30,
                    child: Opacity(
                      opacity: 0.05,
                      child: Icon(Icons.volunteer_activism, size: 180, color: Colors.white),
                    ),
                  ),
                  Center(
                    child: FadeInDown(
                      child: Icon(Icons.favorite_rounded, size: 60, color: Colors.white.withValues(alpha: 0.2)),
                    ),
                  )
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInRight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4, height: 24,
                                decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(2)),
                              ),
                              const SizedBox(width: 12),
                              Text('بوابة طلب الخدمات الخيرية', 
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isReordering 
                              ? 'قم بسحب وإفلات الخدمات لإعادة ترتيبها حسب الأهمية' 
                              : 'اختر نوع الخدمة التي تحتاجها، وسنعمل جاهدين لمساعدتك', 
                            style: TextStyle(
                              color: isReordering ? AppTheme.primaryGreen : Theme.of(context).colorScheme.onSurfaceVariant, 
                              fontSize: 14, 
                              height: 1.5,
                              fontWeight: isReordering ? FontWeight.bold : FontWeight.normal
                            )
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildServicesGrid(),
                    const SizedBox(height: 40),
                    _buildGuidelineCard(),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.info_outline_rounded, color: AppTheme.primaryGreen, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('تنبيه هام', style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryGreen, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'نحن في خدمتكم دائماً. يرجى توخي الدقة في البيانات المدخلة لضمان سرعة معالجة الطلب من قبل لجنة الجمعية.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesGrid() {
    return Obx(() {
      if (controller.isLoadingServices.value) return const Center(child: Padding(padding: EdgeInsets.all(50.0), child: CircularProgressIndicator()));
      if (controller.availableServices.isEmpty) return AppTheme.emptyState('لا توجد خدمات متاحة حالياً');

      if (isReordering) {
        return ReorderableWrap(
          spacing: 16,
          runSpacing: 16,
          onReorder: (oldIndex, newIndex) async {
            final items = List<ServiceTypeModel>.from(controller.availableServices);
            final item = items.removeAt(oldIndex);
            items.insert(newIndex, item);
            controller.availableServices.value = items;

            // Update popularities in Firestore to maintain order
            final batch = FirebaseFirestore.instance.batch();
            for (int i = 0; i < items.length; i++) {
              batch.update(
                FirebaseFirestore.instance.collection('service_types').doc(items[i].id),
                {'popularity': (items.length - i) * 10}
              );
            }
            await batch.commit();
          },
          children: controller.availableServices.map((service) => _buildServiceItem(service, true)).toList(),
        );
      }

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.82,
        ),
        itemCount: controller.availableServices.length,
        itemBuilder: (context, index) {
          final service = controller.availableServices[index];
          return FadeInUp(
            delay: Duration(milliseconds: index * 40),
            child: _buildServiceItem(service, false),
          );
        },
      );
    });
  }

  Widget _buildServiceItem(ServiceTypeModel service, bool isReorderMode) {
    final isSelected = selectedService?.id == service.id;
    return GestureDetector(
      key: ValueKey(service.id),
      onTap: () => _onServiceSelected(service),
      child: AnimatedContainer(
        width: (MediaQuery.of(context).size.width - 72) / 3, // For ReorderableWrap
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.05) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : (isReorderMode ? AppTheme.primaryGreen.withValues(alpha: 0.3) : Theme.of(context).colorScheme.outline.withValues(alpha: 0.05)),
            width: isSelected || isReorderMode ? 2.5 : 1,
          ),
          boxShadow: isSelected 
            ? [BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.15), blurRadius: 15, offset: const Offset(0, 8))]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isReorderMode)
              const Icon(Icons.drag_indicator_rounded, color: AppTheme.primaryGreen, size: 18),
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.15) : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppConstants.getIconFromName(service.icon), 
                color: isSelected ? AppTheme.primaryGreen : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                service.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected ? AppTheme.primaryGreen : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _getFieldIcon(String fieldName) {
    final name = fieldName.toLowerCase();
    if (name.contains('اسم')) return Icons.badge_outlined;
    if (name.contains('مكان') || name.contains('عنوان')) return Icons.location_on_outlined;
    if (name.contains('ولاية')) return Icons.map_outlined;
    if (name.contains('بلدية')) return Icons.location_city_rounded;
    if (name.contains('تاريخ')) return Icons.calendar_today_rounded;
    if (name.contains('وقت')) return Icons.schedule_rounded;
    if (name.contains('عدد') || name.contains('كمية')) return Icons.format_list_numbered_rtl_rounded;
    if (name.contains('فصيلة')) return Icons.water_drop_outlined;
    if (name.contains('مستشفى')) return Icons.local_hospital_outlined;
    if (name.contains('مبلغ') || name.contains('ثمن')) return Icons.account_balance_wallet_outlined;
    if (name.contains('هاتف') || name.contains('جوال')) return Icons.phone_android_rounded;
    if (name.contains('جنس')) return Icons.people_outline_rounded;
    if (name.contains('مستلزمات')) return Icons.inventory_2_outlined;
    if (name.contains('غسل')) return Icons.clean_hands_rounded;
    return Icons.edit_note_rounded;
  }
}

class ReorderableWrap extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final Function(int, int) onReorder;

  const ReorderableWrap({
    super.key,
    required this.children,
    this.spacing = 0,
    this.runSpacing = 0,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableDelayedDragStartListener(
      index: 0, // Not really used this way in a grid
      child: Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: children.asMap().entries.map((entry) {
          return ReorderableDragStartListener(
            index: entry.key,
            child: entry.value,
          );
        }).toList(),
      ),
    );
  }
}
