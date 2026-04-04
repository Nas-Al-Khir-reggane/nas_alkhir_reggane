import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_controller.dart';

class FuneralGhuslDetailScreen extends StatefulWidget {
  const FuneralGhuslDetailScreen({super.key});

  @override
  State<FuneralGhuslDetailScreen> createState() => _FuneralGhuslDetailScreenState();
}

class _FuneralGhuslDetailScreenState extends State<FuneralGhuslDetailScreen> {
  final List<Map<String, dynamic>> _ghuslAdab = [
    {'title': 'كتمان ما قد يُرى من الميت (الأمانة)', 'checked': false},
    {'title': 'اتباع السنة النبوية في التغسيل', 'checked': false},
    {'title': 'الرفق بالمتوفى أثناء الغسل', 'checked': false},
    {'title': 'احتساب الأجر والثواب من الله وحده', 'checked': false},
  ];

  bool get _isAllChecked => _ghuslAdab.every((item) => item['checked'] == true);
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final String requestId = args['id'] ?? args['requestId'] ?? '';
    final currentUser = Get.find<AuthController>().currentUser.value;

    return StreamBuilder<DocumentSnapshot>(
      stream: requestId.isNotEmpty 
          ? FirebaseFirestore.instance.collection('service_requests').doc(requestId).snapshots()
          : null,
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String status = data['status'] ?? 'pending';
        final String? assignedTo = data['assignedTo'];
        final bool isAssignedToMe = assignedTo == currentUser?.id;
        final bool isAlreadyTaken = assignedTo != null && assignedTo.isNotEmpty;

        // Data extraction
        final String gender = data['deceasedGender'] ?? data['details']?['جنس المتوفى'] ?? 'غير محدد';
        final String location = data['washingLocation'] ?? data['details']?['مكان الغسل'] ?? 'غير محدد';
        final String supplies = data['details']?['المستلزمات المطلوبة'] ?? 'غير محدد';
        final String phone = data['phone'] ?? data['details']?['رقم هاتف المنسق'] ?? '';

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: CustomScrollView(
            slivers: [
              _buildHeader(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildMainCard(gender, location, supplies, status, isAlreadyTaken),
                      const SizedBox(height: 24),
                      _buildAdabSection(),
                      const SizedBox(height: 32),
                      _buildActionButtons(requestId, phone, isAlreadyTaken, isAssignedToMe),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withValues(alpha: 0.9)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter
            ),
          ),
          child: Center(
            child: FadeInDown(
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 40),
                  Icon(Icons.wash_rounded, color: Colors.white, size: 48),
                  SizedBox(height: 12),
                  Text('إكرام الميت (تغسيل)', 
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Tajawal')),
                ],
              ),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Get.back(),
      ),
    );
  }

  Widget _buildMainCard(String gender, String location, String supplies, String status, bool isAlreadyTaken) {
    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.glassDecoration.copyWith(
          border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.15), width: 1.5)
        ),
        child: Column(
          children: [
            Text('إِنَّا لِلَّٰهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ', 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
            const SizedBox(height: 20),
            _buildInfoRow(Icons.person_pin_rounded, 'جنس المتوفى', gender),
            const Divider(color: AppTheme.glassBorder, height: 24),
            _buildInfoRow(Icons.location_on_rounded, 'مكان الغسل', location),
            const Divider(color: AppTheme.glassBorder, height: 24),
            _buildInfoRow(Icons.inventory_2_rounded, 'المستلزمات', supplies),
            const SizedBox(height: 20),
            _buildStatusBadge(status, isAlreadyTaken),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textHint, size: 20),
        const SizedBox(width: 12),
        Text('$label: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        Expanded(child: Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildStatusBadge(String status, bool isAlreadyTaken) {
    String text = 'الطلب ينتظر متطوع';
    Color color = AppTheme.warningColor;
    if (isAlreadyTaken) {
      text = 'تم قبول المهمة';
      color = AppTheme.primaryGreen;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.15))),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildAdabSection() {
    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ميثاق المتطوع لخدمة التغسيل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...List.generate(_ghuslAdab.length, (index) => CheckboxListTile(
            value: _ghuslAdab[index]['checked'],
            title: Text(_ghuslAdab[index]['title'], style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
            onChanged: (val) => setState(() => _ghuslAdab[index]['checked'] = val),
            activeColor: AppTheme.primaryGreen,
            contentPadding: EdgeInsets.zero,
            dense: true,
          )),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String requestId, String phone, bool isAlreadyTaken, bool isAssignedToMe) {
    if (isAssignedToMe) {
      return Column(
        children: [
          AppTheme.gradientButton(
            text: 'الاتصال بأهل المتوفى',
            icon: Icons.phone_forwarded_rounded,
            onPressed: () => launchUrl(Uri.parse('tel:$phone')),
          ),
          const SizedBox(height: 12),
          Text('جزاك الله خيراً على سعيك لإكرام روح مسلم', 
            style: TextStyle(color: AppTheme.textHint, fontSize: 11, fontStyle: FontStyle.italic)),
        ],
      );
    }

    if (isAlreadyTaken) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(15)),
        child: const Text('نشكر رغبتك في التطوع، المهمة جاري تنفيذها من قبل متطوع آخر.', 
          textAlign: TextAlign.center, style: TextStyle(color: Colors.blue, fontSize: 12)),
      );
    }

    return _isSending 
      ? const CircularProgressIndicator()
      : AppTheme.gradientButton(
          text: 'أنا سأقوم بالتغسيل (قبول)',
          icon: Icons.check_circle_rounded,
          onPressed: _isAllChecked ? () => _acceptTask(requestId) : null,
        );
  }

  void _acceptTask(String requestId) async {
    setState(() => _isSending = true);
    try {
      final currentUser = Get.find<AuthController>().currentUser.value;
      await FirebaseFirestore.instance.collection('service_requests').doc(requestId).update({
        'status': 'in_progress',
        'assignedTo': currentUser?.id,
        'assignedToName': currentUser?.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      Get.snackbar('مباركة', 'تم قبول المهمة، جزاك الله خيراً', backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15));
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في قبول المهمة: $e', backgroundColor: Colors.red.withValues(alpha: 0.15));
    } finally {
      setState(() => _isSending = false);
    }
  }
}

