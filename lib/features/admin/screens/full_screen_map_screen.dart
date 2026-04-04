import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/admin_controller.dart';
import '../../../data/models/service_request_model.dart';
import 'dart:math' as math;

class FullScreenMapScreen extends StatefulWidget {
  final LatLng? targetLocation;
  final double initialZoom;
  final String? title;

  const FullScreenMapScreen({
    super.key, 
    this.targetLocation, 
    this.initialZoom = 12.0,
    this.title,
  });

  @override
  State<FullScreenMapScreen> createState() => _FullScreenMapScreenState();
}

class _FullScreenMapScreenState extends State<FullScreenMapScreen> {
  final MapController _mapController = MapController();
  
  void _recenter() {
    _mapController.move(
      widget.targetLocation ?? const LatLng(26.7119, 0.1706), 
      widget.initialZoom
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // الخريطة الأساسية
          Hero(
            tag: 'admin_map_hero',
            child: Obx(() {
              final requests = controller.recentRequests;
              final List<Marker> markers = [];

              for (var request in requests) {
                LatLng pos;
                if (request.latitude != null && request.longitude != null) {
                  pos = LatLng(request.latitude!, request.longitude!);
                } else {
                  final random = math.Random(request.id.hashCode);
                  pos = LatLng(
                    26.7119 + (random.nextDouble() - 0.5) * 0.08,
                    0.1706 + (random.nextDouble() - 0.5) * 0.08
                  );
                }
                markers.add(
                  Marker(
                    point: pos,
                    width: 75,
                    height: 75,
                    child: _buildPulseMarker(request, isDark),
                  ),
                );
              }

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: widget.targetLocation ?? const LatLng(26.7119, 0.1706),
                  initialZoom: widget.initialZoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: isDark 
                      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                      : 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    tileDisplay: const TileDisplay.fadeIn(),
                    userAgentPackageName: 'com.nasalkheir.nas_alkheir_app',
                  ),
                  MarkerLayer(markers: markers),
                ],
              );
            }),
          ),

          // زر الإغلاق الأنيق
          Positioned(
            top: 50,
            right: 20,
            child: GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15),
                  ],
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).scale(delay: 200.ms),

          // زر إعادة التمركز
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              onPressed: _recenter,
              backgroundColor: AppTheme.primaryGreen,
              child: const Icon(Icons.my_location_rounded, color: Colors.black),
            ),
          ),

          // لوحة معلومات علوية
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  ).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(1, 1), end: const Offset(1.5, 1.5)).fadeOut(),
                  const SizedBox(width: 10),
                  Text(
                    widget.title ?? 'الرقابة الميدانية الشاملة',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                  ),
                ],
              ),
            ),
          ).animate().slideX(begin: -1, end: 0, duration: 500.ms),
        ],
      ),
    );
  }

  Widget _buildPulseMarker(ServiceRequestModel request, bool isDark) {
    final isEmergency = request.urgency == 'emergency';
    final baseColor = isEmergency ? Colors.redAccent : (isDark ? Colors.cyanAccent : const Color(0xFF00ACC1));

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: baseColor.withValues(alpha: 0.35),
          ),
        ).animate(onPlay: (controller) => controller.repeat())
         .scale(begin: const Offset(1, 1), end: const Offset(3, 3), duration: 2000.ms, curve: Curves.easeOut)
         .fadeOut(duration: 2000.ms),

        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: baseColor, blurRadius: 15, spreadRadius: 4),
            ],
          ),
        ),
        
        Positioned(
          top: 6,
          child: Icon(
            _getRequestIcon(request.type),
            color: baseColor,
            size: 18,
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .moveY(begin: -3, end: 3, duration: 1200.ms),
        ),
      ],
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
}
