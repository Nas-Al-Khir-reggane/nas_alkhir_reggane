import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../core/routes/app_routes.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();
  
  Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  RxBool isLoading = false.obs;

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

  Future<void> register({
    required String name,
    required String phone,
    required String wilaya,
    required String address,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    try {
      isLoading.value = true;
      UserModel userData = UserModel(
        id: '',
        name: name,
        email: email,
        phone: phone,
        wilaya: wilaya,
        address: address,
        role: role,
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

  Future<void> checkAuthState() async {
    try {
      User? firebaseUser = FirebaseAuth.instance.currentUser;
      
      if (firebaseUser != null) {
        UserModel? user = await _authService.getCurrentUserData().timeout(
          const Duration(seconds: 10),
          onTimeout: () => null,
        );

        if (user != null) {
          currentUser.value = user;
          _navigateBasedOnRole(user);
        } else {
          await logout();
        }
      } else {
        Get.offAllNamed(AppRoutes.login);
      }
    } catch (e) {
      Get.offAllNamed(AppRoutes.login);
    }
  }

  void _navigateBasedOnRole(UserModel user) {
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
      case UserRole.guest:
        Get.offAllNamed(AppRoutes.login);
        break;
    }
  }
}
