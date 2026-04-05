import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/notification_service.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class AuthController extends GetxController with WidgetsBindingObserver {
  final AuthService _authService = AuthService();

  Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  Rx<UserRole?> activeRoleOverride = Rx<UserRole?>(null); // الدور النشط المختار يدوياً
  RxBool isLoading = false.obs;
  Timer? _heartbeatTimer;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  String _authErrorMessage(dynamic error, {String fallback = 'تعذر إتمام العملية حالياً. يرجى المحاولة مرة أخرى.'}) {
    final message = error.toString().toLowerCase();

    if (message.contains('invalid-credential') || message.contains('wrong-password') || message.contains('user-not-found')) {
      return 'بيانات الدخول غير صحيحة. تأكد من البريد الإلكتروني وكلمة المرور.';
    }
    if (message.contains('invalid-email')) {
      return 'صيغة البريد الإلكتروني غير صحيحة.';
    }
    if (message.contains('user-disabled')) {
      return 'تم تعطيل هذا الحساب. يرجى التواصل مع الإدارة.';
    }
    if (message.contains('too-many-requests')) {
      return 'تم تجاوز عدد المحاولات المسموح. يرجى الانتظار ثم إعادة المحاولة.';
    }
    if (message.contains('email-already-in-use')) {
      return 'هذا البريد الإلكتروني مسجل مسبقاً.';
    }
    if (message.contains('weak-password')) {
      return 'كلمة المرور ضعيفة. يرجى اختيار كلمة مرور أقوى.';
    }
    if (message.contains('network') || message.contains('socketexception')) {
      return 'تعذر الاتصال بالخادم. يرجى التحقق من الإنترنت.';
    }
    if (message.contains('timeout') || message.contains('deadline-exceeded')) {
      return 'انتهت مهلة الاتصال. يرجى إعادة المحاولة.';
    }
    if (message.contains('permission-denied')) {
      return 'لا تملك صلاحية تنفيذ هذا الإجراء.';
    }

    return fallback;
  }

  void _startUserListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    _userSubscription?.cancel();
    _userSubscription = FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((doc) {
      if (doc.exists) {
        try {
          final userData = doc.data() as Map<String, dynamic>;
          final updatedUser = UserModel.fromMap(userData, uid);
          
          currentUser.value = updatedUser;
          currentUser.refresh();

          _authService.saveCachedUserModel(updatedUser);

          _checkDonorCooldown(updatedUser);
        } catch (e) {
          debugPrint('Error parsing user data in listener: $e');
        }
      }
    }, onError: (e) {
      debugPrint('Error listening to user changes: $e');
    });
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _startHeartbeat();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _userSubscription?.cancel();
    super.onClose();
  }

  void _startHeartbeat() {
    _updateGlobalActivity();
    // إرسال تحديث كل 3 دقائق لضمان بقاء المستخدم الحقيقي "متصل الآن"
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      _updateGlobalActivity();
    });
  }

  void _updateGlobalActivity() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    // التأكد من أن المستخدم لديه حساب مسجل قبل التحديث المستمر
    if (uid != null && currentUser.value != null && currentUser.value!.id.isNotEmpty) {
      try {
        FirebaseFirestore.instance.collection('users').doc(uid).set({
          'lastActivity': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Failed to update global heartbeat: $e');
      }
    }
  }

  Future<void> _checkDonorCooldown(UserModel user) async {
    if (user.lastDonatedAt != null && user.isDonorAvailable == false) {
      final difference = DateTime.now().difference(user.lastDonatedAt!);
      if (difference.inDays >= user.smartDonationCoolOffDays) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.id).update({
            'isDonorAvailable': true,
          });
          // No need to manually update local because stream will trigger again
        } catch (e) {
          debugPrint('Error auto-resetting donor cooldown: $e');
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // عندما يعود المستخدم للتطبيق، نرسل إشارة "متصل" فوراً
      _updateGlobalActivity();
    }
  }

  Future<void> login(String email, String password) async {
    try {
      isLoading.value = true;
      UserModel? user = await _authService.signIn(email, password);
      
      if (user != null) {
        currentUser.value = user;
        _startUserListener();
        _navigateBasedOnRole(user);
      } else {
        // إذا نجح تسجيل الدخول في Firebase (لأن signIn لم تطلق خطأ) ولكن لم يتم العثور على ملف Firestore
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          debugPrint('🔑 Login succesful but Firestore doc missing. Redirecting...');
          Get.offAllNamed(AppRoutes.register, arguments: {
            'isCompletingProfile': true,
            'email': firebaseUser.email,
            'uid': firebaseUser.uid,
          });
        }
      }
    } catch (e) {
      debugPrint("AuthController: Login Error: $e");
      final message = _authErrorMessage(e, fallback: 'تعذر تسجيل الدخول حالياً. يرجى المحاولة مرة أخرى.');
      Get.snackbar('تعذر تسجيل الدخول', message,
        backgroundColor: Colors.red.withValues(alpha: 0.15),
        duration: const Duration(seconds: 5));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      isLoading.value = true;
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      Get.snackbar("✅ نجاح", "تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني");
    } catch (e) {
      Get.snackbar('تعذر إرسال الرابط', _authErrorMessage(e, fallback: 'فشل إرسال رابط إعادة التعيين. يرجى المحاولة لاحقاً.'));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> register({
    required String name,
    required String phone,
    required String wilaya,
    required String commune,
    required String address,
    required String email,
    required String password,
    required UserRole role,
    String? profileImage,
    required String bloodType,
    required String gender,
    String? workerRole,
    List<String> volunteerServices = const [],
    String? ghuslExpertise,
    String? otherServices,
  }) async {
    try {
      isLoading.value = true;
      UserRole finalRole = role;
      bool autoApprove = false;

      UserModel userData = UserModel(
        id: '',
        name: name,
        email: email,
        phone: phone,
        wilaya: wilaya,
        commune: commune,
        address: address,
        role: finalRole,
        isApproved: autoApprove,
        profileImage: profileImage,
        bloodType: bloodType,
        gender: gender,
        workerRole: workerRole,
        volunteerServices: volunteerServices,
        ghuslExpertise: ghuslExpertise,
        otherServices: otherServices,
        createdAt: DateTime.now(),
      );
      UserModel? user = await _authService.signUp(email, password, userData);
      if (user != null) {
        currentUser.value = user;
        _startUserListener();

        // إرسال إشعار للمدير العام والإدارة
        await NotificationService.notifyAllAdmins(
          type: 'new_registration',
          title: '👤 تسجيل جديد',
          body: 'طلب ${user.name} الانضمام كـ ${user.role.displayName}',
          data: {'userId': user.id},
        );

        Get.offAllNamed(AppRoutes.pending);
      }
    } catch (e) {
      String errorMessage = _authErrorMessage(e, fallback: 'فشل إنشاء الحساب. يرجى التأكد من البيانات والمحاولة مجدداً.');
      if (e.toString().toLowerCase().contains('email-already-in-use')) {
        errorMessage = 'هذا البريد مسجل مسبقاً. إذا كان ملفك الشخصي غير مكتمل، سجّل الدخول أولاً لإكمال بياناتك.';
      }
      Get.snackbar("تنبيه", errorMessage, 
        backgroundColor: Colors.orange.withValues(alpha: 0.15),
        duration: const Duration(seconds: 5)
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> completeProfile({
    required String uid,
    required String name,
    required String phone,
    required String wilaya,
    required String commune,
    required String address,
    required String email,
    required String gender,
    required UserRole role,
    String? profileImage,
    required String bloodType,
    String? workerRole,
    List<String> volunteerServices = const [],
    String? ghuslExpertise,
    String? otherServices,
  }) async {
    try {
      isLoading.value = true;
      
      UserModel userData = UserModel(
        id: uid,
        name: name,
        email: email,
        phone: phone,
        wilaya: wilaya,
        commune: commune,
        address: address,
        role: role,
        isApproved: false, // يحتاج لموافقة الإدارة كالمعتاد
        profileImage: profileImage,
        bloodType: bloodType,
        gender: gender,
        workerRole: workerRole,
        volunteerServices: volunteerServices,
        ghuslExpertise: ghuslExpertise,
        otherServices: otherServices,
        createdAt: DateTime.now(),
      );

      await _authService.saveUserToFirestore(userData);
      
      final freshUser = await _authService.getCurrentUserData();
      if (freshUser != null) {
        currentUser.value = freshUser;
        _startUserListener();

        // إرسال إشعار للمدير العام والإدارة
        await NotificationService.notifyAllAdmins(
          type: 'new_registration',
          title: '👤 استكمال تسجيل مستخدم',
          body: 'قام ${freshUser.name} باستكمال تسجيله كـ ${freshUser.role.displayName}',
          data: {'userId': freshUser.id},
        );

        Get.offAllNamed(AppRoutes.pending);
      }
    } catch (e) {
      Get.snackbar('تعذر حفظ البيانات', _authErrorMessage(e, fallback: 'فشل حفظ بيانات الحساب. يرجى المحاولة مرة أخرى.'));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    _userSubscription?.cancel();
    _userSubscription = null;

    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userUid != null) {
      try {
        // حذف التوكن من قاعدة البيانات لمنع وصول إشعارات الحساب القديم للجهاز الحالي
        await FirebaseFirestore.instance.collection('users').doc(userUid).update({
          'fcmToken': FieldValue.delete(),
        });
      } catch (e) {
        debugPrint('⚠️ خطأ في مسح توكن الإشعارات: $e');
      }
    }

    // مسح كاش الدردشة لمنع تسريب رسائل المستخدم لمستخدم آخر
    try {
      final prefs = await SharedPreferences.getInstance();
      final keysToRemove = prefs.getKeys()
          .where((k) => k.startsWith('cached_chat_') || k.startsWith('muted_'))
          .toList();
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('⚠️ فشل مسح كاش الدردشة: \$e');
    }

    await _authService.signOut();
    currentUser.value = null;
    activeRoleOverride.value = null; // إعادة تعيين الدور عند تسجيل الخروج
    Get.offAllNamed(AppRoutes.login);
  }

  /// 🔄 تبديل الدور النشط للمستخدم
  void switchActiveRole(UserRole targetRole) {
    if (currentUser.value == null) return;

    // التأكد من أن المستخدم يملك هذا الدور كدور أساسي أو إضافي
    bool hasPermission = currentUser.value!.role == targetRole;
    if (!hasPermission) {
      final additional = currentUser.value!.additionalRoles;
      if (targetRole == UserRole.donor && additional.contains('canDonate')) hasPermission = true;
      if (targetRole == UserRole.beneficiary && additional.contains('canRequestService')) hasPermission = true;
      // يمكنك إضافة مزيد من التحققات هنا للأدوار الأخرى
    }

    if (hasPermission) {
      activeRoleOverride.value = targetRole;
      _navigateBasedOnRole(currentUser.value!);
      
      Get.snackbar(
        '🔄 تم تبديل الوضع',
        'أنت الآن في وضع ${targetRole.displayName}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
        colorText: AppTheme.primaryGreen,
        duration: const Duration(seconds: 2),
      );
    } else {
      Get.snackbar(
        '⚠️ عذراً',
        'لا تملك صلاحية الوصول لوضع ${targetRole.displayName}',
        backgroundColor: Colors.orange.withValues(alpha: 0.15),
      );
    }
  }

  /// 🛡️ الحصول على الدور الفعال حالياً (الأساسي أو المختار)
  UserRole get currentActiveRole => activeRoleOverride.value ?? currentUser.value?.role ?? UserRole.beneficiary;


  // تم حذف signInAnonymously — لا وجود لميزة الزائر

  Future<void> checkAuthState() async {
    try {
      User? firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser != null) {
        // Offline-First: Load from cache immediately
        UserModel? cachedUser;
        try {
          cachedUser = await _authService.getCachedUserModel().timeout(const Duration(seconds: 3));
        } catch (e) {
          debugPrint('⚠️ Cache retrieval timed out or failed: $e');
        }
        
        if (cachedUser != null) {
          currentUser.value = cachedUser;
          _startUserListener();
          _navigateBasedOnRole(cachedUser);
          
          // Silent refresh in the background
          _silentRefresh(cachedUser);
        } else {
          debugPrint('ℹ️ No valid cache, fetching from network...');
          // Fallback to network if no cache is available
          UserModel? user;
          try {
            user = await _authService.getCurrentUserData().timeout(const Duration(seconds: 10));
          } catch (e) {
            debugPrint("Offline or timeout fetching user data: $e");
          }
          
          if (user != null) {
            currentUser.value = user;
            _startUserListener();
            _navigateBasedOnRole(user);
          } else {
            debugPrint('⚠️ No user data found in Firestore for UID: ${firebaseUser.uid}. Redirecting to Complete Profile...');
            // بدلاً من تسجيل الخروج، نوجه المستخدم لإكمال بياناته
            Get.offAllNamed(AppRoutes.register, arguments: {
              'isCompletingProfile': true,
              'email': firebaseUser.email,
              'uid': firebaseUser.uid,
            });
          }
        }
      } else {
        Get.offAllNamed(AppRoutes.login);
      }
    } catch (e) {
      debugPrint('❌ Auth checkAuthState Error: $e');
      Get.offAllNamed(AppRoutes.login);
    }
  }

  Future<void> _silentRefresh(UserModel cachedUser) async {
    try {
      final freshUser = await _authService.getCurrentUserData();
      if (freshUser != null) {
        currentUser.value = freshUser; // Update state globally
        
        // Verify if critical privileges changed
        if (cachedUser.role != freshUser.role || cachedUser.isApproved != freshUser.isApproved) {
          Get.snackbar("تحديث الحساب", "تم تحديث صلاحيات حسابك");
          _navigateBasedOnRole(freshUser);
        }
      }
    } catch (e) {
      debugPrint("Silent refresh failed: $e");
    }
  }

  void _navigateBasedOnRole(UserModel user) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!user.isApproved && user.role != UserRole.superAdmin) {
        Get.offAllNamed(AppRoutes.pending);
        return;
      }

      final roleToUse = activeRoleOverride.value ?? user.role;

      switch (roleToUse) {
        case UserRole.superAdmin:
        case UserRole.admin:
          Get.offAllNamed(AppRoutes.adminDashboard);
          break;
        case UserRole.worker:
          Get.offAllNamed(AppRoutes.workerDashboard);
          break;
        case UserRole.donor:
          Get.offAllNamed(AppRoutes.donorDashboard);
          break;
        case UserRole.beneficiary:
          Get.offAllNamed(AppRoutes.beneficiaryDashboard);
          break;
        case UserRole.chatModerator:
          Get.offAllNamed(AppRoutes.chatGroup);
          break;
      }

      // 🩸 فحص لاحق: تنبيه المستخدمين الجدد/العائدين بنداءات الاستغاثة المتوافقة
      if (user.isApproved && user.bloodType != null && user.bloodType!.isNotEmpty) {
        _checkActiveBloodEmergencies(user);
      }
    });
  }

  /// 🩸 خوارزمية الفحص اللاحق (Post-Registration Catch-up)
  /// تفحص طلبات الدم النشطة المتوافقة مع فصيلة المستخدم
  /// وترسل إشعاراً محلياً فورياً إذا وُجدت حالات تحتاج لمساعدته
  Future<void> _checkActiveBloodEmergencies(UserModel user) async {
    try {
      final compatibleTypes = _getCompatibleBloodTypes(user.bloodType!);
      if (compatibleTypes.isEmpty) return;

      final querySnap = await FirebaseFirestore.instance
          .collection(AppConstants.serviceRequestsCollection)
          .where('type', whereIn: ['blood_donation', 'blood_emergency'])
          .get();

      final activeRequests = querySnap.docs.where((doc) {
        final data = doc.data();
        final status = data['status'] ?? 'pending';
        // تصفية الحالات النشطة برمجياً لتجنب قيود Firebase Query
        if (status != 'pending' && status != 'in_progress') return false;
        
        final reqBloodType = (data['bloodType'] ?? data['details']?['الفصيلة'] ?? '').toString();
        return compatibleTypes.contains(reqBloodType);
      }).toList();

      if (activeRequests.isNotEmpty) {
        final firstReq = activeRequests.first.data();
        final bloodType = (firstReq['bloodType'] ?? firstReq['details']?['الفصيلة'] ?? '').toString();
        final hospital = (firstReq['hospital'] ?? firstReq['details']?['المستشفى'] ?? '').toString();
        final count = activeRequests.length;

        // إرسال إشعار Firestore للمستخدم الجديد
        await NotificationService.sendNotification(
          userId: user.id,
          type: 'blood_emergency',
          title: '🚨 أهلاً يا منقذ! هناك $count ${count == 1 ? "حالة تحتاج" : "حالات تحتاج"} مساعدتك',
          body: 'مريض في $hospital بحاجة لفصيلة $bloodType. ساهم في الأجر العظيم.',
          data: {
            'requestId': activeRequests.first.id,
            'bloodType': bloodType,
            'hospital': hospital,
          },
        );
        debugPrint('🩸 [CatchUp] Notified user ${user.id} about $count active blood requests');
      }
    } catch (e) {
      debugPrint('⚠️ [CatchUp] Error checking blood emergencies: $e');
    }
  }

  /// قائمة الفصائل المتوافقة للتبرع
  List<String> _getCompatibleBloodTypes(String donorType) {
    const Map<String, List<String>> compatibility = {
      'O-':  ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'],
      'O+':  ['O+', 'A+', 'B+', 'AB+'],
      'A-':  ['A-', 'A+', 'AB-', 'AB+'],
      'A+':  ['A+', 'AB+'],
      'B-':  ['B-', 'B+', 'AB-', 'AB+'],
      'B+':  ['B+', 'AB+'],
      'AB-': ['AB-', 'AB+'],
      'AB+': ['AB+'],
    };
    // نبحث عن الحالات التي تحتاج فصيلة يمكن لهذا المتبرع التبرع لها
    return compatibility[donorType] ?? [donorType];
  }

  Future<void> refreshUser() async {
    try {
      final user = await _authService.getCurrentUserData();
      if (user != null) currentUser.value = user;
    } catch (_) {}
  }
}
