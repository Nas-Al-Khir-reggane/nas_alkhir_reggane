import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/worker_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/service_request_model.dart';

class UpdateTaskScreen extends StatefulWidget {
  const UpdateTaskScreen({super.key});

  @override
  State<UpdateTaskScreen> createState() => _UpdateTaskScreenState();
}

class _UpdateTaskScreenState extends State<UpdateTaskScreen> {
  final WorkerController _workerController = Get.find<WorkerController>();
  final _formKey = GlobalKey<FormState>();
  final _descCtl = TextEditingController();

  ServiceRequestModel? _selectedRequest;
  String? _selectedTaskType;
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (Get.arguments is ServiceRequestModel) {
      _selectedRequest = Get.arguments as ServiceRequestModel;
    }
  }

  @override
  void dispose() {
    _descCtl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedRequest == null) {
        Get.snackbar("تنبيه", "يرجى اختيار المهمة المراد تحديثها");
        return;
      }
      if (_selectedTaskType == null) {
        Get.snackbar("تنبيه", "يرجى اختيار نوع التحديث");
        return;
      }

      setState(() => _isLoading = true);
      String text = "[$_selectedTaskType] - ${_descCtl.text}";
      await _workerController.submitUpdate(_selectedRequest!.id, text, _imageFile);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إضافة تحديث للمهمة")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("المهمة", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Obx(() => DropdownButtonFormField<ServiceRequestModel>(
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    value: _selectedRequest,
                    hint: const Text("اختر المهمة..."),
                    items: _workerController.assignedRequests.map((req) {
                      return DropdownMenuItem(
                        value: req,
                        child: SizedBox(
                          width: 200,
                          child: Text("${req.type} - ${req.requesterName}", overflow: TextOverflow.ellipsis),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedRequest = val),
                    validator: (v) => v == null ? "مطلوب" : null,
                  )),
              const SizedBox(height: 16),
              const Text("نوع التحديث", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(border: OutlineInputBorder()),
                value: _selectedTaskType,
                hint: const Text("اختر النوع..."),
                items: AppConstants.defaultTaskTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _selectedTaskType = val),
                validator: (v) => v == null ? "مطلوب" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: "وصف التحديث", border: OutlineInputBorder()),
                validator: (v) => (v == null || v.isEmpty) ? "مطلوب" : null,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.camera_alt),
                label: const Text("التقاط / إرفاق صورة"),
              ),
              if (_imageFile != null) ...[
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      onPressed: _submit,
                      icon: const Icon(Icons.send),
                      label: const Text("إرسال التحديث"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
