import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';
import '../../../data/models/donation_model.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/user_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../screens/donate_screen.dart';

class DonorController extends GetxController {
  RxList<DonationModel> myDonations = <DonationModel>[].obs;
  RxList<ProjectModel> activeProjects = <ProjectModel>[].obs;
  RxBool isLoading = false.obs;
  Rx<UserModel?> currentDonor = Rx<UserModel?>(null);

  // إحصائيات
  RxDouble totalDonated = 0.0.obs;
  RxInt donationsCount = 0.obs;
  RxList<Map<String, dynamic>> donationsByProject = <Map<String, dynamic>>[].obs;

  // اختيار مسبق للمشروع عند الضغط على "تبرع لهذا المشروع"
  RxString preSelectedProjectId = 'general'.obs;
  RxString preSelectedProjectName = 'تبرع عام للجمعية'.obs;

  void preSelectProject(String id, String name) {
    preSelectedProjectId.value = id;
    preSelectedProjectName.value = name;
  }

  @override
  void onInit() {
    super.onInit();
    currentDonor.value = Get.find<AuthController>().currentUser.value;
    loadMyDonations();
    loadActiveProjects();
  }

  void loadMyDonations() {
    if (currentDonor.value == null) return;
    
    FirebaseFirestore.instance
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
    // توليد لون بناءً على معرف المشروع
    final int hash = id.hashCode;
    return Color((hash & 0xFFFFFF) | 0xFF000000).withValues(alpha: 0.8);
  }

  void loadActiveProjects() {
    FirebaseFirestore.instance
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
      final donorName = isAnonymous ? 'متبرع مجهول' : currentDonor.value?.name ?? '';
      final donationData = {
        'donorId': isAnonymous ? 'anonymous' : currentDonor.value?.id,
        'donorName': donorName,
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
      
      // تحديث إجمالي المشروع
      if (projectId != 'general') {
        await FirebaseFirestore.instance.collection('projects').doc(projectId).update({
          'collected': FieldValue.increment(amount),
          'donorsCount': FieldValue.increment(1),
        });
      }
      
      // رسالة شكر
      _showThankYouMessage(donorName, amount, projectName);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في عملية التبرع: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _showThankYouMessage(String name, double amount, String projectName) {
    Get.dialog(
      ThankYouDialog(name: name, amount: amount, projectName: projectName),
    );
  }

  Future<void> generateCertificate() async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      build: (context) => pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('شهادة تقدير', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('تشكر جمعية ناس الخير رقان'),
            pw.Text('السيد/ة ${currentDonor.value?.name}'),
            pw.Text('على تبرعه السخي بمبلغ ${totalDonated.value} دج'),
            pw.Text('جزاكم الله خير الجزاء'),
          ],
        ),
      ),
    ));
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'شهادة_تقدير.pdf');
  }

}
