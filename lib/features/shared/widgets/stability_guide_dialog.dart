import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

class StabilityGuideDialog extends StatefulWidget {
  final Map<String, String> oemIntents;
  final String? manufacturer;

  const StabilityGuideDialog({
    super.key,
    required this.oemIntents,
    this.manufacturer,
  });

  @override
  State<StabilityGuideDialog> createState() => _StabilityGuideDialogState();
}

class _StabilityGuideDialogState extends State<StabilityGuideDialog> {
  int _currentStep = 0;
  bool _notificationStatus = false;
  bool _batteryStatus = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final notif = await Permission.notification.isGranted;
    final batt = await Permission.ignoreBatteryOptimizations.isGranted;
    if (mounted) {
      setState(() {
        _notificationStatus = notif;
        _batteryStatus = batt;
        if (notif && !batt) _currentStep = 1;
        if (notif && batt) _currentStep = 2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.white.withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.9),
                Colors.white.withValues(alpha: 0.7),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeInDown(
                duration: const Duration(milliseconds: 600),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.shade500,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emergency_share_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ).animate(onPlay: (controller) => controller.repeat())
                 .shimmer(duration: const Duration(seconds: 2), color: Colors.white.withValues(alpha: 0.3)),
              ),
              const SizedBox(height: 24),
              const Text(
                'استقرار نظام الطوارئ',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1C1E),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'لكي تصلك استغاثات التبرع بالدم والحالات الحرجة دون تأخير، يرجى تفعيل هذه الإعدادات الهامة:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF44474E),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              _buildStepItem(
                index: 0,
                icon: Icons.notifications_active_rounded,
                title: 'تفعيل الإشعارات',
                subtitle: 'لضمان وصول النداءات فوراً',
                isDone: _notificationStatus,
                onTap: () async {
                  await Permission.notification.request();
                  _checkPermissions();
                },
              ),
              _buildStepItem(
                index: 1,
                icon: Icons.battery_charging_full_rounded,
                title: 'تجاهل توفير الطاقة',
                subtitle: 'لمنع النظام من إيقاف الخدمة',
                isDone: _batteryStatus,
                onTap: () async {
                  await Permission.ignoreBatteryOptimizations.request();
                  _checkPermissions();
                },
              ),
              _buildStepItem(
                index: 2,
                icon: Icons.settings_suggest_rounded,
                title: 'التشغيل التلقائي',
                subtitle: 'إعدادات الشركة المصنعة (${widget.manufacturer ?? "عام"})',
                isDone: false,
                onTap: () async {
                  if (widget.manufacturer != null && widget.oemIntents.containsKey(widget.manufacturer)) {
                    final intent = widget.oemIntents[widget.manufacturer]!;
                    await launchUrl(Uri.parse(intent));
                  } else {
                    await openAppSettings();
                  }
                },
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                   Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: Text(
                        'لاحقاً',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_notificationStatus && _batteryStatus) {
                           Get.back();
                        } else {
                           _checkPermissions();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(_notificationStatus && _batteryStatus ? 'تم الإعداد' : 'تحديث الحالة'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => launchUrl(Uri.parse('https://dontkillmyapp.com/')),
                child: Text(
                  'مشاكل في وصول الإشعارات؟ اضغط هنا لمزيد من الحلول',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade700, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDone,
    required VoidCallback onTap,
  }) {
    final bool isActive = _currentStep == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue.shade50.withValues(alpha: 0.5) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? Colors.blue.shade200 : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDone ? Colors.green.shade100 : (isActive ? Colors.blue.shade100 : Colors.grey.shade100),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDone ? Icons.check_circle_rounded : icon,
                  color: isDone ? Colors.green.shade700 : (isActive ? Colors.blue.shade700 : Colors.grey.shade500),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDone ? Colors.green.shade800 : (isActive ? Colors.blue.shade900 : Colors.grey.shade700),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDone ? Colors.green.shade600 : (isActive ? Colors.blue.shade600 : Colors.grey.shade500),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDone)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isActive ? Colors.blue.shade700 : Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
