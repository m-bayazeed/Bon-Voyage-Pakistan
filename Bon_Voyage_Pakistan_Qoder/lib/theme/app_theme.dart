import 'package:flutter/material.dart';

/// Centralized color palette and theme configuration for the app.
///
/// Cinematic dark/light travel identity with an earthy olive-green
/// accent, glassmorphism panels, and premium typography.
class AppTheme {
  AppTheme._();

  // ── Core palette ──────────────────────────────────────────────
  // Main accent changed from neon turquoise to #5A7328.
  static const Color primary = Color(0xFF5A7328);
  static const Color primaryDim = Color(0xFF4A6120);

  // Light text for maximum readability on the olive-green accent.
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Warm complementary accent.
  static const Color secondary = Color(0xFFFFB783);
  static const Color secondaryContainer = Color(0xFFD97722);
  static const Color tertiary = Color(0xFFA8E7CD);

  // ── Dark palette ──────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF121414);
  static const Color darkSurface = Color(0xFF1A1C1C);
  static const Color darkSurfaceVariant = Color(0xFF333535);

  static const Color darkOnBackground = Color(0xFFE2E2E2);
  static const Color darkOnSurfaceVariant = Color(0xFFBACAC5);

  // ── Light palette ─────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFE8ECEF);

  static const Color lightOnBackground = Color(0xFF1A1A1A);
  static const Color lightOnSurfaceVariant = Color(0xFF5A6A72);

  // ── Shared utilities ─────────────────────────────────────────
  static const Color error = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF4ADE80);

  // ── Theme entry points ───────────────────────────────────────
  static ThemeData dark() => _buildTheme(Brightness.dark);

  static ThemeData light() => _buildTheme(Brightness.light);

  // ── Main theme builder ───────────────────────────────────────
  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? darkBackground : lightBackground;
    final surface = isDark ? darkSurface : lightSurface;
    final surfaceVariant =
        isDark ? darkSurfaceVariant : lightSurfaceVariant;

    final onBg = isDark ? darkOnBackground : lightOnBackground;

    final onSurfaceVariant =
        isDark ? darkOnSurfaceVariant : lightOnSurfaceVariant;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,

      // ── Background ────────────────────────────────────────────
      scaffoldBackgroundColor: bg,

      // ── Color scheme ──────────────────────────────────────────
      colorScheme: ColorScheme(
        brightness: brightness,

        // Main olive-green accent.
        primary: primary,
        onPrimary: onPrimary,

        // Secondary accent.
        secondary: secondary,
        onSecondary: Colors.white,

        // Error colors.
        error: error,
        onError: Colors.white,

        // Surfaces.
        surface: surface,
        onSurface: onBg,

        // Variant surfaces.
        surfaceContainerHighest: surfaceVariant,
        onSurfaceVariant: onSurfaceVariant,

        // Borders/dividers.
        outline: onSurfaceVariant.withOpacity(0.3),
      ),

      // ── Typography ────────────────────────────────────────────
      fontFamily: 'PlusJakartaSans',
      textTheme: _textTheme(brightness),

      // ── Buttons ───────────────────────────────────────────────
      elevatedButtonTheme: _elevatedButtonTheme(),

      textButtonTheme: _textButtonTheme(),

      // ── Text fields ───────────────────────────────────────────
      inputDecorationTheme: _inputDecorationTheme(
        isDark,
        surface,
        surfaceVariant,
        onBg,
        onSurfaceVariant,
      ),

      // ── App bar ────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,

        iconTheme: IconThemeData(
          color: onBg,
        ),

        titleTextStyle: TextStyle(
          color: onBg,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'PlusJakartaSans',
        ),
      ),
    );
  }

  // ── Text theme ────────────────────────────────────────────────
  static TextTheme _textTheme(Brightness brightness) {
    final color = brightness == Brightness.dark
        ? darkOnBackground
        : lightOnBackground;

    final variant = brightness == Brightness.dark
        ? darkOnSurfaceVariant
        : lightOnSurfaceVariant;

    return TextTheme(
      displayLarge: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: 36,
        letterSpacing: -0.5,
      ),

      displayMedium: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: 32,
        letterSpacing: -0.5,
      ),

      displaySmall: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: 28,
        letterSpacing: -0.5,
      ),

      headlineLarge: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: 26,
        letterSpacing: -0.5,
        fontFamily: 'PlayfairDisplay',
      ),

      headlineMedium: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        letterSpacing: -0.5,
        fontFamily: 'PlayfairDisplay',
      ),

      headlineSmall: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        letterSpacing: -0.3,
      ),

      titleLarge: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),

      titleMedium: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),

      bodyLarge: TextStyle(
        color: color,
        fontWeight: FontWeight.w400,
        fontSize: 16,
        height: 1.5,
      ),

      bodyMedium: TextStyle(
        color: variant,
        fontWeight: FontWeight.w400,
        fontSize: 14,
        height: 1.5,
      ),

      bodySmall: TextStyle(
        color: variant,
        fontWeight: FontWeight.w400,
        fontSize: 12,
        height: 1.4,
      ),

      labelLarge: TextStyle(
        color: color,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),

      labelMedium: TextStyle(
        color: variant,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
    );
  }

  // ── Elevated button theme ────────────────────────────────────
  static ElevatedButtonThemeData _elevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        // Olive-green button.
        backgroundColor: primary,

        // White text/icons on olive-green.
        foregroundColor: onPrimary,

        // Disabled button.
        disabledForegroundColor: onPrimary.withOpacity(0.55),
        disabledBackgroundColor: primary.withOpacity(0.35),

        elevation: 0,

        minimumSize: const Size(
          double.infinity,
          56,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),

        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          fontFamily: 'PlusJakartaSans',
        ),

        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
      ),
    );
  }

  // ── Text button theme ─────────────────────────────────────────
  static TextButtonThemeData _textButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        // Olive-green text instead of neon blue/turquoise.
        foregroundColor: primary,

        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          fontFamily: 'PlusJakartaSans',
        ),
      ),
    );
  }

  // ── Input fields ──────────────────────────────────────────────
  static InputDecorationTheme _inputDecorationTheme(
    bool isDark,
    Color surface,
    Color surfaceVariant,
    Color onBg,
    Color onSurfaceVariant,
  ) {
    final fill = isDark
        ? surfaceVariant
        : lightSurface;

    return InputDecorationTheme(
      filled: true,

      fillColor: fill,

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 18,
      ),

      hintStyle: TextStyle(
        color: onSurfaceVariant.withOpacity(0.7),
        fontSize: 14,
        fontFamily: 'PlusJakartaSans',
      ),

      labelStyle: TextStyle(
        color: onSurfaceVariant,
        fontSize: 14,
        fontFamily: 'PlusJakartaSans',
      ),

      // Default border.
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),

      // Normal field.
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),

      // Olive-green focus border.
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: primary,
          width: 1.5,
        ),
      ),

      // Error border.
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: error,
          width: 1.2,
        ),
      ),

      // Focused error border.
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: error,
          width: 1.5,
        ),
      ),
    );
  }
}