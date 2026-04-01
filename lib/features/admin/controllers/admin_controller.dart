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
import '../../../data/services/notification_service.dart';

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
          'name': 'إكرام الموتى (نقل)',
          'icon': 'airport_shuttle',
          'isActive': true,
          'fields': ['اسم المتوفى', 'مكان الاستلام', 'مكان التسليم', 'التاريخ والوقت'],
        },
        {
          'id': 'funeral_ghusl',
          'name': 'تغسيل الموتى',
          'icon': 'wash',
          'isActive': true,
          'fields': ['جنس المتوفى', 'مكان الغسل', 'المستلزمات المطلوبة', 'رقم هاتف المنسق'],
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

      // تهيئة إعدادات الإصدار والتحديث
      await initializeVersionConfig(silent: true);

      Get.snackbar('✅ تمت التهيئة', 'تم تحديث الأيقونات والمسميات وإعدادات التحديث بنجاح',
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
          colorText: AppTheme.successColor);

      loadDashboardData();
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في تهيئة البيانات: $e');
    } finally {
      isLoading.value = false;
    }
  }

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
      // Prefer cached aggregate stats to avoid loading all donations.
      try {
        final statsDoc = await _firestore.collection('stats').doc('global').get();
        if (statsDoc.exists && (statsDoc.data() as Map<String, dynamic>).containsKey('totalDonations') && (statsDoc.data() as Map<String, dynamic>)['totalDonations'] > 0) {
          final data = statsDoc.data() as Map<String, dynamic>;
          totalDonations.value = ((data['totalDonations'] ?? 0) as num).toInt();
        } else {
          throw Exception('Fallback to calculating total donations manually');
        }
      } catch (e) {
        // Fallback (legacy): keep previous behavior but with a cap to reduce cost.
        final donationsSnap = await _firestore
            .collection(AppConstants.donationsCollection)
            .orderBy('date', descending: true)
            .limit(2000)
            .get();
        double total = 0;
        for (var doc in donationsSnap.docs) {
          total += (doc.data()['amount'] ?? 0).toDouble();
        }
        totalDonations.value = total.toInt();
      }

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
      final sinceSixMonths = DateTime(now.year, now.month - 5, 1);
      final sinceSixMonthsTs = Timestamp.fromDate(sinceSixMonths);

      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final nextMonth = DateTime(now.year, now.month - i + 1, 1);
        
        try {
          final snap = await _firestore.collection(AppConstants.donationsCollection)
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(month))
            .where('date', isLessThan: Timestamp.fromDate(nextMonth))
            .get();
          
          double total = 0;
          for (var doc in snap.docs) { total += (doc.data()['amount'] ?? 0).toDouble(); }
          sixMonthsData.add({'month': monthNames[month.month - 1], 'amount': total / 1000});
        } catch (e) {
          debugPrint('Error fetching donations for month ${month.month}: $e');
          sixMonthsData.add({'month': monthNames[month.month - 1], 'amount': 0.0});
        }
      }
      donationsLastSixMonths.value = sixMonthsData;

      // Restrict distribution queries to last ~6 months to avoid huge reads.
      final requestsSnap = await _firestore
          .collection(AppConstants.serviceRequestsCollection)
          .where('createdAt', isGreaterThanOrEqualTo: sinceSixMonthsTs)
          .get();
      final guestRequestsSnap = await _firestore
          .collection('guest_requests')
          .where('createdAt', isGreaterThanOrEqualTo: sinceSixMonthsTs)
          .get();

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
      serviceTypeDistribution.value = typeCounts.isEmpty 
          ? [] 
          : typeCounts.entries.map((e) => {
               'name': e.key, 
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
      if (donationsLastSixMonths.isEmpty) {
        donationsLastSixMonths.value = List.generate(6, (i) {
          final m = DateTime(DateTime.now().year, DateTime.now().month - (5-i), 1);
          return {'month': ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'][m.month-1], 'amount': 0.0};
        });
      }
      if (serviceTypeDistribution.isEmpty) {
        serviceTypeDistribution.value = [];
      }
      if (monthlyRequests.isEmpty) {
        monthlyRequests.value = List.generate(DateTime.now().day, (i) => {'day': i + 1, 'count': 0});
      }
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
      await _sendNotificationToUser(workerId, 'مهمة جديدة', 'تم إسناد طلب خدمة إليك', type: 'request_update', data: {'requestId': requestId});
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
      // إشعار للمسؤول عن السيارة
      Get.snackbar('تم الإسناد', 'تم تخصيص السيارة للطلب');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إسناد السيارة: $e');
    }
  }

  Future<void> updateRequestStatus(String id, String status, {bool isGuest = false}) async {
    try {
      String collection = isGuest ? 'guest_requests' : AppConstants.serviceRequestsCollection;
      
      final doc = await _firestore.collection(collection).doc(id).get();
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;

      await _firestore.collection(collection).doc(id).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (status == 'completed' || status == 'rejected' || status == 'cancelled') {
        // ✨ إلغاء التتبع الحي لجميع من استجاب لهذا الطلب
        final responses = data['donorResponses'] ?? [];
        final batch = _firestore.batch();
        for (var response in responses) {
          final uId = response['userId'];
          if (uId != null) {
            batch.update(_firestore.collection(AppConstants.usersCollection).doc(uId), {
              'activeBloodRequestId': FieldValue.delete(),
              'activeBloodRequestIsGuest': FieldValue.delete(),
            });
          }
        }
        await batch.commit();

        // تحديث الكائن المحلي إذا كان المستخدم الحالي أحد المستجيبين
        final currentUserId = _authController.currentUser.value?.id;
        if (currentUserId != null && responses.any((r) => r['userId'] == currentUserId)) {
          final user = _authController.currentUser.value!;
          final map = user.toMap();
          map.remove('activeBloodRequestId');
          map.remove('activeBloodRequestIsGuest');
          _authController.currentUser.value = UserModel.fromMap(map, user.id);
          _authController.currentUser.refresh();
        }
      }

      if (status == 'completed') {
        String? vehicleId = data['assignedCarId'];
        if (vehicleId != null) {
          await _firestore.collection(AppConstants.vehiclesCollection).doc(vehicleId).update({'isAvailable': true});
        }

        // تحديث إحصائيات المتبرع إذا كان الطلب تبرع بالدم
        final String serviceType = data['type'] ?? '';
        String? donorId = data['assignedTo'];
        
        final List<dynamic> responsesData = data['donorResponses'] ?? [];
        if ((donorId == null || donorId.isEmpty) && responsesData.isNotEmpty) {
           donorId = responsesData.first['userId'];
           await _firestore.collection(collection).doc(id).update({'assignedTo': donorId});
        }

        if ((serviceType == 'blood_donation' || serviceType == 'blood_emergency' || data['typeName']?.toString().contains('الدم') == true) && donorId != null && donorId.isNotEmpty) {
            await confirmDonation(donorId);
          }
        }
        if (!isGuest && data['requesterId'] != null) {
        String title = 'تحديث حالة الطلب';
        String body = '';
        String serviceName = data['typeName'] ?? 'الخدمة';
        if (status == 'in_progress') {
          body = 'تم البدء في تنفيذ طلبك ($serviceName)';
        } else if (status == 'completed') {
          body = 'تم الانتهاء من تنفيذ طلبك ($serviceName)';
        } else if (status == 'rejected') {
          body = 'نأسف، تم رفض طلبك ($serviceName)';
        } else {
          body = 'تم تحديث حالة طلبك ($serviceName) إلى $status';
        }

        await NotificationService.sendNotification(
          userId: data['requesterId'],
          type: 'request_update',
          title: title,
          body: body,
          data: {'requestId': id}
        );
      }

      Get.snackbar('تم التحديث', 'تم تغيير حالة الطلب بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
    }
  }

  Future<void> deleteRequest(String id, {bool isGuest = false}) async {
    try {
      String collection = isGuest ? 'guest_requests' : AppConstants.serviceRequestsCollection;
      
      // ✨ إلغاء التتبع الحي للمتبرعين المستجيبين قبل حذف الطلب
      final doc = await _firestore.collection(collection).doc(id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final responses = data['donorResponses'] ?? [];
        if (responses.isNotEmpty) {
          final batch = _firestore.batch();
          for (var response in responses) {
            final uId = response['userId'];
            if (uId != null) {
              batch.update(_firestore.collection(AppConstants.usersCollection).doc(uId), {
                'activeBloodRequestId': FieldValue.delete(),
                'activeBloodRequestIsGuest': FieldValue.delete(),
              });
            }
          }
          await batch.commit();
          
          // تحديث الكائن المحلي إذا كان المستخدم الحالي أحدهم
          final currentUserId = _authController.currentUser.value?.id;
          if (currentUserId != null && responses.any((r) => r['userId'] == currentUserId)) {
            final user = _authController.currentUser.value!;
            final map = user.toMap();
            map.remove('activeBloodRequestId');
            map.remove('activeBloodRequestIsGuest');
            _authController.currentUser.value = UserModel.fromMap(map, user.id);
            _authController.currentUser.refresh();
          }
        }
      }

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

  Future<void> _sendNotificationToUser(String userId, String title, String body, {String type = 'system', Map<String, dynamic>? data}) async {
    try {
      await NotificationService.sendNotification(
        userId: userId,
        type: type,
        title: title,
        body: body,
        data: data,
      );
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

  // تهيئة إعدادات تحديث التطبيق
  Future<void> initializeVersionConfig({bool silent = false}) async {
    isLoading.value = true;
    try {
      await _firestore.collection('config').doc('version').set({
        'currentVersion': '1.0.0',
        'buildNumber': 1,
        'minVersion': '1.0.0',
        'forceUpdate': false,
        'updateUrl': 'https://play.google.com/store/apps/details?id=com.nasalkheir.reggane',
        'title': 'تحديث جديد متوفر',
        'message': 'يرجى تحديث التطبيق للحصول على آخر المميزات والتحسينات.',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!silent) {
        Get.snackbar('✅ تم التفعيل', 'تم تهيئة إعدادات تحديث التطبيق بنجاح',
            backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
            colorText: AppTheme.successColor);
      }
    } catch (e) {
      if (!silent) {
        Get.snackbar('❌ خطأ', 'فشل تهيئة إعدادات التحديث: $e',
            backgroundColor: AppTheme.errorColor.withValues(alpha: 0.2),
            colorText: AppTheme.errorColor);
      }
    } finally {
      isLoading.value = false;
    }
  }

  // استرجاع الفصائل المتوافقة طبياً (من يمكنه التبرع للمريض)
  List<String> getCompatibleDonors(String patientType) {
    switch (patientType) {
      case 'A+': return ['A+', 'A-', 'O+', 'O-'];
      case 'A-': return ['A-', 'O-'];
      case 'B+': return ['B+', 'B-', 'O+', 'O-'];
      case 'B-': return ['B-', 'O-'];
      case 'AB+': return ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
      case 'AB-': return ['AB-', 'A-', 'B-', 'O-'];
      case 'O+': return ['O+', 'O-'];
      case 'O-': return ['O-'];
      default: return [patientType];
    }
  }

  // إرسال تنبيه مستهدف للمتبرعين بالدم
  Future<void> sendTargetedBloodAlert({
    required String bloodType,
    required String requestId,
    required String hospital,
    required String phone,
    String? targetWilaya,
    String? targetCommune,
    bool isGuest = false,
  }) async {
    try {
      isLoading.value = true;
      
      List<String> compatibleTypes = getCompatibleDonors(bloodType);
      
      Query query = _firestore.collection(AppConstants.usersCollection)
          .where('bloodType', whereIn: compatibleTypes);

      final usersSnap = await query.get();

      String? cleanWilaya;
      if (targetWilaya != null && targetWilaya != 'all' && targetWilaya.isNotEmpty) {
        cleanWilaya = targetWilaya.contains(' - ') ? targetWilaya.split(' - ')[1] : targetWilaya;
      }

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final validDonors = usersSnap.docs.where((doc) {
        final userData = doc.data() as Map<String, dynamic>;

        if (userData['isApproved'] != true) return false;
        if (userData['receiveBloodAlerts'] != true) return false;
        if (userData['isDonorAvailable'] != true) return false;

        if (cleanWilaya != null) {
          final userWilaya = userData['wilaya'] as String? ?? '';
          if (userWilaya != targetWilaya && userWilaya != cleanWilaya) return false;
        }

        if (targetCommune != null && targetCommune != 'all' && targetCommune.isNotEmpty) {
          final userCommune = userData['commune'] as String? ?? '';
          if (userCommune != targetCommune) return false;
        }

        if (userData['lastDonatedAt'] != null) {
          final lastDonation = (userData['lastDonatedAt'] as Timestamp).toDate();
          if (lastDonation.isAfter(thirtyDaysAgo)) return false;
        }

        return true;
      }).toList();

      if (validDonors.isEmpty) {
        Get.snackbar('تنبيه', 'لا يوجد متبرعون متوافقون ومتاحون في النطاق الجغرافي المحدد حالياً.',
          backgroundColor: AppTheme.warningColor.withValues(alpha: 0.2),
          colorText: AppTheme.warningColor,
          duration: const Duration(seconds: 5));
        return;
      }

      String title = '🩸 نداء إنساني عاجل: فصيلة $bloodType مطلوبة';
      String body = 'أخي في الله، أنت ممن يمكنهم إنقاذ حياة مريض بحاجة لفصيلة $bloodType في $hospital. كن أنت الأمل المتجدد وساهم في إحياء نفس.';

      int count = 0;
      for (var doc in validDonors) {
        if (doc.id == _authController.currentUser.value?.id) continue;

        await NotificationService.sendNotification(
          userId: doc.id,
          type: 'blood_emergency',
          title: title,
          body: body,
          data: {
            'requestId': requestId,
            'bloodType': bloodType,
            'hospital': hospital,
            'phone': phone,
            'isGuest': isGuest.toString(),
            'type': 'blood_emergency'
          }
        );
        count++;
      }

      if (count > 0) {
        Get.snackbar('✅ تم الإرسال', 'تم إرسال نداء الاستغاثة إلى $count متبرع متوافق وجاهز بنجاح',
            backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
            colorText: AppTheme.successColor,
            duration: const Duration(seconds: 5));
      }
    } catch (e) {
      Get.snackbar('❌ خطأ', 'فشل إرسال التنبيهات: $e',
          backgroundColor: AppTheme.errorColor.withValues(alpha: 0.2),
          colorText: AppTheme.errorColor);
    } finally {
      isLoading.value = false;
    }
  }

  // تسجيل استجابة المتبرع لنداء استغاثة
  Future<void> respondToBloodAlert({
    required String requestId,
    required String donorName,
    required String donorPhone,
    bool isGuest = false,
  }) async {
    try {
      String collection = isGuest ? 'guest_requests' : AppConstants.serviceRequestsCollection;
      final docRef = _firestore.collection(collection).doc(requestId);
      
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        final List<dynamic> existingResponses = data['donorResponses'] ?? [];
        final currentUserId = _authController.currentUser.value?.id;
        
        if (existingResponses.any((r) => r['userId'] == currentUserId)) {
          return; 
        }
      }
      
      await docRef.update({
        'donorResponses': FieldValue.arrayUnion([{
          'userName': donorName,
          'userPhone': donorPhone,
          'respondedAt': Timestamp.now(),
          'userId': _authController.currentUser.value?.id,
        }])
      });

      final currentUserId = _authController.currentUser.value?.id;
      if (currentUserId != null) {
        await _firestore.collection(AppConstants.usersCollection).doc(currentUserId).update({
          'activeBloodRequestId': requestId,
          'activeBloodRequestIsGuest': isGuest,
        });
        
        final user = _authController.currentUser.value;
        if (user != null) {
           _authController.currentUser.value = user.copyWith(
             activeBloodRequestId: requestId,
             activeBloodRequestIsGuest: isGuest,
           );
           _authController.currentUser.refresh();
        }
      }
    } catch (e) {
      debugPrint('Error recording donor response: $e');
    }
  }

  // إرسال إشعار تشجيعي للمتبرعين الآخرين عند استجابة أحدهم
  Future<void> notifyOtherDonors({
    required String requestId,
    required String bloodType,
    required String hospital,
    required String respondingDonorId,
    bool isGuest = false,
  }) async {
    try {
      final String collection = isGuest ? 'guest_requests' : AppConstants.serviceRequestsCollection;
      final doc = await _firestore.collection(collection).doc(requestId).get();
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;

      final String? targetWilaya = data['wilaya'];
      final String? targetCommune = data['commune'];

      List<String> compatibleTypes = getCompatibleDonors(bloodType);
      Query query = _firestore.collection(AppConstants.usersCollection)
          .where('bloodType', whereIn: compatibleTypes)
          .where('isApproved', isEqualTo: true)
          .where('receiveBloodAlerts', isEqualTo: true)
          .where('isDonorAvailable', isEqualTo: true);

      final usersSnap = await query.get();

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      for (var doc in usersSnap.docs) {
        final userId = doc.id;
        if (userId == respondingDonorId) continue;

        final userData = doc.data() as Map<String, dynamic>;
        final lastDonated = (userData['lastDonatedAt'] as Timestamp?)?.toDate();
        if (lastDonated != null && lastDonated.isAfter(thirtyDaysAgo)) continue;

        await NotificationService.sendNotification(
          userId: userId,
          type: 'blood_encouragement',
          title: '🩸 بشرى سارة - فرصة ذهبية للخير!',
          body: 'أبشر! استجاب أحد المتبرعين الكرام لنداء فصيلة ($bloodType). من يرغب في التبرع لاحتياط $hospital فلا يضيع الفرصة، فتبرعك اليوم قد ينقذ روحاً أخرى غداً. ﴿وَمَنْ أَحْيَاهَا فَكَأَنَّمَا أَحْيَا النَّاسَ جَمِيعًا﴾',
          data: {
            'requestId': requestId,
            'bloodType': bloodType,
            'hospital': hospital,
            'isGuest': isGuest.toString(),
            'type': 'blood_encouragement',
          },
        );
      }
    } catch (e) {
      debugPrint('Error sending motivational notifications: $e');
    }
  }

  // تأكيد متبرع محدد للقيام بالمهمة
  Future<void> confirmDonor({
    required String requestId,
    required String donorId,
    required String donorName,
    bool isGuest = false,
  }) async {
    try {
      isLoading.value = true;
      String collection = isGuest ? 'guest_requests' : AppConstants.serviceRequestsCollection;
      
      await _firestore.collection(collection).doc(requestId).update({
        'assignedTo': donorId,
        'assignedToName': donorName,
        'status': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final reqDoc = await _firestore.collection(collection).doc(requestId).get();
      final reqData = reqDoc.data() as Map<String, dynamic>? ?? {};
      final bloodType = reqData['details']?['فصيلة الدم'] ?? reqData['details']?['bloodType'] ?? '';
      final hospital = reqData['details']?['المستشفى'] ?? reqData['details']?['hospital'] ?? '';
      final contactPhone = reqData['details']?['رقم التواصل'] ?? reqData['phone'] ?? '';
      
      await NotificationService.sendNotification(
        userId: donorId,
        type: 'donor_confirmed',
        title: '✅ تم اختيارك للمساعدة',
        body: 'جزاك الله خيراً، تم اختيارك لتوفير فصيلة ($bloodType) في $hospital. يرجى التوجه للموقع.',
        data: {
          'requestId': requestId,
          'bloodType': bloodType,
          'hospital': hospital,
          'phone': contactPhone,
          'isGuest': isGuest.toString(),
        },
      );

      if (!isGuest && reqData['requesterId'] != null) {
        await NotificationService.sendNotification(
          userId: reqData['requesterId'],
          type: 'request_update',
          title: '🚑 المساعدة في الطريق!',
          body: 'بشرى سارة! المتبرع $donorName في طريقه إليك لتوفير الدم المطلوب.',
          data: {'requestId': requestId},
        );
      }

      Get.snackbar('✅ تم التأكيد', 'تم إسناد المهمة للمتبرع $donorName بنجاح',
        backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
        colorText: AppTheme.successColor);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تأكيد المتبرع: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // إرسال إعلان عام لجميع المستخدمين
  Future<void> sendGlobalAnnouncement({
    required String title,
    required String body,
  }) async {
    isLoading.value = true;
    try {
      final usersSnap = await _firestore.collection(AppConstants.usersCollection)
          .where('isApproved', isEqualTo: true)
          .get();

      int count = 0;
      final batch = _firestore.batch();

      for (var doc in usersSnap.docs) {
        final notifRef = _firestore.collection('notifications').doc();
        batch.set(notifRef, {
          'userId': doc.id,
          'type': 'announcement',
          'title': title,
          'body': body,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        count++;
      }

      await batch.commit();

      Get.snackbar('✅ تم الإرسال', 'تم إرسال الإعلان إلى $count مستخدم بنجاح',
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.15),
          colorText: AppTheme.successColor);
    } catch (e) {
      Get.snackbar('❌ خطأ', 'فشل إرسال الإعلان: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // تحديث إعدادات التبرع للمستخدم الحالي
  Future<void> updateUserDonorSettings({bool? receiveAlerts, bool? isAvailable}) async {
    try {
      final user = _authController.currentUser.value;
      if (user == null) return;

      Map<String, dynamic> updates = {};
      if (receiveAlerts != null) updates['receiveBloodAlerts'] = receiveAlerts;
      if (isAvailable != null) updates['isDonorAvailable'] = isAvailable;

      if (updates.isEmpty) return;

      await _firestore.collection(AppConstants.usersCollection).doc(user.id).update(updates);
      
      _authController.currentUser.value = user.copyWith(
        receiveBloodAlerts: receiveAlerts ?? user.receiveBloodAlerts,
        isDonorAvailable: isAvailable ?? user.isDonorAvailable,
      );

      Get.snackbar('✅ تم التحديث', 'تم حفظ التعديلات بنجاح', 
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.successColor.withValues(alpha: 0.15),
        colorText: AppTheme.successColor);
    } catch (e) {
      Get.snackbar('❌ خطأ', 'فشل تحديث الإعدادات');
    }
  }

  // تأكيد إتمام عملية التبرع وتحديث العداد
  Future<void> confirmDonation(String userId) async {
    try {
      final userDoc = await _firestore.collection(AppConstants.usersCollection).doc(userId).get();
      if (!userDoc.exists) return;

      final data = userDoc.data()!;
      final currentCount = data['bloodDonationsCount'] ?? 0;

      await _firestore.collection(AppConstants.usersCollection).doc(userId).update({
        'bloodDonationsCount': currentCount + 1,
        'lastDonatedAt': FieldValue.serverTimestamp(),
        'isDonorAvailable': false,
      });

      await NotificationService.sendNotification(
        userId: userId,
        type: 'donation_confirmed',
        title: 'بارك الله فيك! ❤️',
        body: 'تم تسجيل تبرعك بنجاح. شكراً لإنقاذك حياة إنسان.',
        data: {'newCount': (currentCount + 1).toString()}
      );
    } catch (e) {
      debugPrint('ConfirmDonation Error: $e');
    }
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(userId).update({
        'role': newRole,
      });
      Get.snackbar('تم التحديث', 'تم تغيير رتبة المستخدم إلى $newRole');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحديث الرتبة: $e');
    }
  }

  Future<void> seedDefaultServices() async {
    isLoading.value = true;
    try {
      final snapshot = await _firestore.collection('service_types').get();
      final existingNames = snapshot.docs.map((doc) => doc['name'] as String).toList();
      
      final Map<String, List<String>> defaultFields = {
        'نقل الجنائز': ['اسم المتوفى', 'مكان الوفاة', 'الوجهة المقصودة', 'رقم هاتف الأهل'],
        'تغسيل الموتى': ['اسم المتوفى', 'جنس المتوفى', 'مكان الغسل', 'المستلزمات', 'رقم هاتف الأهل'],
        'مساعدات غذائية': ['عدد أفراد الأسرة', 'العنوان بالتفصيل', 'الحالة الاجتماعية'],
        'مساعدات مالية': ['المبلغ المطلوب تقريباً', 'السبب', 'رقم الهاتف'],
        'مساعدة طبية': ['نوع المساعدة', 'اسم المستشفى', 'رقم الملف الطبي'],
        'تعليم وكفالة أيتام': ['عدد الأيتام', 'المستوى الدراسي', 'العنوان'],
        'بناء وتعمير': ['نوع العمل', 'العنوان', 'مساحة المسكن'],
      };

      int addedCount = 0;
      for (String serviceName in AppConstants.defaultServiceTypes) {
        if (!existingNames.contains(serviceName)) {
          String icon = 'category';
          if (serviceName.contains('جنازة') || serviceName.contains('جنائز')) icon = 'mosque';
          if (serviceName.contains('غسل')) icon = 'waves';
          if (serviceName.contains('طبية')) icon = 'hospital';
          if (serviceName.contains('غذائية')) icon = 'shopping_basket';
          if (serviceName.contains('مالية')) icon = 'payments';
          
          await _firestore.collection('service_types').add({
            'name': serviceName,
            'icon': icon,
            'isActive': true,
            'popularity': 0,
            'fields': defaultFields[serviceName] ?? ['الوصف', 'العنوان', 'رقم الهاتف'],
            'createdAt': FieldValue.serverTimestamp(),
          });
          addedCount++;
        }
      }

      if (addedCount > 0) {
        Get.snackbar('✅ تم بنجاح', 'تمت استعادة $addedCount من الخدمات الأساسية المفقودة',
            backgroundColor: AppTheme.successColor.withValues(alpha: 0.15),
            colorText: AppTheme.successColor);
      } else {
        Get.snackbar('ℹ️ تنبيه', 'جميع الخدمات الأساسية موجودة بالفعل في النظام',
            backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15),
            colorText: AppTheme.warningColor);
      }
    } catch (e) {
      Get.snackbar('❌ خطأ', 'فشل استعادة الخدمات الأساسية: $e');
    } finally {
      isLoading.value = false;
    }
  }
}

