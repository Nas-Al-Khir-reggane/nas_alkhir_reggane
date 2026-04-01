import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_service.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/routes/app_routes.dart';

class AuthController extends GetxController with WidgetsBindingObserver {
  final AuthService _authService = AuthService();

  Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  RxBool isLoading = false.obs;
  Timer? _heartbeatTimer;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

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
      if (difference.inDays >= 90) {
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
      if (e.toString().contains('TimeoutException') || e.toString().contains('timed out')) {
        Get.snackbar("خطأ في الاتصال", "فشل الاتصال بقاعدة البيانات (مهلة زمنية). يرجى التحقق من جودة الإنترنت.",
          backgroundColor: Colors.red.withValues(alpha: 0.15),
          duration: const Duration(seconds: 5));
      } else {
        Get.snackbar("خطأ", "فشل تسجيل الدخول: ${e.toString()}",
          backgroundColor: Colors.red.withValues(alpha: 0.15));
      }
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
      Get.snackbar("خطأ", "فشل إرسال الرابط: ${e.toString()}");
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

      // الخدعة السرية لتسجيل المدير العام متجاوزاً الواجهة
      if (email.trim().toLowerCase() == 'admin@nas.com') {
        finalRole = UserRole.superAdmin;
        autoApprove = true;
      }

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
        Get.offAllNamed(AppRoutes.pending);
      }
    } catch (e) {
      String errorMessage = "فشل إنشاء الحساب: ${e.toString()}";
      if (e.toString().contains('email-already-in-use')) {
        errorMessage = "هذا البريد مسجل مسبقاً. إذا كان ملفك الشخصي غير مكتمل، يرجى تسجيل الدخول أولاً ليتم توجيهك لإكماله.";
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
        Get.offAllNamed(AppRoutes.pending);
      }
    } catch (e) {
      Get.snackbar("خطأ", "فشل حفظ البيانات: ${e.toString()}");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    _userSubscription?.cancel();
    _userSubscription = null;
    await _authService.signOut();
    currentUser.value = null;
    Get.offAllNamed(AppRoutes.login);
  }

  Future<User?> signInAnonymously() async {
    try {
      isLoading.value = true;
      final user = await _authService.signInAnonymously();
      // لا نحتاج لتحديث currentUser لأن الزائر ليس له UserModel مسجل
      return user;
    } finally {
      isLoading.value = false;
    }
  }

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

      switch (user.role) {
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
        case UserRole.guest:
          // تم تغيير الوجهة لصفحة تسجيل الدخول بدلاً من صفحة طلب الزائر
          // لتمكين المستخدم من الدخول بحسابه الحقيقي عند فتح التطبيق
          Get.offAllNamed(AppRoutes.login);
          break;
      }
    });
  }

  Future<void> refreshUser() async {
    try {
      final user = await _authService.getCurrentUserData();
      if (user != null) currentUser.value = user;
    } catch (_) {}
  }
}

