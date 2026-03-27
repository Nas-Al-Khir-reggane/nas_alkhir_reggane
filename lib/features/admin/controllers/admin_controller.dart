import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/donation_model.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/worker_update_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/utils/app_error_handler.dart';

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
  RxInt unseenUrgentCount = 0.obs;
  RxBool isLoading = false.obs;
  RxBool shouldShowSwipeHint = false.obs;

  // قوائم حية
  RxList<ServiceRequestModel> recentRequests = <ServiceRequestModel>[].obs;
  RxList<ServiceRequestModel> urgentRequests = <ServiceRequestModel>[].obs;
  RxList<DonationModel> recentDonations = <DonationModel>[].obs;
  RxList<ProjectModel> activeProjectsList = <ProjectModel>[].obs;
  RxList<WorkerUpdate> fieldUpdates = <WorkerUpdate>[].obs;
  RxMap<String, String> workerAvatarsCache = <String, String>{}.obs;
  
  // قوائم داخلية للدمج
  final RxList<ServiceRequestModel> _memberUrgent = <ServiceRequestModel>[].obs;
  final RxList<ServiceRequestModel> _guestUrgent = <ServiceRequestModel>[].obs;

  // بيانات الرسوم البيانية
  RxList<Map<String, dynamic>> monthlyRequests = <Map<String, dynamic>>[].obs;
  RxList<Map<String, dynamic>> donationsLastSixMonths = <Map<String, dynamic>>[].obs;
  RxList<Map<String, dynamic>> serviceTypeDistribution = <Map<String, dynamic>>[].obs;
  RxList<Map<String, dynamic>> completedVsPending = <Map<String, dynamic>>[].obs;

  StreamSubscription? _urgentRequestsSub;
  StreamSubscription? _guestRequestsSub;

  @override
  void onInit() {
    super.onInit();
    loadDashboardData();
    listenToUrgentRequests();
    _checkSwipeHintStatus();
  }
  
  Future<void> _checkSwipeHintStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getString('last_swipe_hint_date') ?? '';
    final today = DateTime.now().toIso8601String().split('T')[0];

    if (lastShown != today) {
      shouldShowSwipeHint.value = true;
    }
  }

  Future<void> markSwipeHintAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    await prefs.setString('last_swipe_hint_date', today);
    shouldShowSwipeHint.value = false;
  }

  @override
  void onClose() {
    _urgentRequestsSub?.cancel();
    _guestRequestsSub?.cancel();
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
      AppErrorHandler.handleError(e, customMessage: 'فشل في تحميل بيانات لوحة التحكم');
    } finally {
      isLoading.value = false;
    }
  }

  // دالة التهيئة الأولية للبيانات بأيقونات إسلامية معبرة
  Future<void> seedInitialData() async {
    isLoading.value = true;
    try {
      final serviceTypes = [
        {
          'id': 'funeral_transport',
          'name': 'إكرام الموتى',
          'icon': 'mosque',
          'isActive': true,
          'fields': ['اسم المتوفى', 'مكان الاستلام', 'مكان التسليم', 'التاريخ والوقت'],
        },
        {
          'id': 'food_aid',
          'name': 'إطعام الطعام',
          'icon': 'shopping_basket',
          'isActive': true,
          'fields': ['عدد أفراد العائلة', 'وصف الاحتياج'],
        },
        {
          'id': 'medical_aid',
          'name': 'الرعاية الطبية',
          'icon': 'medication',
          'isActive': true,
          'fields': ['نوع الحالة المرضية', 'الأدوية/المستلزمات المطلوبة'],
        },
        {
          'id': 'financial_aid',
          'name': 'تفريج كربة (مالي)',
          'icon': 'payments',
          'isActive': true,
          'fields': ['المبلغ التقريبي', 'سبب الطلب'],
        },
        {
          'id': 'construction',
          'name': 'ترميم بيوت الله والفقراء',
          'icon': 'home_work',
          'isActive': true,
          'fields': ['نوع العمل', 'العنوان بالتفصيل', 'وصف الحالة'],
        },
        {
          'id': 'education',
          'name': 'تعليم وكفالة طالب',
          'icon': 'menu_book',
          'isActive': true,
          'fields': ['عدد الطلاب', 'المستوى الدراسي', 'المستلزمات'],
        },
        {
          'id': 'water_supply',
          'name': 'سقيا الماء',
          'icon': 'water_drop',
          'isActive': true,
          'fields': ['المنطقة', 'نوع الخدمة (صهريج/بئر)'],
        },
        {
          'id': 'orphans_care',
          'name': 'كفالة اليتيم',
          'icon': 'volunteer_activism',
          'isActive': true,
          'fields': ['عدد الأيتام', 'الأعمار', 'الاحتياجات'],
        },
        {
          'id': 'clothing_aid',
          'name': 'كسوة العيد والفقراء',
          'icon': 'checkroom',
          'isActive': true,
          'fields': ['عدد الأفراد', 'الفئات العمرية'],
        },
        {
          'id': 'home_appliances',
          'name': 'تجهيز بيوت المحتاجين',
          'icon': 'inventory',
          'isActive': true,
          'fields': ['الجهاز المطلوب', 'الحالة الحالية'],
        },
        {
          'id': 'patient_transport',
          'name': 'نقل المرضى (إسعاف)',
          'icon': 'emergency',
          'isActive': true,
          'fields': ['نوع المرض', 'المستشفى', 'المواعيد'],
        },
        {
          'id': 'winter_warmth',
          'name': 'حملة دفء الشتاء',
          'icon': 'ac_unit',
          'isActive': true,
          'fields': ['الاحتياج (أغطية/تدفئة)', 'عدد الأفراد'],
        },
        {
          'id': 'seasonal_aid',
          'name': 'صدقات موسمية (هلال)',
          'icon': 'nightlight_round',
          'isActive': true,
          'fields': ['نوع المناسبة', 'عدد الأفراد'],
        },
        {
          'id': 'blood_donation',
          'name': 'إغاثة بقطرة دم',
          'icon': 'bloodtype',
          'isActive': true,
          'fields': ['فصيلة الدم', 'المستشفى', 'رقم التواصل'],
        },
        {
          'id': 'other',
          'name': 'أبواب خير أخرى',
          'icon': 'more_horiz',
          'isActive': true,
          'fields': ['مسمى الخدمة', 'وصف الطلب'],
        }
      ];

      for (var service in serviceTypes) {
        final id = service.remove('id') as String;
        await _firestore.collection('service_types').doc(id).set({
          ...service,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // إضافة أنواع المهام
      final taskTypes = [
        {'id': 'delivery', 'name': 'توصيل أمانة', 'description': 'توصيل مساعدات للمستحقين', 'isActive': true},
        {'id': 'social_visit', 'name': 'تقصي وبحث ميداني', 'description': 'دراسة حالات اجتماعية', 'isActive': true},
        {'id': 'maintenance', 'name': 'صيانة وتجهيز', 'description': 'أعمال صيانة وإصلاح', 'isActive': true},
        {'id': 'transport', 'name': 'خدمات نقل لوجستي', 'description': 'نقل معدات أو أفراد', 'isActive': true}
      ];

      for (var task in taskTypes) {
        final id = task.remove('id') as String;
        await _firestore.collection('task_types').doc(id).set({
          ...task,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      Get.snackbar('✅ تمت التهيئة', 'تم تحديث الأيقونات والمسميات بنجاح',
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
          colorText: AppTheme.successColor);

      loadDashboardData();
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في تهيئة البيانات: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // باقي الكود كما هو...
  void listenToUrgentRequests() {
    // الاستماع لطلبات الأعضاء
    _urgentRequestsSub = _firestore
        .collection(AppConstants.serviceRequestsCollection)
        .where('urgency', whereIn: ['urgent', 'emergency'])
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      _memberUrgent.assignAll(snap.docs.map((d) => ServiceRequestModel.fromMap({...d.data(), 'id': d.id})).toList());
      _combineUrgent();
    });

    // الاستماع لطلبات الزوار
    _guestRequestsSub = _firestore
        .collection('guest_requests')
        .where('urgency', whereIn: ['urgent', 'emergency'])
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      _guestUrgent.assignAll(snap.docs.map((d) => ServiceRequestModel.fromMap({...d.data(), 'id': d.id, 'isGuest': true})).toList());
      _combineUrgent();
    });
  }

  void _combineUrgent() {
    var combined = [..._memberUrgent, ..._guestUrgent];
    combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    urgentRequests.assignAll(combined);

    // حساب التنبيهات غير المقروءة فقط
    unseenUrgentCount.value = combined.where((r) => !r.isSeenByAdmin).length;
  }

  Future<void> markAllUrgentAsSeen() async {
    if (unseenUrgentCount.value == 0) return;

    try {
      WriteBatch batch = _firestore.batch();

      // طلبات الأعضاء
      for (var req in _memberUrgent) {
        if (!req.isSeenByAdmin) {
          batch.update(_firestore.collection(AppConstants.serviceRequestsCollection).doc(req.id),
            {'isSeenByAdmin': true});
        }
      }

      // طلبات الزوار
      for (var req in _guestUrgent) {
        if (!req.isSeenByAdmin) {
          batch.update(_firestore.collection('guest_requests').doc(req.id),
            {'isSeenByAdmin': true});
        }
      }

      await batch.commit();
      unseenUrgentCount.value = 0;
    } catch (e) {
      debugPrint('Error marking urgent requests as seen: $e');
    }
  }

  Future<void> loadStats() async {
    try {
      var donationsSnap = await _firestore.collection(AppConstants.donationsCollection).get();
      double total = 0;
      for (var doc in donationsSnap.docs) {
        total += (doc.data()['amount'] ?? 0).toDouble();
      }
      totalDonations.value = total.toInt();

      var pendingSnap = await _firestore
          .collection(AppConstants.serviceRequestsCollection)
          .where('status', isEqualTo: 'pending')
          .get();

      var guestPendingSnap = await _firestore
          .collection('guest_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      pendingRequests.value = pendingSnap.docs.length + guestPendingSnap.docs.length;

      var projectsSnap = await _firestore
          .collection(AppConstants.projectsCollection)
          .where('status', isEqualTo: 'active')
          .get();
      activeProjects.value = projectsSnap.docs.length;

      var workersSnap = await _firestore
          .collection(AppConstants.usersCollection)
          .where('role', isEqualTo: UserRole.worker.name)
          .where('isApproved', isEqualTo: true)
          .get();
      availableWorkers.value = workersSnap.docs.length;

      var vehiclesSnap = await _firestore
          .collection(AppConstants.vehiclesCollection)
          .where('isAvailable', isEqualTo: true)
          .get();
      availableVehicles.value = vehiclesSnap.docs.length;

      var beneficiariesSnap = await _firestore
          .collection(AppConstants.usersCollection)
          .where('role', isEqualTo: UserRole.beneficiary.name)
          .get();
      totalBeneficiaries.value = beneficiariesSnap.docs.length;
    } catch (e) {
      AppErrorHandler.handleError(e, customMessage: 'تعذر تحميل الإحصائيات');
    }
  }

  Future<void> loadRecentRequests() async {
    var memberSnap = await _firestore
        .collection(AppConstants.serviceRequestsCollection)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    var guestSnap = await _firestore
        .collection('guest_requests')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    var members = memberSnap.docs.map((d) => ServiceRequestModel.fromMap({...d.data(), 'id': d.id})).toList();
    var guests = guestSnap.docs.map((d) => ServiceRequestModel.fromMap({...d.data(), 'id': d.id, 'isGuest': true})).toList();

    var combined = [...members, ...guests];
    combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    recentRequests.assignAll(combined.take(10).toList());
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

    Set<String?> workerIds = fieldUpdates.map((e) => e.workerId).toSet();
    for (var wId in workerIds) {
      if (wId != null && !workerAvatarsCache.containsKey(wId)) {
        var userDoc = await _firestore.collection(AppConstants.usersCollection).doc(wId).get();
        if (userDoc.exists) {
          workerAvatarsCache[wId] = (userDoc.data() as Map<String, dynamic>)['profileImage'] ?? '';
        }
      }
    }
  }

  Future<void> loadChartData() async {
    try {
      final now = DateTime.now();
      final List<Map<String, dynamic>> sixMonthsData = [];
      final monthNames = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];

      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final nextMonth = DateTime(now.year, now.month - i + 1, 1);
        final snap = await _firestore.collection(AppConstants.donationsCollection)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(month))
          .where('date', isLessThan: Timestamp.fromDate(nextMonth))
          .get();
        double total = 0;
        for (var doc in snap.docs) { total += (doc.data()['amount'] ?? 0).toDouble(); }
        sixMonthsData.add({'month': monthNames[month.month - 1], 'amount': total / 1000});
      }
      donationsLastSixMonths.value = sixMonthsData;

      final requestsSnap = await _firestore.collection(AppConstants.serviceRequestsCollection).get();
      final guestRequestsSnap = await _firestore.collection('guest_requests').get();

      final Map<String, int> typeCounts = {};

      for (var doc in requestsSnap.docs) {
        final type = doc.data()['type'] ?? 'other';
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }
      for (var doc in guestRequestsSnap.docs) {
        final type = doc.data()['type'] ?? 'other';
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }
      final total = typeCounts.values.fold(0, (a, b) => a + b);
      final colors = [Colors.blue, Colors.green, Colors.red, Colors.orange, Colors.purple, Colors.teal];
      int colorIndex = 0;
      serviceTypeDistribution.value = typeCounts.entries.map((e) => {
        'name': AppConstants.translateServiceType(e.key),
        'count': e.value,
        'color': colors[colorIndex++ % colors.length],
        'percentage': total > 0 ? ((e.value / total) * 100).toInt() : 0,
      }).toList();

      final startOfMonth = DateTime(now.year, now.month, 1);
      final monthSnap = await _firestore.collection(AppConstants.serviceRequestsCollection)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .get();

      final guestMonthSnap = await _firestore.collection('guest_requests')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .get();

      final Map<int, int> dayCounts = {};

      void countDays(QuerySnapshot snap) {
        for (var doc in snap.docs) {
          final ts = (doc.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (ts != null) {
            final day = ts.toDate().day;
            dayCounts[day] = (dayCounts[day] ?? 0) + 1;
          }
        }
      }

      countDays(monthSnap);
      countDays(guestMonthSnap);
      monthlyRequests.value = List.generate(now.day, (i) => {
        'day': i + 1,
        'count': dayCounts[i + 1] ?? 0,
      });

    } catch (e) {
      debugPrint('Error loading chart data: $e');
      donationsLastSixMonths.value = List.generate(6, (i) => {'month': 'شهر ${i+1}', 'amount': 0.0});
      serviceTypeDistribution.value = [{'name': 'لا يوجد', 'count': 1, 'color': Colors.grey, 'percentage': 100}];
      monthlyRequests.value = List.generate(30, (i) => {'day': i + 1, 'count': 0});
    }
  }

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

  Future<void> assignRequestToWorker(String requestId, String workerId) => assignToWorker(requestId, workerId);
  Future<void> assignRequestToVehicle(String requestId, String vehicleId) => assignToVehicle(requestId, vehicleId);

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
      Get.snackbar('خطأ', 'فشل إسناد السيارة: $e');
    }
  }

  Future<void> updateRequestStatus(String id, String status, {bool isGuest = false}) async {
    try {
      String collection = isGuest ? 'guest_requests' : AppConstants.serviceRequestsCollection;
      await _firestore.collection(collection).doc(id).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (status == 'completed') {
        var doc = await _firestore.collection(collection).doc(id).get();
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

  Future<void> deleteRequest(String id, {bool isGuest = false}) async {
    try {
      String collection = isGuest ? 'guest_requests' : AppConstants.serviceRequestsCollection;
      await _firestore.collection(collection).doc(id).delete();
      Get.snackbar('🗑️ تم الحذف', 'تم حذف الطلب نهائياً',
          backgroundColor: AppTheme.errorColor.withValues(alpha: 0.2),
          colorText: AppTheme.errorColor,
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل حذف الطلب: $e');
    }
  }

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

  Future<void> toggleServiceType(String id, bool isActive) async {
    try {
      await _firestore.collection(AppConstants.serviceTypesCollection).doc(id).update({
        'isActive': isActive,
      });
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
    }
  }

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
      await _firestore.collection(AppConstants.projectsCollection).add(newProject.toMap());
      await loadActiveProjects();
      Get.snackbar('✅ تم', 'تم إضافة المشروع بنجاح',
        backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
        colorText: AppTheme.successColor);
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ: $e', backgroundColor: AppTheme.errorColor.withValues(alpha: 0.2));
    }
  }
}
