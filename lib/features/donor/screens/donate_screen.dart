import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/donor_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/models/donation_model.dart';
import '../../../data/models/project_model.dart';

class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key});

  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  final _formKey = GlobalKey<FormState>();
  final DonorController _donorController = Get.find<DonorController>();
  final AuthController _authController = Get.find<AuthController>();

  ProjectModel? _selectedProject;
  final _amountCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  String _paymentMethod = 'bank_transfer';
  bool _isLoading = false;

  @override
  void dispose() {
    _amountCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final user = _authController.currentUser.value!;
      final amount = double.tryParse(_amountCtl.text.trim()) ?? 0.0;
      
      DonationModel donation = DonationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        donorId: user.id,
        donorName: user.name,
        amount: amount,
        projectId: _selectedProject?.id ?? 'general',
        projectName: _selectedProject?.name ?? 'صندوق الجمعية',
        method: _paymentMethod,
        status: 'pending',
        notes: _notesCtl.text.trim(),
        date: DateTime.now(),
      );

      await _donorController.makeDonation(donation);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تبرع جديد")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("المشروع المراد دعمه", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Obx(() => DropdownButtonFormField<ProjectModel?>(
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    value: _selectedProject,
                    hint: const Text("تبرع عام (بدون تحديد مشروع)"),
                    items: [
                      const DropdownMenuItem<ProjectModel?>(
                        value: null,
                        child: Text("تبرع عام (صندوق الجمعية)"),
                      ),
                      ..._donorController.activeProjects.map((p) => DropdownMenuItem<ProjectModel?>(
                            value: p,
                            child: Text(p.name),
                          ))
                    ],
                    onChanged: (val) => setState(() => _selectedProject = val),
                  )),
              const SizedBox(height: 16),
              const Text("طريقة الدفع", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(border: OutlineInputBorder()),
                value: _paymentMethod,
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text("نقدي (مقر الجمعية)")),
                  DropdownMenuItem(value: 'bank_transfer', child: Text("تحويل بنكي / CCP")),
                  DropdownMenuItem(value: 'electronic', child: Text("دفع إلكتروني (البطاقة الذهبية)")),
                ],
                onChanged: (val) => setState(() => _paymentMethod = val ?? 'bank_transfer'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "المبلغ (دج)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return "يرجى إدخال المبلغ";
                  if (double.tryParse(v) == null || double.parse(v) <= 0) return "مبلغ غير صحيح";
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesCtl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "ملاحظات الدفع (رقم الحوالة، تاريخ التحويل...)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      onPressed: _submit,
                      icon: const Icon(Icons.favorite),
                      label: const Text("تأكيد التبرع"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
