import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Modern Fintech Palette
  static const Color primary = Color(0xFF0F172A); // Sleek Obsidian / Slate 900
  static const Color primaryDark = Color(0xFF020617);
  static const Color primaryLight = Color(0xFF1E293B);

  // Modern Accents
  static const Color accent = Color(0xFF6366F1); // Electric Indigo
  static const Color accentLight = Color(0xFFEEF2FF);
  static const Color emerald = Color(0xFF10B981); // Crisp Emerald Green
  static const Color emeraldLight = Color(0xFFECFDF5);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFFFBEB);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color violetLight = Color(0xFFF5F3FF);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color cyanLight = Color(0xFFECFEFF);

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF8FAFC); // Clean Modern Slate
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color cardSubtle = Color(0xFFF1F5F9);

  // Typography
  static const Color textPrimary = Color(0xFF0F172A); // Rich Obsidian
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0); // Subtle Slate border
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color borderFocused = Color(0xFF0F172A);

  // Interactive
  static const Color buttonGrey = Color(0xFF475569);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEF2F2);

  // Linear Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  static const LinearGradient indigoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
  );

  static const LinearGradient violetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
  );

  static const LinearGradient amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F172A), Color(0xFF020617)],
  );

  // Soft Fintech Box Shadow
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.02),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get cardHoverShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> glowShadow(Color color, {double opacity = 0.25}) => [
        BoxShadow(
          color: color.withOpacity(opacity),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}

class AppStyles {
  /// Standard modern card decoration
  static BoxDecoration cardDecoration({
    Color? color,
    BorderRadius? borderRadius,
    Border? border,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: border ?? Border.all(color: AppColors.border, width: 1.2),
      boxShadow: shadows ?? AppColors.softShadow,
    );
  }

  /// Glassmorphic container decoration
  static BoxDecoration glassDecoration({
    Color? color,
    BorderRadius? borderRadius,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white.withOpacity(0.85),
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: Border.all(
        color: borderColor ?? Colors.white.withOpacity(0.8),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.04),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// Pill badge decoration
  static BoxDecoration pillDecoration({
    required Color background,
    Color? border,
    double radius = 30,
  }) {
    return BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(radius),
      border: border != null ? Border.all(color: border, width: 1) : null,
    );
  }
}

class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.emerald,
        selectionColor: Color(0x3310B981),
        selectionHandleColor: AppColors.emerald,
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.emerald,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: baseTextTheme.copyWith(
        titleLarge: GoogleFonts.plusJakartaSans(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 22,
          letterSpacing: -0.5,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 17,
          letterSpacing: -0.3,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          color: AppColors.textPrimary,
          fontSize: 15,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border, width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderFocused, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
