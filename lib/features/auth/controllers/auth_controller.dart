import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_service.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/routes/app_routes.dart';class AuthController extends GetxController with WidgetsBindingObserver {
  final AuthService _authService = AuthService();

  Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  RxBool isLoading = false.obs;
  Timer? _heartbeatTimer;

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
        _navigateBasedOnRole(user);
      }
    } catch (e) {
      Get.snackbar("خطأ", "فشل تسجيل الدخول: ${e.toString()}");
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
        createdAt: DateTime.now(),
      );
      UserModel? user = await _authService.signUp(email, password, userData);
      if (user != null) {
        currentUser.value = user;
        Get.offAllNamed(AppRoutes.pending);
      }
    } catch (e) {
      Get.snackbar("خطأ", "فشل إنشاء الحساب: ${e.toString()}");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
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
        UserModel? cachedUser = await _authService.getCachedUserModel();
        
        if (cachedUser != null) {
          currentUser.value = cachedUser;
          _navigateBasedOnRole(cachedUser);
          
          // Silent refresh in the background
          _silentRefresh(cachedUser);
        } else {
          // Fallback to network if no cache is available
          UserModel? user;
          try {
            user = await _authService.getCurrentUserData().timeout(const Duration(seconds: 8));
          } catch (e) {
            debugPrint("Offline or timeout fetching user data: $e");
          }

          if (user != null) {
            currentUser.value = user;
            _navigateBasedOnRole(user);
          } else {
            await logout();
          }
        }
      } else {
        Get.offAllNamed(AppRoutes.login);
      }
    } catch (e) {
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
          Get.offAllNamed(AppRoutes.guestRequest);
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
