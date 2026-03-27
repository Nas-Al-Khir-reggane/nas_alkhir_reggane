import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/service_request_model.dart';

class GuestSuccessScreen extends StatefulWidget {
  final String refNumber;
  final String phone;

  const GuestSuccessScreen({
    super.key,
    required this.refNumber,
    required this.phone,
  });

  @override
  State<GuestSuccessScreen> createState() => _GuestSuccessScreenState();
}

class _GuestSuccessScreenState extends State<GuestSuccessScreen> {
  final TextEditingController phoneController = TextEditingController();

  bool isTracking = false;

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  void _trackRequest() async {
    if (phoneController.text.isEmpty) {
      Get.snackbar('تنبيه', 'يرجى إدخال رقم الهاتف للتتبع',
          backgroundColor: AppTheme.warningColor.withValues(alpha: 0.2));
      return;
    }

    setState(() => isTracking = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('guest_requests')
          .where('refNumber', isEqualTo: widget.refNumber)
          .where('phone', isEqualTo: phoneController.text)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        Get.snackbar('عذراً', 'لم نتمكن من العثور على طلب بهذا الرقم المرجعي ورقم الهاتف.',
            backgroundColor: AppTheme.warningColor.withValues(alpha: 0.2));
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
          backgroundColor: AppTheme.errorColor.withValues(alpha: 0.2));
    } finally {
      if (mounted) setState(() => isTracking = false);
    }
  }

  void _shareRequestDetails() {
    final String shareText = 'تم إرسال طلبي بنجاح إلى جمعية ناس الخير.\n'
        'رقم الطلب المرجعي: ${widget.refNumber}\n'
        'رقم الهاتف: ${widget.phone}\n'
        'شكراً لجمعية ناس الخير على مجهوداتكم.';
    Share.share(shareText, subject: 'تفاصيل طلب جمعية ناس الخير');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.primaryGreen),
            onPressed: _shareRequestDetails,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // أيقونة نجاح متحركة
              FadeInDown(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.greenGlow,
                  ),
                  child: const Icon(Icons.check, color: Colors.black, size: 50),
                ),
              ),
              const SizedBox(height: 24),
              FadeInUp(
                child: Text('تم إرسال طلبك!',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 8),
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: Text('سيتواصل معك فريقنا في أقرب وقت',
                    style: TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 24),
              
              // الرقم المرجعي
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: Container(
                  width: double.infinity,
                  decoration: AppTheme.glassDecoration,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text('رقم الطلب المرجعي', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 8),
                      Text(widget.refNumber,
                          style: const TextStyle(
                              color: AppTheme.primaryGreen,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2)),
                      const SizedBox(height: 8),
                      Text('احتفظ بهذا الرقم لمتابعة طلبك',
                          style: TextStyle(color: AppTheme.textHint, fontSize: 12), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // متابعة الطلب
              FadeInUp(
                delay: const Duration(milliseconds: 500),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text('تتبع طلبك لاحقاً',
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: AppTheme.inputDecoration('أدخل رقم الهاتف', Icons.phone),
                      ),
                      const SizedBox(height: 12),
                      isTracking
                          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                          : OutlinedButton.icon(
                              onPressed: _trackRequest,
                              icon: const Icon(Icons.search),
                              label: const Text('تتبع طلبي'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryGreen,
                                side: const BorderSide(color: AppTheme.primaryGreen),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              FadeInUp(
                delay: const Duration(milliseconds: 600),
                child: AppTheme.gradientButton(
                  text: 'الصفحة الرئيسية',
                  icon: Icons.home,
                  onPressed: () => Get.offAllNamed('/login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
