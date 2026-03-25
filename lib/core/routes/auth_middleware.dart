import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/auth/controllers/auth_controller.dart';
import 'app_routes.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final authController = Get.find<AuthController>();
    
    // إذا لم يكن المستخدم مسجلاً دخوله، وجهه لصفحة تسجيل الدخول
    if (authController.currentUser.value == null) {
      if (FirebaseAuth.instance.currentUser != null) {
        return null; // Let the screen load and fetch the user data
      }
      return const RouteSettings(name: AppRoutes.login);
    }
    
    // إذا كان الحساب غير مفعل (بانتظار الموافقة)
    if (!authController.currentUser.value!.isApproved) {
      return const RouteSettings(name: AppRoutes.pending);
    }

    return null;
  }
}
