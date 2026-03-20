import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_constants.dart';

class GuestRequestScreen extends StatefulWidget {
  const GuestRequestScreen({super.key});

  @override
  State<GuestRequestScreen> createState() => _GuestRequestScreenState();
}

class _GuestRequestScreenState extends State<GuestRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  final _deceasedNameCtl = TextEditingController();
  final _pickupLocCtl = TextEditingController();
  final _dropoffLocCtl = TextEditingController();
  final _notesCtl = TextEditingController();

  String? _selectedWilaya;
  String? _selectedServiceType;
  List<String> _serviceTypes = AppConstants.defaultServiceTypes;
  bool _isLoading = false;
  LatLng? _pickupLatLng;
  LatLng? _dropoffLatLng;

  @override
  void initState() {
    super.initState();
    _loadServiceTypes();
  }

  Future<void> _loadServiceTypes() async {
    try {
      final snap = await FirebaseFirestore.instance.collection(AppConstants.serviceTypesCollection).get();
      if (snap.docs.isNotEmpty) {
        setState(() {
          _serviceTypes = snap.docs.map((doc) => doc.data()['name'] as String).toList();
        });
      }
    } catch (e) {
      // fallback to default
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    _deceasedNameCtl.dispose();
    _pickupLocCtl.dispose();
    _dropoffLocCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedWilaya == null || _selectedServiceType == null) {
        Get.snackbar("تنبيه", "يرجى إكمال جميع الحقول المطلوبة");
        return;
      }
      
      setState(() => _isLoading = true);
      try {
        final refNum = "GREQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";
        Map<String, dynamic> reqData = {
          'referenceNumber': refNum,
          'fullName': _nameCtl.text.trim(),
          'phone': _phoneCtl.text.trim(),
          'wilaya': _selectedWilaya,
          'address': _addressCtl.text.trim(),
          'serviceType': _selectedServiceType,
          'status': 'pending',
          'notes': _notesCtl.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        };

        if (_selectedServiceType!.contains("جنازة") || _selectedServiceType!.contains("جنازات")) {
          reqData['details'] = {
            'deceasedName': _deceasedNameCtl.text.trim(),
            'pickupLocation': _pickupLocCtl.text.trim(),
            'dropoffLocation': _dropoffLocCtl.text.trim(),
            'pickupLatLng': _pickupLatLng != null ? {'lat': _pickupLatLng!.latitude, 'lng': _pickupLatLng!.longitude} : null,
            'dropoffLatLng': _dropoffLatLng != null ? {'lat': _dropoffLatLng!.latitude, 'lng': _dropoffLatLng!.longitude} : null,
          };
        }

        await FirebaseFirestore.instance.collection('guest_requests').add(reqData);
        
        Get.back();
        Get.snackbar(
          "تم إرسال طلبك بنجاح",
          "الرقم المرجعي لطلبك: $refNum\nسنقوم بالاتصال بك قريباً.",
          duration: const Duration(seconds: 10),
        );
      } catch (e) {
        Get.snackbar("خطأ", "فشل إرسال الطلب: ${e.toString()}");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _pickLocation(bool isPickup) async {
    // This is a simplified location picker. In a real app, it would open a full map screen.
    // Assuming user selects center of the current map view
    LatLng res = const LatLng(36.7525, 3.04197); // Algiers for example
    setState(() {
      if (isPickup) {
        _pickupLatLng = res;
      } else {
        _dropoffLatLng = res;
      }
    });
    Get.snackbar("موقع", "تم تحديد الموقع بنجاح (للتجربة)");
  }

  @override
  Widget build(BuildContext context) {
    bool isFuneral = _selectedServiceType != null && 
        (_selectedServiceType!.contains("جنازة") || _selectedServiceType!.contains("جنازات"));

    return Scaffold(
      appBar: AppBar(title: const Text("طلب خدمة بدون حساب")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtl,
                decoration: const InputDecoration(labelText: "الاسم الكامل", border: OutlineInputBorder()),
                validator: (v) => (v == null || v.isEmpty) ? "مطلوب" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "رقم الهاتف", border: OutlineInputBorder()),
                validator: (v) => (v == null || v.isEmpty) ? "مطلوب" : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "الولاية", border: OutlineInputBorder()),
                value: _selectedWilaya,
                items: AppConstants.algeriaWilayas.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                onChanged: (val) => setState(() => _selectedWilaya = val),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressCtl,
                decoration: const InputDecoration(labelText: "العنوان التفصيلي", border: OutlineInputBorder()),
                validator: (v) => (v == null || v.isEmpty) ? "مطلوب" : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "نوع الخدمة", border: OutlineInputBorder()),
                value: _selectedServiceType,
                items: _serviceTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _selectedServiceType = val),
              ),
              const SizedBox(height: 16),
              if (isFuneral) ...[
                TextFormField(
                  controller: _deceasedNameCtl,
                  decoration: const InputDecoration(labelText: "اسم المتوفى", border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.isEmpty) ? "مطلوب" : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pickupLocCtl,
                        decoration: const InputDecoration(labelText: "مكان الاستلام", border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.isEmpty) ? "مطلوب" : null,
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.map), onPressed: () => _pickLocation(true))
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dropoffLocCtl,
                        decoration: const InputDecoration(labelText: "مكان التسليم", border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.isEmpty) ? "مطلوب" : null,
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.map), onPressed: () => _pickLocation(false))
                  ],
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _notesCtl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "ملاحظات إضافية", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
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
