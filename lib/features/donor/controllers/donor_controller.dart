import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class DonorController extends GetxController {
  RxList<DonationModel> myDonations = <DonationModel>[].obs;
  RxList<ProjectModel> activeProjects = <ProjectModel>[].obs;
  RxBool isLoading = false.obs;
  Rx<UserModel?> currentDonor = Rx<UserModel?>(null);
  
  final ScreenshotController screenshotController = ScreenshotController();

  // إحصائيات
  RxDouble totalDonated = 0.0.obs;
  RxInt donationsCount = 0.obs;
  RxList<Map<String, dynamic>> donationsByProject = <Map<String, dynamic>>[].obs;

  // اختيار مسبق للمشروع
  RxString preSelectedProjectId = 'general'.obs;
  RxString preSelectedProjectName = 'تبرع عام للجمعية'.obs;

  StreamSubscription? _donationsSub;
  StreamSubscription? _projectsSub;

  @override
  void onInit() {
    super.onInit();
    currentDonor.value = Get.find<AuthController>().currentUser.value;
    loadMyDonations();
    loadActiveProjects();
  }

  // دالة لاختيار مشروع مسبقاً
  void preSelectProject(String id, String name) {
    preSelectedProjectId.value = id;
    preSelectedProjectName.value = name;
  }

  // دالة لجلب اسم المتبرع الحالي
  String get donorName => currentDonor.value?.name ?? "متبرع فاعل خير";

  // دالة لعرض الشهادة وتنزيلها
  void showCertificate() {
    if (totalDonated.value <= 0) {
      Get.snackbar('تنبيه', 'يجب أن تساهم في تبرع واحد على الأقل للحصول على شهادة.',
          backgroundColor: AppTheme.warningColor.withValues(alpha: 0.8),
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
    return Color((hash & 0xFFFFFF) | 0xFF000000).withValues(alpha: 0.8);
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
  }) async {
    isLoading.value = true;
    try {
      final dName = isAnonymous ? 'متبرع مجهول' : donorName;
      final donationData = {
        'donorId': isAnonymous ? 'anonymous' : currentDonor.value?.id,
        'donorName': dName,
        'amount': amount,
        'projectId': projectId,
        'projectName': projectName,
        'method': method,
        'isAnonymous': isAnonymous,
        'isRecurring': isRecurring,
        'status': 'pending',
        'notes': notes,
        'date': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('donations').add(donationData);
      
      if (projectId != 'general') {
        await FirebaseFirestore.instance.collection('projects').doc(projectId).update({
          'collected': FieldValue.increment(amount),
          'donorsCount': FieldValue.increment(1),
        });
      }
      
      Get.dialog(
        ThankYouDialog(name: dName, amount: amount, projectName: projectName),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في عملية التبرع: $e');
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    _donationsSub?.cancel();
    _projectsSub?.cancel();
    super.onClose();
  }
}
