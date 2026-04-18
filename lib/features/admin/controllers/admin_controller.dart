import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import '../../../data/models/strategic_goal_model.dart';
import '../../../data/models/broadcast_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/services/notification_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';

enum MetricType { donations, requests, projects, team }

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
  RxInt totalRegisteredUsers = 0.obs; // العداد الإجمالي الجديد
  RxInt pendingVerificationsCount = 0.obs; // عداد التوثيقات المعلقة
  RxInt unseenUrgentCount = 0.obs;
  RxBool isLoading = false.obs;
  RxBool shouldShowSwipeHint = false.obs;
  RxList<BroadcastModel> activeBroadcasts = <BroadcastModel>[].obs;
  bool _hasShownPopupThisSession = false; // لمنع تكرار المنبثق في نفس الجلسة
  
  // --- Hizb Al-Ma'at Alf Management ---
  RxList<UserModel> hizbMembers = <UserModel>[].obs;
  RxList<Map<String, dynamic>> hizbAlertsHistory = <Map<String, dynamic>>[].obs;
  StreamSubscription? _hizbMembersSub;

  // --- التحكم في الرسوم البيانية ---
  RxString selectedPeriod = 'weekly'.obs; // weekly, monthly, yearly
  RxList<double> chartData = <double>[].obs;
  RxList<String> chartLabels = <String>[].obs;

  // --- صلاحيات الأدوار (RBAC) ---
  bool get isSuperAdmin => currentUser?.role == UserRole.superAdmin;
  bool get isAdminOnly => currentUser?.role == UserRole.admin;
  bool get isAnyAdmin => isSuperAdmin || isAdminOnly;

  bool _requireSuperAdmin(String actionLabel) {
    if (isSuperAdmin) return true;
    Get.snackbar(
      '❌ وصول مرفوض',
      'هذه العملية ($actionLabel) متاحة للمنسق العام فقط',
      backgroundColor: Colors.red.withValues(alpha: 0.1),
      colorText: Colors.red,
    );
    return false;
  }

  bool _isValidRoleName(String roleName) {
    return UserRole.values.any((role) => role.name == roleName);
  }

  String _localizedErrorMessage(dynamic error, {String fallback = 'حدث خلل غير متوقع. يرجى المحاولة مرة أخرى.'}) {
    final raw = error.toString();
    final normalized = raw.toLowerCase();

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'لا تملك صلاحية تنفيذ هذا الإجراء.';
        case 'unavailable':
          return 'الخدمة غير متاحة حالياً. يرجى التحقق من الإنترنت والمحاولة لاحقاً.';
        case 'deadline-exceeded':
          return 'استغرقت العملية وقتاً أطول من المتوقع. حاول مرة أخرى.';
        case 'not-found':
          return 'البيانات المطلوبة غير موجودة أو تم حذفها.';
        case 'aborted':
          return 'تم إيقاف العملية بسبب تعارض في التحديث. أعد المحاولة.';
      }
    }

    if (normalized.contains('permission-denied') || normalized.contains('insufficient permissions')) {
      return 'لا تملك صلاحية تنفيذ هذا الإجراء.';
    }
    if (normalized.contains('network') || normalized.contains('socketexception')) {
      return 'تعذر الاتصال بالخادم. يرجى التحقق من الإنترنت.';
    }
    if (normalized.contains('timeout') || normalized.contains('deadline-exceeded')) {
      return 'انتهت مهلة العملية. يرجى إعادة المحاولة.';
    }
    if (normalized.contains('request-closed')) {
      return 'تم إغلاق هذا الطلب ولا يمكن تعديله الآن.';
    }
    if (normalized.contains('donor-not-in-responses')) {
      return 'لا يمكن اعتماد متبرع لم يؤكد استجابته لهذا الطلب.';
    }
    if (normalized.contains('request-not-found')) {
      return 'الطلب غير موجود أو تم حذفه.';
    }
    if (normalized.contains('no-assigned-donor')) {
      return 'لا يوجد متبرع مؤكد حالياً لفك الإسناد.';
    }
    if (normalized.contains('already-assigned')) {
      return 'تم اعتماد متبرع لهذه الحالة بالفعل.';
    }
    if (normalized.contains('assigned-donor-cannot-withdraw')) {
      return 'لا يمكن إلغاء الاستجابة بعد اعتمادك رسمياً. يرجى التواصل مع الإدارة مباشرة.';
    }

    return fallback;
  }

  Future<void> _settleWorkerTaskCounterOnTerminalStatus(String? assignedUserId) async {
    if (assignedUserId == null || assignedUserId.isEmpty) return;

    final workerRef = _firestore.collection(AppConstants.usersCollection).doc(assignedUserId);
    await _firestore.runTransaction((tx) async {
      final workerSnap = await tx.get(workerRef);
      if (!workerSnap.exists) return;

      final workerData = workerSnap.data() as Map<String, dynamic>;
      if ((workerData['role'] ?? '').toString() != UserRole.worker.name) {
        return;
      }

      final currentTasks = ((workerData['currentTasksCount'] ?? 0) as num).toInt();
      final safeCurrentTasks = currentTasks > 0 ? currentTasks - 1 : 0;

      tx.update(workerRef, {
        'currentTasksCount': safeCurrentTasks,
        'isAvailable': safeCurrentTasks == 0,
        'lastActivity': FieldValue.serverTimestamp(),
      });
    });
  }

  // إحصائيات الرسوم البيانية
  RxList<Map<String, dynamic>> donationsLastSixMonths = <Map<String, dynamic>>[].obs;
  RxList<Map<String, dynamic>> serviceTypeDistribution = <Map<String, dynamic>>[].obs;
  RxList<Map<String, dynamic>> monthlyRequests = <Map<String, dynamic>>[].obs;

  // قوائم حية
  RxList<ServiceRequestModel> recentRequests = <ServiceRequestModel>[].obs;
  RxList<ServiceRequestModel> urgentRequests = <ServiceRequestModel>[].obs;
  RxList<DonationModel> recentDonations = <DonationModel>[].obs;

  // ✨ دار السبيل
  RxList<UserModel> darSabilManagers = <UserModel>[].obs;
  RxList<Map<String, dynamic>> darSabilTasks = <Map<String, dynamic>>[].obs;
  RxList<ServiceRequestModel> darSabilGuests = <ServiceRequestModel>[].obs;
  RxList<Map<String, dynamic>> darSabilSupplies = <Map<String, dynamic>>[].obs;
  RxMap<String, dynamic> darSabilSummary = <String, dynamic>{
    'guestsCount': 0,
    'tasksProgress': 0.0,
    'pendingTasks': 0,
    'lowSuppliesCount': 0,
  }.obs;
  RxList<ProjectModel> activeProjectsList = <ProjectModel>[].obs;
  RxList<WorkerUpdate> fieldUpdates = <WorkerUpdate>[].obs;
  RxList<UserModel> activeWorkersList = <UserModel>[].obs;
  RxMap<String, String> workerAvatarsCache = <String, String>{}.obs;
  RxList<StrategicGoalModel> activeGoals = <StrategicGoalModel>[].obs;
  
  StreamSubscription? _urgentRequestsSub;
  StreamSubscription? _broadcastsSub;
  final List<StreamSubscription> _statsSubs = [];
  bool _isRecalculating = false; // حارس لمنع التكرار

  @override
  void onInit() {
    super.onInit();
    
    // مراقبة تغير حالة المستخدم لإعادة تشغيل المستمعات فور اكتمال التحميل
    ever(_authController.currentUser, (user) {
      if (isAnyAdmin) {
        _startLiveStatsListeners();
        listenToUrgentRequests();
      } else {
        _cancelAdminSubscriptions();
      }
    });

    if (isAnyAdmin) {
      _startLiveStatsListeners();
      loadDashboardData();
      listenToUrgentRequests();
    }
    _startBroadcastListener();
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
    _broadcastsSub?.cancel();
    for (final sub in _statsSubs) {
      sub.cancel();
    }
    _statsSubs.clear();
    super.onClose();
  }

  void _cancelAdminSubscriptions() {
    for (final sub in _statsSubs) {
      sub.cancel();
    }
    _statsSubs.clear();
    _urgentRequestsSub?.cancel();
    _urgentRequestsSub = null;
  }

  void _startLiveStatsListeners() {
    if (!isAnyAdmin) return;
    
    _cancelAdminSubscriptions();

    debugPrint('🛡️ AdminController: Starting Live Listeners. isSuperAdmin: $isSuperAdmin, isAnyAdmin: $isAnyAdmin');

    // --- 1. إحصائيات مالية (للمدير العام فقط من وثيقة الإحصائيات المركزية) ---
    _listenToDarSabilData();

    if (isSuperAdmin) {
      _statsSubs.add(
        _firestore.collection(AppConstants.donationsCollection).snapshots().listen((snap) {
          debugPrint('📊 AdminController: Donations snapshot received. Docs count: ${snap.docs.length}');
          if (snap.docs.isEmpty) {
            debugPrint('⚠️ AdminController: No donation documents found in the collection.');
          }
          double total = 0;
          for (var d in snap.docs) {
            final data = d.data();

            final status = (data['status'] ?? 'missing').toString().toLowerCase();
            final amountRaw = data['amount'] ?? 0;
            final isAdminRegistered = data['registeredByAdmin'] == true;

            double amount = 0;
            if (amountRaw is num) {
              amount = amountRaw.toDouble();
            } else {
              amount = double.tryParse(amountRaw.toString()) ?? 0;
            }

            final bool isCountable = status == 'confirmed' || status == 'completed' || isAdminRegistered;

            debugPrint('  - Doc ID: ${d.id}, Amount: $amount, Status: $status, IsAdmin: $isAdminRegistered, IsCountable: $isCountable');

            if (isCountable) {
              total += amount;
            }
          }
          debugPrint('✅ AdminController: Calculated Total Donations: $total');
          totalDonations.value = total.toInt();
          totalDonations.refresh();
        }, onError: (e) => debugPrint('❌ AdminController: Live global stats error: $e')),
      );
    }

    // --- 2. أحدث التبرعات ---
    _statsSubs.add(
      _firestore
          .collection(AppConstants.donationsCollection)
          .orderBy('date', descending: true)
          .limit(10)
          .snapshots()
          .listen((snap) {
        recentDonations.assignAll(
          snap.docs
              .map((d) => DonationModel.fromMap({...d.data(), 'id': d.id}))
              .toList(),
        );
      }, onError: (e) => debugPrint('Live recentDonations error: $e')),
    );

    // --- 3. الطلبات المعلقة والعدد الإجمالي ---
    _statsSubs.add(
      _firestore
          .collection(AppConstants.serviceRequestsCollection)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snap) => pendingRequests.value = snap.docs.length),
    );

    // --- 4. المشاريع النشطة وقائمة المشاريع ---
    _statsSubs.add(
      _firestore
          .collection(AppConstants.projectsCollection)
          .where('status', isEqualTo: 'active')
          .snapshots()
          .listen((snap) {
        activeProjects.value = snap.docs.length;
        activeProjectsList.assignAll(
          snap.docs
              .map((d) => ProjectModel.fromMap(d.data(), d.id))
              .toList(),
        );
      }, onError: (e) => debugPrint('Live activeProjects error: $e')),
    );

    // --- 5. المتطوعون المتاحون وقائمة المتطوعين ---
    _statsSubs.add(
      _firestore
          .collection(AppConstants.usersCollection)
          .where('role', isEqualTo: UserRole.worker.name)
          .where('isApproved', isEqualTo: true)
          .snapshots()
          .listen((snap) {
        availableWorkers.value = snap.docs.length;
        activeWorkersList.assignAll(
          snap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList(),
        );
      }),
    );

    // --- 6. المركبات المتاحة ---
    _statsSubs.add(
      _firestore
          .collection(AppConstants.vehiclesCollection)
          .where('isAvailable', isEqualTo: true)
          .snapshots()
          .listen((snap) => availableVehicles.value = snap.docs.length),
    );

    // --- 7. إجمالي المستفيدين ---
    _statsSubs.add(
      _firestore
          .collection(AppConstants.usersCollection)
          .where('role', isEqualTo: UserRole.beneficiary.name)
          .snapshots()
          .listen((snap) => totalBeneficiaries.value = snap.docs.length),
    );

    // --- 7.1 عداد المستخدمين الإجمالي (المسجلين) ---
    _statsSubs.add(
      _firestore
          .collection(AppConstants.usersCollection)
          .where('role', whereNotIn: ['rejected']) // استبعاد المرفوضين فقط
          .snapshots()
          .listen((snap) {
        totalRegisteredUsers.value = snap.docs.length;
        debugPrint('📊 AdminController: Total Registered Users: ${snap.docs.length}');
      }),
    );

    // --- 8. التوثيقات المعلقة ---
    _statsSubs.add(
      _firestore
          .collection(AppConstants.usersCollection)
          .where('isApproved', isEqualTo: true)
          .where('isVerified', isEqualTo: false)
          .snapshots()
          .listen((snap) {
            // تصفية المحتوى الذي يحتوي على صورة بطاقة الهوية فقط
            pendingVerificationsCount.value = snap.docs.where((doc) {
              final data = doc.data();
              return data['nationalIdUrl'] != null && data['nationalIdUrl'].toString().isNotEmpty;
            }).length;
          }),
    );

    // --- 9. أحدث الطلبات (Real-time List) ---
    _statsSubs.add(
      _firestore
          .collection(AppConstants.serviceRequestsCollection)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots()
          .listen((snap) {
        recentRequests.assignAll(
          snap.docs
              .map((d) => ServiceRequestModel.fromMap({...d.data(), 'id': d.id}))
              .toList(),
        );
      }, onError: (e) => debugPrint('Live recentRequests error: $e')),
    );

    // --- 9. تحديثات الميدان (Real-time Updates) ---
    _statsSubs.add(
      _firestore
          .collection('worker_updates')
          .orderBy('createdAt', descending: true)
          .limit(15)
          .snapshots()
          .listen((snap) {
        fieldUpdates.assignAll(
          snap.docs
              .map((d) => WorkerUpdate.fromMap(d.data(), d.id))
              .toList(),
        );
      }, onError: (e) => debugPrint('Live fieldUpdates error: $e')),
    );

    // --- 10. الأهداف التشغيلية (Real-time Goals) ---
    _statsSubs.add(
      _firestore
          .doc(AppConstants.strategicGoalsDoc)
          .snapshots()
          .listen((snap) {
        if (!snap.exists) {
          activeGoals.clear();
          return;
        }
        
        final data = snap.data();
        if (data == null || data['goals'] == null) {
          activeGoals.clear();
          return;
        }

        final Map<String, dynamic> goalsMap = Map<String, dynamic>.from(data['goals']);
        List<StrategicGoalModel> goals = [];
        
        for (var entry in goalsMap.entries) {
          var goalData = Map<String, dynamic>.from(entry.value);
          if (!(goalData['isActive'] ?? true)) continue;
          goals.add(StrategicGoalModel.fromMap(goalData, entry.key));
        }

        // ترتيب حسب حقل order إذا وجد، أو حسب ترتيب الإضافة
        activeGoals.assignAll(goals);
      }, onError: (e) => debugPrint('Live activeGoals error: $e')),
    );

    _listenToDarSabilData();
  }

  // تحميل كل بيانات الداشبورد (للبيانات غير اللحظية مثل الرسوم البيانية)
  Future<void> loadDashboardData() async {
    isLoading.value = true;
    try {
      // الملاحظة: البيانات اللحظية يتم التعامل معها عبر _startLiveStatsListeners في onInit
      if (currentUser?.role == UserRole.donor || currentUser?.role == UserRole.beneficiary) {
        // لا نحتاج لتحميل شيء إضافي هنا للمتبرع حالياً
      } else {
        // المسؤولون يحملون الرسوم البيانية فقط لأن الباقي لحظي
        await loadChartData();
      }
    } catch (e) {
      debugPrint('Dashboard loading error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> seedInitialData() async {
    if (!_requireSuperAdmin('تهيئة البيانات الأساسية')) return;
    isLoading.value = true;
    try {
      final serviceTypes = [
        {
          'id': 'funeral_transport',
          'name': 'إكرام الموتى (نقل)',
          'icon': 'airport_shuttle',
          'color': '#512DA8',
          'isActive': true,
          'popularity': 100,
          'fields': ['اسم المتوفى', 'مكان الاستلام', 'مكان التسليم', 'التاريخ والوقت'],
          'fieldConfigs': {'اسم المتوفى': 'text', 'مكان الاستلام': 'text', 'مكان التسليم': 'text', 'التاريخ والوقت': 'date'},
        },
        {
          'id': 'funeral_ghusl',
          'name': 'تغسيل الموتى',
          'icon': 'wash',
          'color': '#1976D2',
          'isActive': true,
          'popularity': 90,
          'fields': ['اسم المتوفى', 'جنس المتوفى', 'مكان الغسل', 'المستلزمات', 'رقم هاتف المنسق'],
          'fieldConfigs': {'اسم المتوفى': 'text', 'جنس المتوفى': 'selection', 'مكان الغسل': 'selection', 'المستلزمات': 'selection', 'رقم هاتف المنسق': 'text'},
        },
        {
          'id': 'food_aid',
          'name': 'مساعدات غذائية',
          'icon': 'shopping_basket',
          'color': '#2E7D32',
          'isActive': true,
          'popularity': 80,
          'fields': ['عدد أفراد العائلة', 'وصف الاحتياج', 'ولاية', 'بلدية'],
          'fieldConfigs': {'عدد أفراد العائلة': 'number', 'وصف الاحتياج': 'text', 'ولاية': 'selection', 'بلدية': 'selection'},
        },
        {
          'id': 'medical_aid',
          'name': 'مساعدة طبية',
          'icon': 'medication',
          'color': '#C62828',
          'isActive': true,
          'popularity': 85,
          'fields': ['الحالة الصحية', 'المستلزمات/الأدوية المطلوبة', 'المستشفى'],
          'fieldConfigs': {'الحالة الصحية': 'text', 'المستلزمات/الأدوية المطلوبة': 'text', 'المستشفى': 'text'},
        },
        {
          'id': 'financial_aid',
          'name': 'مساعدات مالية',
          'icon': 'payments',
          'color': '#D4AF37',
          'isActive': true,
          'popularity': 70,
          'fields': ['مبلغ الطلب', 'سبب الطلب', 'رقم هاتف'],
          'fieldConfigs': {'مبلغ الطلب': 'number', 'سبب الطلب': 'text', 'رقم هاتف': 'text'},
        },
        {
          'id': 'construction',
          'name': 'بناء وتعمير',
          'icon': 'home_work',
          'color': '#795548',
          'isActive': true,
          'popularity': 60,
          'fields': ['نوع العمل (بناء/ترميم)', 'وصف الحالة', 'العنوان بالتفصيل'],
          'fieldConfigs': {'نوع العمل (بناء/ترميم)': 'selection', 'وصف الحالة': 'text', 'العنوان بالتفصيل': 'text'},
        },
        {
          'id': 'education',
          'name': 'تعليم وكفالة طالب',
          'icon': 'menu_book',
          'color': '#0097A7',
          'isActive': true,
          'popularity': 50,
          'fields': ['عدد الطلاب', 'المستوى الدراسي', 'الاحتياجات'],
          'fieldConfigs': {'عدد الطلاب': 'number', 'المستوى الدراسي': 'text', 'الاحتياجات': 'text'},
        },
        {
          'id': 'dar_sabil',
          'name': 'دار السبيل أدرار',
          'icon': 'home_rounded',
          'color': '#455A64',
          'isActive': true,
          'popularity': 45,
          'fields': ['الاسم الكامل', 'الغرض من الإقامة', 'تاريخ الوصول', 'المدة المتوقعة'],
          'fieldConfigs': {'الاسم الكامل': 'text', 'الغرض من الإقامة': 'text', 'تاريخ الوصول': 'date', 'المدة المتوقعة': 'text'},
        },
        {
          'id': 'water_supply',
          'name': 'سقي الماء',
          'icon': 'water_drop',
          'color': '#0288D1',
          'isActive': true,
          'popularity': 40,
          'fields': ['المنطقة/الحي', 'الكمية المطلوبة', 'رقم هاتف التواصل'],
          'fieldConfigs': {'المنطقة/الحي': 'text', 'الكمية المطلوبة': 'text', 'رقم هاتف التواصل': 'text'},
        },
        {
          'id': 'orphans_care',
          'name': 'كفالة اليتيم',
          'icon': 'volunteer_activism',
          'color': '#E91E63',
          'isActive': true,
          'popularity': 55,
          'fields': ['عدد الأيتام', 'الأعمار', 'نوع الكفالة'],
          'fieldConfigs': {'عدد الأيتام': 'number', 'الأعمار': 'text', 'نوع الكفالة': 'text'},
        },
        {
          'id': 'blood_donation',
          'name': 'إغاثة بقطرة دم',
          'icon': 'bloodtype',
          'color': '#C62828',
          'isActive': true,
          'popularity': 95,
          'fields': ['اسم المريض', 'الفصيلة', 'المستشفى', 'رقم الهاتف'],
          'fieldConfigs': {'اسم المريض': 'text', 'الفصيلة': 'selection', 'المستشفى': 'text', 'رقم الهاتف': 'text'},
        },
        {
          'id': 'other',
          'name': 'أبواب خير أخرى',
          'icon': 'more_horiz',
          'color': '#607D8B',
          'isActive': true,
          'popularity': 0,
          'fields': ['مسمى الخدمة', 'وصف الطلب بالتفصيل'],
          'fieldConfigs': {'مسمى الخدمة': 'text', 'وصف الطلب بالتفصيل': 'text'},
        }
      ];

      final WriteBatch batch = _firestore.batch();
      
      // ✨ مسح الخدمات القديمة المكررة التي قد تكون بأسماء مختلفة بدلاً من IDs
      // سنقوم بمسح المساعدة الطبية القديمة "الرعاية الطبية" if exists
      // لكن الأفضل أن نقوم بمسح المجموعة بالكامل أو overwrite بالمعرفات
      for (var service in serviceTypes) {
        final id = service['id'] as String;
        final data = Map<String, dynamic>.from(service);
        data.remove('id');
        data['createdAt'] = FieldValue.serverTimestamp();
        
        batch.set(_firestore.collection('service_types').doc(id), data);
      }

      await batch.commit();
      await initializeVersionConfig(silent: true);

      Get.snackbar('✅ تمت الاستعادة', 'تمت استعادة كافة الخدمات (بما فيها دار السبيل) بكامل حقولها وتفعيل الميزات الذكية بنجاح.',
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
          snackPosition: SnackPosition.TOP,
          colorText: AppTheme.successColor);

      loadDashboardData();
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في استعادة البيانات: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void listenToUrgentRequests() {
    if (!isAnyAdmin) {
      _urgentRequestsSub?.cancel();
      urgentRequests.clear();
      unseenUrgentCount.value = 0;
      return;
    }

    _urgentRequestsSub = _firestore
        .collection(AppConstants.serviceRequestsCollection)
        .where('urgency', whereIn: ['urgent', 'emergency'])
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      urgentRequests.assignAll(snap.docs.map((d) => ServiceRequestModel.fromMap({...d.data(), 'id': d.id})).toList());
      unseenUrgentCount.value = urgentRequests.where((r) => !r.isSeenByAdmin).length;
    }, onError: (error) {
      debugPrint('Urgent requests listener error: $error');
      urgentRequests.clear();
      unseenUrgentCount.value = 0;
    });
  }

  Future<void> markAllUrgentAsSeen() async {
    if (unseenUrgentCount.value == 0) return;
    try {
      WriteBatch batch = _firestore.batch();
      for (var req in urgentRequests) {
        if (!req.isSeenByAdmin) {
          batch.update(_firestore.collection(AppConstants.serviceRequestsCollection).doc(req.id),
            {'isSeenByAdmin': true});
        }
      }
      await batch.commit();
      unseenUrgentCount.value = 0;
    } catch (e) {
      debugPrint('Error marking urgent requests as seen: $e');
    }
  }



  Future<void> deleteFieldUpdate(String updateId) async {
    if (!isAnyAdmin) return;
    try {
      isLoading.value = true;
      await _firestore.collection('worker_updates').doc(updateId).delete();
      
      Get.snackbar('✅ تم الحذف', 'تم حذف التحديث من نبض الميدان بنجاح.',
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
          colorText: AppTheme.successColor);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في حذف التحديث: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteDonation(DonationModel donation) async {
    if (!isSuperAdmin) {
      Get.snackbar('❌ وصول مرفوض', 'عذراً، هذه الصلاحية محصورة للمنسق العام فقط.',
        backgroundColor: Colors.red.withValues(alpha: 0.1),
        colorText: Colors.red);
      return;
    }

    try {
      isLoading.value = true;
      final WriteBatch batch = _firestore.batch();

      // 1. حذف وثيقة التبرع
      batch.delete(_firestore.collection(AppConstants.donationsCollection).doc(donation.id));

      // 2. تحديث إحصائيات المشروع (إن وجد)
      try {
        if (donation.projectId != 'general') {
          final projectDoc = await _firestore.collection(AppConstants.projectsCollection).doc(donation.projectId).get();
          if (projectDoc.exists) {
            batch.update(_firestore.collection(AppConstants.projectsCollection).doc(donation.projectId), {
              'collected': FieldValue.increment(-donation.amount),
              'donorsCount': FieldValue.increment(-1),
            });
          }
        }
      } catch (e) {
        debugPrint('Project stats update skipped: $e');
      }

      // 3. تحديث الإحصائيات العالمية باستخدام set(merge: true) لتجنب خطأ not-found
      batch.set(_firestore.collection('stats').doc('global'), {
        'totalDonations': FieldValue.increment(-donation.amount),
      }, SetOptions(merge: true));

      await batch.commit();
      
      Get.snackbar('✅ تم الحذف', 'تم حذف التبرع وتحديث كافة الإحصائيات المرتبطة به بنجاح.',
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
          colorText: AppTheme.successColor);
      
      // تحديث البيانات في لوحة التحكم
      await loadDashboardData();
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في حذف التبرع: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> clearDonationProof(String donationId) async {
    try {
      isLoading.value = true;
      await _firestore
          .collection(AppConstants.donationsCollection)
          .doc(donationId)
          .update({
            'proofImageUrl': FieldValue.delete(),
            'proofImageId': FieldValue.delete(),
          });
      
      // التحديث المحلي للقائمة إذا كانت موجودة
      final index = recentDonations.indexWhere((d) => d.id == donationId);
      if (index != -1) {
        recentDonations[index] = recentDonations[index].copyWith(proofImageUrl: null, proofImageId: null);
      }
      
      Get.snackbar('✅ نجاح', 'تم مسح إثبات التبرع وتوفير المساحة بنجاح.',
        backgroundColor: AppTheme.successColor.withValues(alpha: 0.1),
        colorText: AppTheme.successColor);
    } catch (e) {
      Get.snackbar('❌ خطأ', 'فشل مسح الإثبات: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> removeRequestAttachment(String requestId, String attachmentUrl) async {
    if (!isSuperAdmin) {
      Get.snackbar('❌ وصول مرفوض', 'عذراً، هذه الصلاحية محصورة للمنسق العام فقط.',
        backgroundColor: Colors.red.withValues(alpha: 0.1),
        colorText: Colors.red);
      return;
    }

    try {
      isLoading.value = true;
      await _firestore
          .collection(AppConstants.serviceRequestsCollection)
          .doc(requestId)
          .update({
            'attachments': FieldValue.arrayRemove([attachmentUrl]),
          });
      
      Get.snackbar('✅ نجاح', 'تم حذف المرفق بنجاح.',
        backgroundColor: AppTheme.successColor.withValues(alpha: 0.1),
        colorText: AppTheme.successColor);
    } catch (e) {
      Get.snackbar('❌ خطأ', 'فشل حذف المرفق: ${_localizedErrorMessage(e)}');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> registerAdminDonation({
    required String donorName,
    required double amount,
    required String method,
    required String projectId,
    required String projectName,
    bool requestPrayerPost = false,
    String? prayerType,
    String? prayerTarget,
    String? prayerColor,
    String? prayerAction,
    String? prayerCustomMessage,
  }) async {
    final normalizedMethod = DonationModel.normalizeMethod(method);
    final donationRef = _firestore.collection(AppConstants.donationsCollection).doc();
    final statsRef = _firestore.collection('stats').doc('global');

    final donationData = {
      'donorId': 'admin_registered',
      'donorName': donorName,
      'amount': amount,
      'projectId': projectId,
      'projectName': projectName,
      'method': normalizedMethod,
      'paymentMethod': normalizedMethod,
      'isAnonymous': false,
      'status': 'confirmed',
      'registeredByAdmin': true,
      'requestPrayerPost': requestPrayerPost,
      'prayerType': prayerType,
      'prayerTarget': prayerTarget,
      'prayerColor': prayerColor,
      'prayerAction': prayerAction,
      'prayerCustomMessage': prayerCustomMessage,
      'date': FieldValue.serverTimestamp(),
    };

    await _firestore.runTransaction((tx) async {
      if (projectId != 'general') {
        final projectRef = _firestore.collection(AppConstants.projectsCollection).doc(projectId);
        final projectSnap = await tx.get(projectRef);

        if (!projectSnap.exists) {
          throw Exception('المشروع المحدد غير موجود');
        }

        final projectData = projectSnap.data() as Map<String, dynamic>;
        if (projectData['status'] != 'active') {
          throw Exception('لا يمكن التبرع لمشروع غير نشط');
        }

        final currentCollected = ((projectData['collected'] ?? 0) as num).toDouble();
        final budget = ((projectData['budget'] ?? 0) as num).toDouble();
        final nextCollected = currentCollected + amount;

        final Map<String, dynamic> projectUpdates = {
          'collected': FieldValue.increment(amount),
          'donorsCount': FieldValue.increment(1),
        };

        if (budget > 0 && nextCollected >= budget) {
          projectUpdates['status'] = 'completed';
          projectUpdates['completedAt'] = FieldValue.serverTimestamp();
        }

        tx.update(projectRef, projectUpdates);
      }

      tx.set(donationRef, donationData);
      tx.set(
        statsRef,
        {'totalDonations': FieldValue.increment(amount)},
        SetOptions(merge: true),
      );
    });
  }

    Future<void> recalculateGlobalDonations() async {
    if (_isRecalculating) return; // منع التنفيذ المتزامن
    _isRecalculating = true;
    try {
      debugPrint('🧮 AdminController: Manual Recalculation Started...');
      final snap = await _firestore.collection(AppConstants.donationsCollection).get();
      debugPrint('🧮 AdminController: Found ${snap.docs.length} donation documents.');
      
      double total = 0;
      for (var d in snap.docs) {
        final data = d.data();
        // نقبل كلاً من الحالات المؤكدة والمكتملة والتبرعات المسجلة إدارياً وأيضاً المعلقة
        final status = (data['status'] ?? '').toString().toLowerCase();
        final amountRaw = data['amount'] ?? 0;

        // تحويل القيمة بصورة آمنة مهما كان نوعها (double, int, String)
        double amount = 0;
        if (amountRaw is num) {
          amount = amountRaw.toDouble();
        } else {
          amount = double.tryParse(amountRaw.toString()) ?? 0;
        }

        if (status == 'confirmed' || status == 'completed' || data['registeredByAdmin'] == true || status == 'pending') {
          total += amount;
        }
      }
      
      totalDonations.value = total.toInt();
      totalDonations.refresh(); // لضمان تحديث Obx في الواجهة
      debugPrint('🧮 AdminController: Manual Recalculation Finished. Total: $total');

      // تحديث الوثيقة المركزية لتصل لكافة الأطراف
      await _firestore.collection('stats').doc('global').set({
        'totalDonations': total,
        'lastRecalculatedAt': FieldValue.serverTimestamp(),
        'recalculatedBy': currentUser?.id,
      }, SetOptions(merge: true));
      
    } catch (e) {
      debugPrint('❌ AdminController: Recalculate Error: $e');
    } finally {
      _isRecalculating = false;
    }
    }

  Future<void> loadRecentDonations() async {
    try {
      final bool isAdminUser = _authController.currentUser.value?.role == UserRole.admin || 
                               _authController.currentUser.value?.role == UserRole.superAdmin;
      final String uid = _authController.currentUser.value?.id ?? '';

      Query query = _firestore.collection(AppConstants.donationsCollection);
      if (!isAdminUser) {
        query = query.where('donorId', isEqualTo: uid);
      }

      var snap = await query.orderBy('date', descending: true).limit(10).get();
      recentDonations.assignAll(snap.docs.map((d) => DonationModel.fromMap({...d.data() as Map<String, dynamic>, 'id': d.id})).toList());
    } catch (e) {
      debugPrint('Error loading recent donations: $e');
    }
  }

  Future<void> loadActiveProjects() async {
    try {
      var snap = await _firestore
          .collection(AppConstants.projectsCollection)
          .where('status', isEqualTo: 'active')
          .get();
      activeProjectsList.value = snap.docs.map((d) => ProjectModel.fromMap({...d.data(), 'id': d.id})).toList();
    } catch (e) {
      debugPrint('Error loading active projects: $e');
    }
  }

  Future<void> loadFieldUpdates() async {
    try {
      var snap = await _firestore
          .collection('worker_updates')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      fieldUpdates.value = snap.docs.map((d) => WorkerUpdate.fromMap(d.data(), d.id)).toList();

      Set<String?> workerIds = fieldUpdates.map((e) => e.workerId).toSet();
      for (var wId in workerIds) {
        if (wId != null && wId.isNotEmpty && !workerAvatarsCache.containsKey(wId)) {
          var userDoc = await _firestore.collection(AppConstants.usersCollection).doc(wId).get();
          if (userDoc.exists) {
            workerAvatarsCache[wId] = (userDoc.data() as Map<String, dynamic>)['profileImage'] ?? '';
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading field updates: $e');
      fieldUpdates.clear();
    }
  }

  // جلب بيانات الرسم البياني حسب الفترة والنوع
  Future<void> loadChartDataForMetric(MetricType type, String period) async {
    selectedPeriod.value = period;
    chartData.clear();
    chartLabels.clear();

    try {
      final now = DateTime.now();
      int count = 7;

      if (period == 'monthly') {
        count = 30;
      } else if (period == 'yearly') {
        count = 12;
      }

      List<double> values = List.filled(count, 0.0);
      List<String> labels = [];

      for (int i = count - 1; i >= 0; i--) {
        DateTime start;
        DateTime end;

        if (period == 'yearly') {
          start = DateTime(now.year, now.month - i, 1);
          end = DateTime(now.year, now.month - i + 1, 1);
          labels.add('${start.month}/${start.year.toString().substring(2)}');
        } else {
          start = DateTime(now.year, now.month, now.day - i);
          start = DateTime(start.year, start.month, start.day);
          end = start.add(const Duration(days: 1));
          final days = ['أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];
          labels.add(period == 'weekly' ? days[start.weekday % 7] : '${start.day}/${start.month}');
        }

        double val = 0;
        switch (type) {
          case MetricType.donations:
            final snap = await _firestore.collection(AppConstants.donationsCollection)
                .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                .where('date', isLessThan: Timestamp.fromDate(end))
                .get();
            val = snap.docs.fold(0.0, (acc, doc) => acc + ((doc.data()['amount'] ?? 0) as num).toDouble()) / 1000;
            break;
          case MetricType.requests:
            final snap = await _firestore.collection(AppConstants.serviceRequestsCollection)
                .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                .where('createdAt', isLessThan: Timestamp.fromDate(end))
                .get();
            val = snap.docs.length.toDouble();
            break;
          case MetricType.projects:
            final snap = await _firestore.collection(AppConstants.projectsCollection)
                .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                .where('createdAt', isLessThan: Timestamp.fromDate(end))
                .get();
            val = snap.docs.length.toDouble();
            break;
          case MetricType.team:
            final snap = await _firestore.collection('worker_updates')
                .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                .where('createdAt', isLessThan: Timestamp.fromDate(end))
                .get();
            val = snap.docs.length.toDouble();
            break;
        }
        values[count - 1 - i] = val;
      }

      chartData.assignAll(values);
      chartLabels.assignAll(labels);
    } catch (e) {
      debugPrint('Error loading metric chart data: $e');
    }
  }

  Future<void> loadChartData() async {
    // تم استبدال المنطق القديم بـ loadChartDataForMetric للتحليل التفصيلي
    // هذا التابع مخصص للإحصائيات العامة في الداشبورد الرئيسي
    try {
      final now = DateTime.now();
      final List<Map<String, dynamic>> sixMonthsData = [];
      final monthNames = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];

      if (isSuperAdmin || currentUser?.role == UserRole.donor) {
        final String? uid = currentUser?.id;
        for (int i = 5; i >= 0; i--) {
          final month = DateTime(now.year, now.month - i, 1);
          final nextMonth = DateTime(now.year, now.month - i + 1, 1);
          
          Query query = _firestore.collection(AppConstants.donationsCollection)
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(month))
            .where('date', isLessThan: Timestamp.fromDate(nextMonth));
          
          if (currentUser?.role == UserRole.donor && uid != null) {
            query = query.where('donorId', isEqualTo: uid);
          }

          final snap = await query.get();
          double total = snap.docs.fold(0.0, (s, d) => s + ((d.data() as Map)['amount'] ?? 0).toDouble());
          sixMonthsData.add({'month': monthNames[month.month - 1], 'amount': total / 1000});
        }
        donationsLastSixMonths.value = sixMonthsData;
      }

      // توزيع الخدمات
      // نجمع أسماء الخدمات أولاً لضمان ترجمة المعرفات (IDs)
      final serviceTypesSnap = await _firestore.collection('service_types').get();
      final Map<String, String> idToName = {
        for (var doc in serviceTypesSnap.docs) doc.id: (doc.data()['name'] ?? doc.id).toString()
      };

      final sinceSixMonthsTs = Timestamp.fromDate(now.subtract(const Duration(days: 180)));
      final requestsSnap = await _firestore.collection(AppConstants.serviceRequestsCollection)
          .where('createdAt', isGreaterThanOrEqualTo: sinceSixMonthsTs).get();

      final Map<String, int> typeCounts = {};
      for (var doc in requestsSnap.docs) {
        final type = doc.data()['type'] ?? 'other';
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }
      
      final totalRequests = typeCounts.values.fold(0, (a, b) => a + b);
      final colors = [Colors.blue, Colors.green, Colors.red, Colors.orange, Colors.purple, AppTheme.primaryGreen];
      int colorIdx = 0;
      
      serviceTypeDistribution.value = typeCounts.isEmpty ? [] : typeCounts.entries.map((e) {
               // نستخدم الاسم من الداتابيز إذا وجد، وإلا نستخدم الترجمة التقليدية
               final rawName = idToName[e.key] ?? e.key;
               final translatedName = AppConstants.translateServiceType(rawName);
               
               return {
                 'name': translatedName, 
                 'count': e.value,
                 'color': colors[colorIdx++ % colors.length],
                 'percentage': totalRequests > 0 ? ((e.value / totalRequests) * 100).toInt() : 0,
               };
             }).toList();

      // 3. الطلبات الشهرية الحالية (يومياً) - للبار تشارت في الداشبورد
      final startOfMonth = DateTime(now.year, now.month, 1);
      final monthSnap = await _firestore.collection(AppConstants.serviceRequestsCollection)
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

      // تحسين العرض ليشمل الأيام الحالية فقط مع ضمان ظهور الأعمدة بشكل لائق
      final int currentDay = now.day;
      monthlyRequests.value = List.generate(currentDay, (i) => {
        'day': i + 1,
        'count': dayCounts[i + 1] ?? 0,
      });

    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
    }
  }

  Future<void> approveUser(String userId, dynamic role, {List<String>? additionalRoles, bool? canManageDarSabil}) async {
    if (!_requireSuperAdmin('الموافقة على المستخدمين')) return;
    try {
      String roleStr = role is UserRole ? role.name : role.toString();
      if (!_isValidRoleName(roleStr)) {
        Get.snackbar('❌ خطأ', 'رتبة غير صالحة: $roleStr');
        return;
      }
      
      Map<String, dynamic> updateData = {
        'isApproved': true,
        'role': roleStr,
      };
      
      if (additionalRoles != null) {
        updateData['additionalRoles'] = additionalRoles;
      }

      if (canManageDarSabil != null) {
        updateData['canManageDarSabil'] = canManageDarSabil;
        
        // ✨ التزامن مع وثيقة الإعدادات لضمان عمل القواعد الأمنية
        if (canManageDarSabil) {
          await _firestore.collection(AppConstants.darSabilMgmtCollection).doc('config').set({
            'managerIds': FieldValue.arrayUnion([userId])
          }, SetOptions(merge: true));
        } else {
          await _firestore.collection(AppConstants.darSabilMgmtCollection).doc('config').set({
            'managerIds': FieldValue.arrayRemove([userId])
          }, SetOptions(merge: true));
        }
      }

      await _firestore.collection(AppConstants.usersCollection).doc(userId).update(updateData);
      
      Get.snackbar('✅ تمت الموافقة', 'تم تفعيل الحساب بنجاح',
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
          colorText: AppTheme.successColor);
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء الموافقة: $e');
    }
  }

  // ✨ توثيق هوية المستخدم وتعيين كود العضوية
  Future<void> verifyUserIdentity(String userId) async {
    if (!_requireSuperAdmin('توثيق الهوية')) return;
    isLoading.value = true;
    try {
      final userRef = _firestore.collection(AppConstants.usersCollection).doc(userId);
      final userSnap = await userRef.get();
      
      if (!userSnap.exists) throw 'المستخدم غير موجود';
      
      final userData = userSnap.data() as Map<String, dynamic>;
      String? currentMemberId = userData['memberId'];
      
      await _firestore.runTransaction((tx) async {
        // إذا لم يكن لديه كود عضوية، نقوم بتوليد واحد
        if (currentMemberId?.isEmpty ?? true) {
          final counterRef = _firestore.collection('metadata').doc('user_counter');
          final counterSnap = await tx.get(counterRef);
          
          int newCount = 1;
          if (counterSnap.exists) {
            newCount = (counterSnap.data() as Map<String, dynamic>)['count'] + 1;
            tx.update(counterRef, {'count': newCount});
          } else {
            tx.set(counterRef, {'count': 1});
          }
          
          currentMemberId = 'nas${newCount.toString().padLeft(2, '0')}';
        }
        
        tx.update(userRef, {
          'isVerified': true,
          'memberId': currentMemberId,
          'verifiedAt': FieldValue.serverTimestamp(),
        });
      });

      // إرسال إشعار للمستخدم
      await NotificationService.sendNotification(
        userId: userId,
        type: 'status_change',
        title: '✨ تهانينا! تم توثيق هويتك',
        body: 'أهلاً بك كعضو موثق في الجمعية. رقم عضويتك الجديد هو: $currentMemberId',
        data: {
          'type': 'verification_success',
          'memberId': currentMemberId,
        },
      );

      Get.snackbar(
        '✅ تم التوثيق', 
        'تم توثيق هوية المستخدم وتعيين كود العضوية ($currentMemberId) بنجاح.',
        backgroundColor: AppTheme.successColor,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(15),
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل عملية التوثيق: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateAdditionalRoles(String userId, List<String> additionalRoles) async {
    if (!_requireSuperAdmin('تعديل الصلاحيات الإضافية')) return;
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(userId).update({
        'additionalRoles': additionalRoles,
      });
      Get.snackbar('✅ تم التحديث', 'تم تحديث الصلاحيات الإضافية بنجاح',
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
          colorText: AppTheme.successColor);
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر تحديث الصلاحيات: $e');
    }
  }

  Future<void> rejectUser(String userId) async {
    if (!_requireSuperAdmin('رفض المستخدمين')) return;
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

    Future<void> assignToWorker(String requestId, String workerId, {String? workerName, bool? isGuest}) async {
    if (!isSuperAdmin) {
      Get.snackbar('❌ وصول مرفوض', 'عذراً، صلاحية إسناد المهام محصورة للمنسق العام فقط.',
        backgroundColor: Colors.red.withValues(alpha: 0.1),
        colorText: Colors.red);
      return;
    }
    if (isLoading.value) return; // 🛡️ حماية الضغط المزدوج
    isLoading.value = true;
    try {
      final String collection = AppConstants.serviceRequestsCollection;
      final requestRef = _firestore.collection(collection).doc(requestId);
      final newWorkerRef = _firestore.collection(AppConstants.usersCollection).doc(workerId);

      await _firestore.runTransaction((tx) async {
        final requestSnap = await tx.get(requestRef);
        final newWorkerSnap = await tx.get(newWorkerRef);
        
        if (!requestSnap.exists) throw 'الطلب غير موجود';
        if (!newWorkerSnap.exists) throw 'المتطوع غير موجود';

        final requestData = requestSnap.data() as Map<String, dynamic>;
        final String? previousAssignedTo = requestData['assignedTo'];
        
        DocumentSnapshot? previousWorkerSnap;
        if (previousAssignedTo != null && previousAssignedTo.isNotEmpty) {
          previousWorkerSnap = await tx.get(_firestore.collection(AppConstants.usersCollection).doc(previousAssignedTo));
        }

        tx.update(requestRef, {
          'assignedTo': workerId,
          'assignedToName': workerName ?? (newWorkerSnap.data() as Map<String, dynamic>)['name'],
          'status': 'in_progress',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (previousAssignedTo != workerId) {
          tx.update(newWorkerRef, {
            'currentTasksCount': FieldValue.increment(1),
            'isAvailable': false,
            'lastActivity': FieldValue.serverTimestamp(),
          });

          if (previousWorkerSnap != null && previousWorkerSnap.exists) {
            final previousWorkerData = previousWorkerSnap.data() as Map<String, dynamic>;
            if ((previousWorkerData['role'] ?? '').toString() == UserRole.worker.name) {
              final previousCount = ((previousWorkerData['currentTasksCount'] ?? 0) as num).toInt();
              final safePreviousCount = previousCount > 0 ? previousCount - 1 : 0;
              tx.update(previousWorkerSnap.reference, {
                'currentTasksCount': safePreviousCount,
                'isAvailable': safePreviousCount == 0,
                'lastActivity': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      });

      await _sendNotificationToUser(workerId, 'مهمة جديدة', 'تم إسناد طلب خدمة إليك', type: 'request_update', data: {'requestId': requestId});
      Get.snackbar('تم الإسناد', 'تم إسناد المهمة بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> assignRequestToWorker(String requestId, String workerId, {bool? isGuest}) => assignToWorker(requestId, workerId, isGuest: isGuest);
  Future<void> assignRequestToVehicle(String requestId, String vehicleId, {bool? isGuest}) => assignToVehicle(requestId, vehicleId, isGuest: isGuest);

    Future<void> assignToVehicle(String requestId, String vehicleId, {bool? isGuest}) async {
    if (!isSuperAdmin) {
      Get.snackbar('❌ وصول مرفوض', 'عذراً، صلاحية إسناد السيارات محصورة للمنسق العام فقط.',
        backgroundColor: Colors.red.withValues(alpha: 0.1),
        colorText: Colors.red);
      return;
    }
    if (isLoading.value) return; // 🛡️ حماية الضغط المزدوج
    isLoading.value = true;
    try {
      String collection = AppConstants.serviceRequestsCollection;
      await _firestore.collection(collection).doc(requestId).update({
        'assignedCarId': vehicleId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      Get.snackbar('تم الإسناد', 'تم تخصيص السيارة للطلب');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إسناد السيارة: $e');
    } finally {
      isLoading.value = false;
    }
    }

    Future<void> updateRequestStatus(String id, String status, {bool? isGuest}) async {
    if (!isSuperAdmin) {
      Get.snackbar('❌ وصول مرفوض', 'عذراً، صلاحية تغيير حالة وتأكيد الطلبات محصورة للمنسق العام فقط.',
        backgroundColor: Colors.red.withValues(alpha: 0.1),
        colorText: Colors.red);
      return;
    }
    if (isLoading.value) return; // 🛡️ حماية الضغط المزدوج
    isLoading.value = true;
    try {
      String collection = AppConstants.serviceRequestsCollection;
      final doc = await _firestore.collection(collection).doc(id).get();
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final currentStatus = (data['status'] ?? '').toString();
      final terminalStatuses = {'completed', 'rejected', 'cancelled'};
      final wasTerminal = terminalStatuses.contains(currentStatus);

      if (currentStatus == status) {
        Get.snackbar('تنبيه', 'الطلب بالحالة نفسها بالفعل');
        return;
      }

      await _firestore.collection(collection).doc(id).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (status == 'completed' || status == 'rejected' || status == 'cancelled') {
        final responses = data['donorResponses'] ?? [];
        final batch = _firestore.batch();
        for (var response in responses) {
          final uId = response['userId'];
          if (uId != null) {
            batch.update(_firestore.collection(AppConstants.usersCollection).doc(uId), {
              'activeBloodRequestId': FieldValue.delete(),
            });
          }
        }
        await batch.commit();

        if (!wasTerminal) {
          await _settleWorkerTaskCounterOnTerminalStatus(data['assignedTo']?.toString());
        }

        final currentUserId = _authController.currentUser.value?.id;
        if (currentUserId != null && responses.any((r) => r['userId'] == currentUserId)) {
          final user = _authController.currentUser.value!;
          final map = user.toMap();
          map.remove('activeBloodRequestId');
          _authController.currentUser.value = UserModel.fromMap(map, user.id);
          _authController.currentUser.refresh();
        }
      }

      if (status == 'completed') {
        String? vehicleId = data['assignedCarId'];
        if (vehicleId != null) {
          await _firestore.collection(AppConstants.vehiclesCollection).doc(vehicleId).update({'isAvailable': true});
        }
        final String serviceType = data['type'] ?? '';
        String? donorId = data['assignedTo'];
        final List<dynamic> responsesData = data['donorResponses'] ?? [];
        if ((donorId == null || donorId.isEmpty) && responsesData.isNotEmpty) {
           donorId = (responsesData.first['userId'] ?? '').toString();
           String donorName = (responsesData.first['userName'] ?? '').toString();
           if (donorName.isEmpty || donorName == 'متبرع') {
              final userSnap = await _firestore.collection(AppConstants.usersCollection).doc(donorId).get();
              donorName = userSnap.exists ? (userSnap.data() as Map<String, dynamic>)['name']?.toString() ?? 'متبرع' : 'متبرع';
           }
           await _firestore.collection(collection).doc(id).update({
             'assignedTo': donorId,
             'assignedToName': donorName,
           });
        }
        if ((serviceType == 'blood_donation' || serviceType == 'blood_emergency' || data['typeName']?.toString().contains('الدم') == true) && donorId != null && donorId.isNotEmpty) {
            await confirmDonation(donorId);
        }
      }
      
      if (data['requesterId'] != null) {
        String title = 'تحديث حالة الطلب';
        String body = '';
        String serviceName = data['typeName'] ?? 'الخدمة';
        if (status == 'in_progress') {
          body = '✨ أبشر، باشر إخوانك الآن تلبية النداء لـ ($serviceName)، نسأل الله التيسير.';
        } else if (status == 'completed') {
          body = '🕊️ الحمد لله، تم قضاء حاجتك بنجاح بخصوص ($serviceName). تقبل الله من الجميع.';
        } else if (status == 'rejected') {
          body = 'نعتذر، تعذر علينا تلبية طلبك لـ ($serviceName) حالياً.';
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
      
      // خروج تلقائي من صفحة التفاصيل عند الإتمام أو الرفض
      if (status == 'completed' || status == 'rejected' || status == 'cancelled') {
        Get.back();
      }
    } catch (e) {
      Get.snackbar('تعذر تحديث الطلب', _localizedErrorMessage(e, fallback: 'فشل تحديث حالة الطلب. يرجى المحاولة لاحقاً.'));
    } finally {
      isLoading.value = false;
    }
  }

    Future<void> deleteRequest(String id, {bool? isGuest}) async {
    if (!isSuperAdmin) {
      Get.snackbar('❌ وصول مرفوض', 'عذراً، صلاحية حذف الطلبات محصورة للمنسق العام فقط.',
        backgroundColor: Colors.red.withValues(alpha: 0.1),
        colorText: Colors.red);
      return;
    }
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      String collection = AppConstants.serviceRequestsCollection;
      final doc = await _firestore.collection(collection).doc(id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final responses = data['donorResponses'] ?? [];
        
        if (data['requesterId'] != null) {
          String serviceName = data['typeName'] ?? 'الخدمة';
          await NotificationService.sendNotification(
            userId: data['requesterId'],
            type: 'request_update',
            title: 'تم حذف طلبك',
            body: 'تم حذف طلبك الخاص بـ ($serviceName) من قبل الإدارة.',
          );
        }

        if (responses.isNotEmpty) {
          final batch = _firestore.batch();
          for (var response in responses) {
            final uId = response['userId'];
            if (uId != null) {
              batch.update(_firestore.collection(AppConstants.usersCollection).doc(uId), {
                'activeBloodRequestId': FieldValue.delete(),
              });
            }
          }
          await batch.commit();
        }
      }
      await _firestore.collection(collection).doc(id).delete();
      Get.back(); // العودة بعد الحذف
      Get.snackbar('🗑️ تم الحذف', 'تم حذف الطلب نهائياً');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل حذف الطلب: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addVehicle(VehicleModel vehicle) async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      await _firestore.collection(AppConstants.vehiclesCollection).doc(vehicle.id).set(vehicle.toMap());
      Get.snackbar("نجاح", "تمت إضافة السيارة");
    } catch (e) {
      Get.snackbar("خطأ", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateVehicle(VehicleModel vehicle) async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      await _firestore.collection(AppConstants.vehiclesCollection).doc(vehicle.id).update(vehicle.toMap());
      Get.snackbar("نجاح", "تم تحديث السيارة");
    } catch (e) {
      Get.snackbar("خطأ", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addServiceType(String name, String icon) async {
    if (!_requireSuperAdmin('إضافة نوع خدمة')) return;
    if (isLoading.value) return;
    isLoading.value = true;
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
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleServiceType(String id, bool isActive) async {
    if (!_requireSuperAdmin('تعديل نوع خدمة')) return;
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      await _firestore.collection(AppConstants.serviceTypesCollection).doc(id).update({
        'isActive': isActive,
      });
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
    } finally {
      isLoading.value = false;
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
    if (!_requireSuperAdmin('إضافة مشروع')) return;
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      await _firestore.collection(AppConstants.projectsCollection).add(newProject.toMap());
      await loadActiveProjects();
      Get.snackbar('✅ تمت الإضافة', 'تم إضافة المشروع بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ: $e');
    } finally {
      isLoading.value = false;
    }
  }

    Future<void> initializeVersionConfig({bool silent = false}) async {
    if (!_requireSuperAdmin('تهيئة إعدادات الإصدار')) return;
    isLoading.value = true;
    try {
      await _firestore.collection('app_config').doc('version').set({
        'currentVersion': '1.0.1',
        'buildNumber': 3,
        'minVersion': '1.0.1',
        'forceUpdate': false,
        'updateUrl': 'https://nas-al-khir-reggane.github.io/nas_alkhir_reggane/',
        'title': 'تحديث جديد متوفر',
        'message': 'يرجى تحديث التطبيق للحصول على آخر المميزات والتحسينات.',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!silent) {
        Get.snackbar('✅ تم التفعيل', 'تم تهيئة إعدادات التحديث بنجاح');
      }
    } catch (e) {
      if (!silent) {
        Get.snackbar('❌ خطأ', 'فشل تهيئة إعدادات التحديث: $e');
      }
    } finally {
      isLoading.value = false;
    }
    }

  List<String> getCompatibleDonors(String patientType) {
    // 🩸 تم التحديث ليكون دقيقاً جداً بناءً على طلب الإدارة: فقط نفس الزمرة
    return [patientType];
  }

  Future<void> sendTargetedBloodAlert({
    required String requestId,
    required String bloodType,
    required String hospital,
    required String phone,
    String? targetWilaya,
    String? targetCommune,
  }) async {
    try {
      isLoading.value = true;
      List<String> compatibleTypes = getCompatibleDonors(bloodType);
      Query query = _firestore.collection(AppConstants.usersCollection).where('bloodType', whereIn: compatibleTypes);
      final usersSnap = await query.get();

      final validDonors = usersSnap.docs.where((doc) {
        final userData = doc.data() as Map<String, dynamic>;
        if (userData['isApproved'] != true || userData['receiveBloodAlerts'] != true) return false;
        if (targetWilaya != null && targetWilaya.isNotEmpty) {
          final userWilaya = (userData['wilaya'] ?? '').toString();
          if (userWilaya != targetWilaya) return false;
        }
        if (targetCommune != null && targetCommune.isNotEmpty) {
          final userCommune = (userData['commune'] ?? '').toString();
          if (userCommune != targetCommune) return false;
        }
        if (userData['lastDonatedAt'] != null) {
          final lastDonation = (userData['lastDonatedAt'] as Timestamp).toDate();
          // 🧠 فترة استراحة ذكية: 60 يوماً للذكور، 90 يوماً للإناث
          final gender = userData['gender'] ?? 'غير محدد';
          final coolOffDays = (gender == 'ذكر') ? 60 : 90;
          final coolOffDate = DateTime.now().subtract(Duration(days: coolOffDays));
          if (lastDonation.isAfter(coolOffDate)) return false;
        }
        return true;
      }).toList();

      int count = 0;
      List<QueryDocumentSnapshot> notifiedDonors = [];
      for (var doc in validDonors) {
        if (doc.id == _authController.currentUser.value?.id) continue;
        await NotificationService.sendNotification(
          userId: doc.id,
          type: 'blood_emergency',
          title: '🚨 مطلوب متبرع فصيلة $bloodType',
          body: 'مريض في $hospital بانتظار فصيلة $bloodType. ساهم في الأجر.',
          data: {'requestId': requestId, 'bloodType': bloodType, 'hospital': hospital, 'phone': phone}
        );
        notifiedDonors.add(doc);
        count++;
      }
      if (count == 0) {
        Get.snackbar('لا يوجد مستجيبون حالياً', 'لم يتم العثور على متبرعين متاحين بنفس شروط الفصيلة والموقع حالياً.');
      } else {
        Get.snackbar('✅ تم الإرسال', 'تم إرسال نداء الاستغاثة إلى $count متبرع متوافق.');
        // تحديث الحالة في قاعدة البيانات لتثبيت القائمة
      final List<Map<String, dynamic>> notifiedDonorsData = notifiedDonors.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'متبرع',
          'phone': data['phone'] ?? '',
          'bloodType': data['bloodType'] ?? '',
        };
      }).toList();

      await _firestore
          .collection(AppConstants.serviceRequestsCollection)
          .doc(requestId)
          .update({'notifiedDonors': notifiedDonorsData});

      _showNotifiedDonorsList(notifiedDonors);
      }
    } catch (e) {
      Get.snackbar('تعذر إرسال النداء', _localizedErrorMessage(e, fallback: 'فشل إرسال نداء الاستغاثة. يرجى المحاولة لاحقاً.'));
    } finally {
      isLoading.value = false;
    }
  }

  /// ✨ تفعيل نداء حزب المائة ألف (تبرعات الطوارئ)
  Future<void> triggerHizbAlert({
    required String title,
    required String body,
    String? requestId,
    String? projectId,
  }) async {
    try {
      isLoading.value = true;
      
      // 1. جلب جميع المشتركين في الحزب
      final hizbMembers = await _firestore
          .collection('users')
          .where('isHizbMember', isEqualTo: true)
          .get();

      if (hizbMembers.docs.isEmpty) {
        Get.snackbar('تنبيه', 'لا يوجد أي مشتركين في حزب المائة ألف حالياً.');
        return;
      }

      // 2. إرسال الإشعارات
      await NotificationService.notifyUsers(
        userIds: hizbMembers.docs.map((doc) => doc.id).toList(),
        type: 'hizb_alert',
        title: title,
        body: body,
        data: {
          'requestId': requestId ?? '',
          'projectId': projectId ?? '',
          'minAmount': '1000',
          'suggestedAmount': '1000',
        },
      );

      // 3. تسجيل الإجراء في السجلات
      await _firestore.collection('hizb_alerts').add({
        'title': title,
        'body': body,
        'requestId': requestId,
        'projectId': projectId,
        'triggeredBy': FirebaseAuth.instance.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'recipientsCount': hizbMembers.docs.length,
      });

      Get.snackbar('✅ تم الإرسال', 'تم إرسال النداء إلى ${hizbMembers.docs.length} مشترك بنجاح.');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إرسال نداء الحزب: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// 📊 جلب بيانات ومتابعة حزب المائة ألف
  void listenToHizbMembers() {
    _hizbMembersSub?.cancel();
    _hizbMembersSub = _firestore
        .collection('users')
        .where('isHizbMember', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      hizbMembers.value = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> fetchHizbAlertsHistory() async {
    try {
      final snapshot = await _firestore
          .collection('hizb_alerts')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      
      hizbAlertsHistory.value = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error fetching Hizb alerts history: $e');
    }
  }

  Future<void> deleteHizbAlert(String id) async {
    try {
      await _firestore.collection('hizb_alerts').doc(id).delete();
      hizbAlertsHistory.removeWhere((alert) => alert['id'] == id);
      Get.snackbar('نجاح', 'تم حذف نداء الحزب من السجل بنجاح.');
    } catch (e) {
      debugPrint('Error deleting Hizb alert: $e');
      Get.snackbar('خطأ', 'حدث خطأ أثناء محاولة مسح هذا النداء.');
    }
  }

  /// 📢 إظهار نافذة إرسال نداء حزب المائة ألف
  void showHizbAlertDialog(BuildContext context, {String? requestId, String? projectId}) {
    final titleCtrl = TextEditingController(text: 'حالة طوارئ إنسانية');
    final bodyCtrl = TextEditingController(text: 'نحتاج لمساهمتكم العاجلة في حزب المائة ألف لتغطية حالة حرجة. جزاكم الله خيراً.');

    String? currentRequestId = requestId;
    String? currentProjectId = projectId;
    bool isProjectSelected = projectId != null || requestId == null; 

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.stars_rounded, color: AppTheme.goldAccent),
                const SizedBox(width: 8),
                Text('تفعيل نداء الحزب', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: AppTheme.inputDecoration('عنوان النداء', Icons.title),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyCtrl,
                    maxLines: 3,
                    decoration: AppTheme.inputDecoration('نص الرسالة', Icons.message),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(height: 16),
                  
                  // إظهار اختيار المشروع أو الطلب فقط إذا لم يكونا محددين مسبقاً
                  if (requestId == null && projectId == null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('مشروع', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            value: true,
                            groupValue: isProjectSelected,
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppTheme.goldAccent,
                            onChanged: (val) {
                              setState(() {
                                isProjectSelected = val!;
                                currentRequestId = null;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('طلب حالة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            value: false,
                            groupValue: isProjectSelected,
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppTheme.goldAccent,
                            onChanged: (val) {
                              setState(() {
                                isProjectSelected = val!;
                                currentProjectId = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isProjectSelected)
                      DropdownButtonFormField<String>(
                        initialValue: currentProjectId,
                        decoration: AppTheme.inputDecoration('اختر المشروع', Icons.folder),
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        items: activeProjectsList.map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name, overflow: TextOverflow.ellipsis, maxLines: 1),
                        )).toList(),
                        onChanged: (val) => setState(() => currentProjectId = val),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: currentRequestId,
                        decoration: AppTheme.inputDecoration('اختر الطلب', Icons.assignment),
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        items: recentRequests.map((r) => DropdownMenuItem(
                          value: r.id,
                          child: Text(r.typeName, overflow: TextOverflow.ellipsis, maxLines: 1),
                        )).toList(),
                        onChanged: (val) => setState(() => currentRequestId = val),
                      ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'سيتم إرسال هذا النداء لجميع المشتركين في حزب المائة ألف للمساهمة بـ 1000 دج.',
                    style: GoogleFonts.tajawal(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
              AppTheme.gradientButton(
                text: 'إرسال النداء الآن',
                onPressed: () async {
                  if (titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) {
                    Get.snackbar('خطأ', 'يرجى إكمال البيانات');
                    return;
                  }
                  if (requestId == null && projectId == null && currentRequestId == null && currentProjectId == null) {
                    Get.snackbar('خطأ', 'يرجى تحديد المشروع أو الطلب أولاً', 
                      backgroundColor: Colors.redAccent, colorText: Colors.white);
                    return;
                  }
                  
                  Get.back(); // إغلاق النافذة أولاً لتجنب التداخل مع ظهور الـ Snackbar
                  await triggerHizbAlert(
                    title: titleCtrl.text,
                    body: bodyCtrl.text,
                    requestId: currentRequestId,
                    projectId: currentProjectId,
                  );
                },
              ),
            ],
          );
        }
      ),
    );
  }

  void _showNotifiedDonorsList(List<QueryDocumentSnapshot> donors) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Get.theme.canvasColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المتبرعون الذين تم إشعارهم (${donors.length})',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Get.theme.textTheme.titleLarge?.color,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Get.theme.iconTheme.color),
                  onPressed: () => Get.back(),
                )
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: donors.length,
                itemBuilder: (context, index) {
                  final data = donors[index].data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'متبرع غير معروف';
                  final phone = data['phone'] ?? '';
                  final bloodType = data['bloodType'] ?? '';
                  final wilaya = data['wilaya'] ?? '';
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade100,
                      child: Text(bloodType, style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: Get.theme.textTheme.bodyLarge?.color)),
                    subtitle: Text(wilaya.isNotEmpty ? wilaya : 'لا يوجد ولاية', style: TextStyle(color: Get.theme.textTheme.bodySmall?.color)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (phone.toString().isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.call, color: Colors.green),
                            onPressed: () async {
                              final uri = Uri.parse('tel:$phone');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                          ),
                        if (phone.toString().isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.message, color: Colors.blue),
                            onPressed: () async {
                              final uri = Uri.parse('sms:$phone');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: false,
    );
  }


  Future<void> respondToBloodAlert({required String requestId, required String donorName, required String donorPhone}) async {
    if (isLoading.value) return; // 🛡️ حماية الضغط المزدوج
    isLoading.value = true;
    try {
      final docRef = _firestore.collection(AppConstants.serviceRequestsCollection).doc(requestId);
      final currentUserId = _authController.currentUser.value?.id;
      if (currentUserId == null || currentUserId.isEmpty) {
        return;
      }

      bool accepted = false;

      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) {
          throw Exception('request-not-found');
        }

        final data = snap.data() as Map<String, dynamic>;
        final status = (data['status'] ?? '').toString();
        final assignedTo = (data['assignedTo'] ?? '').toString();

        if (status == 'completed' || status == 'rejected' || status == 'cancelled') {
          throw Exception('request-closed');
        }
        if (assignedTo.isNotEmpty && assignedTo != currentUserId) {
          throw Exception('already-assigned');
        }

        final List<dynamic> existing = List<dynamic>.from(data['donorResponses'] ?? const []);
        final alreadyExists = existing.any((r) => (r['userId'] ?? '').toString() == currentUserId);

        if (!alreadyExists) {
          // محاولة جلب الاسم الحقيقي للمستخدم الحالي لضمان دقته
          final userSnap = await tx.get(_firestore.collection(AppConstants.usersCollection).doc(currentUserId));
          final realName = userSnap.exists ? (userSnap.data() as Map<String, dynamic>)['name']?.toString() ?? donorName : donorName;

          existing.add({
            'userName': realName,
            'userPhone': donorPhone,
            'respondedAt': Timestamp.now(),
            'userId': currentUserId,
          });
          tx.update(docRef, {
            'donorResponses': existing,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        accepted = true;
      });

      if (accepted) {
        Get.snackbar('تم التسجيل', 'شكراً لمبادرتك الطيبة، سيتم التواصل معك عند الحاجة.');
        
        // تحديث حالة المستخدم محلياً
        final user = _authController.currentUser.value;
        if (user != null) {
          _authController.currentUser.value = user.copyWith(activeBloodRequestId: requestId);
          _authController.currentUser.refresh();
        }
      }
    } catch (e) {
      Get.snackbar('خطأ', _localizedErrorMessage(e));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> withdrawBloodResponse({required String requestId}) async {
    final currentUserId = _authController.currentUser.value?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      throw Exception('unauthenticated');
    }

    final requestRef = _firestore.collection(AppConstants.serviceRequestsCollection).doc(requestId);

    await _firestore.runTransaction((tx) async {
      final reqSnap = await tx.get(requestRef);
      if (!reqSnap.exists) {
        throw Exception('request-not-found');
      }

      final data = reqSnap.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString();
      if (status == 'completed' || status == 'rejected' || status == 'cancelled') {
        throw Exception('request-closed');
      }

      final assignedTo = (data['assignedTo'] ?? '').toString();
      final existing = List<Map<String, dynamic>>.from(
        (data['donorResponses'] ?? const <dynamic>[]).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      existing.removeWhere((res) => (res['userId'] ?? '').toString() == currentUserId);

      final Map<String, dynamic> updates = {
        'donorResponses': existing,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (assignedTo == currentUserId) {
        // إذا كان هذا هو المتبرع المعتمد رسمياً وانسحب، نعيد الطلب لحالة الانتظار ونحذف الإسناد
        updates['status'] = 'pending';
        updates['assignedTo'] = FieldValue.delete();
      }

      tx.update(requestRef, updates);

      final userRef = _firestore.collection(AppConstants.usersCollection).doc(currentUserId);
      final userSnap = await tx.get(userRef);
      if (userSnap.exists) {
        tx.update(userRef, {
          'activeBloodRequestId': FieldValue.delete(),
          'lastActivity': FieldValue.serverTimestamp(),
        });
      }
    });

    final user = _authController.currentUser.value;
    if (user != null) {
      final map = user.toMap();
      map.remove('activeBloodRequestId');
      _authController.currentUser.value = UserModel.fromMap(map, user.id);
      _authController.currentUser.refresh();
    }
  }

  Future<void> notifyOtherDonors({required String requestId, required String bloodType, required String hospital, String? respondingDonorId}) async {
    try {
      List<String> compatibleTypes = getCompatibleDonors(bloodType);
      Query query = _firestore.collection(AppConstants.usersCollection).where('bloodType', whereIn: compatibleTypes);
      final usersSnap = await query.get();
      for (var doc in usersSnap.docs) {
        if (doc.id == respondingDonorId) continue;
        await NotificationService.sendNotification(
          userId: doc.id,
          type: 'blood_encouragement',
          title: '🩸 تحديث نداء التبرع بالدم',
          body: 'تم تسجيل استجابة أولية لنداء فصيلة $bloodType في $hospital. لا يزال احتياط المتبرعين مهماً عند الحاجة.',
        );
      }
    } catch (e) {
      debugPrint('NotifyOthers Error: $e');
    }
  }

    Future<void> forceAssignDonor({required String requestId, required String donorId, required String donorName, required String donorPhone}) async {
    if (!isSuperAdmin) {
      Get.snackbar('❌ وصول مرفوض', 'عذراً، تعيين المتبرعين محصور للمنسق العام فقط.',
        backgroundColor: Colors.red.withValues(alpha: 0.1),
        colorText: Colors.red);
      return;
    }
    try {
      isLoading.value = true;
      final docRef = _firestore.collection(AppConstants.serviceRequestsCollection).doc(requestId);
      
      final docSnap = await docRef.get();
      if (!docSnap.exists) throw Exception('request-not-found');
      
      final data = docSnap.data() as Map<String, dynamic>;
      final String existingAssignedId = (data['assignedTo'] ?? '').toString();
      if (existingAssignedId.isNotEmpty && existingAssignedId != donorId) {
        throw Exception('request-already-covered');
      }

      final List<dynamic> existing = List<dynamic>.from(data['donorResponses'] ?? const []);
      final alreadyExists = existing.any((r) => (r['userId'] ?? '').toString() == donorId);
      
      if (!alreadyExists) {
        // جلب الاسم الحقيقي للمستخدم لضمان الدقة وتجنب "متبرع"
        final userSnap = await _firestore.collection(AppConstants.usersCollection).doc(donorId).get();
        final realName = userSnap.exists ? (userSnap.data() as Map<String, dynamic>)['name']?.toString() ?? donorName : donorName;

        existing.add({
          'userName': realName,
          'userPhone': donorPhone,
          'respondedAt': Timestamp.now(),
          'userId': donorId,
        });
        await docRef.update({
          'donorResponses': existing,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // تأكيد المتبرع بالاسم الحقيقي
        await confirmDonor(
          requestId: requestId,
          donorId: donorId,
          donorName: realName,
        );
      } else {
        await confirmDonor(
          requestId: requestId,
          donorId: donorId,
          donorName: donorName,
        );
      }
    } catch (e) {
      Get.snackbar('تعذر الإسناد المباشر', _localizedErrorMessage(e, fallback: 'فشل إسناد المتبرع. يرجى المحاولة مرة أخرى.'));
    } finally {
      isLoading.value = false;
    }
  }

    Future<void> confirmDonor({required String requestId, required String donorId, required String donorName}) async {
    if (!isSuperAdmin) {
      Get.snackbar('❌ وصول مرفوض', 'عذراً، اعتماد المتبرعين محصور للمنسق العام فقط.',
        backgroundColor: Colors.red.withValues(alpha: 0.1),
        colorText: Colors.red);
      return;
    }
    if (isLoading.value) return; // 🛡️ منع الضغط المتكرر
    try {
      isLoading.value = true;
      final requestRef = _firestore.collection(AppConstants.serviceRequestsCollection).doc(requestId);
      Map<String, dynamic> reqData = <String, dynamic>{};
      String resolvedDonorName = donorName.trim();

      await _firestore.runTransaction((tx) async {
        // 1. القراءات (Reads)
        final reqSnap = await tx.get(requestRef);
        if (!reqSnap.exists) {
          throw Exception('request-not-found');
        }

        reqData = reqSnap.data() as Map<String, dynamic>;
        final currentStatus = (reqData['status'] ?? '').toString();
        if (currentStatus == 'completed' || currentStatus == 'rejected' || currentStatus == 'cancelled') {
          throw Exception('request-closed');
        }

        final List<Map<String, dynamic>> assignedDonors = List<Map<String, dynamic>>.from(
          reqData['assignedDonors'] ?? reqData['assigned_donors'] ?? []
        );

        // 🛡️ منع تكرار نفس المتبرع
        if (assignedDonors.any((d) => d['id'] == donorId)) {
          throw Exception('already-assigned');
        }

        final responses = ((reqData['donorResponses'] ?? const []) as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        final selectedResponse = responses.where((res) => (res['userId'] ?? '').toString() == donorId).toList();
        if (selectedResponse.isEmpty) {
          throw Exception('donor-not-in-responses');
        }

        // جلب وثيقة المتبرع المختار أولاً كجزء من القراءات
        final selectedDonorRef = _firestore.collection(AppConstants.usersCollection).doc(donorId);
        final selectedDonorSnap = await tx.get(selectedDonorRef);

        final nameFromResponse = (selectedResponse.first['userName'] ?? '').toString().trim();
        final nameFromUserDoc = selectedDonorSnap.exists ? (selectedDonorSnap.data() as Map<String, dynamic>)['name']?.toString() ?? '' : '';

        if (resolvedDonorName.isEmpty || resolvedDonorName == 'متبرع') {
          if (nameFromUserDoc.isNotEmpty) {
            resolvedDonorName = nameFromUserDoc;
          } else if (nameFromResponse.isNotEmpty) {
            resolvedDonorName = nameFromResponse;
          } else {
            resolvedDonorName = 'متبرع';
          }
        }

        // 2. الكتابات (Writes)
        assignedDonors.add({
          'id': donorId,
          'name': resolvedDonorName,
          'confirmedAt': Timestamp.now(),
        });

        final requiredCount = (reqData['requiredDonorsCount'] ?? 1) as int;
        final bool isFullyCovered = assignedDonors.length >= requiredCount;

        tx.update(requestRef, {
          'assignedDonors': assignedDonors,
          'assignedTo': donorId, // للحفاظ على التوافق مع الأنظمة الأخرى، نضع آخر معتمد
          'assignedToName': resolvedDonorName,
          'status': isFullyCovered ? 'in_progress' : 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (selectedDonorSnap.exists) {
          tx.update(selectedDonorSnap.reference, {
            'activeBloodRequestId': requestId,
            'lastActivity': FieldValue.serverTimestamp(),
          });
        }
      });

      final bloodType = (reqData['bloodType'] ?? reqData['details']?['الفصيلة'] ?? reqData['details']?['bloodType'] ?? '').toString();
      final hospital = (reqData['hospital'] ?? reqData['details']?['المستشفى'] ?? reqData['details']?['hospital'] ?? '').toString();
      final phone = (reqData['phone'] ?? reqData['details']?['رقم الهاتف'] ?? reqData['details']?['phone'] ?? '').toString();

      // 3. الإشعارات
      final bool isFullyCovered = (reqData['assignedDonors'] ?? []).length >= (reqData['requiredDonorsCount'] ?? 1);

      await NotificationService.sendNotification(
        userId: donorId,
        type: 'donor_confirmed',
        title: '✅ تم اعتمادك للتبرع',
        body: 'تم اعتمادك رسمياً لهذه الحالة. يرجى التوجه فوراً والتنسيق مع الجهة الطبية.',
        data: {
          'requestId': requestId,
          'bloodType': bloodType,
          'hospital': hospital,
          'phone': phone,
        },
      );

      final requesterId = (reqData['requesterId'] ?? '').toString();
      if (requesterId.isNotEmpty) {
        await NotificationService.sendNotification(
          userId: requesterId,
          type: 'request_update',
          title: '🫀 تم اعتماد متبرع جديد للحالة',
          body: isFullyCovered 
            ? 'الحمد لله، تم تأمين العدد المطلوب من المتبرعين لهذه الحالة.'
            : 'تم اعتماد ($resolvedDonorName) وجاري البحث عن بقية المتبرعين.',
          data: {
            'requestId': requestId,
            'bloodType': bloodType,
            'hospital': hospital,
            'donorName': resolvedDonorName,
          },
        );
      }

      Get.snackbar('✅ تم', 'تم اعتماد المتبرع ($resolvedDonorName) وإخطار جميع الأطراف المعنية.');
    } catch (e) {
      Get.snackbar('تعذر اعتماد المتبرع', _localizedErrorMessage(e, fallback: 'فشل اعتماد المتبرع. يرجى المحاولة مرة أخرى.'));
    } finally {
      isLoading.value = false;
    }
  }

    Future<void> unassignConfirmedDonor({required String requestId, required String donorId}) async {
    if (!isSuperAdmin) {
      Get.snackbar('❌ وصول مرفوض', 'عذراً، فك الإسناد محصور للمنسق العام فقط.',
        backgroundColor: Colors.red.withValues(alpha: 0.1),
        colorText: Colors.red);
      return;
    }
    if (isLoading.value) return; // 🛡️ حماية ضد الضغط المتكرر
    try {
      isLoading.value = true;

      final requestRef = _firestore.collection(AppConstants.serviceRequestsCollection).doc(requestId);
      String previousDonorName = 'المتبرع';
      String requesterId = '';

      await _firestore.runTransaction((tx) async {
        // 1. القراءات (Reads)
        final requestSnap = await tx.get(requestRef);
        if (!requestSnap.exists) {
          throw Exception('request-not-found');
        }

        final requestData = requestSnap.data() as Map<String, dynamic>;
        final currentStatus = (requestData['status'] ?? '').toString();
        if (currentStatus == 'completed' || currentStatus == 'rejected' || currentStatus == 'cancelled') {
          throw Exception('request-closed');
        }

        final List<Map<String, dynamic>> assignedDonors = List<Map<String, dynamic>>.from(
          requestData['assignedDonors'] ?? requestData['assigned_donors'] ?? []
        );

        final donorIndex = assignedDonors.indexWhere((d) => d['id'] == donorId);
        if (donorIndex == -1) {
          throw Exception('donor-not-assigned');
        }

        previousDonorName = assignedDonors[donorIndex]['name'] ?? 'المتبرع';
        assignedDonors.removeAt(donorIndex);
        
        requesterId = (requestData['requesterId'] ?? '').toString();

        final donorRef = _firestore.collection(AppConstants.usersCollection).doc(donorId);
        final donorSnap = await tx.get(donorRef);

        // 2. الكتابات (Writes)
        tx.update(requestRef, {
          'assignedDonors': assignedDonors,
          'status': 'pending', // دائماً نعيده إلى قيد الانتظار إذا انسحب أحد المتبرعين المعتمدين
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // إذا كان المتبرع المحذوف هو نفسه assignedTo، نقوم بتحديث المسند إليه لأقرب واحد في القائمة أو حذفه
        if ((requestData['assignedTo'] ?? '').toString() == donorId) {
          if (assignedDonors.isNotEmpty) {
            tx.update(requestRef, {
              'assignedTo': assignedDonors.last['id'],
              'assignedToName': assignedDonors.last['name'],
            });
          } else {
            tx.update(requestRef, {
              'assignedTo': FieldValue.delete(),
              'assignedToName': FieldValue.delete(),
            });
          }
        }

        if (donorSnap.exists) {
          tx.update(donorSnap.reference, {
            'activeBloodRequestId': FieldValue.delete(),
            'lastActivity': FieldValue.serverTimestamp(),
          });
        }
      });

      if (donorId.isNotEmpty) {
        await NotificationService.sendNotification(
          userId: donorId,
          type: 'request_update',
          title: 'تم تعليق التكليف مؤقتاً',
          body: 'تم تعليق اعتمادك لهذه الحالة حالياً، وقد يتم التواصل معك مجدداً عند الحاجة.',
          data: {
            'requestId': requestId,
          },
        );
      }

      if (requesterId.isNotEmpty) {
        await NotificationService.sendNotification(
          userId: requesterId,
          type: 'request_update',
          title: 'تحديث حالة طلب التبرع',
          body: 'تم إلغاء اعتماد أحد المتبرعين وتحديث قائمة الانتظار لضمان تأمين الحالة.',
          data: {
            'requestId': requestId,
          },
        );
      }

      Get.snackbar('✅ تم', 'تم فك إسناد ($previousDonorName) وتحديث الطلب.');
    } catch (e) {
      Get.snackbar('تعذر تحديث الإسناد', _localizedErrorMessage(e, fallback: 'فشل فك إسناد المتبرع. يرجى المحاولة مرة أخرى.'));
    } finally {
      isLoading.value = false;
    }
    }

  Future<void> markBloodDonationCompleted({required String requestId, required String donorId, required String donorName}) async {
    if (isLoading.value) return; // 🛡️ حماية ضد الضغط المتكرر
    try {
      isLoading.value = true;
      final reqDoc = await _firestore.collection(AppConstants.serviceRequestsCollection).doc(requestId).get();
      if (!reqDoc.exists) return;
      
      final reqData = reqDoc.data() ?? {};
      final String currentStatus = (reqData['status'] ?? '').toString();
      if (currentStatus == 'completed') {
        Get.back();
        return; // بالفعل مكتمل
      }

      final requesterId = (reqData['requesterId'] ?? '').toString();

      final List<Map<String, dynamic>> assignedDonors = List<Map<String, dynamic>>.from(
        reqData['assignedDonors'] ?? reqData['assigned_donors'] ?? []
      );

      final donorIndex = assignedDonors.indexWhere((d) => d['id'] == donorId);
      if (donorIndex != -1) {
        assignedDonors[donorIndex]['status'] = 'donated';
        assignedDonors[donorIndex]['donatedAt'] = DateTime.now().toIso8601String();
      }

      final int requiredCount = reqData['requiredDonorsCount'] ?? 1;
      final int donatedCount = assignedDonors.where((d) => d['status'] == 'donated').length;
      final bool isAllFinished = donatedCount >= requiredCount;

      await _firestore.collection(AppConstants.serviceRequestsCollection).doc(requestId).update({
        'assignedDonors': assignedDonors,
        'status': isAllFinished ? 'completed' : currentStatus,
        'completedAt': isAllFinished ? FieldValue.serverTimestamp() : (reqData['completedAt']),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final String bloodType = (reqData['bloodType'] ?? reqData['details']?['الفصيلة'] ?? '').toString();

      await _firestore.collection(AppConstants.usersCollection).doc(donorId).update({
        'bloodDonationsCount': FieldValue.increment(1),
        'lastDonatedAt': FieldValue.serverTimestamp(),
        'activeBloodRequestId': FieldValue.delete(),
      });

      // 🩸 تحديث العداد العالمي لإحصائيات الدم
      await _incrementGlobalBloodStats(bloodType: bloodType);

      await NotificationService.sendNotification(
        userId: donorId,
        type: 'blood_donation_completed',
        title: '🩸 تم توثيق التبرع بنجاح',
        body: 'تم تسجيل مساهمتك وبدء فترة الاستراحة الطبية. جزاك الله خيراً.',
        data: {
          'requestId': requestId,
        },
      );

      if (requesterId.isNotEmpty) {
        await NotificationService.sendNotification(
          userId: requesterId,
          type: 'request_update',
          title: '✅ تم إتمام طلب التبرع بالدم',
          body: 'الحمد لله، تم إتمام طلب التبرع بالدم بنجاح. نسأل الله الشفاء العاجل.',
          data: {
            'requestId': requestId,
          },
        );
      }

      Get.back(); // الخروج التلقائي عند إتمام التبرع
      Get.snackbar('✅ تمت العملية', 'تم إغلاق طلب التبرع بنجاح');
    } catch (e) {
      Get.snackbar('تعذر إتمام الطلب', _localizedErrorMessage(e, fallback: 'فشل توثيق إتمام التبرع. يرجى المحاولة مرة أخرى.'));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendGlobalAnnouncement({required String title, required String body}) async {
    // ⚠️ Deprecated: use sendGlobalBroadcast instead
    if (!_requireSuperAdmin('الإعلان العام')) return;
    isLoading.value = true;
    try {
      final usersSnap = await _firestore.collection(AppConstants.usersCollection).where('isApproved', isEqualTo: true).get();
      final batch = _firestore.batch();
      for (var doc in usersSnap.docs) {
        batch.set(_firestore.collection('notifications').doc(), {
          'userId': doc.id,
          'type': 'announcement',
          'title': title,
          'body': body,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      Get.snackbar('✅ تم الإرسال', 'تم إرسال الإعلان للجميع');
    } finally {
      isLoading.value = false;
    }
  }

  // --- نظام البث الموحد الجديد (Broadcasting System) ---

  void _startBroadcastListener() {
    _broadcastsSub = _firestore
        .collection('broadcasts')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      activeBroadcasts.assignAll(
          snap.docs.map((d) => BroadcastModel.fromMap(d.data(), d.id)).toList());
      
      // التفكير في إظهار المنبثق عند وصول بيانات جديدة أو عند الدخول
      _checkAndShowBroadcastPopup();
    }, onError: (e) {
      debugPrint('Broadcast listener error: $e');
    });
  }

  void _checkAndShowBroadcastPopup() {
    if (_hasShownPopupThisSession) return;
    final uid = _authController.currentUser.value?.id;
    if (uid == null) return;

    final unseen = activeBroadcasts.where((b) => !b.viewedByUserIds.contains(uid)).toList();
    if (unseen.isNotEmpty) {
      _hasShownPopupThisSession = true;
      final broadcast = unseen.first;
      
      Get.dialog(
        _buildBroadcastDialog(broadcast),
        barrierDismissible: false,
      );
    }
  }

  Widget _buildBroadcastDialog(BroadcastModel broadcast) {
    return AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      content: FadeInUp(
        duration: const Duration(milliseconds: 500),
        child: Container(
          width: Get.width * 0.9,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Get.theme.colorScheme.primary,
                Get.theme.colorScheme.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Get.theme.colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                broadcast.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                broadcast.body,
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Get.theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    confirmBroadcastReceipt(broadcast.id);
                    Get.back();
                  },
                  child: Text(
                    'رأيت الإعلان ✅',
                    style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

    Future<void> sendGlobalBroadcast({required String title, required String body}) async {
    if (!_requireSuperAdmin('إرسال نداء عام')) return;
    isLoading.value = true;
    try {
      final id = _firestore.collection('broadcasts').doc().id;
      final broadcast = BroadcastModel(
        id: id,
        title: title,
        body: body,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('broadcasts').doc(id).set(broadcast.toMap());

      // 🔔 إرسال إشعار فوري لجميع المستخدمين لضمان وصول التنبيه حتى لو كان التطبيق مغلقاً
      await NotificationService.notifyAll(
        type: 'announcement',
        title: title,
        body: body,
      );

      Get.snackbar('🚀 انطلق النداء', 'تم نشر الإعلان التفاعلي وإرسال الإشعارات لجميع المستخدمين بنجاح.',
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.15),
          colorText: AppTheme.successColor);
    } catch (e) {
      Get.snackbar('❌ خطأ', 'فشل نشر النداء: $e');
    } finally {
      isLoading.value = false;
    }
    }

  Future<void> confirmBroadcastReceipt(String broadcastId) async {
    final uid = _authController.currentUser.value?.id;
    if (uid == null) return;

    try {
      await _firestore.collection('broadcasts').doc(broadcastId).update({
        'viewedByUserIds': FieldValue.arrayUnion([uid]),
        'viewCount': FieldValue.increment(1),
      });
      // تحديث الحالة محلياً فوراً لضمان السرعة قبل وصول تحديث الستريم
      activeBroadcasts.refresh();
    } catch (e) {
      debugPrint('Error confirming broadcast receipt: $e');
    }
  }

  Future<void> deleteBroadcast(String broadcastId) async {
    if (!isSuperAdmin) return;
    isLoading.value = true;
    try {
      await _firestore.collection('broadcasts').doc(broadcastId).delete();
      Get.snackbar('🗑️ تم المسح', 'تم حذف الإعلان وبياناته نهائياً من النظام.');
    } catch (e) {
      Get.snackbar('❌ خطأ', 'فشل حذف الإعلان: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateUserDonorSettings({bool? receiveAlerts}) async {
    try {
      final user = _authController.currentUser.value;
      if (user == null) return;
      Map<String, dynamic> updates = {};
      if (receiveAlerts != null) updates['receiveBloodAlerts'] = receiveAlerts;
      if (updates.isEmpty) return;
      await _firestore.collection(AppConstants.usersCollection).doc(user.id).update(updates);
      _authController.currentUser.value = user.copyWith(
        receiveBloodAlerts: receiveAlerts ?? user.receiveBloodAlerts,
      );
      Get.snackbar('✅ تم', 'تم حفظ الإعدادات');
    } catch (e) {
      Get.snackbar('❌ خطأ', 'فشل التحديث');
    }
  }

  Future<void> confirmDonation(String userId) async {
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(userId).update({
        'bloodDonationsCount': FieldValue.increment(1),
        'lastDonatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ConfirmDonation Error: $e');
    }
  }

  /// 🩸 تحديث العداد العالمي لإحصائيات التبرع بالدم
  /// يتم استدعاؤها فقط من `markBloodDonationCompleted` لضمان دقة الأرقام
  Future<void> _incrementGlobalBloodStats({String bloodType = ''}) async {
    try {
      final statsRef = _firestore.collection('stats').doc('blood_stats');
      final Map<String, dynamic> updates = {
        'totalUnits': FieldValue.increment(1),
        'livesSaved': FieldValue.increment(1),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      };
      // تحديث عداد الفصيلة المحددة
      if (bloodType.isNotEmpty) {
        // تحويل الفصيلة إلى مفتاح آمن (مثلاً: A+ -> a_pos)
        final safeKey = _bloodTypeToKey(bloodType);
        updates['byType.$safeKey'] = FieldValue.increment(1);
      }
      await statsRef.set(updates, SetOptions(merge: true));
      debugPrint('📊 [BloodStats] Global counter incremented (type: $bloodType)');
    } catch (e) {
      debugPrint('❌ [BloodStats] Failed to update global stats: $e');
    }
  }

  /// تحويل فصيلة الدم إلى مفتاح آمن لـ Firestore
  String _bloodTypeToKey(String bloodType) {
    return bloodType
        .replaceAll('+', '_pos')
        .replaceAll('-', '_neg')
        .replaceAll(' ', '')
        .toLowerCase();
  }

  // --- 👤 إدارة رتب المستخدمين ---

  Future<void> updateUserRole(String userId, String newRole) async {
    if (!_requireSuperAdmin('تغيير رتبة المستخدم')) return;
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(userId).update({
        'role': newRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      Get.snackbar('✅ تم التحديث', 'تم تغيير رتبة المستخدم بنجاح.');
    } catch (e) {
      Get.snackbar('❌ خطأ', 'فشل تحديث الرتبة: $e');
    }
  }

  Future<void> deleteServiceType(String id) async {
    try {
      await _firestore.collection(AppConstants.serviceTypesCollection).doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting service type: $e');
    }
  }

  Future<void> updateServiceType(String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(AppConstants.serviceTypesCollection).doc(id).update(data);
    } catch (e) {
      debugPrint('Error updating service type: $e');
    }
  }

  Future<void> deleteTaskType(String id) async {
    try {
      await _firestore.collection(AppConstants.taskTypesCollection).doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting task type: $e');
    }
  }

  Future<void> updateTaskType(String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(AppConstants.taskTypesCollection).doc(id).update(data);
    } catch (e) {
      debugPrint('Error updating task type: $e');
    }
  }

  // --- 🚀 إدارة الأهداف التحديات التشغيلية (Challenges) ---

  Future<void> loadStrategicGoals() async {
    try {
      final doc = await _firestore.doc(AppConstants.strategicGoalsDoc).get();
      if (!doc.exists) return;

      final data = doc.data();
      if (data == null || data['goals'] == null) return;

      final Map<String, dynamic> goalsMap = Map<String, dynamic>.from(data['goals']);
      List<StrategicGoalModel> goals = [];

      for (var entry in goalsMap.entries) {
        var goalData = Map<String, dynamic>.from(entry.value);
        if (!(goalData['isActive'] ?? true)) continue;
        goals.add(StrategicGoalModel.fromMap(goalData, entry.key));
      }
      activeGoals.assignAll(goals);
    } catch (e) {
      debugPrint('Error loading strategic goals: $e');
    }
  }

  Future<void> addStrategicGoal(StrategicGoalModel goal) async {
    if (!isSuperAdmin) return;
    try {
      final goalId = _firestore.collection('dummy').doc().id;
      final data = goal.toMap();
      data['id'] = goalId;
      await _firestore.doc(AppConstants.strategicGoalsDoc).set({
        'goals': {goalId: data}
      }, SetOptions(merge: true));
      await loadStrategicGoals();
      Get.snackbar('✅ نجاح', 'تم إضافة التحدي بنجاح');
    } catch (e) {
      debugPrint('Error adding strategic goal: $e');
    }
  }

  Future<void> updateStrategicGoal(StrategicGoalModel goal) async {
    if (!isSuperAdmin) return;
    try {
      await _firestore.doc(AppConstants.strategicGoalsDoc).set({
        'goals': {goal.id: goal.toMap()}
      }, SetOptions(merge: true));
      await loadStrategicGoals();
    } catch (e) {
      debugPrint('Error updating goal: $e');
    }
  }

  Future<void> deactivateGoal(String goalId) async {
    if (!isSuperAdmin) return;
    try {
      await _firestore.doc(AppConstants.strategicGoalsDoc).set({
        'goals': {goalId: {'isActive': false}}
      }, SetOptions(merge: true));
      await loadStrategicGoals();
    } catch (e) {
      debugPrint('Error deactivating goal: $e');
    }
  }

  Future<void> deleteStrategicGoal(String goalId) async {
    if (!isSuperAdmin) return;
    try {
      await _firestore.doc(AppConstants.strategicGoalsDoc).update({
        'goals.$goalId': FieldValue.delete()
      });
      await loadStrategicGoals();
    } catch (e) {
      debugPrint('Error deleting goal: $e');
    }
  }

  // --- 🍃 إدارة دار السبيل (Dar al-Sabil Logic) ---

  void _listenToDarSabilData() {
    if (!isAnyAdmin) return;

    // تتبع النزلاء
    _statsSubs.add(
      _firestore.collection(AppConstants.serviceRequestsCollection)
          .where('type', isEqualTo: 'dar_sabil')
          .orderBy('createdAt', descending: true)
          .snapshots().listen((snap) {
            darSabilGuests.value = snap.docs.map((d) => ServiceRequestModel.fromMap(d.data(), id: d.id)).toList();
            _updateDarSabilSummary();
          })
    );

    // تتبع المهام الداخلية
    _statsSubs.add(
      _firestore.collection(AppConstants.darSabilMgmtCollection)
          .doc('tasks').collection('items')
          .orderBy('createdAt', descending: true)
          .snapshots().listen((snap) {
            darSabilTasks.value = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
            _updateDarSabilSummary();
          })
    );

    // تتبع المسيرين
    _statsSubs.add(
      _firestore.collection(AppConstants.darSabilMgmtCollection)
          .doc('config').snapshots().listen((doc) async {
            if (doc.exists && doc.data() != null) {
              final List<String> ids = List<String>.from(doc.data()!['managerIds'] ?? []);
              if (ids.isEmpty) {
                darSabilManagers.clear();
                return;
              }
              final usersSnap = await _firestore.collection(AppConstants.usersCollection)
                  .where(FieldPath.documentId, whereIn: ids).get();
              darSabilManagers.value = usersSnap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();
            }
          })
    );

    // تتبع المؤن
    _statsSubs.add(
      _firestore.collection(AppConstants.darSabilMgmtCollection)
          .doc('supplies').collection('items').snapshots().listen((snap) {
            darSabilSupplies.value = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
            _updateDarSabilSummary();
          })
    );
  }

  void _updateDarSabilSummary() {
    final completedCount = darSabilTasks.where((t) => t['status'] == 'completed').length;
    final total = darSabilTasks.length;
    final lowCount = darSabilSupplies.where((s) => s['status'] != 'available').length;

    darSabilSummary.value = {
      'guestsCount': darSabilGuests.length,
      'tasksProgress': total > 0 ? (completedCount / total) : 0.0,
      'pendingTasks': total - completedCount,
      'lowSuppliesCount': lowCount,
    };
    darSabilSummary.refresh();
  }

  Future<void> assignDarSabilManager(String userId) async {
    if (!_requireSuperAdmin('تعيين مسير لدار السبيل')) return;
    try {
      await _firestore.collection(AppConstants.darSabilMgmtCollection).doc('config').set({
        'managerIds': FieldValue.arrayUnion([userId])
      }, SetOptions(merge: true));
      Get.snackbar('✅ نجاح', 'تم تعيين المسير بنجاح');
    } catch (e) {
      Get.snackbar('❌ خطأ', 'تعذر التعيين: $e');
    }
  }

  Future<void> revokeDarSabilManager(String userId) async {
    if (!_requireSuperAdmin('إلغاء تعيين مسير')) return;
    try {
      await _firestore.collection(AppConstants.darSabilMgmtCollection).doc('config').update({
        'managerIds': FieldValue.arrayRemove([userId])
      });
      Get.snackbar('✅ نجاح', 'تم إلغاء التعيين');
    } catch (e) {
      Get.snackbar('❌ خطأ', 'تعذر الإلغاء: $e');
    }
  }

  Future<void> addDarSabilTask(String title, String desc, String assignedToId, String assignedToName) async {
    if (!isAnyAdmin) return; // Changed from SuperAdmin to AnyAdmin
    try {
      await _firestore.collection(AppConstants.darSabilMgmtCollection).doc('tasks').collection('items').add({
        'title': title,
        'description': desc,
        'assignedToId': assignedToId,
        'assignedToName': assignedToName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      Get.snackbar('✅ نجاح', 'تم إضافة المهمة بنجاح للمسؤول: $assignedToName');
    } catch (e) {
      Get.snackbar('❌ خطأ', 'فشل إضافة المهمة: $e');
    }
  }

  Future<void> updateDarSabilSupply(String itemId, String newStatus) async {
    if (!isAnyAdmin) return;
    try {
      await _firestore.collection(AppConstants.darSabilMgmtCollection)
          .doc('supplies').collection('items').doc(itemId).set({
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      _updateDarSabilSummary();
    } catch (e) {
      debugPrint('Supply update error: $e');
    }
  }

  Future<void> toggleDarSabilTask(String taskId, String currentStatus) async {
    if (!isAnyAdmin) return;
    try {
      final newStatus = currentStatus == 'pending' ? 'completed' : 'pending';
      await _firestore.collection(AppConstants.darSabilMgmtCollection)
          .doc('tasks').collection('items').doc(taskId).update({'status': newStatus});
    } catch (e) {
      debugPrint('Task toggle error: $e');
    }
  }

  Future<void> deleteDarSabilTask(String taskId) async {
    if (!isAnyAdmin) return; // Changed from SuperAdmin to AnyAdmin
    try {
      await _firestore.collection(AppConstants.darSabilMgmtCollection)
          .doc('tasks').collection('items').doc(taskId).delete();
      Get.snackbar('✅ تم الحذف', 'تم حذف المهمة بنجاح');
    } catch (e) {
      Get.snackbar('❌ خطأ', 'تعذر الحذف');
    }
  }

  Future<void> seedDarSabilInitialTasks() async {
    if (!_requireSuperAdmin('تهيئة المهام')) return;
    try {
      final batch = _firestore.batch();
      final collection = _firestore.collection(AppConstants.darSabilMgmtCollection).doc('tasks').collection('items');
      final tasks = [
        {'title': 'تجهيز الغرف', 'description': 'غسل الأغطية وفحص الإنارة.'},
        {'title': 'جرد المطبخ', 'description': 'التأكد من توفر المواد الأساسية.'},
        {'title': 'سجل النزلاء', 'description': 'مراجعة بيانات النزلاء لليوم.'},
        {'title': 'صيانة المرافق', 'description': 'فحص دورات المياه.'},
        {'title': 'الاستقبال', 'description': 'توزيع الوجبات ومرافقة الضيوف الجدد.'},
      ];
      for (var t in tasks) {
        final doc = collection.doc();
        batch.set(doc, {
          ...t,
          'assignedToId': currentUser?.id ?? '',
          'assignedToName': currentUser?.name ?? 'المنسق',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      Get.snackbar('✅ نجاح', 'تمت تهيئة المهام بنجاح');
    } catch (e) {
      debugPrint('Seeding error: $e');
    }
  }

  Future<void> assignDarSabilRoom(String requestId, String roomNumber) async {
    if (!isAnyAdmin) return;
    try {
      isLoading.value = true;
      await _firestore.collection(AppConstants.serviceRequestsCollection).doc(requestId).update({
        'roomNumber': roomNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      Get.snackbar('✅ تم التخصيص', 'تم تخصيص الغرفة رقم $roomNumber للنزيل بنجاح.',
          backgroundColor: Colors.green.withValues(alpha: 0.1),
          colorText: Colors.green);
    } catch (e) {
      Get.snackbar('❌ خطأ', 'تعذر تخصيص الغرفة: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshDarSabilData() async {
    isLoading.value = true;
    try {
      await Future.delayed(const Duration(seconds: 1)); // UX delay for visual feedback
      _updateDarSabilSummary();
      Get.snackbar('🔄 تم التحديث', 'تمت إعادة حساب إحصائيات الدار وتحديث البيانات الحية', 
          backgroundColor: Colors.blue.withValues(alpha: 0.1),
          colorText: Colors.blue);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleUserDarSabilPermission(String userId, bool value) async {
    if (!_requireSuperAdmin('تعديل صلاحيات دار السبيل')) return;
    try {
      isLoading.value = true;
      await _firestore.collection(AppConstants.usersCollection).doc(userId).update({
        'canManageDarSabil': value,
      });
      // تحديث قائمة المستخدمين النشطة محلياً لضمان الانعكاس الفوري في الواجهة
      final index = activeWorkersList.indexWhere((u) => u.id == userId);
      if (index != -1) {
        activeWorkersList[index] = activeWorkersList[index].copyWith(canManageDarSabil: value);
      }
      
      Get.snackbar('✅ تم التحديث', value ? 'تم منح صلاحية إدارة دار السبيل' : 'تم سحب صلاحية إدارة دار السبيل',
          backgroundColor: value ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1));
    } catch (e) {
      Get.snackbar('❌ خطأ', 'تعذر تحديث الصلاحية: $e');
    } finally {
      isLoading.value = false;
    }
  }
}
