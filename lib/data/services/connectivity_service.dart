import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'offline_queue_service.dart';

/// خدمة مراقبة الشبكة — تعرض Banner وتُطلق flush عند استعادة الاتصال
class ConnectivityService extends GetxService {
  final RxBool isOnline = true.obs;
  StreamSubscription? _sub;

  OfflineQueueService get _queue => Get.find<OfflineQueueService>();

  @override
  Future<void> onInit() async {
    super.onInit();

    // تحقق من الحالة الأولية
    final result = await Connectivity().checkConnectivity();
    isOnline.value = _isConnected(result);

    // ابدأ الاستماع للتغييرات
    _sub = Connectivity().onConnectivityChanged.listen((result) {
      final wasOnline = isOnline.value;
      isOnline.value = _isConnected(result);

      if (!wasOnline && isOnline.value) {
        // عادل الاتصال
        _onConnectionRestored();
      } else if (wasOnline && !isOnline.value) {
        // انقطع الاتصال
        _onConnectionLost();
      }
    });
  }

  bool _isConnected(List<ConnectivityResult> result) =>
      result.any((r) => r != ConnectivityResult.none);

  void _onConnectionRestored() {
    Get.closeCurrentSnackbar();
    Get.snackbar(
      '📶 تم استعادة الاتصال',
      'جارٍ إرسال الطلبات المحفوظة...',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF00C853).withValues(alpha: 0.15),
      colorText: const Color(0xFF00C853),
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.wifi_rounded, color: Color(0xFF00C853)),
      margin: const EdgeInsets.all(12),
      borderRadius: 16,
    );

    // أرسل الطابور بعد ثانية (للتأكد من استقرار الاتصال)
    Future.delayed(const Duration(seconds: 1), () async {
      if (_queue.hasPending) await _queue.flush();
    });
  }

  void _onConnectionLost() {
    Get.snackbar(
      '📵 لا يوجد إنترنت',
      'سيتم حفظ طلباتك وإرسالها عند استعادة الاتصال',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFFF5252).withValues(alpha: 0.15),
      colorText: const Color(0xFFFF5252),
      duration: const Duration(seconds: 5),
      icon: const Icon(Icons.wifi_off_rounded, color: Color(0xFFFF5252)),
      margin: const EdgeInsets.all(12),
      borderRadius: 16,
      isDismissible: false,
    );
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}

