import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/auth/controllers/auth_controller.dart';
import 'app_routes.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final authController = Get.find<AuthController>();
    
    // التحقق من نوع البيانات المرسلة بأمان لتجنب الخطأ الذي ظهر في السجلات
    String? chatId;
    if (Get.arguments is Map<String, dynamic>) {
      final args = Get.arguments as Map<String, dynamic>;
      chatId = args['chatId'];
    }

    // إذا لم يكن المستخدم مسجلاً دخوله، وجهه لصفحة تسجيل الدخول (إلا إذا كانت دردشة زائر)
    if (authController.currentUser.value == null) {
      if (chatId != null && chatId.startsWith('guest_')) {
        return null;
      }
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

