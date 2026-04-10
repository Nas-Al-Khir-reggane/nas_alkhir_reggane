import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// خدمة إبقاء التطبيق حياً في الخلفية
/// تمنع النظام من قتل التطبيق حتى على هواتف Xiaomi و Samsung و Huawei
class BackgroundKeepAliveService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();

  /// تهيئة الخدمة — تُستدعى مرة واحدة من main.dart
  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    try {
      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: _onStart,
          isForegroundMode: true,
          autoStart: true,
          autoStartOnBoot: true,
          foregroundServiceNotificationId: 9999,
          initialNotificationTitle: 'ناس الخير',
          initialNotificationContent: '🟢 جاهز لاستقبال نداءات الطوارئ',
          foregroundServiceTypes: [AndroidForegroundType.dataSync],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: _onStart,
        ),
      );

      debugPrint('✅ [BackgroundService] Initialized successfully');
    } catch (e) {
      debugPrint('❌ [BackgroundService] Init failed: $e');
    }
  }

  /// نقطة البداية عندما تبدأ الخدمة في الخلفية
  @pragma('vm:entry-point')
  static Future<void> _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      // تحديث الإشعار الثابت
      service.setAsForegroundService();

      service.on('setAsForeground').listen((_) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((_) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((_) {
      service.stopSelf();
    });

    // نبضة حياة كل 30 ثانية لإبقاء الخدمة حية
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: 'ناس الخير',
            content: '🟢 جاهز لاستقبال نداءات الطوارئ',
          );
        }
      }

      // إرسال نبضة للتطبيق الرئيسي
      service.invoke('update', {'timestamp': DateTime.now().toIso8601String()});
    });
  }

  /// تفعيل WakeLock لمنع نوم المعالج (يُستدعى عند فتح التطبيق)
  static Future<void> enableWakeLock() async {
    try {
      await WakelockPlus.enable();
      debugPrint('🔒 [WakeLock] Enabled');
    } catch (e) {
      debugPrint('⚠️ [WakeLock] Failed to enable: $e');
    }
  }

  /// تعطيل WakeLock (يُستدعى عند إغلاق التطبيق إذا لزم الأمر)
  static Future<void> disableWakeLock() async {
    try {
      await WakelockPlus.disable();
      debugPrint('🔓 [WakeLock] Disabled');
    } catch (e) {
      debugPrint('⚠️ [WakeLock] Failed to disable: $e');
    }
  }
}
