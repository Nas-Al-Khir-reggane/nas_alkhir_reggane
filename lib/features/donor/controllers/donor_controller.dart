import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/donation_model.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/user_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../widgets/donation_certificate_widget.dart';
import '../screens/donate_screen.dart';
import '../../../data/services/firebase_storage_service.dart';
import '../../../data/services/image_compression_service.dart';
import '../../../data/services/notification_service.dart';

class DonorController extends GetxController {
  RxList<DonationModel> myDonations = <DonationModel>[].obs;
  RxList<ProjectModel> activeProjects = <ProjectModel>[].obs;
  RxBool isLoading = false.obs;
  Rx<UserModel?> currentDonor = Rx<UserModel?>(null);
  
  final ScreenshotController screenshotController = ScreenshotController();

  // إحصائيات
  RxDouble totalDonated = 0.0.obs;
  RxInt donationsCount = 0.obs;
  RxInt hizbMembersCount = 0.obs; // ✨ عدد المشتركين في حزب المائة ألف
  RxList<Map<String, dynamic>> donationsByProject = <Map<String, dynamic>>[].obs;

  // إثبات التبرع
  Rx<File?> selectedProofImage = Rx<File?>(null);
  final ImagePicker _picker = ImagePicker();


  // اختيار مسبق للمشروع
  RxString preSelectedProjectId = 'general'.obs;
  RxString preSelectedProjectName = 'تبرع عام للجمعية'.obs;

  StreamSubscription? _donationsSub;
  StreamSubscription? _projectsSub;
  StreamSubscription? _hizbSub;

  @override
  void onInit() {
    super.onInit();
    currentDonor.value = Get.find<AuthController>().currentUser.value;
    loadMyDonations();
    loadActiveProjects();
    
    // شحن مستمع عدد أعضاء الحزب فقط للمسؤولين لتجنب أخطاء الصلاحيات للمتبرعين
    final auth = Get.find<AuthController>();
    if (auth.currentUser.value?.isAdmin == true) {
      _listenToHizbCount();
    }
  }

  void _listenToHizbCount() {
    _hizbSub = FirebaseFirestore.instance
        .collection('users')
        .where('isHizbMember', isEqualTo: true)
        .snapshots()
        .listen((snap) {
      hizbMembersCount.value = snap.docs.length;
    });
  }

  // دالة لاختيار مشروع مسبقاً
  void preSelectProject(String id, String name) {
    preSelectedProjectId.value = id;
    preSelectedProjectName.value = name;
  }

  // دالة لجلب اسم المتبرع الحالي
  String get donorName => currentDonor.value?.name ?? "متبرع فاعل خير";

  // اختيار صورة الإثبات
  Future<void> pickProofImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1200,
      );
      if (pickedFile != null) {
        selectedProofImage.value = File(pickedFile.path);
      }
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في اختيار الصورة: $e');
    }
  }

  void clearProofImage() {
    selectedProofImage.value = null;
  }


  // دالة لعرض الشهادة وتنزيلها
  void showCertificate() {
    if (totalDonated.value <= 0) {
      Get.snackbar('تنبيه', 'يجب أن تساهم في تبرع واحد على الأقل للحصول على شهادة.',
          backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15),
          colorText: Colors.black);
      return;
    }

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // معاينة الشهادة
            Screenshot(
              controller: screenshotController,
              child: DonationCertificateWidget(
                donorName: donorName,
                date: DateFormat('yyyy/MM/dd').format(DateTime.now()),
                amount: totalDonated.value.toString(),
              ),
            ),
            const SizedBox(height: 20),
            // أزرار التحكم
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppTheme.gradientButton(
                  text: 'تحميل الشهادة',
                  icon: Icons.download,
                  onPressed: _downloadCertificate,
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('إغلاق', style: TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // دالة التقاط الصورة وحفظها/مشاركتها
  Future<void> _downloadCertificate() async {
    try {
      final image = await screenshotController.capture();
      if (image != null) {
        final pdf = pw.Document();
        final pdfImage = pw.MemoryImage(image);
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(pdfImage));
          }
        ));
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name: 'Certificate_$donorName.pdf',
        );
      }
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحميل الشهادة: $e');
    }
  }

  void loadMyDonations() {
    if (currentDonor.value == null) return;
    
    _donationsSub = FirebaseFirestore.instance
        .collection('donations')
        .where('donorId', isEqualTo: currentDonor.value?.id)
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snap) {
      myDonations.value = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return DonationModel.fromMap(data);
      }).toList();
      
      totalDonated.value = myDonations.fold(0.0, (acc, d) => acc + d.amount);
      donationsCount.value = myDonations.length;
      _calculateDonationsByProject();
    });
  }

  void _calculateDonationsByProject() {
    final Map<String, Map<String, dynamic>> projectMap = {};
    for (var d in myDonations) {
      if (projectMap.containsKey(d.projectId)) {
        projectMap[d.projectId]!['total'] += d.amount;
      } else {
        projectMap[d.projectId] = {
          'projectId': d.projectId,
          'projectName': d.projectName,
          'total': d.amount,
          'color': _getProjectColor(d.projectId),
        };
      }
    }
    donationsByProject.value = projectMap.values.toList();
  }

  Color _getProjectColor(String id) {
    final int hash = id.hashCode;
    return Color((hash & 0xFFFFFF) | 0xFF000000).withValues(alpha: 0.15);
  }

  void loadActiveProjects() {
    _projectsSub = FirebaseFirestore.instance
        .collection('projects')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snap) {
      activeProjects.value = snap.docs.map((d) => ProjectModel.fromMap(d.data(), d.id)).toList();
    });
  }

  Future<void> makeDonation({
    required String projectId,
    required String projectName,
    required double amount,
    required String method,
    bool isAnonymous = false,
    bool isRecurring = false,
    String? notes,
    bool requestPrayerPost = false,
    String? prayerType,
    String? prayerTarget,
    String? prayerColor,
    String? prayerCustomMessage,
    String? requestId, // ✨ مرتب بطلب خدمة معين (خاص بحزب المائة ألف)
  }) async {
    // ✅ التحقق من صحة المبلغ
    if (amount <= 0) {
      Get.snackbar('خطأ في المبلغ', 'يجب أن يكون المبلغ أكبر من الصفر',
          backgroundColor: AppTheme.errorColor.withValues(alpha: 0.15));
      return;
    }

    // ✅ التحقق من وجود وصل التبرع (إلزامي)
    if (selectedProofImage.value == null) {
      Get.snackbar('وثيقة الإثبات مطلوبة', 'يرجى رفع صورة وصل التبرع لإتمام العملية',
          backgroundColor: Colors.orange.withValues(alpha: 0.15),
          colorText: Colors.black);
      return;
    }

    isLoading.value = true;
    try {
      final dName = isAnonymous ? 'متبرع مجهول' : donorName;
      final normalizedMethod = DonationModel.normalizeMethod(method);
      final donationData = {
        'donorId': currentDonor.value?.id,
        'donorName': dName,
        'amount': amount,
        'projectId': projectId,
        'projectName': projectName,
        'method': normalizedMethod,
        'paymentMethod': normalizedMethod,
        'isAnonymous': isAnonymous,
        'isRecurring': isRecurring,
        'status': 'pending',
        'notes': notes,
        'requestPrayerPost': requestPrayerPost,
        'prayerType': prayerType,
        'prayerTarget': prayerTarget,
        'prayerColor': prayerColor,
        'prayerCustomMessage': prayerCustomMessage,
        'serviceRequestId': requestId, // ✨ حفظ معرف الطلب إن وجد
        'date': FieldValue.serverTimestamp(),
      };

      final donationsRef = FirebaseFirestore.instance.collection('donations');
      final docRef = donationsRef.doc();

      String? proofUrl;

      // رفع الصورة إلى Firebase Storage إذا وجدت
      if (selectedProofImage.value != null) {
        // ضغط الصورة قبل الرفع
        final compressedFile = await ImageCompressionService.compressImage(selectedProofImage.value!);
        final fileName = 'proof_${DateTime.now().millisecondsSinceEpoch}.png';
        proofUrl = await FirebaseStorageService.uploadMedia(
          compressedFile ?? selectedProofImage.value!,
          'donations/${docRef.id}/$fileName',
        );
        
        if (proofUrl != null) {
          donationData['proofImageUrl'] = proofUrl;
        }
      }

      if (projectId != 'general') {
        final projectRef = FirebaseFirestore.instance.collection('projects').doc(projectId);
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final projectSnap = await tx.get(projectRef);
          if (!projectSnap.exists) {
            throw Exception('المشروع غير موجود');
          }

          final projectData = projectSnap.data() as Map<String, dynamic>;
          if (projectData['status'] != 'active') {
            throw Exception('هذا المشروع لم يعد يقبل تبرعات جديدة');
          }

          final currentCollected = (projectData['collected'] ?? 0).toDouble();
          final budget = (projectData['budget'] ?? 0).toDouble();
          final nextCollected = currentCollected + amount;

          final Map<String, dynamic> projectUpdates = {
            'collected': FieldValue.increment(amount),
            'donorsCount': FieldValue.increment(1),
          };

          if (budget > 0 && nextCollected >= budget) {
            projectUpdates['status'] = 'completed';
            projectUpdates['completedAt'] = FieldValue.serverTimestamp();
          }

          tx.set(docRef, donationData);
          tx.update(projectRef, projectUpdates);
        });
      } else {
        await docRef.set(donationData);
      }

      // إرسال الإشعار بشكل غير حاجب حتى ينعكس أثر التبرع بصرياً فوراً.
      unawaited(NotificationService.notifyAllAdmins(
        type: 'new_donation',
        title: '🌱 صدقة جديدة تزهر في بستان الخير',
        body: 'أبشروا! جاد المتصدق $dName بمبلغ $amount د.ج لمشروع $projectName. ﴿وَمَا تُقَدِّمُوا لِأَنْفُسِكُمْ مِنْ خَيْرٍ تَجِدُوهُ عِنْدَ اللَّهِ هُوَ خَيْرًا وَأَعْظَمَ أَجْرًا﴾',
        data: {'donationId': docRef.id, 'projectId': projectId},
      ));

      // تحديث إجمالي التبرعات العالمي (أفضل جهد دون تعطيل تجربة المتبرع).
      unawaited(FirebaseFirestore.instance.collection('stats').doc('global').set({
          'totalDonations': FieldValue.increment(amount),
        }, SetOptions(merge: true)).catchError((error, stackTrace) {
          debugPrint('Global stats update failed: $error');
        }));
      
      Get.dialog(
        ThankYouDialog(name: dName, amount: amount, projectName: projectName),
      );
      
      // مسح الصورة المختارة بعد النجاح
      clearProofImage();
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      Get.snackbar('خطأ', 'فشل في عملية التبرع: $message');
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    _donationsSub?.cancel();
    _projectsSub?.cancel();
    _hizbSub?.cancel();
    super.onClose();
  }
}

