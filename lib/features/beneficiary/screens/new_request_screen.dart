import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/beneficiary_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/service_type_model.dart';
import 'package:intl/intl.dart';

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final BeneficiaryController _controller = Get.find<BeneficiaryController>();
  final AuthController _authController = Get.find<AuthController>();

  ServiceTypeModel? _selectedServiceType;
  String _urgency = 'normal';
  final _notesCtl = TextEditingController();

  // Funeral fields
  final _deceasedNameCtl = TextEditingController();
  final _pickupLocCtl = TextEditingController();
  final _dropoffLocCtl = TextEditingController();
  DateTime? _funeralDate;

  bool _isLoading = false;

  @override
  void dispose() {
    _notesCtl.dispose();
    _deceasedNameCtl.dispose();
    _pickupLocCtl.dispose();
    _dropoffLocCtl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate() && _selectedServiceType != null) {
      if ((_selectedServiceType!.name.contains('جنازة') || _selectedServiceType!.name.contains('جنازات')) && _funeralDate == null) {
        Get.snackbar('تنبيه', 'يرجى تحديد وقت وتاريخ الجنازة');
        return;
      }

      setState(() => _isLoading = true);
      final user = _authController.currentUser.value!;

      Map<String, dynamic> details = {};
      if (_selectedServiceType!.name.contains('جنازة') || _selectedServiceType!.name.contains('جنازات')) {
        details = {
          'deceasedName': _deceasedNameCtl.text.trim(),
          'pickupLocation': _pickupLocCtl.text.trim(),
          'dropoffLocation': _dropoffLocCtl.text.trim(),
          'datetime': _funeralDate?.toIso8601String(),
        };
      }

      ServiceRequestModel request = ServiceRequestModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: _selectedServiceType!.name,
        requesterId: user.id,
        requesterName: user.name,
        phone: user.phone,
        wilaya: user.wilaya,
        address: user.address,
        description: _notesCtl.text.trim(),
        urgency: _urgency,
        status: 'pending',
        details: details,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _controller.submitRequest(request);
      setState(() => _isLoading = false);
    } else if (_selectedServiceType == null) {
      Get.snackbar('تنبيه', 'يرجى اختيار نوع الخدمة');
    }
  }

  Future<void> _pickDateTime() async {
    DateTime? d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null) {
      TimeOfDay? t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (t != null) {
        setState(() {
          _funeralDate = DateTime(d.year, d.month, d.day, t.hour, t.minute);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isFuneral = _selectedServiceType != null &&
        (_selectedServiceType!.name.contains('جنازة') || _selectedServiceType!.name.contains('جنازات'));

    return Scaffold(
      appBar: AppBar(title: const Text("طلب خدمة جديدة")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("اختر نوع الخدمة", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Obx(() => DropdownButtonFormField<ServiceTypeModel>(
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    value: _selectedServiceType,
                    items: _controller.availableServices
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedServiceType = val),
                    validator: (v) => v == null ? 'الرجاء اختيار نوع الخدمة' : null,
                  )),
              const SizedBox(height: 24),
              if (isFuneral) ...[
                const Text("تفاصيل الجنازة", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _deceasedNameCtl,
                  decoration: const InputDecoration(labelText: "اسم المتوفى", border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pickupLocCtl,
                  decoration: const InputDecoration(labelText: "مكان الاستلام", border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dropoffLocCtl,
                  decoration: const InputDecoration(labelText: "مكان التسليم", border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 16),
                ListTile(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  title: Text(_funeralDate == null
                      ? "تحديد الوقت والتاريخ"
                      : DateFormat('yyyy-MM-dd HH:mm').format(_funeralDate!)),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: _pickDateTime,
                ),
                const SizedBox(height: 24),
              ],
              const Text("درجة الاستعجال", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(border: OutlineInputBorder()),
                value: _urgency,
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text("عادي (أخضر)", style: TextStyle(color: Colors.green))),
                  DropdownMenuItem(value: 'urgent', child: Text("مستعجل (برتقالي)", style: TextStyle(color: Colors.orange))),
                  DropdownMenuItem(value: 'emergency', child: Text("طارئ (أحمر)", style: TextStyle(color: Colors.red))),
                ],
                onChanged: (val) => setState(() => _urgency = val ?? 'normal'),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _notesCtl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: "ملاحظات إضافية (اختياري)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      onPressed: _submit,
                      child: const Text("إرسال الطلب"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
