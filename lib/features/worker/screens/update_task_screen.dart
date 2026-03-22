import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/worker_controller.dart';
import '../../../data/models/service_request_model.dart';

class UpdateTaskScreen extends StatefulWidget {
  const UpdateTaskScreen({super.key});

  @override
  State<UpdateTaskScreen> createState() => _UpdateTaskScreenState();
}

class _UpdateTaskScreenState extends State<UpdateTaskScreen> {
  final WorkerController workerController = Get.find<WorkerController>();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  
  ServiceRequestModel? _selectedRequest;
  String _selectedType = 'progress';
  File? _imageFile;

  final List<Map<String, dynamic>> _updateTypes = [
    {'id': 'progress', 'label': 'تقدم في العمل', 'icon': Icons.trending_up, 'color': AppTheme.primaryGreen},
    {'id': 'arrived', 'label': 'وصلت للموقع', 'icon': Icons.location_on, 'color': Colors.blue},
    {'id': 'issue', 'label': 'مشكلة / عائق', 'icon': Icons.warning_outlined, 'color': AppTheme.warningColor},
    {'id': 'note', 'label': 'ملاحظة عامة', 'icon': Icons.note_outlined, 'color': AppTheme.textHint},
  ];

  @override
  void initState() {
    super.initState();
    if (Get.arguments is ServiceRequestModel) {
      _selectedRequest = Get.arguments as ServiceRequestModel;
    } else if (workerController.myTasks.isNotEmpty) {
      _selectedRequest = workerController.myTasks.first;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  void _submitUpdate() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedRequest == null) {
        Get.snackbar('تنبيه', 'يرجى اختيار المهمة', backgroundColor: AppTheme.warningColor.withValues(alpha: 0.2));
        return;
      }

      await workerController.submitQuickUpdate(
        requestId: _selectedRequest!.id,
        type: _selectedType,
        description: _descriptionController.text,
        imageFile: _imageFile,
      );
      
      _descriptionController.clear();
      setState(() {
        _imageFile = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('إضافة تحديث'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('اختر المهمة', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Obx(() => Container(
                decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.glassBorder)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ServiceRequestModel>(
                    value: _selectedRequest,
                    isExpanded: true,
                    dropdownColor: AppTheme.darkSurface,
                    hint: Text('اختر المهمة...', style: TextStyle(color: AppTheme.textHint)),
                    items: workerController.myTasks.map((req) {
                      return DropdownMenuItem(
                        value: req,
                        child: Text('${req.type} - ${req.requesterName}', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedRequest = val),
                  ),
                ),
              )),
              
              const SizedBox(height: 20),
              Text('نوع التحديث', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: _updateTypes.length,
                itemBuilder: (context, index) {
                  final type = _updateTypes[index];
                  final isSelected = _selectedType == type['id'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = type['id']),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected ? type['color'].withValues(alpha: 0.2) : AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? type['color'] : AppTheme.glassBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(type['icon'], color: isSelected ? type['color'] : AppTheme.textHint, size: 18),
                          const SizedBox(width: 8),
                          Text(type['label'], style: TextStyle(color: isSelected ? type['color'] : AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              Text('الوصف', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: AppTheme.inputDecoration('اكتب ما تم إنجازه أو أي ملاحظات...', Icons.edit_note),
                validator: (v) => v == null || v.isEmpty ? 'يرجى كتابة وصف' : null,
              ),

              const SizedBox(height: 20),
              Text('إرفاق صورة', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.glassBorder, style: BorderStyle.solid),
                  ),
                  child: _imageFile != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(_imageFile!, width: double.infinity, height: 120, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => setState(() => _imageFile = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: AppTheme.errorColor, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo_outlined, color: AppTheme.textHint, size: 32),
                            const SizedBox(height: 8),
                            Text('التقط صورة للتوثيق', style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 32),
              Obx(() => workerController.isLoading.value
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                  : AppTheme.gradientButton(
                      text: 'إرسال التحديث الآن',
                      icon: Icons.send,
                      onPressed: _submitUpdate,
                    )),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
