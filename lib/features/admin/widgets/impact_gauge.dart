import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math' as math;
import '../../../core/theme/app_theme.dart';
import '../controllers/admin_controller.dart';
import '../../../data/models/strategic_goal_model.dart';
import '../../../core/animations/scroll_animations.dart';

class ImpactGauge extends StatelessWidget {
  final double size;
  
  const ImpactGauge({super.key, this.size = 180});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();
    
    return Obx(() {
      if (controller.activeGoals.isEmpty) {
        return _buildEmptyImpactState(context);
      }

      // عرض الهدف الأول كهدف رئيسي (المؤشر) والبقية كقائمة أسفله
      final mainGoal = controller.activeGoals.first;
      final percentage = (mainGoal.progressPercentage * 100).toInt();

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.glassDecoration,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مستهدفات الأداء التشغيلية', 
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface, 
                        fontSize: 16, 
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Tajawal'
                      )
                    ),
                    Text(mainGoal.title, 
                      style: TextStyle(color: AppTheme.primaryGreen, fontSize: 11, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
                _buildTypeBadge(mainGoal.type),
              ],
            ),
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: CustomPaint(
                    painter: _GaugePainter(
                      progress: mainGoal.progressPercentage.clamp(0.01, 1.0),
                      color: _getGoalColor(mainGoal.type),
                      backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScrollAnimations.numberCounter(
                      value: percentage,
                      suffix: '%',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface, 
                        fontSize: 32, 
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Tajawal'
                      )
                    ),
                    Text('نسبة الإنجاز', 
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontFamily: 'Tajawal')
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('الحالي', mainGoal.currentValue, mainGoal.unit, Icons.check_circle_outline),
                _buildStatItem('المستهدف', mainGoal.targetValue, mainGoal.unit, Icons.flag_outlined),
              ],
            ),

            if (controller.activeGoals.length > 1) ...[
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 16),
              ...controller.activeGoals.skip(1).map((goal) => _buildSecondaryGoal(context, goal)),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildEmptyImpactState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: AppTheme.glassDecoration,
      child: Column(
        children: [
          Icon(Icons.rocket_launch_rounded, color: Colors.grey[200], size: 60),
          const SizedBox(height: 16),
          Text('انطلق بجمعية "ناس الخير" نحو القمة', 
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')
          ),
          const SizedBox(height: 8),
          Text('قم بتحديد مستهدفات تشغيلية لهذا الشهر لتحفيز الجميع على العطاء والمشاركة.', 
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontFamily: 'Tajawal', height: 1.5)
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryGoal(BuildContext context, StrategicGoalModel goal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(goal.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
              Text('${(goal.progressPercentage * 100).toInt()}%', 
                style: TextStyle(color: _getGoalColor(goal.type), fontSize: 11, fontWeight: FontWeight.bold)
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: goal.progressPercentage.clamp(0.0, 1.0),
              backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              color: _getGoalColor(goal.type),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(GoalType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getGoalColor(type).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(_getGoalTypeLabel(type), 
        style: TextStyle(color: _getGoalColor(type), fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')
      ),
    );
  }

  Color _getGoalColor(GoalType type) {
    switch (type) {
      case GoalType.donations: return Colors.orange;
      case GoalType.beneficiaries: return AppTheme.primaryGreen;
      case GoalType.services: return Colors.blue;
      default: return Colors.purple;
    }
  }

  String _getGoalTypeLabel(GoalType type) {
    switch (type) {
      case GoalType.donations: return 'تبرعات';
      case GoalType.beneficiaries: return 'مستفيدين';
      case GoalType.services: return 'عملياتي';
      default: return 'عام';
    }
  }

  Widget _buildStatItem(String label, num value, String unit, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScrollAnimations.numberCounter(
              value: value,
              suffix: ' $unit',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Tajawal')
            ),
            Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontFamily: 'Tajawal')),
          ],
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _GaugePainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2);
    final strokeWidth = 15.0;

    // Background arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      math.pi * 0.8,
      math.pi * 1.4,
      false,
      bgPaint,
    );

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
      
    // Add glow effect
    final shadowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      math.pi * 0.8,
      math.pi * 1.4 * progress,
      false,
      shadowPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      math.pi * 0.8,
      math.pi * 1.4 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.color != color || 
           oldDelegate.backgroundColor != backgroundColor;
  }
}
