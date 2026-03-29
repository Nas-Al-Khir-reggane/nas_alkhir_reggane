import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppTheme {
  // === الألوان الأساسية الفاخرة ===
  static const Color primaryGreen = Color(0xFF00C853);
  static const Color primaryGreenDark = Color(0xFF008933);
  static const Color goldAccent = Color(0xFFFFD700);
  
  // === ألوان الوضع الداكن (Dark Premium) ===
  static const Color darkBg = Color(0xFF05100B);      // خلفية عميقة مخضرة
  static const Color darkSurface = Color(0xFF0D1E16); // سطح ناعم
  static const Color darkCard = Color(0xFF14291E);    // بطاقات واضحة
  static const Color textPrimaryDark = Color(0xFFF5FDF8);
  static const Color textSecondaryDark = Color(0xFF8BBA9B);
  
  // === ألوان الوضع الفاتح (Light Premium) ===
  static const Color lightBg = Color(0xFFF7FAF7);     // خلفية هادئة
  static const Color lightSurface = Color(0xFFFFFFFF); 
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0A2E14);
  static const Color textSecondaryLight = Color(0xFF4A7456);

  static const Color errorColor = Color(0xFFFF5252);
  static const Color warningColor = Color(0xFFFFB300);
  static const Color successColor = Color(0xFF00E676);
  static const Color emergencyColor = Color(0xFFD50000);
  static const Color urgentColor = Color(0xFFFF6D00);
  static const Color glassBorder = Color(0x3300C853);

  // === الوصول الديناميكي للألوان ===
  static Color get textPrimary => Get.isDarkMode ? textPrimaryDark : textPrimaryLight;
  static Color get textSecondary => Get.isDarkMode ? textSecondaryDark : textSecondaryLight;
  static Color get cardColor => Get.isDarkMode ? darkCard : lightCard;
  static Color get backgroundColor => Get.isDarkMode ? darkBg : lightBg;
  static Color get surfaceColor => Get.isDarkMode ? darkSurface : lightSurface;
  static Color get textHint => Get.isDarkMode ? textSecondaryDark : textSecondaryLight;
  
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double radiusLarge = 24.0;
  static const double radiusExtraLarge = 32.0;

  static BoxDecoration get cardDecoration => BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(radiusMedium),
    boxShadow: cardShadow,
  );

  static EdgeInsets getScreenPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return const EdgeInsets.symmetric(horizontal: 150, vertical: 40);
    if (width > 800) return const EdgeInsets.symmetric(horizontal: 60, vertical: 30);
    return const EdgeInsets.symmetric(horizontal: 20, vertical: 20);
  }

  // === التدرجات الفاخرة ===
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00C853), Color(0xFF008933)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBgGradient = LinearGradient(
    colors: [Color(0xFF05100B), Color(0xFF0D1E16)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: (Get.isDarkMode ? Colors.black : Colors.grey).withValues(alpha: 0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        )
      ];

  static List<BoxShadow> get greenGlow => [
        BoxShadow(
          color: (Get.isDarkMode ? primaryGreen : primaryGreenDark).withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        )
      ];

  static BoxDecoration get glassDecoration => BoxDecoration(
    color: primaryGreen.withValues(alpha: Get.isDarkMode ? 0.1 : 0.05),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: glassBorder, width: 1),
  );

  static const double radiusSmall = 12;
  static const double radiusMedium = 20;

  // === التايبوغرافي (Typography) الشامل والواضح ===
  static TextTheme get _baseTextTheme => const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Tajawal', fontSize: 32, fontWeight: FontWeight.w900, height: 1.2),
        displayMedium: TextStyle(fontFamily: 'Tajawal', fontSize: 28, fontWeight: FontWeight.w800, height: 1.2),
        headlineLarge: TextStyle(fontFamily: 'Tajawal', fontSize: 22, fontWeight: FontWeight.w700, height: 1.3),
        headlineMedium: TextStyle(fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
        titleLarge: TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.w700, height: 1.4),
        titleMedium: TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
        bodyLarge: TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w400, height: 1.6),
        bodyMedium: TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w400, height: 1.6),
        bodySmall: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w400, height: 1.6),
        labelLarge: TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
        labelMedium: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
        labelSmall: TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
      );

  // === ThemeData الحديث ===
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Tajawal',
    scaffoldBackgroundColor: darkBg,
    cardColor: darkCard,
    canvasColor: darkSurface,
    dividerColor: Colors.white10,
    textTheme: _baseTextTheme.apply(
      bodyColor: textPrimaryDark,
      displayColor: textPrimaryDark,
    ),
    colorScheme: const ColorScheme.dark(
      primary: primaryGreen,
      onPrimary: Colors.black,
      secondary: goldAccent,
      onSecondary: Colors.black,
      surface: darkSurface,
      onSurface: textPrimaryDark,
      surfaceContainerHighest: darkCard,
      onSurfaceVariant: textSecondaryDark,
      error: errorColor,
      outline: Colors.white10,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBg,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.bold, color: textPrimaryDark),
    ),
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Tajawal',
    scaffoldBackgroundColor: lightBg,
    cardColor: lightCard,
    canvasColor: lightSurface,
    dividerColor: Colors.black12,
    textTheme: _baseTextTheme.apply(
      bodyColor: textPrimaryLight,
      displayColor: textPrimaryLight,
    ),
    colorScheme: const ColorScheme.light(
      primary: primaryGreenDark,
      onPrimary: Colors.white,
      secondary: Color(0xFFD4AF37),
      onSecondary: Colors.white,
      surface: lightSurface,
      onSurface: textPrimaryLight,
      surfaceContainerHighest: Color(0xFFF0F4F0),
      onSurfaceVariant: textSecondaryLight,
      error: errorColor,
      outline: Colors.black12,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightSurface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.bold, color: textPrimaryLight),
    ),
  );

  // === الدوال المساعدة (Helper Widgets) ===
  static Widget loadingState() {
    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
  }

  static Widget gradientButton({required String text, required VoidCallback onPressed, IconData? icon, Color? textColor}) {
    final primaryColor = Get.theme.colorScheme.primary;
    final onPrimaryColor = Get.theme.colorScheme.onPrimary;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radiusMedium),
        boxShadow: [
          BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, color: textColor ?? onPrimaryColor, size: 20) : const SizedBox.shrink(),
        label: Text(text, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, color: textColor ?? onPrimaryColor, fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
        ),
      ),
    );
  }

  static Widget errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: errorColor, size: 48),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontFamily: 'Tajawal'), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  static Widget emptyState(String message, {IconData icon = Icons.inbox_outlined}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: primaryGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: primaryGreen, size: 48),
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  static InputDecoration inputDecoration(String hint, IconData prefixIcon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(prefixIcon, color: primaryGreen),
      filled: true,
      fillColor: Get.isDarkMode ? darkCard.withValues(alpha: 0.5) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: BorderSide(color: Get.theme.colorScheme.outline)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: BorderSide(color: Get.theme.colorScheme.outline)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: const BorderSide(color: primaryGreen, width: 2)),
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
      case 'emergency': color = emergencyColor; label = 'طارئ'; break;
      case 'urgent': color = urgentColor; label = 'مستعجل'; break;
      case 'normal': color = successColor; label = 'عادي'; break;
      default: color = Colors.grey; label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'Tajawal', letterSpacing: 0.5)),
    );
  }

  static Widget sectionHeader(String title, {String? action, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Text(title, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (action != null) TextButton(
          onPressed: onAction,
          child: Text(action, style: const TextStyle(color: primaryGreen, fontFamily: 'Tajawal', fontSize: 13)),
        ),
      ]),
    );
  }

  static Widget listItem({
    required String title,
    String? subtitle,
    required IconData icon,
    Color? iconColor,
    Widget? trailing,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: showDivider ? const Border(bottom: BorderSide(color: Colors.white10, width: 0.5)) : null,
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? primaryGreen).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor ?? primaryGreen, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 15)),
            if (subtitle != null) Text(subtitle, style: TextStyle(fontFamily: 'Tajawal', color: textSecondary, fontSize: 13)),
          ])),
          trailing ?? const SizedBox.shrink(),
          if (onTap != null && trailing == null) Icon(Icons.arrow_forward_ios, color: textSecondary.withValues(alpha: 0.5), size: 14),
        ]),
      ),
    );
  }
}
