import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/services/notification_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../admin/controllers/admin_controller.dart';
import '../../../data/models/user_model.dart';

class BloodEmergencyDetailScreen extends StatefulWidget {
  const BloodEmergencyDetailScreen({super.key});

  @override
  State<BloodEmergencyDetailScreen> createState() => _BloodEmergencyDetailScreenState();
}

class _BloodEmergencyDetailScreenState extends State<BloodEmergencyDetailScreen> {
  final List<Map<String, dynamic>> _checklist = [
    {'title': 'تناولت وجبة غذائية جيدة', 'checked': false},
    {'title': 'شربت كمية كافية من السوائل', 'checked': false},
    {'title': 'أشعر بجاهزية بدنية تامة', 'checked': false},
  ];

  bool get _isAllChecked => _checklist.every((item) => item['checked'] == true);
  
  // ✨ متغيرات حالة محلية للتحديث الفوري في الواجهة
  bool _hasResponded = false;
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    String bloodType = args['bloodType'] ?? 'غير محدد';
    String hospital = args['hospital'] ?? 'غير محدد';
    final String requestId = args['requestId'] ?? '';
    String phone = args['phone'] ?? '';
    final String collection = AppConstants.serviceRequestsCollection;
    final currentUser = Get.find<AuthController>().currentUser.value;
    final dynamic isGuestArg = args['isGuest'];
    final bool isGuest = isGuestArg is bool
      ? isGuestArg
      : (isGuestArg?.toString().toLowerCase() == 'true');

    return StreamBuilder<DocumentSnapshot>(
      stream: requestId.isNotEmpty 
          ? FirebaseFirestore.instance.collection(collection).doc(requestId).snapshots()
          : null,
      builder: (context, snapshot) {
        bool isAssignedToMe = false;
        bool isAlreadyRespondedByMe = _hasResponded; // ✨ نستخدم المتغير المحلي أولاً
        bool isEmergencyCovered = false;
        int responderCount = 0;
        bool isCompleted = false;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String? assignedTo = data['assignedTo'];
          final List<dynamic> responses = data['donorResponses'] ?? [];
          
          responderCount = responses.length;
          isEmergencyCovered = assignedTo != null && assignedTo.isNotEmpty;
          isAssignedToMe = assignedTo == currentUser?.id;
          isCompleted = data['status'] == 'completed';
          
          // ✨ نتحقق من Firestore أيضاً لدعم حالة إعادة فتح الشاشة
          final bool firestoreResponded = responses.any((r) => r['userId'] == currentUser?.id);
          if (firestoreResponded) isAlreadyRespondedByMe = true;

          // ✨ تحديث المتغيرات لتغطية نقص البيانات القادمة من الواجهات السابقة
          final String? dbBloodType = data['bloodType'] ?? data['details']?['الفصيلة'] ?? data['details']?['bloodType'];
          if (dbBloodType != null && dbBloodType.isNotEmpty) bloodType = dbBloodType;

          final String? dbHospital = data['hospital'] ?? data['details']?['المستشفى'] ?? data['details']?['hospital'] ?? data['deliveryLocation'] ?? data['details']?['deliveryLocation'];
          if (dbHospital != null && dbHospital.isNotEmpty) hospital = dbHospital;

          final String? dbPhone = data['phone'] ?? data['details']?['phone'];
          if (dbPhone != null && dbPhone.isNotEmpty) phone = dbPhone;
        }

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.errorColor.withValues(alpha: 0.15),
                        AppTheme.backgroundColor,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
              
              SafeArea(
                child: Column(
                  children: [
                    _buildAppBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // ✨ أيقونة ورسالة الحالة تتغير بناءً على الاستجابة
                            FadeInDown(
                              child: Icon(
                                isAlreadyRespondedByMe 
                                  ? Icons.favorite_rounded 
                                  : Icons.emergency_share,
                                color: isAlreadyRespondedByMe 
                                  ? AppTheme.successColor 
                                  : AppTheme.errorColor, 
                                size: 80,
                                shadows: [
                                  Shadow(
                                    color: (isAlreadyRespondedByMe ? AppTheme.successColor : AppTheme.errorColor).withValues(alpha: 0.15),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            FadeInDown(
                              delay: const Duration(milliseconds: 200),
                              child: Text(
                                isCompleted
                                  ? 'اكتمل التبرع بنجاح 🩸'
                                  : isAlreadyRespondedByMe 
                                    ? 'أنت في طريقك لإنقاذ حياة 🚑' 
                                    : 'نداء استغاثة عاجل',
                                style: GoogleFonts.tajawal(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted || isAlreadyRespondedByMe 
                                    ? AppTheme.successColor 
                                    : AppTheme.errorColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FadeInDown(
                              delay: const Duration(milliseconds: 300),
                              child: Text(
                                isCompleted
                                  ? 'نشكرك على إنقاذ الأرواح، ستبدأ الآن فترة النقاهة الخاصة بك'
                                  : isAlreadyRespondedByMe 
                                    ? 'بارك الله فيك، جزاك الله خير الجزاء'
                                    : 'حياة شخص ما تعتمد على مبادرتك',
                                style: GoogleFonts.tajawal(
                                  fontSize: 16,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            _buildStatusBanner(isEmergencyCovered, isAssignedToMe, isAlreadyRespondedByMe, responderCount, isCompleted),
                            
                            if ((currentUser?.role == UserRole.superAdmin || currentUser?.role == UserRole.admin) && !isCompleted) ...[
                              const SizedBox(height: 16),
                              _buildAdminDonorsButton(bloodType, requestId, isEmergencyCovered),
                            ],
                            
                            const SizedBox(height: 16),
                            _buildImpactCard(isAlreadyRespondedByMe, responderCount),
                            const SizedBox(height: 24),

                            _buildInfoCard(
                              icon: Icons.bloodtype,
                              label: 'الفصيلة المطلوبة',
                              value: bloodType,
                              color: AppTheme.errorColor,
                            ),
                            const SizedBox(height: 16),
                            _buildInfoCard(
                              icon: Icons.local_hospital,
                              label: 'المستشفى / الموقع',
                              value: hospital,
                              color: AppTheme.primaryGreen,
                            ),

                            const SizedBox(height: 32),
                            
                            if (!isAlreadyRespondedByMe && !isCompleted) ...[
                              _buildMedicalChecklist(),
                              const SizedBox(height: 32),
                            ],
                            
                            if (isAlreadyRespondedByMe && !isCompleted) ...[
                              _buildRespondedCard(hospital),
                              const SizedBox(height: 24),
                            ],

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                    
                    if (!isCompleted)
                      _buildBottomActions(requestId, phone, bloodType, hospital, isEmergencyCovered, isAlreadyRespondedByMe, isGuest, currentUser?.id, snapshot.hasData ? (snapshot.data!.data() as Map<String, dynamic>)['assignedTo'] : null),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  // ✨ بطاقة تظهر بعد الاستجابة مع أزرار مساعدة
  Widget _buildRespondedCard(String hospital) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تم تسجيل استجابتك',
                  style: GoogleFonts.tajawal(color: AppTheme.successColor, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'الإدارة على علم بتوجهك. يمكنك الاتصال للحصول على إرشادات إضافية أو فتح خريطة الوصول للمستشفى.',
            style: GoogleFonts.tajawal(color: AppTheme.textSecondary, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(bool isCovered, bool isMe, bool isResponded, int count, bool isCompleted) {
    if (isCompleted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(color: AppTheme.successColor, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('تقبل الله منك! تمت عملية التبرع بنجاح.', style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
          ],
        ),
      );
    }
    if (isMe) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(color: AppTheme.successColor, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.verified, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('لقد تم اختيارك رسمياً لهذه المهمة. بارك الله فيك!', style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
          ],
        ),
      );
    }

    if (isResponded && !isCovered) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryGreen),
        ),
        child: Row(
          children: [
            const Icon(Icons.directions_run_rounded, color: AppTheme.primaryGreen),
            const SizedBox(width: 12),
            Expanded(child: Text('أنت قيد محاولة الإنقاذ الآن 🚑 - الإدارة تتابع وضعك.', style: GoogleFonts.tajawal(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 13))),
          ],
        ),
      );
    }
    
    if (isCovered) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primaryGreen)),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppTheme.primaryGreen),
            const SizedBox(width: 12),
            Expanded(child: Text('تم تأمين المتبرع لهذا النداء بنجاح. شكراً لروحك الطيبة.', style: GoogleFonts.tajawal(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 13))),
          ],
        ),
      );
    }

    if (count > 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(color: AppTheme.goldAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.goldAccent)),
        child: Row(
          children: [
            const Icon(Icons.info, color: AppTheme.goldAccent),
            const SizedBox(width: 12),
            Expanded(child: Text('هناك $count متبرع استجابوا لهذا النداء وهم الآن قيد التواصل.', style: GoogleFonts.tajawal(color: AppTheme.goldAccent, fontWeight: FontWeight.bold, fontSize: 13))),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildImpactCard(bool isResponded, int responderCount) {
    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (isResponded ? AppTheme.successColor : AppTheme.errorColor).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: (isResponded ? AppTheme.successColor : AppTheme.errorColor).withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(
              isResponded ? Icons.volunteer_activism_rounded : Icons.group_outlined, 
              color: isResponded ? AppTheme.successColor : AppTheme.errorColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isResponded
                  ? 'شكراً لك! إدارة الجمعية ستتواصل معك لتأكيد التفاصيل.'
                  : (responderCount == 0 
                    ? 'تم إرسال هذا النداء إلى جميع المتبرعين المتوافقين في منطقتك. كن أول المستجيبين!'
                    : 'تم إرسال النداء للمتبرعين. باب الخير لا يزال مفتوحاً حتى تأكيد الاستجابة.'),
                style: GoogleFonts.tajawal(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close, color: AppTheme.textPrimary),
            onPressed: () => Get.back(),
          ),
          const Spacer(),
          Text('تفاصيل الطوارئ', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration.copyWith(
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.tajawal(color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.tajawal(
                  color: AppTheme.textPrimary, 
                  fontSize: 20, 
                  fontWeight: FontWeight.bold
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalChecklist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text('قائمة الجاهزية الطبية', 
            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ),
        Container(
          decoration: AppTheme.glassDecoration,
          child: Column(
            children: _checklist.map((item) {
              return CheckboxListTile(
                value: item['checked'],
                onChanged: (val) => setState(() => item['checked'] = val),
                title: Text(item['title'], style: GoogleFonts.tajawal(fontSize: 14)),
                activeColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(String requestId, String phone, String bloodType, String hospital, bool isCovered, bool isResponded, bool isGuest, String? userId, String? assignedTo) {
    bool showComingButton = !isCovered && !isResponded;
    final user = Get.find<AuthController>().currentUser.value;
    final bool canDonate = user?.canDonateBloodSmart ?? true;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, -5))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCovered && (userId == assignedTo || user?.role == UserRole.superAdmin || user?.role == UserRole.admin)) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : () async {
                  setState(() => _isSending = true);
                  await Get.find<AdminController>().updateRequestStatus(requestId, 'completed');
                  setState(() => _isSending = false);
                },
                icon: const Icon(Icons.verified, color: Colors.white),
                label: Text(
                  _isSending ? 'جاري التأكيد...' : 'تأكيد إتمام التبرع',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (showComingButton)
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      if (!canDonate) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'أنت حالياً في فترة الاستراحة الطبية. يمكنك المحاولة مجدداً بعد انتهاء الفترة المحددة لسلامتك.',
                                  style: GoogleFonts.tajawal(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (canDonate && _isAllChecked && !_isSending)
                            ? () => _notifyAdminComing(requestId, bloodType, hospital, isGuest)
                            : null,
                          icon: _isSending 
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline, color: Colors.white),
                          label: Text(
                            _isSending ? 'جاري الإرسال...' : (canDonate ? 'أنا قادم للمساعدة' : 'غير متاح للتبرع حالياً'), 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (canDonate && _isAllChecked) ? AppTheme.primaryGreen : Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else if (isResponded)
            Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.favorite, color: AppTheme.successColor, size: 20),
                        const SizedBox(width: 8),
                        Text('تم تسجيل استجابتك للحالة بنجاح', style: GoogleFonts.tajawal(color: AppTheme.successColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                if (!isCovered) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSending ? null : () => _withdrawMyResponse(requestId),
                      icon: const Icon(Icons.cancel_outlined, color: AppTheme.errorColor),
                      label: Text(
                        _isSending ? 'جاري المعالجة...' : 'إلغاء الاستجابة',
                        style: GoogleFonts.tajawal(color: AppTheme.errorColor, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                  icon: const Icon(Icons.phone),
                  label: const Text('اتصال بصاحب الطلب'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openMaps(hospital),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('فتح الخريطة'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _notifyAdminComing(String requestId, String bloodType, String hospital, bool isGuest) async {
    final user = Get.find<AuthController>().currentUser.value;
    if (user == null) return;

    // ✨ تحديث الواجهة فوراً قبل انتظار Firestore
    setState(() {
      _hasResponded = true;
      _isSending = true;
    });

    try {
      if (requestId.isEmpty || requestId == 'null') {
         Get.snackbar('تحذير ⚠️', 'معرف الطلب غير صحيح، يرجى إعادة فتح الإشعار أو التواصل مع الإدارة');
         setState(() { _hasResponded = false; _isSending = false; });
         return;
      }

      await Get.find<AdminController>().respondToBloodAlert(
        requestId: requestId,
        donorName: user.name,
        donorPhone: user.phone,
      );

      // إشعار الإدارة
      await NotificationService.notifyAllAdmins(
        type: 'donor_responding',
        title: '🚑 سباق مع الزمن.. متبرع في الطريق!',
        body: 'المحسن ${user.name} أكد استعداده وهو في طريقه الآن لتوفير فصيلة $bloodType في $hospital. نسأل الله له التوفيق والقبول.',
        data: {
          'requestId': requestId,
          'donorName': user.name,
          'donorPhone': user.phone,
        }
      );

      // ✨ إشعار تشجيعي للمتبرعين الآخرين
      Get.find<AdminController>().notifyOtherDonors(
        requestId: requestId,
        bloodType: bloodType,
        hospital: hospital,
        respondingDonorId: user.id,
      );
      
      Get.snackbar(
        'بارك الله فيك ✅', 
        'تم إبلاغ الإدارة بتوجهك للمساعدة. جزاك الله خيراً.',
        backgroundColor: AppTheme.successColor.withValues(alpha: 0.15),
        colorText: AppTheme.successColor,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('❌ RespondToBloodAlert Error: $e');
      // ✨ إعادة الواجهة لحالتها إذا فشلت العملية
      setState(() { _hasResponded = false; });
      String errorMessage = 'فشل إرسال التأكيد، يرجى المحاولة لاحقاً';
      final lower = e.toString().toLowerCase();
      if (lower.contains('permission-denied')) {
        errorMessage = 'عذراً، لا تملك صلاحية تحديث هذا الطلب. يرجى الاتصال بالإدارة هاتفياً.';
      } else if (lower.contains('request-closed')) {
        errorMessage = 'تم إغلاق هذا الطلب بالفعل، ونشكرك على مبادرتك الكريمة.';
      } else if (lower.contains('already-assigned')) {
        errorMessage = 'تم اعتماد متبرع لهذه الحالة بالفعل. يمكنك متابعة نداءات أخرى.';
      } else if (lower.contains('request-not-found')) {
        errorMessage = 'الطلب غير موجود أو تم حذفه.';
      }
      Get.snackbar('خطأ', errorMessage);
    } finally {
      setState(() { _isSending = false; });
    }
  }

  Future<void> _withdrawMyResponse(String requestId) async {
    if (requestId.isEmpty || requestId == 'null') {
      Get.snackbar('تعذر الإلغاء', 'معرف الطلب غير صالح.');
      return;
    }

    final user = Get.find<AuthController>().currentUser.value;
    setState(() => _isSending = true);
    try {
      await Get.find<AdminController>().withdrawBloodResponse(requestId: requestId);

      if (user != null) {
        await NotificationService.notifyAllAdmins(
          type: 'donor_response_withdrawn',
          title: 'تنبيه متابعة طوارئ الدم',
          body: 'المتبرع ${user.name} ألغى استجابته للحالة، يرجى متابعة إعادة تأمين متبرع بديل سريعاً.',
          data: {
            'requestId': requestId,
            'donorName': user.name,
          },
        );
      }

      if (!mounted) return;
      setState(() {
        _hasResponded = false;
      });
      Get.snackbar(
        'تم الإلغاء',
        'تم إلغاء استجابتك وإعادة فتح الفرصة لبقية المتبرعين.',
        backgroundColor: Colors.orange.withValues(alpha: 0.15),
        colorText: Colors.orange.shade800,
      );
    } catch (e) {
      String errorMessage = 'تعذر إلغاء الاستجابة حالياً. يرجى المحاولة مرة أخرى.';
      final lower = e.toString().toLowerCase();
      if (lower.contains('assigned-donor-cannot-withdraw')) {
        errorMessage = 'لا يمكن إلغاء الاستجابة بعد اعتمادك رسمياً. يرجى التواصل مع الإدارة مباشرة.';
      } else if (lower.contains('request-closed')) {
        errorMessage = 'تم إغلاق هذا الطلب بالفعل.';
      } else if (lower.contains('request-not-found')) {
        errorMessage = 'الطلب غير موجود أو تم حذفه.';
      }
      Get.snackbar('تعذر الإلغاء', errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _openMaps(String query) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Widget _buildAdminDonorsButton(String bloodType, String requestId, bool isCovered) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showAvailableDonorsSheet(bloodType, requestId, isCovered),
        icon: const Icon(Icons.search, color: Colors.white),
        label: const Text('بحث عن المتبرعين المتاحين', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  void _showAvailableDonorsSheet(String bloodType, String requestId, bool isCovered) {
    Get.bottomSheet(
      DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('المتبرعون المتاحون (زمرة $bloodType)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Tajawal')),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'donor')
                        .where('isActive', isEqualTo: true)
                        .where('bloodType', isEqualTo: bloodType)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      final allDonors = snapshot.data!.docs
                          .map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                          .toList();
                      
                      final availableDonors = allDonors.where((d) => d.canDonateBloodSmart).toList();
                      
                      if (availableDonors.isEmpty) {
                        return Center(child: Text('لا يوجد متبرعون متاحون لهذه الزمرة حالياً', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: 'Tajawal')));
                      }

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: availableDonors.length,
                        itemBuilder: (context, index) {
                          final donor = availableDonors[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.errorColor.withValues(alpha: 0.15),
                                child: Text(donor.bloodType ?? '?', style: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(donor.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                              subtitle: Text(donor.wilaya, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.chat_bubble, color: Theme.of(context).colorScheme.primary),
                                    onPressed: () => Get.toNamed('/chat/private', arguments: {'userId': donor.id, 'userName': donor.name}),
                                  ),
                                  IconButton(
                                      icon: const Icon(Icons.call, color: AppTheme.primaryGreen),
                                      onPressed: () => launchUrl(Uri.parse('tel:${donor.phone}')),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.assignment_turned_in, 
                                        color: isCovered ? Colors.grey : AppTheme.primaryGreen
                                      ),
                                      tooltip: isCovered ? 'تم إسناد متبرع بالفعل' : 'إسناد مباشر وتأكيد',
                                      onPressed: isCovered ? null : () async {
                                        Get.back();
                                        await Get.find<AdminController>().forceAssignDonor(
                                          requestId: requestId,
                                          donorId: donor.id,
                                          donorName: donor.name,
                                          donorPhone: donor.phone,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }
}

