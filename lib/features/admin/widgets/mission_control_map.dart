import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/admin_controller.dart';
import '../../../data/models/service_request_model.dart';
import '../screens/full_screen_map_screen.dart';
import 'dart:math' as math;

class MissionControlMap extends StatefulWidget {
  const MissionControlMap({super.key});

  @override
  State<MissionControlMap> createState() => _MissionControlMapState();
}

class _MissionControlMapState extends State<MissionControlMap> {
  final MapController _mapController = MapController();
  
  // موقع افتراضي (رقان، أدرار)
  static const LatLng _initialCenter = LatLng(26.7119, 0.1706);

  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final requests = controller.recentRequests;
      
      // تجهيز الإحداثيات للماركرات وضبط الحدود
      final List<LatLng> points = [];
      final List<Marker> markers = [];

      for (var request in requests) {
        LatLng pos;
        if (request.latitude != null && request.longitude != null) {
          pos = LatLng(request.latitude!, request.longitude!);
        } else {
          // عشوائي حول رقان للعرض الجمالي في حالة غياب المواقع الحقيقية
          final random = math.Random(request.id.hashCode);
          pos = LatLng(
            26.7119 + (random.nextDouble() - 0.5) * 0.08,
            0.1706 + (random.nextDouble() - 0.5) * 0.08
          );
        }
        points.add(pos);
        
        markers.add(
          Marker(
            point: pos,
            width: 70,
            height: 70,
            child: _buildPulseMarker(request, isDark),
          ),
        );
      }

      // تفعيل التحرك التلقائي إذا وجدت نقاط جديدة
      if (points.isNotEmpty) {
        _fitBounds(points);
      }

      return GestureDetector(
        onTap: () => Get.to(() => const FullScreenMapScreen(), transition: Transition.fadeIn),
        child: Container(
          height: 280,
          width: double.infinity,
          decoration: AppTheme.glassDecoration.copyWith(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3), width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Hero(
                tag: 'admin_map_hero',
                child: FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: 11,
                    interactionOptions: InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  ),
                  children: [
                    TileLayer(
                      // استخدام OSM Hot لمزيد من الحيوية والوضوح (Humanitarian OpenStreetMap)
                      urlTemplate: isDark 
                        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                        : 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      tileDisplay: const TileDisplay.fadeIn(),
                      userAgentPackageName: 'com.nasalkheir.nas_alkheir_app',
                    ),
                    MarkerLayer(markers: markers),
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
      );
    });
  }

  Widget _buildPulseMarker(ServiceRequestModel request, bool isDark) {
    final isEmergency = request.urgency == 'emergency';
    final baseColor = isEmergency ? Colors.redAccent : (isDark ? Colors.cyanAccent : const Color(0xFF00ACC1));

    return GestureDetector(
      onTap: () => _showRequestBrief(request),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // توهج نابض (Pulse Effect)
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: baseColor.withValues(alpha: 0.4),
            ),
          ).animate(onPlay: (controller) => controller.repeat())
           .scale(begin: const Offset(1, 1), end: const Offset(2.8, 2.8), duration: 1800.ms, curve: Curves.easeOut)
           .fadeOut(duration: 1800.ms),

          // النقطة المركزية
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: baseColor, blurRadius: 12, spreadRadius: 3),
              ],
            ),
          ),
          
          // أيقونة النوع بجودة عالية
          Positioned(
            top: 5,
            child: Icon(
              _getRequestIcon(request.type),
              color: isDark ? baseColor : baseColor.withValues(alpha: 0.9),
              size: 16,
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .moveY(begin: -2, end: 2, duration: 1000.ms),
          ),
        ],
      ),
    );
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

  IconData _getRequestIcon(String type) {
    switch (type) {
      case 'medical': return Icons.medical_services_rounded;
      case 'food': return Icons.flatware_rounded;
      case 'water': return Icons.water_drop_rounded;
      case 'blood': return Icons.bloodtype_rounded;
      default: return Icons.help_center_rounded;
    }
  }

  void _showRequestBrief(ServiceRequestModel request) {
    Get.snackbar(
      request.typeName,
      'صاحب الطلب: ${request.requesterName}',
      backgroundColor: Get.isDarkMode ? Colors.black87 : Colors.white,
      colorText: Get.isDarkMode ? Colors.white : AppTheme.textPrimaryLight,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(20),
      borderRadius: 15,
      borderWidth: 1,
      borderColor: AppTheme.primaryGreen.withValues(alpha: 0.3),
      icon: Icon(
        Icons.info_outline, 
        color: request.urgency == 'emergency' ? Colors.redAccent : Colors.cyanAccent
      ),
    );
  }
}
