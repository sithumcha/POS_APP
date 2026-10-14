import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ----------------------------------------------------------------------------
/// QUICK POS DESIGN SYSTEM (Colors & Design Tokens)
/// Aligned strictly with the Design System UI Board:
/// - Primary: Vibrant Mint Emerald (#00D26A / #10B981)
/// - Secondary: Deep Pine / Forest Green (#065F46 / #064E3B)
/// - Tertiary: Mint Teal (#0D9488 / #14B8A6)
/// - Neutral: Dark Obsidian Slate (#0F172A)
/// - Typography: Plus Jakarta Sans (Headings/Body) + JetBrains Mono (Codes/Labels)
/// ----------------------------------------------------------------------------
class AppColors {
  // --- 1. DESIGN SYSTEM BRAND SWATCHES ---
  /// Primary Brand Color: Vibrant Mint Emerald
  static const Color primaryGreen = Color(0xFF00D26A);
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldLight = Color(0xFFECFDF5);
  static const Color emeraldDark = Color(0xFF059669);

  /// Secondary Brand Color: Deep Forest / Pine Green (As seen on "Primary" Button in board)
  static const Color secondaryGreen = Color(0xFF065F46);
  static const Color deepForest = Color(0xFF064E3B);
  static const Color pineLight = Color(0xFFE6F4EA);

  /// Tertiary Brand Color: Mint / Teal
  static const Color tertiaryGreen = Color(0xFF0D9488);
  static const Color tertiaryLight = Color(0xFFCCFBF1);

  /// Neutral Palette (Centered on #0F172A from the Design Board)
  static const Color neutralDark = Color(0xFF0F172A); // Base Dark Obsidian
  static const Color neutralCard = Color(0xFF1E293B);
  static const Color primaryDark = Color(0xFF020617);
  static const Color primaryLight = Color(0xFF1E293B);

  /// Primary action color for existing widgets (points to Deep Pine Green from board)
  static const Color primary = Color(0xFF065F46);

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF8FAFC); // Clean Modern Slate
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color cardSubtle = Color(0xFFF1F5F9); // Soft Tint Background

  // Typography
  static const Color textPrimary = Color(0xFF0F172A); // Rich Obsidian
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0); // Subtle Slate border
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color borderFocused = Color(0xFF065F46);

  // Interactive Accents
  static const Color accent = Color(0xFF6366F1); // Indigo
  static const Color accentLight = Color(0xFFEEF2FF);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFFFBEB);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color violetLight = Color(0xFFF5F3FF);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color cyanLight = Color(0xFFECFEFF);

  static const Color buttonGrey = Color(0xFF475569);
  static const Color success = Color(0xFF059669);
  static const Color error = Color(0xFFDC2626); // Red Action from Design Board
  static const Color errorLight = Color(0xFFFEF2F2);

  // Linear Gradients matching the design kit
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF065F46), Color(0xFF064E3B)],
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00D26A), Color(0xFF059669)],
  );

  static const LinearGradient mintTealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00D26A), Color(0xFF0D9488)],
  );

  static const LinearGradient neutralGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
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

  // Box Shadows
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

/// ----------------------------------------------------------------------------
/// COMPONENT STYLES & TYPOGRAPHY HELPERS (From Design Board)
/// ----------------------------------------------------------------------------
class AppStyles {
  // --- TYPOGRAPHY TOKENS ---
  /// Main Brand Font: Plus Jakarta Sans
  static TextStyle heading({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w800,
    Color color = AppColors.textPrimary,
    double? letterSpacing = -0.4,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.textSecondary,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  /// Monospace Font: JetBrains Mono (For SKU, codes, prices & technical tags)
  static TextStyle mono({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w700,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );

  // --- BUTTON STYLES (Exact 4 styles from the Design Board) ---
  /// 1. Primary Button: Deep Forest Green (#065F46) + White
  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
        backgroundColor: AppColors.secondaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
      );

  /// 2. Secondary Button: Soft Tinted Slate + Dark Text
  static ButtonStyle get secondaryButton => ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFEEF2FF),
        foregroundColor: const Color(0xFF334155),
        elevation: 0,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
      );

  /// 3. Inverted Button: Obsidian Dark (#0F172A) + White Text
  static ButtonStyle get invertedButton => ElevatedButton.styleFrom(
        backgroundColor: AppColors.neutralDark,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
      );

  /// 4. Outlined Button: White Background + Clean Border
  static ButtonStyle get outlinedButton => OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border, width: 1.2),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
      );

  // --- DECORATION TOKENS ---
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

  /// Pill badge decoration (like the "Label" chip on the design board)
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

/// ----------------------------------------------------------------------------
/// THEMEDATA (Material 3 AppTheme)
/// ----------------------------------------------------------------------------
class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primaryGreen,
        selectionColor: Color(0x3300D26A),
        selectionHandleColor: AppColors.primaryGreen,
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.secondaryGreen, // #065F46 Deep Pine (Design Board Primary Button)
        secondary: AppColors.primaryGreen, // #00D26A Vibrant Mint
        tertiary: AppColors.tertiaryGreen, // #0D9488 Teal
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
      cardTheme: CardThemeData(
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
          backgroundColor: AppColors.secondaryGreen,
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
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.secondaryGreen,
        foregroundColor: Colors.white,
        elevation: 3,
      ),
    );
  }
}
