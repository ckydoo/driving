import 'package:flutter/material.dart';

class AppTheme {
  static const Color _seedColor = Color(0xFF2563EB);
  static const Color _accentColor = Color(0xFF14B8A6);
  static const Color _warningColor = Color(0xFFF59E0B);
  static const Color _dangerColor = Color(0xFFEF4444);
  static const Color _neutralSurfaceLight = Color(0xFFF5F7FB);
  static const Color _neutralSurfaceDark = Color(0xFF0B1220);
  static const Color shellBackground = Color(0xFF0F172A);
  static const Color surfaceElevatedLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedDark = Color(0xFF111B2E);

  static const String appName = 'DriveSync Pro';
  static const String fallbackBusinessName = 'DriveSync School';
  static const String syncPageTitle = 'Data Sync';
  static const String subscriptionPageTitle = 'Subscription & Billing';

  static Color get primary => _seedColor;
  static Color get accent => _accentColor;
  static Color get warning => _warningColor;
  static Color get danger => _dangerColor;

  static LinearGradient brandGradient({required bool isDark}) {
    return LinearGradient(
      colors: [
        isDark ? const Color(0xFF3B82F6) : _seedColor,
        isDark ? const Color(0xFF2DD4BF) : _accentColor,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static ThemeMode mapTheme(String theme) {
    switch (theme) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  static ThemeData theme({required bool isDark}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: isDark ? Brightness.dark : Brightness.light,
      secondary: _accentColor,
      tertiary: _warningColor,
      error: _dangerColor,
    );

    final baseTextTheme =
        isDark ? Typography.whiteMountainView : Typography.blackMountainView;

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor:
          isDark ? _neutralSurfaceDark : _neutralSurfaceLight,
      cardColor: isDark ? surfaceElevatedDark : surfaceElevatedLight,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: baseTextTheme
          .apply(
            bodyColor: colorScheme.onBackground,
            displayColor: colorScheme.onBackground,
          )
          .copyWith(
            headlineSmall: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            titleLarge: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: const TextStyle(fontSize: 16, height: 1.35),
            bodyMedium: const TextStyle(fontSize: 14, height: 1.4),
            labelLarge: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF111827) : shellBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? surfaceElevatedDark : surfaceElevatedLight,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.45)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceVariant,
        selectedColor: colorScheme.primary.withOpacity(0.15),
        labelStyle: TextStyle(color: colorScheme.onSurface),
        secondaryLabelStyle: TextStyle(color: colorScheme.onPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: colorScheme.outlineVariant.withOpacity(0.7)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      listTileTheme: ListTileThemeData(
        dense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? surfaceElevatedDark : shellBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shadowColor: colorScheme.primary.withOpacity(0.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          minimumSize: const Size(0, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          minimumSize: const Size(0, 42),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicator: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? surfaceElevatedDark : surfaceElevatedLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          colorScheme.surfaceContainerHighest.withOpacity(0.7),
        ),
        dividerThickness: 0.8,
        dataTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 13.5),
        headingTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outlineVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withOpacity(0.35);
          }
          return colorScheme.outlineVariant.withOpacity(0.5);
        }),
      ),
      dividerTheme: DividerThemeData(
        thickness: 1,
        color: colorScheme.outlineVariant.withOpacity(0.5),
      ),
    );
  }
}
