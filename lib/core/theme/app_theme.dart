import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';

class AppTheme {
  // === الألوان الأساسية الفاخرة ===
  static const Color primaryGreen = Color(0xFF16804d); // جعل الأخضر أكثر حيوية قليلاً لتحسين التباين
  static const Color primaryGreenDark = Color(0xFF0b4228);
  static const Color goldAccent = Color(0xFFD4AF37);

  // === ألوان الوضع الداكن (Dark Premium) ===
  static const Color darkBg = Color(0xFF0c110e);      // خلفية داكنة فاخرة
  static const Color darkSurface = Color(0xFF131c17); // سطح ناعم وعميق
  static const Color darkCard = Color(0xFF18231d);    // بطاقات أنيقة
  static const Color textPrimaryDark = Color(0xFFF0F5F2);
  static const Color textSecondaryDark = Color(0xFF9CAAA1);

  // === ألوان الوضع الفاتح (Light Premium) ===
  static const Color lightBg = Color(0xFFF6F8F6);     // خلفية هادئة وفاتحة
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1B241F);
  static const Color textSecondaryLight = Color(0xFF5A665E); // تغميق طفيف لزيادة التباين

  static const Color errorColor = Color(0xFFD32F2F);
  static const Color warningColor = Color(0xFFF9A825); // تغميق الاصفر للوضوح في الوضع الفاتح
  static const Color successColor = Color(0xFF2E7D32);
  static const Color emergencyColor = Color(0xFFC62828);
  static const Color urgentColor = Color(0xFFEF6C00);
  static const Color glassBorder = Color(0x33105d38);

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
    colors: [Color(0xFF16804d), Color(0xFF0b4228)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFD4AF37), Color(0xFFA67C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBgGradient = LinearGradient(
    colors: [Color(0xFF0c110e), Color(0xFF131c17)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient emergencyGradient = LinearGradient(
    colors: [Color(0xFFC62828), Color(0xFF8E0000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ظلال ناعمة جداً تمنح شعوراً بالعمق دون حدة
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: Get.isDarkMode ? 0.35 : 0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        )
      ];

  static List<BoxShadow> get greenGlow => [
        BoxShadow(
          color: primaryGreen.withValues(alpha: 0.15),
          blurRadius: 20,
          offset: const Offset(0, 6),
        )
      ];

  static List<BoxShadow> get redGlow => [
        BoxShadow(
          color: emergencyColor.withValues(alpha: 0.25),
          blurRadius: 20,
          offset: const Offset(0, 6),
        )
      ];

  static BoxDecoration get glassDecoration => BoxDecoration(
    color: Get.isDarkMode ? primaryGreen.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.9),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Get.isDarkMode ? glassBorder : primaryGreen.withValues(alpha: 0.1), width: 1),
    boxShadow: Get.isDarkMode ? null : cardShadow,
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
      onPrimary: Colors.white,
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
      iconTheme: IconThemeData(color: textPrimaryDark),
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
    dividerColor: Colors.black.withValues(alpha: 0.1),
    textTheme: _baseTextTheme.apply(
      bodyColor: textPrimaryLight,
      displayColor: textPrimaryLight,
    ),
    colorScheme: const ColorScheme.light(
      primary: primaryGreen,
      onPrimary: Colors.white,
      secondary: goldAccent,
      onSecondary: Colors.black, // تعديل: استخدام اللون الأسود مع الذهبي لتحسين التباين
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
      iconTheme: IconThemeData(color: textPrimaryLight),
      titleTextStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.bold, color: textPrimaryLight),
    ),
  );

  // === الدوال المساعدة (Helper Widgets) ===
  static Widget loadingState() {
    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
  }

  static Widget gradientButton({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    Color? textColor,
    bool isLoading = false,
  }) {
    final onPrimaryColor = Get.theme.colorScheme.onPrimary;
    
    return Container(
      decoration: BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(radiusMedium),
        boxShadow: [
          BoxShadow(color: primaryGreen.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor ?? onPrimaryColor),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: textColor ?? onPrimaryColor, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w700,
                      color: textColor ?? onPrimaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
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
      child: FadeInUp(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: primaryGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: primaryGreen, size: 64),
            ),
            const SizedBox(height: 24),
            Text(
                'عذراً',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                    color: textPrimary)),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(fontFamily: 'Tajawal', fontSize: 14, color: textSecondary), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }

  static InputDecoration inputDecoration(String hint, IconData prefixIcon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(prefixIcon, color: primaryGreen),
      filled: true,
      fillColor: Get.isDarkMode ? darkCard.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: const BorderSide(color: primaryGreen, width: 2)),
    );
  }

  static Widget statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending': color = warningColor; label = 'معلق'; break;
      case 'in_progress': color = successColor; label = 'جاري'; break; // استخدام successColor بدلاً من primaryGreen لزيادة الوضوح
      case 'completed': color = successColor; label = 'مكتمل'; break;
      case 'rejected': color = errorColor; label = 'مرفوض'; break;
      case 'emergency': color = emergencyColor; label = 'طارئ'; break;
      case 'urgent': color = urgentColor; label = 'مستعجل'; break;
      case 'normal': color = successColor; label = 'عادي'; break;
      default: color = Colors.grey; label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'Tajawal', letterSpacing: 0.5)),
    );
  }

  static Widget sectionHeader(String title, {String? action, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Text(title, style: TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
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
          border: showDivider ? Border(bottom: BorderSide(color: Get.theme.dividerColor, width: 0.5)) : null,
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (iconColor ?? primaryGreen).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor ?? primaryGreen, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w800, fontSize: 16, color: textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontFamily: 'Tajawal', color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
            ]
          ])),
          trailing ?? const SizedBox.shrink(),
          if (onTap != null && trailing == null) Icon(Icons.arrow_forward_ios, color: textPrimary.withValues(alpha: 0.4), size: 16),
        ]),
      ),
    );
  }
}
