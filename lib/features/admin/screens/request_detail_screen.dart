import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/user_model.dart';
import '../controllers/admin_controller.dart';
import '../widgets/share_emergency_generator.dart';

class RequestDetailScreen extends StatelessWidget {
  final ServiceRequestModel? request; // إعادة الاسم الأصلي ليتوافق مع app_routes
  final AdminController adminController = Get.find<AdminController>();

  RequestDetailScreen({super.key, this.request});

  // الحصول على الطلب من المشيد أو من arguments كخيار بديل
  ServiceRequestModel get displayRequest {
    if (request != null) return request!;
    final args = Get.arguments;
    if (args is ServiceRequestModel) return args;
    if (args is Map<String, dynamic>) return ServiceRequestModel.fromMap(args);
    throw Exception('Invalid request data');
  }

  Future<void> _openAttachment(String attachmentRef) async {
    try {
      final uri = attachmentRef.startsWith('http')
          ? Uri.parse(attachmentRef)
          : Uri.parse(await FirebaseStorage.instance.ref(attachmentRef).getDownloadURL());

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        Get.snackbar('تعذر فتح المرفق', 'تحقق من صلاحيات الوصول أو إعدادات الجهاز');
      }
    } catch (e) {
      Get.snackbar('تعذر فتح المرفق', 'فشل في فتح الملف: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // التأكد من وجود بيانات قبل البدء
    if (Get.arguments == null && request == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(backgroundColor: AppTheme.surfaceColor),
        body: Center(child: Text('خطأ في تحميل بيانات الطلب', style: TextStyle(color: AppTheme.textPrimary))),
      );
    }

    final req = displayRequest;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('تفاصيل الطلب #${req.id.isNotEmpty ? req.id.substring(0, 5) : '...'}', 
          style: const TextStyle(fontFamily: 'Tajawal')),
        backgroundColor: AppTheme.surfaceColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Get.back(),
        ),
        actions: [
          if (req.type == 'blood_donation' || req.typeName.contains('دم'))
            IconButton(
              icon: const Icon(Icons.share_rounded, color: AppTheme.primaryGreen),
              onPressed: () => _onSharePressed(context, req),
              tooltip: 'مشاركة نداء طوارئ',
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection(AppConstants.serviceRequestsCollection).doc(req.id).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
             return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                   _buildStatusCard(req),
                   const SizedBox(height: 16),
                   _buildInfoCard(context, req),
                ],
              ),
            );
          }

          final liveData = snapshot.data!.data() as Map<String, dynamic>;
          final liveReq = ServiceRequestModel.fromMap(liveData, id: snapshot.data!.id);
          final String currentStatus = liveReq.status;
          final String assignedDonorId = (liveData['assignedTo'] ?? '').toString();
          final bool isCovered = assignedDonorId.isNotEmpty;
          final bool isTerminal = currentStatus == 'completed' || currentStatus == 'rejected' || currentStatus == 'cancelled';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(liveReq),
                const SizedBox(height: 16),
                _buildInfoCard(context, liveReq),
                const SizedBox(height: 20),
                if (liveReq.type == 'blood_donation' || liveReq.typeName.contains('دم'))
                  _buildRespondersSection(context, liveReq),
                const SizedBox(height: 24),
                Text('الإجراءات المتاحة', 
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    if (liveReq.type != 'blood_donation' && liveReq.typeName != 'إغاثة بقطرة دم') ...[
                      _buildActionButton(
                        'إسناد لمتطوع',
                        Icons.person_add_alt_1_outlined,
                        AppTheme.primaryGreen,
                        isTerminal ? null : () => _showAssignWorkerDialog(context, liveReq),
                      ),
                      _buildActionButton(
                        'تخصيص سيارة',
                        Icons.directions_car_filled_outlined,
                        AppTheme.goldAccent,
                        isTerminal ? null : () => _showAssignVehicleDialog(context, liveReq),
                      ),
                    ],
                    if (liveReq.type == 'blood_donation' || liveReq.typeName == 'إغاثة بقطرة دم')
                      _buildActionButton(
                        'نداء استغاثة',
                        Icons.campaign_rounded,
                        isCovered || isTerminal ? Colors.grey : AppTheme.errorColor,
                        isCovered || isTerminal ? null : () => _showBloodAlertConfirmation(context, liveReq),
                      ),
                    
                    _buildActionButton(
                      currentStatus == 'completed' ? 'الطلب مكتمل' : 'إتمام الطلب',
                      Icons.check_circle_outline,
                      currentStatus == 'completed' ? Colors.grey : AppTheme.successColor,
                      currentStatus == 'completed' ? null : () {
                        if (liveReq.type == 'blood_donation' || liveReq.typeName.contains('دم')) {
                          _confirmBloodDonationCompletion(liveReq.id);
                        } else {
                          _confirmStatusUpdate(liveReq, 'completed', 'إتمام الطلب', 'هل أنت متأكد من تحديد هذا الطلب كمكتمل؟');
                        }
                      },
                    ),
                    _buildActionButton(
                      'إلغاء الطلب',
                      Icons.highlight_off_rounded,
                      isTerminal ? Colors.grey : AppTheme.errorColor,
                      isTerminal ? null : () => _confirmStatusUpdate(liveReq, 'rejected', 'إلغاء الطلب', 'هل أنت متأكد من إلغاء هذا الطلب؟ سيتم نقله للمرفوضات.'),
                    ),
                    _buildActionButton(
                      'حذف نهائي',
                      Icons.delete_forever_rounded,
                      AppTheme.errorColor,
                      () => _showDeleteConfirmation(liveReq),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _onSharePressed(BuildContext context, ServiceRequestModel req) async {
    // إظهار حوار مبدئي للانتظار
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryGreen),
              const SizedBox(height: 20),
              Text('يتم تجهيز بطاقة المشاركة...', style: TextStyle(fontFamily: 'Tajawal', color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    // توليد واختبار الشير
    await ShareEmergencyGenerator.shareEmergency(req, context);
    
    // غلق حوار الانتظار
    if (Get.isDialogOpen ?? false) Get.back();
  }

  Widget _buildStatusCard(ServiceRequestModel req) {
    Color statusColor = req.status == 'pending' ? AppTheme.warningColor : 
                        (req.status == 'completed' ? AppTheme.successColor : AppTheme.errorColor);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              req.status == 'completed' ? Icons.check_circle : (req.status == 'pending' ? Icons.timer_outlined : Icons.cancel),
              color: statusColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('حالة الطلب', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                Text(
                  req.status == 'pending' ? 'قيد الانتظار' : (req.status == 'in_progress' ? 'جاري التنفيذ' : 'مكتمل/ملغى'),
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          _buildUrgencyBadge(req),
        ],
      ),
    );
  }

  Widget _buildUrgencyBadge(ServiceRequestModel req) {
    Color color = req.urgency == 'emergency' ? AppTheme.errorColor : 
                 (req.urgency == 'urgent' ? AppTheme.warningColor : AppTheme.primaryGreen);
    String label = req.urgency == 'emergency' ? 'طارئ جداً' : 
                  (req.urgency == 'urgent' ? 'مستعجل' : 'عادي');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInfoCard(BuildContext context, ServiceRequestModel req) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration,
      child: Column(
        children: [
          _buildInfoRow(AppConstants.getServiceIcon(req.typeName.isNotEmpty ? req.typeName : req.type), 'نوع الخدمة', 
            AppConstants.translateServiceType(req.typeName.isNotEmpty ? req.typeName : req.type)),
          Divider(color: AppTheme.textHint.withValues(alpha: 0.15)),
          
          StreamBuilder<DocumentSnapshot>(
            stream: (req.requesterId.isNotEmpty)
                ? FirebaseFirestore.instance.collection(AppConstants.usersCollection).doc(req.requesterId).snapshots()
                : null,
            builder: (context, snapshot) {
              // البيانات الافتراضية من الطلب نفسه
              String name = req.requesterName.isNotEmpty ? req.requesterName : '';
              String phone = req.phone.isNotEmpty ? req.phone : '';
              String wilaya = req.wilaya;
              String commune = req.commune;
              String addressDetail = req.address;

              // تحديث البيانات من ملف المستخدم إذا توفرت وكانت البيانات الأساسية ناقصة
              if (snapshot.hasData && snapshot.data!.exists) {
                var userData = snapshot.data!.data() as Map<String, dynamic>;
                if (name.isEmpty) name = userData['name'] ?? '';
                if (phone.isEmpty) phone = userData['phone'] ?? '';
                if (wilaya.isEmpty) wilaya = userData['wilaya'] ?? '';
                if (commune.isEmpty) commune = userData['commune'] ?? '';
                if (addressDetail.isEmpty) addressDetail = userData['address'] ?? '';
              }

              // معالجة حالة "قيد التحميل" فقط إذا لم تكن البيانات متوفرة في الطلب أصلاً
              bool isStillLoading = 
                                  req.requesterId.isNotEmpty && 
                                  snapshot.connectionState == ConnectionState.waiting &&
                                  name.isEmpty;

              if (isStillLoading) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                );
              }

              if (name.isEmpty || name == '(غير متوفر)') {
                name = adminController.currentUser?.name ?? '(غير متوفر)';
              }
              if (phone.isEmpty || phone == '(غير متوفر)') {
                phone = adminController.currentUser?.phone ?? '(غير متوفر)';
              }
              if (wilaya.isEmpty) wilaya = adminController.currentUser?.wilaya ?? '';
              if (commune.isEmpty) commune = adminController.currentUser?.commune ?? '';
              if (addressDetail.isEmpty) addressDetail = adminController.currentUser?.address ?? '';
              
              String fullAddress = '(غير متوفر)';
              List<String> addressParts = [];
              if (wilaya.isNotEmpty && wilaya != 'all') addressParts.add(wilaya);
              if (commune.isNotEmpty && commune != 'all') addressParts.add(commune);
              if (addressDetail.isNotEmpty && addressDetail != '(غير متوفر)') addressParts.add(addressDetail);
              if (addressParts.isNotEmpty) fullAddress = addressParts.join(' - ');

              return Column(
                children: [
                  _buildInfoRow(
                    Icons.person_outline, 
                    'المستفيد', 
                    name, 
                    onTap: () {
                      if (adminController.currentUser?.role == UserRole.superAdmin && req.requesterId.isNotEmpty) {
                        Get.toNamed('/profile', arguments: req.requesterId);
                      }
                    },
                    trailing: phone != '(غير متوفر)' ? IconButton(
                      icon: const Icon(Icons.phone_forwarded, color: AppTheme.primaryGreen, size: 20),
                      onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                    ) : null
                  ),
                  const Divider(color: AppTheme.glassBorder),
                  _buildInfoRow(Icons.phone_outlined, 'رقم الهاتف', phone),
                  const Divider(color: AppTheme.glassBorder),
                  _buildInfoRow(Icons.location_on_outlined, 'العنوان', fullAddress),
                ],
              );
            },
          ),
          
          const Divider(color: Colors.white10),
          _buildInfoRow(Icons.description_outlined, 'الوصف', 
            req.description.isNotEmpty ? req.description : 'لا يوجد وصف إضافي'),

          if (req.type == 'blood_donation' || req.typeName.contains('دم')) ...[
            const Divider(color: Colors.white10),
            _buildInfoRow(Icons.person_outline, 'اسم المريض', req.patientName.isNotEmpty ? req.patientName : (req.requesterName.isNotEmpty ? req.requesterName : 'غير محدد')),
            _buildInfoRow(Icons.bloodtype_outlined, 'الفصيلة المطلوبة', req.bloodType.isNotEmpty ? req.bloodType : 'غير محدد'),
            _buildInfoRow(Icons.local_hospital_outlined, 'المستشفى', req.hospital.isNotEmpty ? req.hospital : 'غير محدد'),
            _buildInfoRow(Icons.phone_outlined, 'رقم التواصل للحالة', req.phone.isNotEmpty ? req.phone : 'غير محدد'),
          ],
          
          if (req.assignedToName != null && req.assignedToName!.isNotEmpty) ...[
            const Divider(color: Colors.white10),
            _buildAssignedWorkerRow(req),
          ],
          
          if (req.details.isNotEmpty) ...[
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            Text('تفاصيل الخدمة الإضافية', style: TextStyle(color: AppTheme.primaryGreen.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...req.details.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildInfoRow(Icons.info_outline, entry.key, entry.value.toString()),
            )),
          ],
          
          if (req.attachments.isNotEmpty) ...[
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            Text('المرفقات', style: TextStyle(color: AppTheme.primaryGreen.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: req.attachments.map((attachmentRef) => InkWell(
                onTap: () => _openAttachment(attachmentRef),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.attachment, size: 16, color: AppTheme.primaryGreen),
                      SizedBox(width: 4),
                      Text('عرض المرفق', style: TextStyle(color: AppTheme.primaryGreen, fontSize: 12)),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
    }

  Widget _buildAssignedWorkerRow(ServiceRequestModel req) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.engineering_outlined, color: AppTheme.primaryGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المتطوع المسند إليه', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    if (adminController.currentUser?.role == UserRole.superAdmin && req.assignedTo != null) {
                      Get.toNamed('/profile', arguments: req.assignedTo);
                    }
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                        child: Text(req.assignedToName!.isNotEmpty ? req.assignedToName![0] : '؟', 
                          style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Text(req.assignedToName!, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Widget? trailing, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primaryGreen.withValues(alpha: 0.15), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontFamily: 'Tajawal')),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            ...?(trailing == null ? null : [trailing]),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback? onTap) {
    bool isDisabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isDisabled ? Colors.white.withValues(alpha: 0.05) : color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDisabled ? Colors.white.withValues(alpha: 0.05) : color.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isDisabled ? Colors.grey : color, size: 26),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, 
                style: TextStyle(color: isDisabled ? Colors.grey : color, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Tajawal')),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmStatusUpdate(ServiceRequestModel req, String status, String title, String message) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontFamily: 'Tajawal')),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            onPressed: () {
              adminController.updateRequestStatus(req.id, status);
              Get.back();
            },
            child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBloodDonationCompletion(String requestId) async {
    final reqSnap = await FirebaseFirestore.instance
        .collection(AppConstants.serviceRequestsCollection)
        .doc(requestId)
        .get();

    if (!reqSnap.exists) {
      Get.snackbar('تعذر إتمام الطلب', 'هذا الطلب غير موجود أو تم حذفه.');
      return;
    }

    final data = reqSnap.data() as Map<String, dynamic>;
    final donorId = (data['assignedTo'] ?? '').toString();
    final donorName = (data['assignedToName'] ?? 'متبرع').toString();

    if (donorId.isEmpty) {
      Get.snackbar('تحذير', 'لا يمكن إتمام طلب الدم دون تعيين متبرع أولاً.');
      return;
    }

    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إتمام التبرع بالدم 🩸', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        content: Text('هل تتأكد من أن المتبرع ($donorName) قد أتم التبرع بنجاح؟\nسيتم إغلاق الطلب وبدء فترة النقاهة الطبية للمتبرع.', style: const TextStyle(fontFamily: 'Tajawal', height: 1.5)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
            onPressed: () {
              adminController.markBloodDonationCompleted(
                requestId: requestId,
                donorId: donorId,
                donorName: donorName,
              );
              Get.back();
            },
            child: const Text('تأكيد التبرع بنجاح', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmUnassignDonor(String requestId, String donorName) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('فك إسناد المتبرع', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        content: Text('هل تريد فك إسناد المتبرع ($donorName) وإعادة الطلب إلى حالة الانتظار؟', style: const TextStyle(fontFamily: 'Tajawal')),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () {
              adminController.unassignConfirmedDonor(requestId: requestId);
              Get.back();
            },
            child: const Text('تأكيد فك الإسناد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(ServiceRequestModel req) {
    Get.defaultDialog(
      title: 'تأكيد الحذف النهائي',
      titleStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
      backgroundColor: AppTheme.surfaceColor,
      radius: 20,
      contentPadding: const EdgeInsets.all(20),
      content: const Text(
        'سيتم حذف هذا الطلب نهائياً من قاعدة البيانات. هل أنت متأكد؟',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Tajawal'),
      ),
      textCancel: 'إلغاء',
      textConfirm: 'حذف الآن',
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.errorColor,
      onConfirm: () async {
        Get.back(); // إغلاق الدايالوج
        await adminController.deleteRequest(req.id);
        Get.back(); // العودة للشاشة السابقة
      },
      onCancel: () => Get.back(),
    );
  }

  void _showAssignWorkerDialog(BuildContext context, ServiceRequestModel req) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('إسناد الطلب لمتطوع', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Flexible(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(AppConstants.usersCollection)
                    .where('role', isEqualTo: 'worker')
                    .where('isApproved', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  if (snapshot.data!.docs.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text('لا يوجد عمال متاحون حالياً'));
                  
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var worker = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                          child: Text(worker['name'] != null ? worker['name'][0] : '؟', style: const TextStyle(color: AppTheme.primaryGreen)),
                        ),
                        title: Text(worker['name'] ?? 'بدون اسم', 
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                          (worker['volunteerServices'] as List<dynamic>?)?.join(' - ') ?? 'لا يوجد تخصص محدد',
                          style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.phone_forwarded_rounded, color: AppTheme.primaryGreen, size: 20),
                          onPressed: () {
                            final phone = worker['phone'];
                            if (phone != null && phone.toString().isNotEmpty) {
                              launchUrl(Uri.parse('tel:$phone'));
                            } else {
                              Get.snackbar('غير متوفر', 'لا يوجد رقم هاتف متاح لهذا المتطوع');
                            }
                          },
                        ),
                        onTap: () {
                          adminController.assignToWorker(req.id, snapshot.data!.docs[index].id, workerName: worker['name']);
                          Get.back();
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showAssignVehicleDialog(BuildContext context, ServiceRequestModel req) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('تخصيص سيارة للجنازة', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Flexible(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(AppConstants.vehiclesCollection)
                    .where('isAvailable', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  if (snapshot.data!.docs.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text('لا توجد سيارات متاحة حالياً'));
                  
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var vehicle = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.airport_shuttle, color: AppTheme.primaryGreen),
                        title: Text('${vehicle['brand'] ?? ''} - ${vehicle['model'] ?? ''}', style: TextStyle(color: AppTheme.textPrimary)),
                        subtitle: Text(vehicle['plateNumber'] ?? '', style: TextStyle(color: AppTheme.textSecondary)),
                        onTap: () {
                          adminController.assignToVehicle(req.id, snapshot.data!.docs[index].id);
                          Get.back();
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBloodAlertConfirmation(BuildContext context, ServiceRequestModel req) {
    final bloodType = req.bloodType.isNotEmpty
      ? req.bloodType
      : (req.details['الفصيلة'] ?? req.details['فصيلة الدم'] ?? req.details['bloodType'] ?? 'غير محدد').toString();
    final hospital = req.hospital.isNotEmpty
      ? req.hospital
      : (req.details['المستشفى'] ?? req.details['hospital'] ?? req.details['deliveryLocation'] ?? 'غير محدد').toString();
    final phone = req.phone.isNotEmpty
      ? req.phone
      : (req.details['رقم الهاتف'] ?? req.details['رقم التواصل'] ?? req.details['phone'] ?? 'غير متوفر').toString();
    final patientName = req.patientName.isNotEmpty
      ? req.patientName
      : (req.details['اسم المريض'] ?? req.requesterName).toString();
    
    // محاولة إيجاد الولاية المطابقة في الثوابت لتحديدها تلقائياً
    String? matchedWilaya = AppConstants.algeriaWilayas.firstWhere(
      (w) => w.contains(req.wilaya) || req.wilaya.contains(w.contains(' - ') ? w.split(' - ')[1] : w),
      orElse: () => 'all',
    );
    
    // إذا لم تكن الولاية 'all'، نحاول مطابقة البلدية أيضاً
    String? matchedCommune = 'all';
    if (matchedWilaya != 'all') {
      final communes = AppConstants.getCommunesForWilaya(matchedWilaya);
      matchedCommune = communes.firstWhere(
        (c) => c == req.commune || req.commune.contains(c),
        orElse: () => 'all',
      );
    }

    String? selectedWilaya = matchedWilaya;
    String? selectedCommune = matchedCommune;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.campaign_rounded, color: AppTheme.errorColor),
                const SizedBox(width: 8),
                const Text('إرسال نداء استغاثة عاجل', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('سيتم إرسال إشعار للمتبرعين المتوافقين مع فصيلة ($bloodType) لحالة: $patientName.', 
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  const Text('نطاق الاستهداف الجغرافي:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryGreen)),
                  const SizedBox(height: 12),
                  
                  // Dropdown للولاية
                  DropdownButtonFormField<String>(
                    initialValue: selectedWilaya,
                    dropdownColor: AppTheme.surfaceColor,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: AppTheme.inputDecoration('الولاية', Icons.location_on_outlined),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('جميع الولايات')),
                      ...AppConstants.algeriaWilayas.map((w) => DropdownMenuItem(value: w, child: Text(w))),
                    ],
                    onChanged: (val) {
                      setStateDialog(() {
                        selectedWilaya = val;
                        selectedCommune = 'all';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Dropdown للبلدية
                  if (selectedWilaya != null && selectedWilaya != 'all')
                    DropdownButtonFormField<String>(
                      initialValue: selectedCommune,
                      dropdownColor: AppTheme.surfaceColor,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: AppTheme.inputDecoration('البلدية', Icons.map_outlined),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('جميع بلديات الولاية')),
                        ...AppConstants.getCommunesForWilaya(selectedWilaya!).map((c) => DropdownMenuItem(value: c, child: Text(c))),
                      ],
                      onChanged: (val) => setStateDialog(() => selectedCommune = val),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text('تراجع')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Get.back();
                    adminController.sendTargetedBloodAlert(
                      bloodType: bloodType.toString(),
                      requestId: req.id,
                      hospital: hospital.toString(),
                      phone: phone.toString(),
                      targetWilaya: selectedWilaya == 'all' ? null : selectedWilaya,
                      targetCommune: selectedCommune == 'all' ? null : selectedCommune,
                    );
                },
                child: const Text('إرسال النداء', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }
  Widget _buildRespondersSection(BuildContext context, ServiceRequestModel req) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.serviceRequestsCollection)
          .doc(req.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final List<dynamic> responses = data['donorResponses'] ?? [];
        final String assignedDonorId = (data['assignedTo'] ?? '').toString();
        final String assignedDonorName = (data['assignedToName'] ?? '').toString();
        final String requestStatus = (data['status'] ?? '').toString();
        final bool isTerminal = requestStatus == 'completed' || requestStatus == 'rejected' || requestStatus == 'cancelled';

        if (responses.isEmpty && assignedDonorId.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (assignedDonorId.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: AppTheme.primaryGreen, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        assignedDonorName.isNotEmpty
                            ? 'المتبرع المعتمد حالياً: $assignedDonorName'
                            : 'تم اعتماد متبرع لهذه الحالة',
                        style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    if (!isTerminal)
                      IconButton(
                        icon: const Icon(Icons.person_remove_alt_1_rounded, color: AppTheme.errorColor),
                        tooltip: 'فك إسناد المتبرع',
                        onPressed: () => _confirmUnassignDonor(
                          req.id,
                          assignedDonorName.isNotEmpty ? assignedDonorName : 'المتبرع الحالي',
                        ),
                      ),
                  ],
                ),
              ),
            if (responses.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.volunteer_activism, color: AppTheme.errorColor, size: 20),
                  const SizedBox(width: 8),
                  Text('المتبرعون المستجيبون (${responses.length})',
                      style: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const Divider(color: Colors.white10, height: 20),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: responses.length,
                separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 16),
                itemBuilder: (context, index) {
                  final res = responses[index] as Map<String, dynamic>;
                  final name = (res['userName'] ?? 'متبرع').toString();
                  final phone = (res['userPhone'] ?? '').toString();
                  final userId = (res['userId'] ?? '').toString();
                  final dynamic respondedAt = res['respondedAt'];
                  final time = respondedAt is Timestamp ? respondedAt.toDate() : DateTime.now();
                  final isAssigned = assignedDonorId.isNotEmpty && assignedDonorId == userId;

                  return GestureDetector(
                    onTap: () {
                      if (adminController.currentUser?.role == UserRole.superAdmin) {
                        Get.toNamed('/profile', arguments: userId);
                      }
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: AppTheme.errorColor.withValues(alpha: 0.15),
                          child: Text(name[0], style: const TextStyle(color: AppTheme.errorColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                              Text(intl.DateFormat('HH:mm - yyyy/MM/dd').format(time),
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                            ],
                          ),
                        ),
                        if (phone.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.phone_outlined, color: AppTheme.primaryGreen, size: 18),
                            onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                          ),
                        const SizedBox(width: 4),
                        if (isAssigned)
                          const Icon(Icons.verified_user_rounded, color: AppTheme.primaryGreen, size: 24)
                        else if (!isTerminal)
                          IconButton(
                            icon: Icon(
                              Icons.check_circle_rounded, 
                              color: assignedDonorId.isNotEmpty ? Colors.grey : AppTheme.primaryGreen
                            ),
                            tooltip: assignedDonorId.isNotEmpty ? 'تم تأمين متبرع مسبقاً' : 'تأكيد هذا المتبرع',
                            onPressed: assignedDonorId.isNotEmpty ? null : () {
                              Get.defaultDialog(
                                title: 'تأكيد المتبرع',
                                middleText: 'هل تريد إسناد هذه المهمة للمتبرع ($name) وتنبيهه؟',
                                textCancel: 'تراجع',
                                textConfirm: 'تأكيد',
                                confirmTextColor: Colors.white,
                                onConfirm: () {
                                  adminController.confirmDonor(
                                    requestId: req.id,
                                    donorId: userId,
                                    donorName: name,
                                  );
                                  Get.back();
                                },
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

