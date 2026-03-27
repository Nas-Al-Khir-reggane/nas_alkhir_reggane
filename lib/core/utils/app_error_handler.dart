import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../theme/app_theme.dart';

class AppErrorHandler {
  /// يتعامل مع الأخطاء الصامتة ويعرضها للمستخدم بشكل لائق
  static void handleError(dynamic error, {String? customMessage}) {
    debugPrint("🚨 [AppErrorHandler]: $error");

    if (Get.isSnackbarOpen) return;

    Get.snackbar(
      'تنبيه',
      customMessage ?? 'حدث خطأ في الاتصال، يرجى المحاولة لاحقاً',
      backgroundColor: AppTheme.errorColor.withValues(alpha: 0.2),
      colorText: AppTheme.errorColor,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
      icon: Icon(Icons.error_outline, color: AppTheme.errorColor),
    );
  }
}
