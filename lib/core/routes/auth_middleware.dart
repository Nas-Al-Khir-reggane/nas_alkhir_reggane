import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../features/auth/controllers/auth_controller.dart';
import 'app_routes.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final authController = Get.find<AuthController>();

    // المستخدم غير مسجل → صفحة تسجيل الدخول دائماً دون استثناء
    if (authController.currentUser.value == null) {
      return const RouteSettings(name: AppRoutes.login);
    }

    // الحساب بانتظار موافقة الإدارة (ما عدا superAdmin)
    if (!authController.currentUser.value!.isApproved &&
        authController.currentUser.value!.role.name != 'superAdmin') {
      return const RouteSettings(name: AppRoutes.pending);
    }

    return null;
  }
}
