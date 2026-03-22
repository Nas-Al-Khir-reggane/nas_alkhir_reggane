import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppTheme {
  // === الألوان الأساسية ===
  static const Color primaryGreen = Color(0xFF00C853);
  static const Color primaryGreenDark = Color(0xFF00951D);
  static const Color goldAccent = Color(0xFFFFD700);
  
  // === ألوان الوضع الداكن ===
  static const Color darkBg = Color(0xFF050D0A);
  static const Color darkSurface = Color(0xFF0D1F16);
  static const Color darkCard = Color(0xFF112419);
  static const Color textPrimaryDark = Color(0xFFE8F5E9);
  static const Color textSecondaryDark = Color(0xFF81C784);
  
  // === ألوان الوضع الفاتح ===
  static const Color lightBg = Color(0xFFF1F8F1);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1B5E20);
  static const Color textSecondaryLight = Color(0xFF388E3C);

  static const Color textHint = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFFF5252);
  static const Color warningColor = Color(0xFFFFB300);
  static const Color successColor = Color(0xFF00E676);
  static const Color emergencyColor = Color(0xFFD50000);
  static const Color urgentColor = Color(0xFFFF6D00);
  static const Color glassBorder = Color(0x3300C853);

  // === خصائص ديناميكية للوصول للألوان حسب الوضع الحالي ===
  static Color get textPrimary => Get.isDarkMode ? textPrimaryDark : textPrimaryLight;
  static Color get textSecondary => Get.isDarkMode ? textSecondaryDark : textSecondaryLight;
  static Color get cardColor => Get.isDarkMode ? darkCard : lightCard;
  static Color get backgroundColor => Get.isDarkMode ? darkBg : lightBg;
  static Color get surfaceColor => Get.isDarkMode ? darkSurface : lightSurface;

  // === التدرجات ===
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00C853), Color(0xFF00695C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBgGradient = LinearGradient(
    colors: [Color(0xFF050D0A), Color(0xFF0D1F16)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // === الظلال ===
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Get.isDarkMode ? Colors.black.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.1),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> greenGlow = [
    BoxShadow(color: const Color(0xFF00C853).withValues(alpha: 0.25), blurRadius: 20, spreadRadius: 2),
    BoxShadow(color: const Color(0xFF00C853).withValues(alpha: 0.12), blurRadius: 40, spreadRadius: 4),
  ];

  static List<BoxShadow> darkShadow = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 15, offset: const Offset(0, 8)),
  ];

  static BoxDecoration get glassDecoration => BoxDecoration(
    color: primaryGreen.withValues(alpha: Get.isDarkMode ? 0.1 : 0.05),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: glassBorder, width: 1),
    boxShadow: [BoxShadow(color: primaryGreen.withValues(alpha: 0.12), blurRadius: 20)],
  );

  static BoxDecoration get cardDecoration => BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(20),
    boxShadow: cardShadow,
  );

  static const double radiusSmall = 12;
  static const double radiusMedium = 20;
  static const double radiusLarge = 28;

  // === ThemeData ===
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Tajawal',
    scaffoldBackgroundColor: darkBg,
    cardColor: darkCard,
    colorScheme: const ColorScheme.dark(
      primary: primaryGreen,
      secondary: goldAccent,
      surface: darkSurface,
      error: errorColor,
      onSurface: textPrimaryDark,
    ),
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Tajawal',
    scaffoldBackgroundColor: lightBg,
    cardColor: lightCard,
    colorScheme: const ColorScheme.light(
      primary: primaryGreenDark,
      secondary: Color(0xFFFF8F00),
      surface: lightSurface,
      error: errorColor,
      onSurface: textPrimaryLight,
    ),
  );

  // === الدوال المساعدة (Helper Widgets) ===
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

  static Widget loadingState() {
    return const Center(child: CircularProgressIndicator(color: primaryGreen, strokeWidth: 2));
  }

  static Widget errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: errorColor, size: 48),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(fontFamily: 'Tajawal', color: textSecondary), textAlign: TextAlign.center),
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
            decoration: BoxDecoration(color: primaryGreen.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(icon, color: primaryGreen.withValues(alpha: 0.5), size: 48),
          ),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(
            fontFamily: 'Tajawal', color: textSecondary, fontSize: 15,
          ), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  static InputDecoration inputDecoration(String hint, IconData prefixIcon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(prefixIcon, color: primaryGreen),
      filled: true,
      fillColor: Get.isDarkMode ? darkCard : lightCard,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: const BorderSide(color: glassBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: const BorderSide(color: glassBorder)),
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

  static Widget sectionHeader(String title, {String? action, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Text(title, style: TextStyle(
          fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w700,
          color: textPrimary,
        )),
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
          border: showDivider ? const Border(bottom: BorderSide(color: glassBorder, width: 0.5)) : null,
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
            Text(title, style: TextStyle(fontFamily: 'Tajawal', color: textPrimary, fontWeight: FontWeight.w500)),
            if (subtitle != null) Text(subtitle, style: TextStyle(fontFamily: 'Tajawal', color: textSecondary, fontSize: 12)),
          ])),
          if (trailing != null) trailing,
          if (onTap != null && trailing == null) const Icon(Icons.arrow_forward_ios, color: textHint, size: 14),
        ]),
      ),
    );
  }
}
