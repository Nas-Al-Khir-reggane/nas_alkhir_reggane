import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HexagonalProgressIndicator extends StatelessWidget {
  final double progress;
  final double size;
  final String label;
  final Color? color;

  const HexagonalProgressIndicator({
    super.key,
    required this.progress,
    this.size = 60,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final Color progressColor = color ??
        (progress > 0.75
            ? AppTheme.successColor
            : progress > 0.4
                ? AppTheme.primaryGreen
                : AppTheme.warningColor);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _HexagonPainter(
                  progress: 1.0,
                  color: progressColor.withValues(alpha: 0.75),
                  strokeWidth: 4,
                ),
              ),
              CustomPaint(
                size: Size(size, size),
                painter: _HexagonPainter(
                  progress: value,
                  color: progressColor,
                  strokeWidth: 4,
                ),
              ),
              Text(
                '${(value * 100).toInt()}%',
                style: TextStyle(
                  color: progressColor,
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HexagonPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _HexagonPainter({required this.progress, required this.color, this.strokeWidth = 4.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (progress >= 1.0) {
      final path = _createHexagonPath(center, radius);
      canvas.drawPath(path, paint);
    } else if (progress > 0) {
      final path = Path();
      final angleStep = math.pi / 3;
      final startAngle = -math.pi / 2;

      List<Offset> points = [];
      for (int i = 0; i <= 6; i++) {
        double x = center.dx + radius * math.cos(startAngle + angleStep * i);
        double y = center.dy + radius * math.sin(startAngle + angleStep * i);
        points.add(Offset(x, y));
      }

      final fullPerimeter = 6.0;
      double currentProgress = progress * fullPerimeter;

      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 0; i < 6; i++) {
        if (currentProgress >= 1.0) {
          path.lineTo(points[i + 1].dx, points[i + 1].dy);
          currentProgress -= 1.0;
        } else if (currentProgress > 0) {
          double x = points[i].dx + (points[i + 1].dx - points[i].dx) * currentProgress;
          double y = points[i].dy + (points[i + 1].dy - points[i].dy) * currentProgress;
          path.lineTo(x, y);
          currentProgress = 0;
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  Path _createHexagonPath(Offset center, double radius) {
    final path = Path();
    final angleStep = math.pi / 3;
    final startAngle = -math.pi / 2;
    for (int i = 0; i < 6; i++) {
      double x = center.dx + radius * math.cos(startAngle + angleStep * i);
      double y = center.dy + radius * math.sin(startAngle + angleStep * i);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HexagonPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class GoalGridProgress extends StatefulWidget {
  final double budget;
  final double collected;
  final String categoryId;
  final Color activeColor;
  final bool isScrollable;
  final bool forceComplete;
  final int? maxDisplayUnits; // New: Limit units displayed (for share card)

  const GoalGridProgress({
    super.key,
    required this.budget,
    required this.collected,
    required this.categoryId,
    required this.activeColor,
    this.isScrollable = true,
    this.forceComplete = false,
    this.maxDisplayUnits,
  });

  @override
  State<GoalGridProgress> createState() => _GoalGridProgressState();
}

class _GoalGridProgressState extends State<GoalGridProgress> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  static const double unitValue = 1000.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int totalUnits = (widget.budget / unitValue).ceil();
    final int filledUnits = (widget.collected / unitValue).floor();
    final int displayUnits = widget.maxDisplayUnits != null 
        ? math.min(totalUnits, widget.maxDisplayUnits!) 
        : totalUnits;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'كل شكل يمثل 1,000 دج',
                  style: TextStyle(
                    color: widget.activeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
                Text(
                  'المتبقي لإكمال الهدف: ${(widget.budget - widget.collected).toInt()} دج',
                  style: TextStyle(color: AppTheme.textHint, fontSize: 10, fontFamily: 'Tajawal'),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.activeColor.withValues(alpha: 0.15), widget.activeColor.withValues(alpha: 0.9)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: widget.activeColor.withValues(alpha: 0.75)),
              ),
              child: Text(
                '$filledUnits / $totalUnits وحدة',
                style: TextStyle(color: widget.activeColor, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          constraints: BoxConstraints(
            maxHeight: widget.isScrollable ? (totalUnits > 100 ? 300 : double.infinity) : double.infinity,
          ),
          padding: const EdgeInsets.all(4),
          child: _buildGridContent(displayUnits, filledUnits),
        ),
      ],
    );
  }

  Widget _buildGridContent(int totalUnits, int filledUnits) {
    final grid = LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: Size(constraints.maxWidth, _calculateHeight(totalUnits)),
              painter: _CinematicGridPainter(
                totalUnits: totalUnits,
                filledUnits: math.min(filledUnits, totalUnits),
                categoryId: widget.categoryId,
                activeColor: widget.activeColor,
                animation: widget.forceComplete ? 1.0 : _controller.value,
              ),
            );
          },
        );
      },
    );

    return widget.isScrollable ? SingleChildScrollView(child: grid) : grid;
  }

  double _calculateHeight(int totalUnits) {
    const int crossAxisCount = 10;
    int rows = (totalUnits / crossAxisCount).ceil();
    const double spacing = 10.0;
    const double itemSize = 28.0; 
    return rows * (itemSize + spacing) + 20;
  }
}

class _CinematicGridPainter extends CustomPainter {
  final int totalUnits;
  final int filledUnits;
  final String categoryId;
  final Color activeColor;
  final double animation;

  _CinematicGridPainter({
    required this.totalUnits,
    required this.filledUnits,
    required this.categoryId,
    required this.activeColor,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int crossAxisCount = 10;
    const double spacing = 10.0;
    final double itemSize = (size.width - (spacing * (crossAxisCount - 1))) / crossAxisCount;
    
    for (int i = 0; i < totalUnits; i++) {
      final int row = i ~/ crossAxisCount;
      final int col = i % crossAxisCount;
      
      final double x = col * (itemSize + spacing);
      final double y = row * (itemSize + spacing);
      
      final bool isFilled = i < filledUnits;
      
      // تأثير الظهور المتتابع (Staggered)
      final double unitDelay = (i % 50) / 100.0;
      final double unitProgress = math.max(0.0, math.min(1.0, (animation - unitDelay) * 4.0));
      
      if (unitProgress <= 0) continue;

      _drawPremiumUnit(
        canvas, 
        Offset(x + itemSize / 2, y + itemSize / 2), 
        itemSize * 0.45 * unitProgress, 
        isFilled,
      );
    }
  }

  void _drawPremiumUnit(Canvas canvas, Offset center, double r, bool isFilled) {
    final Rect rect = Rect.fromCircle(center: center, radius: r);

    if (isFilled) {
      // 1. توهج نيون محيطي أقوى لزيادة الوضوح (Vibrant Glow)
      final Paint glowPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8);
      canvas.drawCircle(center, r * 1.4, glowPaint);

      // 2. تدرج لوني أكثر حيوية (High Vibrancy Gradient)
      final Paint bodyPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(activeColor, Colors.white, 0.4)!,
            activeColor,
            Color.lerp(activeColor, Colors.black, 0.3)!,
          ],
        ).createShader(rect);
      
      final Path path = _getPremiumShapePath(center, r);
      canvas.drawPath(path, bodyPaint);

      // 3. لمعة زجاجية حادة (Glass Highlight)
      final Paint highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      
      final Path highlightPath = _getHighlightPath(center, r);
      canvas.drawPath(highlightPath, highlightPaint);
      
      // 4. إطار خارجي أبيض ناعم للتباين
      final Paint borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawPath(path, borderPaint);

    } else {
      // وحدات غير مكتملة (Empty Vibrant Containers)
      final Paint emptyPaint = Paint()
        ..color = AppTheme.textHint.withValues(alpha: 0.15) // Increased opacity for clarity
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      
      final Path path = _getPremiumShapePath(center, r);
      canvas.drawPath(path, emptyPaint);
      
      final Paint innerShadow = Paint()
        ..color = AppTheme.textHint.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, innerShadow);
    }
  }

  Path _getPremiumShapePath(Offset center, double r) {
    final path = Path();
    switch (categoryId) {
      case 'water':
        // قطرة متموجة أكثر احترافية
        path.moveTo(center.dx, center.dy - r * 1.3);
        path.cubicTo(center.dx + r * 1.1, center.dy - r * 0.1, center.dx + r, center.dy + r * 1.1, center.dx, center.dy + r * 1.1);
        path.cubicTo(center.dx - r, center.dy + r * 1.1, center.dx - r * 1.1, center.dy - r * 0.1, center.dx, center.dy - r * 1.3);
        break;
      case 'construction':
      case 'housing':
        // طوبة بناء فاخرة بحواف دقيقة
        path.addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: r * 2.0, height: r * 1.3), 
          const Radius.circular(5)
        ));
        break;
      case 'orphan':
        // نجمة متألقة فخمة (Diamond Sparkle) - تعبر عن الأمل والتميز
        path.moveTo(center.dx, center.dy - r * 1.5);
        path.quadraticBezierTo(center.dx + r * 0.2, center.dy - r * 0.2, center.dx + r * 1.2, center.dy);
        path.quadraticBezierTo(center.dx + r * 0.2, center.dy + r * 0.2, center.dx, center.dy + r * 1.5);
        path.quadraticBezierTo(center.dx - r * 0.2, center.dy + r * 0.2, center.dx - r * 1.2, center.dy);
        path.quadraticBezierTo(center.dx - r * 0.2, center.dy - r * 0.2, center.dx, center.dy - r * 1.5);
        path.close();
        break;
      case 'medical':
        // قلب طبي أنيق وملموس
        final double width = r * 1.1;
        final double height = r * 1.1;
        path.moveTo(center.dx, center.dy + height * 0.7);
        path.cubicTo(center.dx - width * 1.2, center.dy - height * 0.3, center.dx - width * 0.4, center.dy - height * 1.2, center.dx, center.dy - height * 0.4);
        path.cubicTo(center.dx + width * 0.4, center.dy - height * 1.2, center.dx + width * 1.2, center.dy - height * 0.3, center.dx, center.dy + height * 0.7);
        break;
      default:
        // جوهرة سداسية محسنة
        for (int i = 0; i < 6; i++) {
          double angle = (math.pi / 3) * i - (math.pi / 2);
          double x = center.dx + r * 1.1 * math.cos(angle);
          double y = center.dy + r * 1.1 * math.sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
    }
    return path;
  }

  Path _getHighlightPath(Offset center, double r) {
    final path = Path();
    // لمعة الكريستال
    path.addOval(Rect.fromLTWH(center.dx - r * 0.5, center.dy - r * 0.8, r * 0.7, r * 0.4));
    return path;
  }

  @override
  bool shouldRepaint(covariant _CinematicGridPainter oldDelegate) => 
    oldDelegate.animation != animation || oldDelegate.filledUnits != filledUnits;
}

