import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/user_model.dart';
import '../../features/auth/controllers/auth_controller.dart';

class RoleMiddleware extends GetMiddleware {
  RoleMiddleware({required this.allowedRoles});

  final List<UserRole> allowedRoles;

  @override
  RouteSettings? redirect(String? route) {
    final authController = Get.find<AuthController>();
    final user = authController.currentUser.value;

    if (user == null) {
      return const RouteSettings(name: '/login');
    }

    if (allowedRoles.contains(user.role)) {
      return null;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.snackbar('وصول مرفوض', 'ليس لديك صلاحية للوصول إلى هذه الصفحة');
    });

    final fallback = _fallbackRouteForRole(user.role);
    return RouteSettings(name: fallback);
  }

  String _fallbackRouteForRole(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
      case UserRole.admin:
        return '/admin/dashboard';
      case UserRole.worker:
        return '/worker/dashboard';
      case UserRole.donor:
        return '/donor/dashboard';
      case UserRole.beneficiary:
      case UserRole.chatModerator:
        return '/beneficiary/dashboard';
    }
  }
}