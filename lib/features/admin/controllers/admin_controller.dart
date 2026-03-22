import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/donation_model.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/worker_update_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/vehicle_model.dart';
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
        .collection(AppConstants.serviceRequestsCollection)
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
      // إجمالي التبرعات
      var donationsSnap = await _firestore.collection(AppConstants.donationsCollection).get();
      double total = 0;
      for (var doc in donationsSnap.docs) {
        total += (doc.data()['amount'] ?? 0).toDouble();
      }
      totalDonations.value = total.toInt();

      // عدد الطلبات المعلقة
      var pendingSnap = await _firestore
          .collection(AppConstants.serviceRequestsCollection)
          .where('status', isEqualTo: 'pending')
          .get();
      pendingRequests.value = pendingSnap.docs.length;

      // عدد المشاريع النشطة
      var projectsSnap = await _firestore
          .collection(AppConstants.projectsCollection)
          .where('status', isEqualTo: 'active')
          .get();
      activeProjects.value = projectsSnap.docs.length;

      // عدد العمال
      var workersSnap = await _firestore
          .collection(AppConstants.usersCollection)
          .where('role', isEqualTo: UserRole.worker.name)
          .where('isApproved', isEqualTo: true)
          .get();
      availableWorkers.value = workersSnap.docs.length;

      // عدد السيارات المتاحة
      var vehiclesSnap = await _firestore
          .collection(AppConstants.vehiclesCollection)
          .where('isAvailable', isEqualTo: true)
          .get();
      availableVehicles.value = vehiclesSnap.docs.length;

      // المستفيدون
      var beneficiariesSnap = await _firestore
          .collection(AppConstants.usersCollection)
          .where('role', isEqualTo: UserRole.beneficiary.name)
          .get();
      totalBeneficiaries.value = beneficiariesSnap.docs.length;
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> loadRecentRequests() async {
    var snap = await _firestore
        .collection(AppConstants.serviceRequestsCollection)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();
    recentRequests.value = snap.docs.map((d) => ServiceRequestModel.fromMap({...d.data(), 'id': d.id})).toList();
  }

  Future<void> loadRecentDonations() async {
    var snap = await _firestore
        .collection(AppConstants.donationsCollection)
        .orderBy('date', descending: true)
        .limit(10)
        .get();
    recentDonations.value = snap.docs.map((d) => DonationModel.fromMap({...d.data(), 'id': d.id})).toList();
  }

  Future<void> loadActiveProjects() async {
    var snap = await _firestore
        .collection(AppConstants.projectsCollection)
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
    try {
      // التبرعات آخر 6 أشهر - بيانات حقيقية
      final now = DateTime.now();
      final List<Map<String, dynamic>> sixMonthsData = [];
      final monthNames = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
      
      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final nextMonth = DateTime(now.year, now.month - i + 1, 1);
        final snap = await _firestore.collection('donations')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(month))
          .where('date', isLessThan: Timestamp.fromDate(nextMonth))
          .get();
        double total = 0;
        for (var doc in snap.docs) { total += (doc.data()['amount'] ?? 0).toDouble(); }
        sixMonthsData.add({'month': monthNames[month.month - 1], 'amount': total / 1000});
      }
      donationsLastSixMonths.value = sixMonthsData;

      // توزيع الخدمات - بيانات حقيقية
      final requestsSnap = await _firestore.collection('service_requests').get();
      final Map<String, int> typeCounts = {};
      for (var doc in requestsSnap.docs) {
        final type = doc.data()['type'] ?? 'other';
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }
      final total = typeCounts.values.fold(0, (a, b) => a + b);
      final colors = [Colors.blue, Colors.green, Colors.red, Colors.orange, Colors.purple, Colors.teal];
      int colorIndex = 0;
      serviceTypeDistribution.value = typeCounts.entries.map((e) => {
        'name': e.key,
        'count': e.value,
        'color': colors[colorIndex++ % colors.length],
        'percentage': total > 0 ? ((e.value / total) * 100).toInt() : 0,
      }).toList();

      // طلبات هذا الشهر يومياً - بيانات حقيقية
      final startOfMonth = DateTime(now.year, now.month, 1);
      final monthSnap = await _firestore.collection('service_requests')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .get();
      final Map<int, int> dayCounts = {};
      for (var doc in monthSnap.docs) {
        final ts = doc.data()['createdAt'] as Timestamp?;
        if (ts != null) {
          final day = ts.toDate().day;
          dayCounts[day] = (dayCounts[day] ?? 0) + 1;
        }
      }
      monthlyRequests.value = List.generate(now.day, (i) => {
        'day': i + 1,
        'count': dayCounts[i + 1] ?? 0,
      });

    } catch (e) {
      debugPrint('Error loading chart data: $e');
      // بيانات افتراضية في حالة الخطأ
      donationsLastSixMonths.value = List.generate(6, (i) => {'month': 'شهر ${i+1}', 'amount': 0.0});
      serviceTypeDistribution.value = [{'name': 'لا يوجد', 'count': 1, 'color': Colors.grey, 'percentage': 100}];
      monthlyRequests.value = List.generate(30, (i) => {'day': i + 1, 'count': 0});
    }
  }

  // موافقة على مستخدم
  Future<void> approveUser(String userId, dynamic role) async {
    try {
      String roleStr = role is UserRole ? role.name : role.toString();
      await _firestore.collection(AppConstants.usersCollection).doc(userId).update({
        'isApproved': true,
        'role': roleStr,
      });
      Get.snackbar('✅ تمت الموافقة', 'تم تفعيل الحساب بنجاح',
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
          colorText: AppTheme.successColor);
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء الموافقة: $e');
    }
  }

  // رفض مستخدم
  Future<void> rejectUser(String userId) async {
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(userId).update({
        'isApproved': false,
        'role': 'rejected',
      });
      Get.snackbar('تم الرفض', 'تم رفض حساب المستخدم');
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
    }
  }

  // إسناد طلب لعامل
  Future<void> assignToWorker(String requestId, String workerId, {String? workerName, bool isGuest = false}) async {
    try {
      String collection = isGuest ? 'guest_requests' : AppConstants.serviceRequestsCollection;
      await _firestore.collection(collection).doc(requestId).update({
        'assignedTo': workerId,
        'assignedToName': workerName ?? '',
        'status': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _sendNotificationToUser(workerId, 'مهمة جديدة', 'تم إسناد طلب خدمة إليك');
      Get.snackbar('تم الإسناد', 'تم إسناد المهمة بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
    }
  }

  // Aliases for compatibility
  Future<void> assignRequestToWorker(String requestId, String workerId) => assignToWorker(requestId, workerId);
  Future<void> assignRequestToVehicle(String requestId, String vehicleId) => assignToVehicle(requestId, vehicleId);

  // إسناد طلب لسيارة
  Future<void> assignToVehicle(String requestId, String vehicleId, {bool isGuest = false}) async {
    try {
      String collection = isGuest ? 'guest_requests' : AppConstants.serviceRequestsCollection;
      await _firestore.collection(collection).doc(requestId).update({
        'assignedCarId': vehicleId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _firestore.collection(AppConstants.vehiclesCollection).doc(vehicleId).update({
        'isAvailable': false,
      });
      Get.snackbar('تم الإسناد', 'تم تخصيص السيارة للطلب');
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
    }
  }

  // تغيير حالة طلب
  Future<void> updateRequestStatus(String requestId, String status, {bool isGuest = false}) async {
    try {
      String collection = isGuest ? 'guest_requests' : AppConstants.serviceRequestsCollection;
      await _firestore.collection(collection).doc(requestId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (status == 'completed') {
        var doc = await _firestore.collection(collection).doc(requestId).get();
        String? vehicleId = doc.data()?['assignedCarId'];
        if (vehicleId != null) {
          await _firestore.collection(AppConstants.vehiclesCollection).doc(vehicleId).update({'isAvailable': true});
        }
      }
      Get.snackbar('تم التحديث', 'تم تغيير حالة الطلب بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
    }
  }

  // إدارة السيارات
  Future<void> addVehicle(VehicleModel vehicle) async {
    try {
      await _firestore.collection(AppConstants.vehiclesCollection).doc(vehicle.id).set(vehicle.toMap());
      Get.snackbar("نجاح", "تمت إضافة السيارة");
    } catch (e) {
      Get.snackbar("خطأ", e.toString());
    }
  }

  Future<void> updateVehicle(VehicleModel vehicle) async {
    try {
      await _firestore.collection(AppConstants.vehiclesCollection).doc(vehicle.id).update(vehicle.toMap());
      Get.snackbar("نجاح", "تم تحديث السيارة");
    } catch (e) {
      Get.snackbar("خطأ", e.toString());
    }
  }

  // إضافة نوع خدمة
  Future<void> addServiceType(String name, String icon) async {
    try {
      await _firestore.collection(AppConstants.serviceTypesCollection).add({
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
      await _firestore.collection(AppConstants.serviceTypesCollection).doc(id).update({
        'isActive': isActive,
      });
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
    }
  }

  // إرسال إشعار
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

  Future<void> addProject(ProjectModel newProject) async {
    try {
      await _firestore.collection('projects').add(newProject.toMap());
      await loadActiveProjects();
      Get.snackbar('✅ تم', 'تم إضافة المشروع بنجاح',
        backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
        colorText: AppTheme.successColor);
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ: $e', backgroundColor: AppTheme.errorColor.withValues(alpha: 0.2));
    }
  }
}
