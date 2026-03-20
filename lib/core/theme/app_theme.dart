import 'package:flutter/material.dart';

class AppTheme {
  // === الألوان ===
  static const Color primaryGreen = Color(0xFF00C853);
  static const Color primaryGreenDark = Color(0xFF00951D);
  static const Color primaryGreenLight = Color(0xFF69F0AE);
  static const Color goldAccent = Color(0xFFFFD700);
  static const Color darkBg = Color(0xFF050D0A);
  static const Color darkSurface = Color(0xFF0D1F16);
  static const Color darkCard = Color(0xFF112419);
  static const Color darkCardHover = Color(0xFF1A3526);
  static const Color glassColor = Color(0x1A00C853);
  static const Color glassBorder = Color(0x3300C853);
  static const Color textPrimary = Color(0xFFE8F5E9);
  static const Color textSecondary = Color(0xFF81C784);
  static const Color textHint = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFFF5252);
  static const Color warningColor = Color(0xFFFFB300);
  static const Color successColor = Color(0xFF00E676);
  static const Color urgentColor = Color(0xFFFF6D00);
  static const Color emergencyColor = Color(0xFFD50000);

  static const Color lightBg = Color(0xFFF1F8F1);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1B5E20);
  static const Color lightTextSecondary = Color(0xFF388E3C);

  // === التدرجات ===
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00C853), Color(0xFF00695C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBgGradient = LinearGradient(
    colors: [Color(0xFF050D0A), Color(0xFF0D1F16)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF112419), Color(0xFF0D1F16)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // === الظلال ===
  static List<BoxShadow> greenGlow = [
    BoxShadow(color: const Color(0xFF00C853).withValues(alpha: 0.25), blurRadius: 20, spreadRadius: 2),
    BoxShadow(color: const Color(0xFF00C853).withValues(alpha: 0.12), blurRadius: 40, spreadRadius: 4),
  ];

  static List<BoxShadow> darkShadow = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 15, offset: const Offset(0, 8)),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(color: const Color(0xFF00C853).withValues(alpha: 0.37), blurRadius: 12, offset: const Offset(0, 4)),
  ];

  // === Glassmorphism Decoration ===
  static BoxDecoration glassDecoration = BoxDecoration(
    color: const Color(0x1A00C853),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: const Color(0x3300C853), width: 1),
    boxShadow: [BoxShadow(color: const Color(0xFF00C853).withValues(alpha: 0.12), blurRadius: 20)],
  );

  static const double radiusSmall = 12;
  static const double radiusMedium = 20;
  static const double radiusLarge = 28;
  static const double radiusXL = 36;

  // === ThemeData ===
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Tajawal',
    colorScheme: const ColorScheme.dark(
      primary: primaryGreen,
      secondary: goldAccent,
      surface: darkSurface,
      error: errorColor,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: textPrimary,
    ),
    scaffoldBackgroundColor: darkBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
      iconTheme: IconThemeData(color: primaryGreen),
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCard,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: const BorderSide(color: glassBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: const BorderSide(color: glassBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: const BorderSide(color: primaryGreen, width: 2)),
      labelStyle: const TextStyle(color: textSecondary, fontFamily: 'Tajawal'),
      hintStyle: const TextStyle(color: textHint, fontFamily: 'Tajawal'),
      prefixIconColor: primaryGreen,
      suffixIconColor: textSecondary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primaryGreen : textHint),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? const Color(0x5500C853) : darkCard),
    ),
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Tajawal',
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF00951D),
      secondary: Color(0xFFFF8F00),
      surface: lightSurface,
    ),
    scaffoldBackgroundColor: lightBg,
  );

  // === Widget helpers ===
  static Widget gradientButton({required String text, required VoidCallback onPressed, IconData? icon}) {
    return Container(
      decoration: BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(radiusMedium),
        boxShadow: greenGlow,
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, color: Colors.black) : const SizedBox.shrink(),
        label: Text(text, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, color: Colors.black)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
        ),
      ),
    );
  }

  static Widget statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending': color = warningColor; label = 'معلق'; break;
      case 'in_progress': color = primaryGreen; label = 'جاري'; break;
      case 'completed': color = successColor; label = 'مكتمل'; break;
      case 'rejected': color = errorColor; label = 'مرفوض'; break;
      default: color = textHint; label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
    );
  }
}
