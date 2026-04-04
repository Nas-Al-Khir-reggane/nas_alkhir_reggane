import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/project_controller.dart';
import '../../../core/animations/mount_animations.dart';
import '../../../core/animations/micro_interactions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class AddProjectScreen extends StatefulWidget {
  const AddProjectScreen({super.key});

  @override
  State<AddProjectScreen> createState() => _AddProjectScreenState();
}

class _AddProjectScreenState extends State<AddProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _budgetController = TextEditingController();

  String _selectedCategory = AppConstants.projectCategories.first['id'] as String;
  DateTime? _selectedDate;
  bool _isMonthlyGoal = false; 
  bool _isSubscription = false; 

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectController = Get.find<ProjectController>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          SafeArea(
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(AppConstants.getScreenPaddingValue(context), 20, AppConstants.getScreenPaddingValue(context), 10),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.glassBorder),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Get.back(),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(Icons.arrow_back_ios_new_rounded,
                              color: AppTheme.textPrimary, size: 18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MountAnimations.heroTitle(
                        child: Text('➕ مشروع جديد',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary)),
                      ),
                      MountAnimations.heroSubtitle(
                        child: Text('أضف مشروعاً خيرياً جديداً',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.fromSTEB(AppConstants.getScreenPaddingValue(context), 8, AppConstants.getScreenPaddingValue(context), 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionCard(
                      icon: Icons.info_outline_rounded,
                      title: 'بيانات المشروع الأساسية',
                      children: [
                        _field(_nameController, 'اسم المشروع', Icons.edit_rounded,
                            'يرجى إدخال اسم المشروع'),
                        const SizedBox(height: AppTheme.spacingM),
                        _field(_descController, 'وصف المشروع',
                            Icons.description_rounded, 'يرجى إدخال الوصف',
                            maxLines: 4),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _sectionCard(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'التفاصيل المالية والنوع',
                      children: [
                        _field(
                            _budgetController,
                            'الميزانية المستهدفة (دج)',
                            Icons.monetization_on_rounded,
                            'أدخل المبلغ',
                            isNumber: true),
                        const SizedBox(height: AppTheme.spacingM),
                        _categoryDropdown(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // ✨ MODIFIED: Removed const
                            Text('نوع الهدف', style: TextStyle(color: AppTheme.textSecondary)),
                            ToggleButtons(
                              isSelected: [!_isMonthlyGoal, _isMonthlyGoal],
                              onPressed: (index) => setState(() => _isMonthlyGoal = index == 1),
                              borderRadius: BorderRadius.circular(12),
                              selectedColor: Colors.black,
                              fillColor: AppTheme.primaryGreen,
                              color: AppTheme.textHint,
                              constraints: const BoxConstraints(minHeight: 36, minWidth: 80),
                              children: const [
                                Text('إجمالي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('شهري', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          // ✨ MODIFIED: Removed const
                          title: Text('مشروع تبرع دوري (كفالة)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          value: _isSubscription,
                          activeThumbColor: AppTheme.primaryGreen,
                          onChanged: (val) => setState(() => _isSubscription = val),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _sectionCard(
                      icon: Icons.calendar_today_rounded,
                      title: 'الموعد النهائي',
                      children: [_datePicker()],
                    ),

                    const SizedBox(height: 16),

                    Obx(() => projectController.isLoading.value 
                      ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: AppTheme.primaryGreen)))
                      : const SizedBox.shrink()
                    ),

                    const SizedBox(height: 20),

                    MountAnimations.heroButton(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppTheme.greenGlow,
                        ),
                        child: MicroInteractions.bouncingButton(
                          onTap: () async {
                            if (_formKey.currentState!.validate()) {
                              if (_selectedDate == null) {
                                Get.snackbar(
                                  'تنبيه',
                                  'يرجى اختيار الموعد النهائي',
                                  backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15),
                                  colorText: AppTheme.warningColor,
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                                return;
                              }
                              Get.showOverlay(
                                asyncFunction: () async {
                                  await projectController.addProject(
                                    name: _nameController.text.trim(),
                                    description: _descController.text.trim(),
                                    category: _selectedCategory,
                                    budget: double.tryParse(_budgetController.text) ?? 0,
                                    endDate: _selectedDate!,
                                    isSubscription: _isSubscription, 
                                    isMonthlyGoal: _isMonthlyGoal,
                                  );
                                },
                                loadingWidget: const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.send_rounded, color: Colors.black, size: 22),
                                const SizedBox(width: 10),
                                Text('حفظ ونشر المشروع',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                    )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
      {required IconData icon,
      required String title,
      required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryGreen, size: 18),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.primaryGreen)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon,
      String error,
      {bool isNumber = false, int maxLines = 1}) {
    return MicroInteractions.animatedFocusField(
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary),
        decoration: AppTheme.inputDecoration(label, icon),
        validator: (v) => (v == null || v.isEmpty) ? error : null,
      ),
    );
  }

  Widget _categoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      dropdownColor: AppTheme.cardColor,
      isExpanded: true,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary),
      decoration: AppTheme.inputDecoration('الفئة', Icons.category_rounded),
      items: AppConstants.projectCategories.map((c) {
        return DropdownMenuItem<String>(
          value: c['id'] as String,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(c['icon'] as IconData, color: c['color'] as Color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c['name'] as String,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedCategory = val!),
    );
  }

  Widget _datePicker() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _selectedDate != null
                ? AppTheme.primaryGreen
                : AppTheme.glassBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 30)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              builder: (context, child) => Theme(
                data: Get.isDarkMode
                    ? ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(
                            primary: AppTheme.primaryGreen))
                    : ThemeData.light().copyWith(
                        colorScheme: const ColorScheme.light(
                            primary: AppTheme.primaryGreen)),
                child: child!,
              ),
            );
            if (date != null) setState(() => _selectedDate = date);
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                color: _selectedDate != null
                    ? AppTheme.primaryGreen
                    : AppTheme.textHint,
                size: 20),
            const SizedBox(width: 12),
            Text(
              _selectedDate == null
                  ? 'اختر التاريخ النهائي'
                  : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _selectedDate != null
                      ? AppTheme.textPrimary
                      : AppTheme.textHint),
            ),
            const Spacer(),
            if (_selectedDate != null)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.primaryGreen, size: 18),
          ],
        ),
      ),
    ),
  ),
);
  }
}

