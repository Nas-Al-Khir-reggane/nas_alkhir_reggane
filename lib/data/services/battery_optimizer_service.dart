import 'dart:io';

import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../features/shared/widgets/stability_guide_dialog.dart';

/// خدمة تجاوز توفير الطاقة
/// تطلب من المستخدم السماح للتطبيق بالعمل بدون قيود
/// وتوجّهه لإعدادات التشغيل التلقائي حسب نوع هاتفه
class BatteryOptimizerService {
  static const String _prefKey = 'battery_optimization_asked';
  static const String _prefDismissCount = 'battery_dismiss_count';

  /// توثيق روابط الإعدادات الخاصة بالشركات المصنعة (OEM Intents)
  static const Map<String, String> _oemIntents = {
    'Xiaomi': 'intent:#Intent;component=com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity;end',
    'samsung': 'intent:#Intent;component=com.samsung.android.lool/com.samsung.android.sm.ui.battery.BatteryActivity;end',
    'Huawei': 'intent:#Intent;component=com.huawei.systemmanager/com.huawei.systemmanager.optimize.process.ProtectActivity;end',
    'OPPO': 'intent:#Intent;component=com.coloros.safecenter/com.coloros.safecenter.permission.startup.StartupAppListActivity;end',
    'VIVO': 'intent:#Intent;component=com.vivo.permissionmanager/com.vivo.permissionmanager.activity.BgStartUpManagerActivity;end',
    'Realme': 'intent:#Intent;component=com.coloros.safecenter/com.coloros.safecenter.permission.startup.StartupAppListActivity;end',
  };

  /// تُستدعى عند بدء التطبيق — تطلب الأذونات إذا لم تُطلب من قبل
  static Future<void> requestOptimizations(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_prefKey) ?? false;
    final dismissCount = prefs.getInt(_prefDismissCount) ?? 0;

    if (alreadyAsked && dismissCount >= 5) {
      // رفعنا عدد التنبيهات إلى 5 لأهميتها في الهواتف الحديثة
      return;
    }

    // تحقق من الحالة الحالية
    final isBatteryIgnoring = await Permission.ignoreBatteryOptimizations.isGranted;
    final isNotifGranted = await Permission.notification.isGranted;

    if (isBatteryIgnoring && isNotifGranted) {
      await prefs.setBool(_prefKey, true);
      debugPrint('✅ [Battery] Everything is stable.');
      return;
    }

    if (!context.mounted) return;

    // عرض الدليل التفاعلي الجديد
    _showStabilityGuide(context, prefs, dismissCount);
  }

  /// عرض الدليل التفاعلي الجديد بملء الشاشة والزجاجي
  static void _showStabilityGuide(
    BuildContext context,
    SharedPreferences prefs,
    int dismissCount,
  ) async {
    final manufacturer = await _getManufacturer();

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StabilityGuideDialog(
          oemIntents: _oemIntents,
          manufacturer: manufacturer,
        ),
      ),
    ).then((_) {
      // تحديث عدد مرات التجاهل
      prefs.setInt(_prefDismissCount, dismissCount + 1);
    });
  }

  /// كشف الشركة المصنعة للهاتف بدقة باستخدام device_info_plus
  static Future<String?> _getManufacturer() async {
    try {
      if (Platform.isAndroid) {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.manufacturer;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ [Battery] Could not detect manufacturer: $e');
      return null;
    }
  }
}

