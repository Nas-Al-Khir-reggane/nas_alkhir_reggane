import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/service_request_model.dart';

class GuestTrackingScreen extends StatefulWidget {
  const GuestTrackingScreen({super.key});

  @override
  State<GuestTrackingScreen> createState() => _GuestTrackingScreenState();
}

class _GuestTrackingScreenState extends State<GuestTrackingScreen> {
  final TextEditingController refNumberController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  bool isTracking = false;
  String? savedGuestPhone;
  String? savedGuestName;

  @override
  void initState() {
    super.initState();
    _loadGuestData();
  }

  Future<void> _loadGuestData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      savedGuestPhone = prefs.getString('guest_phone');
      savedGuestName = prefs.getString('guest_name');
    });
  }

  @override
  void dispose() {
    refNumberController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void _trackRequest() async {
    final ref = refNumberController.text.trim();
    final phone = phoneController.text.trim().replaceAll(' ', '');

    if (ref.isEmpty || phone.isEmpty) {
      Get.snackbar('تنبيه', 'يرجى إدخال الرقم المرجعي ورقم الهاتف للتتبع',
          backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.2));
      return;
    }

    setState(() => isTracking = true);

    final errorColor = Theme.of(context).colorScheme.error;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('guest_requests')
          .where('refNumber', isEqualTo: ref)
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        Get.snackbar('عذراً', 'لم نتمكن من العثور على طلب بهذا الرقم المرجعي ورقم الهاتف.',
            backgroundColor: errorColor.withValues(alpha: 0.2));
        return;
      }

      final doc = querySnapshot.docs.first;
      final requestData = doc.data();
      requestData['id'] = doc.id;
      requestData['isGuest'] = true;

      final requestModel = ServiceRequestModel.fromMap(requestData);

      Get.toNamed('/beneficiary/request-status', arguments: requestModel);
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء البحث عن الطلب. يرجى المحاولة لاحقاً',
          backgroundColor: errorColor.withValues(alpha: 0.2));
    } finally {
      if (mounted) setState(() => isTracking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('تتبع طلب زائر', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: FadeInUp(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.search, color: Theme.of(context).colorScheme.primary, size: 35),
                  ),
                  const SizedBox(height: 24),
                  Text('تتبع طلبك',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('أدخل رقمك المرجعي ورقم الهاتف لمعرفة حالة طلبك',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5)),
                  const SizedBox(height: 32),
                  
                  TextField(
                    controller: refNumberController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    textCapitalization: TextCapitalization.characters,
                    decoration: AppTheme.inputDecoration('الرقم المرجعي (مثال NAK-123456)', Icons.numbers),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: AppTheme.inputDecoration('رقم الهاتف', Icons.phone),
                  ),
                  const SizedBox(height: 32),
                  
                  isTracking
                      ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                      : AppTheme.gradientButton(
                          text: 'ابحث عن الطلب',
                          icon: Icons.track_changes,
                          onPressed: _trackRequest,
                        ),
                  if (savedGuestPhone != null && savedGuestPhone!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(color: AppTheme.glassBorder),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Get.toNamed(AppRoutes.chatPrivate, arguments: {
                          'chatId': 'guest_$savedGuestPhone',
                          'userName': 'الدعم الفني',
                        });
                      },
                      icon: const Icon(Icons.support_agent, color: AppTheme.primaryGreen),
                      label: const Text('متابعة المحادثة مع الدعم الفني', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        side: const BorderSide(color: AppTheme.primaryGreen),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
