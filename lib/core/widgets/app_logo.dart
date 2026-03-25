import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showGlow;
  const AppLogo({super.key, this.size = 100, this.showGlow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.primaryGradient,
        boxShadow: showGlow ? AppTheme.greenGlow : null,
        border: Border.all(color: AppTheme.glassBorder, width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.volunteer_activism, color: Colors.black, size: size * 0.35),
            Text('ناس الخير', style: TextStyle(
              fontFamily: 'Tajawal',
              color: Colors.black,
              fontSize: size * 0.15,
              fontWeight: FontWeight.w800,
            )),
          ],
        ),
      ),
    );
  }
}
