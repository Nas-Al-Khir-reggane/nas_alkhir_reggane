import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
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
    {'id': 'progress', 'label': 'تقدم في العمل', 'icon': Icons.trending_up, 'color': Colors.green},
    {'id': 'arrived', 'label': 'وصلت للموقع', 'icon': Icons.location_on, 'color': Colors.blue},
    {'id': 'issue', 'label': 'مشكلة / عائق', 'icon': Icons.warning_amber_rounded, 'color': Colors.orange},
    {'id': 'note', 'label': 'ملاحظة عامة', 'icon': Icons.note_outlined, 'color': Colors.grey},
  ];

  @override
  void initState() {
    super.initState();
    _handleArguments();
  }

  void _handleArguments() {
    if (Get.arguments is ServiceRequestModel) {
      _selectedRequest = Get.arguments as ServiceRequestModel;
    } else if (Get.arguments is Map && Get.arguments['requestId'] != null) {
      final reqId = Get.arguments['requestId'];
      _selectedRequest = workerController.myTasks.firstWhereOrNull((task) => task.id == reqId);
    }
    
    if (_selectedRequest == null && workerController.myTasks.isNotEmpty) {
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

  void _submitUpdate({bool isIssue = false}) async {
    if (_formKey.currentState!.validate()) {
      if (_selectedRequest == null) {
        Get.snackbar('تنبيه', 'يرجى اختيار المهمة', backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.15));
        return;
      }

      await workerController.submitQuickUpdate(
        requestId: _selectedRequest!.id,
        type: _selectedType,
        description: _descriptionController.text,
        imageFile: _imageFile,
        changeStatusToIssue: isIssue,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('تحديث حالة المهام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Tajawal')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Obx(() {
        if (_selectedRequest == null && workerController.myTasks.isNotEmpty) {
           _handleArguments();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اختر المهمة', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 8),
                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15))),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ServiceRequestModel>(
                          value: _selectedRequest,
                          isExpanded: true,
                          dropdownColor: Theme.of(context).cardColor,
                          hint: Text(workerController.myTasks.isEmpty ? 'لا توجد مهام حالية' : 'اختر المهمة...', 
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          items: workerController.myTasks.map((req) {
                            // تحسين: استخدام الاسم الفعلي للمهمة بدلاً من الرموز
                            String taskName = (req.typeName.isNotEmpty) ? req.typeName : AppConstants.translateServiceType(req.type);
                            return DropdownMenuItem(
                              value: req,
                              child: Row(
                                children: [
                                  Icon(
                                    req.status == 'in_progress' ? Icons.directions_run : 
                                    req.status == 'issue' ? Icons.report_problem_rounded : Icons.pending_actions, 
                                    color: req.status == 'in_progress' ? AppTheme.primaryGreen : 
                                           req.status == 'issue' ? AppTheme.errorColor : AppTheme.textHint, 
                                    size: 18
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(taskName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedRequest = val),
                        ),
                      ),
                    ),

                    if (_selectedRequest != null && _selectedRequest!.status != 'in_progress' && _selectedRequest!.status != 'issue')
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: AppTheme.gradientButton(
                          text: "باسم الله.. ابدأ المهمة",
                          icon: Icons.play_arrow_rounded,
                          onPressed: () => workerController.startTask(_selectedRequest!),
                          isLoading: workerController.isLoading.value,
                        ),
                      ),

                    if (workerController.isTracking.value)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.satellite_alt_rounded, color: AppTheme.primaryGreen, size: 20),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                "التتبع الحي للمركبة نشط الآن..",
                                style: TextStyle(color: AppTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
                            ),
                          ],
                        ),
                      ).animate(onComplete: (c) => c.repeat()).fade(duration: 800.ms).then().fade(duration: 800.ms, begin: 1, end: 0.3),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                AnimatedOpacity(
                  opacity: _selectedRequest != null ? 1.0 : 0.5,
                  duration: const Duration(milliseconds: 300),
                  child: AbsorbPointer(
                    absorbing: _selectedRequest == null,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('نوع التحديث', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
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
                                    color: isSelected ? type['color'].withValues(alpha: 0.15) : Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isSelected ? type['color'] : Colors.transparent),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(type['icon'], color: isSelected ? type['color'] : Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
                                      const SizedBox(width: 8),
                                      Text(type['label'], style: TextStyle(color: isSelected ? type['color'] : Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 24),
                          Text('التفاصيل', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 3,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            decoration: AppTheme.inputDecoration('ما الذي تم إنجازه؟', Icons.edit_note).copyWith(
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'يرجى كتابة وصف' : null,
                          ),

                          const SizedBox(height: 24),
                          Text('مرفقات (اختياري)', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: double.infinity,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15), style: BorderStyle.solid),
                              ),
                              child: _imageFile != null
                                  ? Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Image.file(_imageFile!, width: double.infinity, height: 100, fit: BoxFit.cover),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: () => setState(() => _imageFile = null),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.error, shape: BoxShape.circle),
                                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt_outlined, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5), size: 28),
                                        const SizedBox(width: 12),
                                        Text('التقط صورة', style: TextStyle(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8), fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                
                _buildActionButton(),
                
                const SizedBox(height: 60),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildActionButton() {
    if (_selectedRequest == null) {
      return AppTheme.gradientButton(
        text: "إرسال التحديث",
        icon: Icons.send_rounded,
        onPressed: null,
      );
    }

    if (_selectedType == 'issue') {
      return AppTheme.gradientButton(
        text: "إبلاغ عن عائق / مشكلة",
        icon: Icons.warning_rounded,
        onPressed: () => _submitUpdate(isIssue: true),
        isLoading: workerController.isLoading.value,
      );
    }

    if (_selectedType == 'progress' && _selectedRequest?.status == 'in_progress') {
      return AppTheme.gradientButton(
        text: "إتمام المهمة وإرسال التقرير",
        icon: Icons.check_circle_rounded,
        onPressed: () => workerController.completeTask(_selectedRequest!.id),
        isLoading: workerController.isLoading.value,
      );
    }

    return AppTheme.gradientButton(
      text: "إرسال تحديث ميداني",
      icon: Icons.send_rounded,
      onPressed: () => _submitUpdate(),
      isLoading: workerController.isLoading.value,
    );
  }
}
