import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/donation_model.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/worker_update_model.dart';
import '../../../data/models/user_model.dart';
import '../../auth/controllers/auth_controller.dart';

class AdminController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authController = Get.find<AuthController>();

  UserModel? get currentUser => _authController.currentUser.value;

  // البيانات الحية
  RxInt totalDonations = 0.obs;
  RxInt pendingRequests = 0.obs;
  RxInt activeProjects = 0.obs;
  RxInt availableWorkers = 0.obs;
  RxInt availableVehicles = 0.obs;
  RxInt totalBeneficiaries = 0.obs;
  RxBool isLoading = false.obs;

  // قوائم حية
  RxList<ServiceRequestModel> recentRequests = <ServiceRequestModel>[].obs;
  RxList<ServiceRequestModel> urgentRequests = <ServiceRequestModel>[].obs;
  RxList<DonationModel> recentDonations = <DonationModel>[].obs;
  RxList<ProjectModel> activeProjectsList = <ProjectModel>[].obs;
  RxList<WorkerUpdate> fieldUpdates = <WorkerUpdate>[].obs;

  // بيانات الرسوم البيانية
  RxList<Map<String, dynamic>> monthlyRequests = <Map<String, dynamic>>[].obs;
  RxList<Map<String, dynamic>> donationsLastSixMonths = <Map<String, dynamic>>[].obs;
  RxList<Map<String, dynamic>> serviceTypeDistribution = <Map<String, dynamic>>[].obs;
  RxList<Map<String, dynamic>> completedVsPending = <Map<String, dynamic>>[].obs;

  StreamSubscription? _urgentRequestsSub;

  @override
  void onInit() {
    super.onInit();
    loadDashboardData();
    listenToUrgentRequests();
  }

  @override
  void onClose() {
    _urgentRequestsSub?.cancel();
    super.onClose();
  }

  // تحميل كل بيانات الداشبورد
  Future<void> loadDashboardData() async {
    isLoading.value = true;
    try {
      await Future.wait([
        loadStats(),
        loadRecentRequests(),
        loadRecentDonations(),
        loadActiveProjects(),
        loadFieldUpdates(),
        loadChartData(),
      ]);
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Stream للطلبات الطارئة فوراً
  void listenToUrgentRequests() {
    _urgentRequestsSub = _firestore
        .collection('service_requests')
        .where('urgency', whereIn: ['urgent', 'emergency'])
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      urgentRequests.value = snap.docs.map((d) => ServiceRequestModel.fromMap({...d.data(), 'id': d.id})).toList();
    });
  }

  // إحصائيات
  Future<void> loadStats() async {
    try {
      // إجمالي التبرعات من Firestore
      var donationsSnap = await _firestore.collection('donations').get();
      double total = 0;
      for (var doc in donationsSnap.docs) {
        total += (doc.data()['amount'] ?? 0).toDouble();
      }
      totalDonations.value = total.toInt();

      // عدد الطلبات المعلقة
      var pendingSnap = await _firestore
          .collection('service_requests')
          .where('status', isEqualTo: 'pending')
          .get();
      pendingRequests.value = pendingSnap.docs.length;

      // عدد المشاريع النشطة
      var projectsSnap = await _firestore
          .collection('projects')
          .where('status', isEqualTo: 'active')
          .get();
      activeProjects.value = projectsSnap.docs.length;

      // عدد العمال isAvailable: true
      var workersSnap = await _firestore
          .collection('users')
          .where('role', isEqualTo: UserRole.worker.name)
          .where('isApproved', isEqualTo: true)
          .get();
      availableWorkers.value = workersSnap.docs.length;

      // عدد السيارات isAvailable: true
      var vehiclesSnap = await _firestore
          .collection('vehicles')
          .where('isAvailable', isEqualTo: true)
          .get();
      availableVehicles.value = vehiclesSnap.docs.length;

      // المستفيدون
      var beneficiariesSnap = await _firestore
          .collection('users')
          .where('role', isEqualTo: UserRole.beneficiary.name)
          .get();
      totalBeneficiaries.value = beneficiariesSnap.docs.length;
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> loadRecentRequests() async {
    var snap = await _firestore
        .collection('service_requests')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();
    recentRequests.value = snap.docs.map((d) => ServiceRequestModel.fromMap({...d.data(), 'id': d.id})).toList();
  }

  Future<void> loadRecentDonations() async {
    var snap = await _firestore
        .collection('donations')
        .orderBy('date', descending: true)
        .limit(10)
        .get();
    recentDonations.value = snap.docs.map((d) => DonationModel.fromMap({...d.data(), 'id': d.id})).toList();
  }

  Future<void> loadActiveProjects() async {
    var snap = await _firestore
        .collection('projects')
        .where('status', isEqualTo: 'active')
        .get();
    activeProjectsList.value = snap.docs.map((d) => ProjectModel.fromMap({...d.data(), 'id': d.id})).toList();
  }

  Future<void> loadFieldUpdates() async {
    var snap = await _firestore
        .collection('worker_updates')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();
    fieldUpdates.value = snap.docs.map((d) => WorkerUpdate.fromMap(d.data(), d.id)).toList();
  }

  Future<void> loadChartData() async {
    // محاكاة بيانات الرسوم البيانية
    donationsLastSixMonths.value = [
      {'month': 'جانفي', 'amount': 120.0},
      {'month': 'فيفري', 'amount': 150.0},
      {'month': 'مارس', 'amount': 110.0},
      {'month': 'أفريل', 'amount': 180.0},
      {'month': 'ماي', 'amount': 220.0},
      {'month': 'جوان', 'amount': 190.0},
    ];

    serviceTypeDistribution.value = [
      {'name': 'جنائزي', 'count': 45, 'color': Colors.blue, 'percentage': 45},
      {'name': 'إطعام', 'count': 25, 'color': Colors.green, 'percentage': 25},
      {'name': 'صحي', 'count': 20, 'color': Colors.red, 'percentage': 20},
      {'name': 'أخرى', 'count': 10, 'color': Colors.orange, 'percentage': 10},
    ];

    monthlyRequests.value = List.generate(30, (index) => {
      'day': index + 1,
      'count': (index % 5) + 2
    });

    completedVsPending.value = [
      {'status': 'مكتمل', 'count': 120, 'color': AppTheme.successColor},
      {'status': 'معلق', 'count': 45, 'color': AppTheme.warningColor},
    ];
  }

  // موافقة على مستخدم
  Future<void> approveUser(String userId, String role) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isApproved': true,
        'role': role,
      });
      Get.snackbar('✅ تمت الموافقة', 'تم تفعيل الحساب بنجاح',
          backgroundColor: AppTheme.successColor.withOpacity(0.2),
          colorText: AppTheme.successColor);
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء الموافقة: $e');
    }
  }

  // رفض مستخدم
  Future<void> rejectUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isApproved': false,
        'role': 'rejected',
      });
      Get.snackbar('تم الرفض', 'تم رفض حساب المستخدم');
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
    }
  }

  // إسناد طلب لعامل
  Future<void> assignToWorker(String requestId, String workerId, String workerName) async {
    try {
      await _firestore.collection('service_requests').doc(requestId).update({
        'assignedTo': workerId,
        'assignedToName': workerName,
        'status': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // إرسال إشعار FCM للعامل
      await _sendNotificationToUser(workerId, 'مهمة جديدة', 'تم إسناد طلب خدمة إليك');
      Get.snackbar('تم الإسناد', 'تم إسناد المهمة للعامل $workerName');
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
    }
  }

  // إسناد طلب لسيارة
  Future<void> assignToVehicle(String requestId, String vehicleId) async {
    try {
      await _firestore.collection('service_requests').doc(requestId).update({
        'assignedCarId': vehicleId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('vehicles').doc(vehicleId).update({
        'isAvailable': false,
      });
      Get.snackbar('تم الإسناد', 'تم تخصيص السيارة للطلب');
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
    }
  }

  // تغيير حالة طلب
  Future<void> updateRequestStatus(String requestId, String status) async {
    try {
      await _firestore.collection('service_requests').doc(requestId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (status == 'completed') {
        var doc = await _firestore.collection('service_requests').doc(requestId).get();
        String? vehicleId = doc.data()?['assignedCarId'];
        if (vehicleId != null) {
          await _firestore.collection('vehicles').doc(vehicleId).update({'isAvailable': true});
        }
      }
      Get.snackbar('تم التحديث', 'تم تغيير حالة الطلب بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
    }
  }

  // إضافة نوع خدمة
  Future<void> addServiceType(String name, String icon) async {
    try {
      await _firestore.collection('service_types').add({
        'name': name,
        'icon': icon,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      Get.snackbar('تمت الإضافة', 'تم إضافة نوع خدمة جديد');
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
    }
  }

  // تفعيل/تعطيل نوع خدمة
  Future<void> toggleServiceType(String id, bool isActive) async {
    try {
      await _firestore.collection('service_types').doc(id).update({
        'isActive': isActive,
      });
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
    }
  }

  // إرسال إشعار FCM (محاكاة عبر Firestore)
  Future<void> _sendNotificationToUser(String userId, String title, String body) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }
}
