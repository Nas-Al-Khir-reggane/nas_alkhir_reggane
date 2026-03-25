import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/project_controller.dart';
import '../../../core/theme/app_theme.dart';

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

  String _selectedCategory = ProjectController.categories.first['id'] as String;
  DateTime? _selectedDate;

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
          // ─── Header ───
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.glassBorder),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppTheme.textPrimary, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('➕ مشروع جديد',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                              fontFamily: 'Tajawal')),
                      Text('أضف مشروعاً خيرياً جديداً',
                          style:
                              TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ─── Form ───
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // قسم: البيانات الأساسية
                    _sectionCard(
                      icon: Icons.info_outline_rounded,
                      title: 'بيانات المشروع الأساسية',
                      children: [
                        _field(_nameController, 'اسم المشروع', Icons.edit_rounded,
                            'يرجى إدخال اسم المشروع'),
                        const SizedBox(height: 14),
                        _field(_descController, 'وصف المشروع',
                            Icons.description_rounded, 'يرجى إدخال الوصف',
                            maxLines: 4),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // قسم: المالية والنوع
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
                        const SizedBox(height: 14),
                        _categoryDropdown(),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // قسم: الموعد النهائي
                    _sectionCard(
                      icon: Icons.calendar_today_rounded,
                      title: 'الموعد النهائي',
                      children: [_datePicker()],
                    ),

                    const SizedBox(height: 28),

                    // زر الحفظ
                    GestureDetector(
                      onTap: () async {
                        if (_formKey.currentState!.validate()) {
                          if (_selectedDate == null) {
                            Get.snackbar(
                              'تنبيه',
                              'يرجى اختيار الموعد النهائي',
                              backgroundColor:
                                  AppTheme.warningColor.withValues(alpha: 0.2),
                              colorText: AppTheme.warningColor,
                              snackPosition: SnackPosition.BOTTOM,
                            );
                            return;
                          }
                          await projectController.addProject(
                            name: _nameController.text.trim(),
                            description: _descController.text.trim(),
                            category: _selectedCategory,
                            budget: double.parse(_budgetController.text),
                            endDate: _selectedDate!,
                          );
                          Get.back();
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppTheme.greenGlow,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_rounded, color: Colors.black, size: 22),
                            SizedBox(width: 10),
                            Text('حفظ المشروع ونشره',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    fontFamily: 'Tajawal')),
                          ],
                        ),
                      ),
                    ),
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
      padding: const EdgeInsets.all(18),
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
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryGreen, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                      fontFamily: 'Tajawal')),
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
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Tajawal'),
      decoration: AppTheme.inputDecoration(label, icon),
      validator: (v) => (v == null || v.isEmpty) ? error : null,
    );
  }

  /// اختيار الفئة — بدون Flexible داخل DropdownMenuItem لتجنب أخطاء الـ layout
  Widget _categoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      dropdownColor: AppTheme.cardColor,
      isExpanded: true,
      style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Tajawal'),
      decoration: AppTheme.inputDecoration('الفئة', Icons.category_rounded),
      items: ProjectController.categories.map((c) {
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
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
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
    return GestureDetector(
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: _selectedDate != null
                  ? AppTheme.primaryGreen
                  : AppTheme.glassBorder),
        ),
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
              style: TextStyle(
                  color: _selectedDate != null
                      ? AppTheme.textPrimary
                      : AppTheme.textHint,
                  fontFamily: 'Tajawal',
                  fontSize: 14),
            ),
            const Spacer(),
            if (_selectedDate != null)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.primaryGreen, size: 18),
          ],
        ),
      ),
    );
  }
}
