import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/donation_model.dart';
import '../../../data/models/project_model.dart';

class DonorController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RxList<DonationModel> myDonations = <DonationModel>[].obs;
  RxList<ProjectModel> activeProjects = <ProjectModel>[].obs;

  RxDouble totalDonated = 0.0.obs;
  RxInt donationCount = 0.obs;
  RxMap<String, double> donationsByProject = <String, double>{}.obs;

  void loadMyDonations(String donorId) {
    _firestore
        .collection(AppConstants.donationsCollection)
        .where('donorId', isEqualTo: donorId)
        .snapshots()
        .listen((snap) {
      myDonations.value = snap.docs.map((doc) => DonationModel.fromMap(doc.data())).toList();
      _calculateStats();
    });
  }

  void loadActiveProjects() {
    _firestore
        .collection(AppConstants.projectsCollection)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snap) {
      activeProjects.value = snap.docs.map((doc) => ProjectModel.fromMap(doc.data())).toList();
    });
  }

  void _calculateStats() {
    double total = 0;
    Map<String, double> byProject = {};

    for (var d in myDonations) {
      total += d.amount;
      String pId = d.projectId;
      byProject[pId] = (byProject[pId] ?? 0) + d.amount;
    }

    totalDonated.value = total;
    donationCount.value = myDonations.length;
    donationsByProject.value = byProject;
  }

  Future<void> makeDonation(DonationModel donation) async {
    try {
      await _firestore.collection(AppConstants.donationsCollection).doc(donation.id).set(donation.toMap());
      
      if (donation.projectId != 'general') {
        // Update project collected amount
        await _firestore.collection(AppConstants.projectsCollection).doc(donation.projectId).update({
          'collected': FieldValue.increment(donation.amount),
        });
      }

      Get.snackbar("نجاح", "تم تسجيل التبرع بنجاح، جزاك الله خيراً");
      Get.back();
    } catch (e) {
      Get.snackbar("خطأ", "فشل تسجيل التبرع: ${e.toString()}");
    }
  }
}
