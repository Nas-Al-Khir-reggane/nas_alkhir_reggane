import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/beneficiary_controller.dart';
import '../../../data/models/service_type_model.dart';

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final BeneficiaryController controller = Get.find<BeneficiaryController>();
  
  ServiceTypeModel? selectedService;
  String selectedUrgency = 'normal';
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController deceasedNameController = TextEditingController();
  final TextEditingController pickupController = TextEditingController();
  final TextEditingController deliveryController = TextEditingController();
  DateTime? selectedDateTime;

  @override
  void dispose() {
    descriptionController.dispose();
    deceasedNameController.dispose();
    pickupController.dispose();
    deliveryController.dispose();
    super.dispose();
  }

  void _submitRequest() {
    if (selectedService == null) {
      Get.snackbar('تنبيه', 'يرجى اختيار نوع الخدمة', backgroundColor: AppTheme.warningColor.withValues(alpha: 0.2));
      return;
    }

    Map<String, dynamic> requestData = {
      'type': selectedService!.id,
      'typeName': selectedService!.name,
      'urgency': selectedUrgency,
      'description': descriptionController.text,
      'details': {},
    };

    if (selectedService!.id == 'funeral_transport') {
      if (deceasedNameController.text.isEmpty || pickupController.text.isEmpty || deliveryController.text.isEmpty || selectedDateTime == null) {
        Get.snackbar('تنبيه', 'يرجى ملء جميع الحقول المطلوبة', backgroundColor: AppTheme.warningColor.withValues(alpha: 0.2));
        return;
      }
      requestData['details'] = {
        'deceasedName': deceasedNameController.text,
        'pickupLocation': pickupController.text,
        'deliveryLocation': deliveryController.text,
        'requestedTime': selectedDateTime,
      };
    } else {
      if (descriptionController.text.isEmpty) {
        Get.snackbar('تنبيه', 'يرجى وصف الطلب', backgroundColor: AppTheme.warningColor.withValues(alpha: 0.2));
        return;
      }
    }

    controller.submitRequest(requestData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('طلب خدمة جديدة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('طلب خدمة جديدة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            Text('اختر نوع الخدمة المطلوبة', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 20),

            Text('نوع الخدمة *', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Obx(() => GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: controller.availableServices.map((service) {
                final isSelected = selectedService?.id == service.id;
                // لون أيقونة افتراضي
                Color serviceColor = AppTheme.primaryGreen;
                if (service.id == 'funeral_transport') serviceColor = Colors.deepPurpleAccent;

                return GestureDetector(
                  onTap: () => setState(() => selectedService = service),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? serviceColor.withValues(alpha: 0.2) : AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? serviceColor : AppTheme.glassBorder,
                        width: isSelected ? 2 : 1
                      ),
                      boxShadow: isSelected ? AppTheme.cardShadow : null
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_getIconData(service.id), color: isSelected ? serviceColor : AppTheme.textHint, size: 28),
                        const SizedBox(height: 8),
                        Text(service.name,
                          style: TextStyle(
                            color: isSelected ? serviceColor : AppTheme.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 13
                          ),
                          textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              }).toList(),
            )),

            const SizedBox(height: 20),

            if (selectedService != null)
              FadeInUp(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تفاصيل الطلب', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    
                    if (selectedService!.id == 'funeral_transport')
                      _buildFuneralFields()
                    else
                      _buildGeneralFields(),
                    
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
                  ],
                ),
              ),

            const SizedBox(height: 24),

            Obx(() => controller.isLoading.value
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
              : AppTheme.gradientButton(
                  text: 'إرسال الطلب',
                  icon: Icons.send,
                  onPressed: _submitRequest,
                )
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFuneralFields() {
    return Column(
      children: [
        _buildLabeledField('اسم المتوفى *', Icons.person_off_outlined, deceasedNameController),
        const SizedBox(height: 12),
        _buildLabeledField('مكان الاستلام *', Icons.place_outlined, pickupController, hint: 'المستشفى/البيت...'),
        const SizedBox(height: 12),
        _buildLabeledField('مكان التسليم (المقبرة) *', Icons.flag_outlined, deliveryController),
        const SizedBox(height: 12),
        Text('التاريخ والوقت المطلوب *', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 7)),
            );
            if (date != null) {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (time != null) {
                setState(() {
                  selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                });
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.glassBorder)
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: AppTheme.primaryGreen),
                const SizedBox(width: 12),
                Text(
                  selectedDateTime != null 
                    ? selectedDateTime.toString().substring(0, 16) 
                    : 'اختر التاريخ والوقت',
                  style: TextStyle(color: selectedDateTime != null ? AppTheme.textPrimary : AppTheme.textHint)
                ),
                const Spacer(),
                const Icon(Icons.arrow_drop_down, color: AppTheme.textHint)
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralFields() {
    return _buildLabeledField('وصف الطلب *', Icons.description_outlined, descriptionController, maxLines: 3);
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? color : AppTheme.textHint, size: 20),
              const SizedBox(height: 4),
              Text(name, style: TextStyle(color: isSelected ? color : AppTheme.textHint, fontSize: 11), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabeledField(String label, IconData icon, TextEditingController controller, {String? hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: AppTheme.inputDecoration(hint ?? label, icon),
        ),
      ],
    );
  }

  IconData _getIconData(String serviceId) {
    switch (serviceId) {
      case 'funeral_transport': return Icons.airport_shuttle;
      case 'food_aid': return Icons.fastfood;
      case 'financial_aid': return Icons.attach_money;
      case 'medical_aid': return Icons.local_hospital;
      case 'education': return Icons.school;
      case 'construction': return Icons.construction;
      default: return Icons.volunteer_activism;
    }
  }
}
