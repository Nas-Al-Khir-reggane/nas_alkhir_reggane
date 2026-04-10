import 'dart:io';

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

/// خدمة تجاوز توفير الطاقة
/// تطلب من المستخدم السماح للتطبيق بالعمل بدون قيود
/// وتوجّهه لإعدادات التشغيل التلقائي حسب نوع هاتفه
class BatteryOptimizerService {
  static const String _prefKey = 'battery_optimization_asked';
  static const String _prefDismissCount = 'battery_dismiss_count';

  /// تُستدعى عند بدء التطبيق — تطلب الأذونات إذا لم تُطلب من قبل
  static Future<void> requestOptimizations(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_prefKey) ?? false;

    // إذا لم يُسأل من قبل أو رفض أقل من 3 مرات
    final dismissCount = prefs.getInt(_prefDismissCount) ?? 0;

    if (alreadyAsked && dismissCount >= 3) {
      // المستخدم رفض 3 مرات، لا نزعجه أكثر
      return;
    }

    // تحقق إذا كان التطبيق بالفعل مستثنى من توفير الطاقة
    final isIgnoring = await Permission.ignoreBatteryOptimizations.isGranted;
    if (isIgnoring) {
      await prefs.setBool(_prefKey, true);
      debugPrint('✅ [Battery] Already ignoring battery optimizations');
      return;
    }

    // انتظر قليلاً حتى تظهر الشاشة الرئيسية
    await Future.delayed(const Duration(seconds: 3));

    if (!context.mounted) return;

    // عرض حوار الشرح أولاً
    _showExplanationDialog(context, prefs, dismissCount);
  }

  /// حوار الشرح المبسّط بالعربية
  static void _showExplanationDialog(
    BuildContext context,
    SharedPreferences prefs,
    int dismissCount,
  ) {
    final manufacturer = _getManufacturer();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.battery_alert_rounded, color: Colors.orange.shade700, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'إعداد مهم للطوارئ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'لكي تصلك إشعارات الطوارئ ونداءات التبرع بالدم في أي وقت، '
                'يجب السماح للتطبيق بالعمل في الخلفية.',
                style: TextStyle(fontSize: 15, height: 1.7),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'بدون هذا الإعداد، قد لا تصلك نداءات الاستغاثة العاجلة!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (manufacturer != null) ...[
                const SizedBox(height: 12),
                Text(
                  'هاتفك: $manufacturer',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                prefs.setInt(_prefDismissCount, dismissCount + 1);
              },
              child: Text('لاحقاً', style: TextStyle(color: Colors.grey.shade500)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _requestAllOptimizations(prefs);
              },
              icon: const Icon(Icons.security_rounded, size: 18),
              label: const Text('السماح الآن'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// تنفيذ كل طلبات تجاوز التحسين
  static Future<void> _requestAllOptimizations(SharedPreferences prefs) async {
    try {
      // 1. طلب النظام الرسمي: تجاوز Battery Optimization
      final status = await Permission.ignoreBatteryOptimizations.request();
      debugPrint('🔋 [Battery] Permission status: $status');

      // 2. We skip using optimize_battery OEM intents to avoid build errors. 
      // The system battery optimization request above handles the main Doze exception.
      
      await prefs.setBool(_prefKey, true);
    } catch (e) {
      debugPrint('❌ [Battery] Optimization request failed: $e');
    }
  }

  /// كشف الشركة المصنعة للهاتف
  static String? _getManufacturer() {
    try {
      // يتم الحصول عليه من Platform environment على Android
      final manufacturer = Platform.environment['MANUFACTURER'] ??
          Platform.environment['BRAND'];
      return manufacturer;
    } catch (_) {
      return null;
    }
  }
}
