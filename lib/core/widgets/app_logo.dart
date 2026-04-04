import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showGlow;
  final Color? color;
  
  const AppLogo({
    super.key, 
    this.size = 150,
    this.showGlow = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: showGlow ? [
          BoxShadow(
            color: (color ?? Colors.black).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ] : null,
      ),
      child: Center(
        child: Image.asset(
          'assets/images/nas_alkhir_app.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          color: color,
        ),
      ),
    );
  }
}

