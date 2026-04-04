import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import '../../../core/theme/app_theme.dart';
import '../controllers/admin_controller.dart';
import '../screens/full_screen_map_screen.dart';

class MissionControlMap extends StatefulWidget {
  const MissionControlMap({super.key});

  @override
  State<MissionControlMap> createState() => _MissionControlMapState();
}

class _MissionControlMapState extends State<MissionControlMap> {
  
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final requests = controller.recentRequests;
      
      return RepaintBoundary(
        child: GestureDetector(
          onTap: () => Get.to(() => const FullScreenMapScreen(), transition: Transition.fadeIn),
          child: Container(
            height: 200, // Reduced height for dashboard
            width: double.infinity,
            decoration: AppTheme.glassDecoration.copyWith(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3), width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // مظهر خريطة رمزي (Symbolic Map visualization)
                // لا نستخدم FlutterMap هنا لضمان عدم تشغيل المكتبة في الخلفية
                Positioned.fill(
                  child: Container(
                    color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                    child: CustomPaint(
                      painter: _GridPainter(
                        color: AppTheme.primaryGreen.withValues(alpha: isDark ? 0.05 : 0.08),
                        spacing: 20,
                      ),
                    ),
                  ),
                ),
                
                // نقاط رمزية تمثل الطلبات (بدون محرك خرائط)
                Positioned.fill(
                  child: Hero(
                    tag: 'admin_map_hero',
                    child: Stack(
                      children: requests.take(10).map((request) {
                        // توزيع عشوائي للنقاط للعرض الجمالي فقط في المعاينة
                        final random = math.Random(request.id.hashCode);
                        return Positioned(
                          left: 50 + random.nextDouble() * 200,
                          top: 40 + random.nextDouble() * 100,
                          child: Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: request.urgency == 'emergency' ? Colors.red : AppTheme.primaryGreen,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (request.urgency == 'emergency' ? Colors.red : AppTheme.primaryGreen).withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                
                // غطاء تدرج للجمالية
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          isDark ? Colors.black.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
                
                // زر الدخول والتشغيل
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.4), blurRadius: 20)],
                        ),
                        child: const Icon(Icons.map_rounded, color: Colors.black, size: 30),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'دخول خريطة العمليات الحية',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                ),
                
                // عنوان وتوهج واجهة قصر القيادة
                _buildMapHeader(isDark),
                
                // مؤشر عدد الطلبات النشطة
                _buildStatusIndicator(requests.length, isDark),
              ],
            ),
          ),
        ),
      );
    });
  }


  Widget _buildMapHeader(bool isDark) {
    return Positioned(
      top: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.black87 : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
            ).animate(onPlay: (c) => c.repeat())
             .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.5, 1.5))
             .fadeOut(),
            const SizedBox(width: 10),
            Text(
              'الانتشار الميداني الحي',
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimaryLight, 
                fontSize: 11, 
                fontWeight: FontWeight.w800, 
                fontFamily: 'Tajawal'
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(int count, bool isDark) {
    return Positioned(
      bottom: 16, left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
        ),
        child: Text(
          '$count طلب نشط حالياً',
          style: TextStyle(
            color: isDark ? Colors.white70 : AppTheme.textPrimaryLight, 
            fontSize: 10, 
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal'
          ),
        ),
      ),
    );
  }

}

class _GridPainter extends CustomPainter {
  final Color color;
  final double spacing;

  _GridPainter({required this.color, required this.spacing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
