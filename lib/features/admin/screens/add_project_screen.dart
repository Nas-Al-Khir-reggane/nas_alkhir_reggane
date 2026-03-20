import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/admin_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/project_model.dart';
import '../../auth/controllers/auth_controller.dart';

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
  
  String _selectedCategory = 'غذائية';
  DateTime? _selectedDate;

  final List<String> _categories = ['غذائية', 'طبية', 'جنائزية', 'تعليمية', 'أخرى'];

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();
    final authController = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: Text("إضافة مشروع جديد", style: GoogleFonts.tajawal()),
        actions: [
          IconButton(
            icon: Icon(Get.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => AppConstants.toggleTheme(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("بيانات المشروع الأساسية"),
              const SizedBox(height: 20),
              _buildTextField(_nameController, "اسم المشروع", Icons.edit, "يرجى إدخال اسم المشروع"),
              const SizedBox(height: 15),
              _buildTextField(_descController, "وصف المشروع", Icons.description, "يرجى إدخال الوصف", maxLines: 4),
              const SizedBox(height: 25),
              
              _buildSectionTitle("التفاصيل المالية والنوع"),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildTextField(_budgetController, "الميزانية (دج)", Icons.monetization_on, "أدخل المبلغ", isNumber: true)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildDropdown()),
                ],
              ),
              const SizedBox(height: 25),
              
              _buildSectionTitle("الموعد النهائي (اختياري)"),
              const SizedBox(height: 15),
              _buildDatePicker(context),
              
              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final newProject = ProjectModel(
                        id: '',
                        name: _nameController.text.trim(),
                        description: _descController.text.trim(),
                        category: _selectedCategory,
                        budget: double.parse(_budgetController.text),
                        deadline: _selectedDate,
                        createdAt: DateTime.now(),
                        createdBy: authController.currentUser.value?.id ?? '',
                      );
                      
                      await controller.addProject(newProject);
                      Get.back();
                      Get.snackbar("نجاح", "تمت إضافة المشروع بنجاح", 
                          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white);
                    }
                  },
                  child: Text("حفظ المشروع ونشره", style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen));
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, String error, {bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: Theme.of(context).cardColor,
      ),
      validator: (value) => value == null || value.isEmpty ? error : null,
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: "الفئة",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: Theme.of(context).cardColor,
      ),
      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: (val) => setState(() => _selectedCategory = val!),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) setState(() => _selectedDate = date);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(15),
          color: Theme.of(context).cardColor,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_selectedDate == null ? "اختر التاريخ" : _selectedDate.toString().split(' ')[0], 
                style: GoogleFonts.tajawal()),
            const Icon(Icons.calendar_today, color: AppTheme.primaryGreen),
          ],
        ),
      ),
    );
  }
}
