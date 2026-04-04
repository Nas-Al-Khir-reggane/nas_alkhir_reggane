import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/animations/scroll_animations.dart';

/// 💊 كبسولة "نبض الخير" - تصميم أفقي مصغر وإبداعي
/// يظهر كمؤشر حي للأثر المجتمعي دون إشغال مساحة كبيرة
class CommunityPulseCard extends StatelessWidget {
  const CommunityPulseCard({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stats')
          .doc('blood_stats')
          .snapshots(),
      builder: (context, snapshot) {
        int totalUnits = 0;
        int livesSaved = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          totalUnits = (data['totalUnits'] ?? 0) as int;
          livesSaved = (data['livesSaved'] ?? 0) as int;
        }

        return Container(
          height: 52,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: const Color(0xFFC62828).withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // أيقونة النبض المصغرة
                      _MiniPulsingHeart(),
                      const SizedBox(width: 12),
                      
                      // مؤشر "مباشر"
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'نبض الخير',
                        style: GoogleFonts.tajawal(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // الإحصائيات (الكبسولات الفرعية)
                      _CompactStatPill(
                        icon: Icons.water_drop_rounded,
                        value: totalUnits,
                        color: const Color(0xFFEF5350),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      _CompactStatPill(
                        icon: Icons.favorite_rounded,
                        value: livesSaved,
                        color: const Color(0xFFFF8A80),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CompactStatPill extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;

  const _CompactStatPill({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          ScrollAnimations.numberCounter(
            value: value,
            style: GoogleFonts.tajawal(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPulsingHeart extends StatefulWidget {
  @override
  State<_MiniPulsingHeart> createState() => _MiniPulsingHeartState();
}

class _MiniPulsingHeartState extends State<_MiniPulsingHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.favorite_rounded,
            color: const Color(0xFFC62828).withValues(alpha: 0.3),
            size: 24,
          ),
          const Icon(
            Icons.favorite_rounded,
            color: Color(0xFFD32F2F),
            size: 16,
          ),
        ],
      ),
    );
  }
}
