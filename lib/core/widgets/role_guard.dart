import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/user_model.dart';
import '../../features/auth/controllers/auth_controller.dart';

/// ويدجت ذكي للتحكم في ظهور العناصر بناءً على رتبة المستخدم.
/// يستخدم لحماية الأزرار أو الأقسام التي تتطلب صلاحيات خاصة (مثل المدير العام فقط).
class RoleGuard extends StatelessWidget {
  final List<UserRole> allowedRoles;
  final Widget child;
  final Widget fallback;

  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = Get.find<AuthController>().currentUser.value;
      if (user == null) return fallback;
      
      if (allowedRoles.contains(user.role)) {
        return child;
      }
      
      return fallback;
    });
  }
}
