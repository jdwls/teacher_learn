import 'package:flutter/material.dart';

class AppTheme {
  // ===== 原项目配色 (class_techer_student-main) =====
  // Primary Blue - 主色调
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryBlueHover = Color(0xFF3B82F6);
  static const Color primaryBluePressed = Color(0xFF1D4ED8);

  // Background Colors
  static const Color backgroundMain = Color(0xFFF8FAFC);
  static const Color cardWhite = Colors.white;

  // Text Colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);

  // Border Colors
  static const Color borderMain = Color(0xFFD1D5DB);
  static const Color borderSidebar = Color(0xFFE5EEFB);

  // Status Colors
  static const Color successGreen = Color(0xFF10B981);
  static const Color successGreenHover = Color(0xFF34D399);
  static const Color successGreenPressed = Color(0xFF059669);

  static const Color dangerRed = Color(0xFFEF4444);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color cyanAccent = Color(0xFF06B6D4);

  // Status Pill Backgrounds
  static const Color pillOnline = Color(0xFFE6F7EC);
  static const Color pillTyping = Color(0xFFEEF2FF);
  static const Color pillQuiz = Color(0xFFF3E8FF);
  static const Color pillOffline = Color(0xFFF1F5F9);

  // Status Pill Text
  static const Color pillOnlineText = Color(0xFF15803D);
  static const Color pillTypingText = Color(0xFF1E40AF);
  static const Color pillQuizText = Color(0xFF7E22CE);
  static const Color pillOfflineText = Color(0xFF475569);

  // ===== 兼容旧代码 =====
  static const Color primaryColor = primaryBlue;
  static const Color errorColor = dangerRed;
  static const Color successColor = successGreen;
  static const Color warningColor = warningOrange;

  // ===== 主题样式 =====
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
        primary: primaryBlue,
        onPrimary: Colors.white,
        secondary: primaryBlueHover,
        onSecondary: Colors.white,
        surface: cardWhite,
        onSurface: textPrimary,
        error: dangerRed,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundMain,
      cardTheme: CardTheme(
        color: cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: borderMain),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderMain),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderMain),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dangerRed),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(color: textSecondary),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: primaryBlue,
        unselectedLabelColor: textSecondary,
        indicatorColor: primaryBlue,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: primaryBlue, width: 3),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: cardWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: borderMain,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(
        color: textPrimary,
        size: 24,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
      ),
    );
  }

  // ===== 辅助样式方法 =====

  /// 原项目样式卡片 - 白色背景, 圆角16px
  static BoxDecoration get cardDecoration {
    return BoxDecoration(
      color: cardWhite,
      borderRadius: BorderRadius.circular(16),
    );
  }

  /// 原项目样式按钮
  static ButtonStyle get primaryButtonStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  static ButtonStyle get successButtonStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: successGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  static ButtonStyle get dangerButtonStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: dangerRed,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  static ButtonStyle get secondaryButtonStyle {
    return OutlinedButton.styleFrom(
      foregroundColor: textPrimary,
      side: const BorderSide(color: borderMain),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  /// 原项目样式 Pill 标签
  static BoxDecoration pillDecoration(Color bgColor, Color textColor) {
    return BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(999),
    );
  }

  /// 状态标签样式
  static Widget statusPill(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pillDecoration(bgColor, textColor),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  /// 统计卡片样式
  static Widget statsCard(String title, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
