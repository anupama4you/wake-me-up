import 'package:flutter/material.dart';

/// Centralized theme configuration for WakeMeUp app
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  /* ============================= COLORS ============================= */

  // Primary Colors - Winter Chill (Cool, Crisp, Clear)
  static const Color primaryColor = Color(0xFF4F7C82); // Dark teal - primary actions
  static const Color primaryLightColor = Color(0xFFB8E3E9); // Light cyan - backgrounds
  static const Color primaryDarkColor = Color(0xFF0B2E33); // Very dark teal - emphasis

  // Accent Colors - Winter Blue-Gray (Calm, Modern, Professional)
  static const Color accentGreen = Color(0xFF93B1B5); // Medium gray-blue
  static const Color accentGreenLight = Color(0xFFB8E3E9); // Light cyan
  static const Color accentGreenDark = Color(0xFF4F7C82); // Dark teal

  // Status Colors
  static const Color successColor = Color(0xFF93B1B5); // Gray-blue (Active alarms)
  static const Color warningColor = Color(0xFFFF6F00); // Orange 800 (Battery warnings)
  static const Color errorColor = Color(0xFFD32F2F); // Red 700 (Delete, critical)
  static const Color infoColor = Color(0xFF4F7C82); // Dark teal (Info messages)

  // Background Colors
  static const Color backgroundColor = Color(0xFFFAFAFA); // Grey 50
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFFFFFF);

  // Text Colors
  static const Color textPrimaryColor = Color(0xFF212121); // Grey 900
  static const Color textSecondaryColor = Color(0xFF757575); // Grey 600
  static const Color textDisabledColor = Color(0xFFBDBDBD); // Grey 400
  static const Color textOnPrimaryColor = Color(0xFFFFFFFF);

  // Border Colors
  static const Color borderColor = Color(0xFFE0E0E0); // Grey 300
  static const Color borderLightColor = Color(0xFFEEEEEE); // Grey 200
  static const Color dividerColor = Color(0xFFBDBDBD);

  // Active Alarm Colors (Winter Chill Theme)
  static const Color activeAlarmBackground = Color(0xFFE8F4F6); // Very light cyan
  static const Color activeAlarmBackgroundGradientEnd = Color(0xFFD0E9ED); // Light cyan-gray
  static const Color activeAlarmBorder = Color(0xFF4F7C82); // Dark teal border
  static const Color activeAlarmText = Color(0xFF0B2E33); // Very dark teal text
  static const Color activeAlarmTextSecondary = Color(0xFF4F7C82); // Dark teal
  static const Color activeAlarmChipBackground = Color(0xFF93B1B5); // Gray-blue chips
  static const Color activeAlarmIconColor = Color(0xFF4F7C82); // Dark teal icons

  /* ========================== TEXT STYLES ========================== */

  // Display Styles
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimaryColor,
    letterSpacing: -0.5,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimaryColor,
    letterSpacing: -0.5,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimaryColor,
  );

  // Heading Styles
  static const TextStyle headingLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: textPrimaryColor,
    letterSpacing: 0.15,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: textPrimaryColor,
    letterSpacing: 0.3,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: textPrimaryColor,
  );

  // Body Text Styles
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimaryColor,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textPrimaryColor,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textSecondaryColor,
    height: 1.4,
  );

  // Label Styles
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimaryColor,
    letterSpacing: 0.1,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textPrimaryColor,
    letterSpacing: 0.2,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textSecondaryColor,
    letterSpacing: 0.5,
  );

  // Caption Styles
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondaryColor,
  );

  // Button Text Styles
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  /* ========================== THEME DATA ========================== */

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentGreen,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: textOnPrimaryColor,
        onSecondary: textOnPrimaryColor,
        onSurface: textPrimaryColor,
        onError: textOnPrimaryColor,
      ),

      // Primary Swatch (for Material 2 compatibility)
      primaryColor: primaryColor,
      primaryColorLight: primaryLightColor,
      primaryColorDark: primaryDarkColor,

      // Background
      scaffoldBackgroundColor: backgroundColor,
      canvasColor: surfaceColor,
      cardColor: cardColor,

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        displaySmall: displaySmall,
        headlineLarge: headingLarge,
        headlineMedium: headingMedium,
        headlineSmall: headingSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
        titleLarge: headingLarge,
        titleMedium: headingMedium,
        titleSmall: headingSmall,
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: textOnPrimaryColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textOnPrimaryColor,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(8),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textOnPrimaryColor,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: buttonMedium,
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: buttonMedium,
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: textOnPrimaryColor,
        elevation: 4,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: textSecondaryColor,
        size: 24,
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 16,
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textOnPrimaryColor;
          }
          return textOnPrimaryColor;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentGreen;
          }
          return borderColor;
        }),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: borderLightColor,
        disabledColor: borderLightColor.withValues(alpha: 0.5),
        selectedColor: primaryLightColor,
        secondarySelectedColor: accentGreenLight,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: labelMedium,
        secondaryLabelStyle: labelMedium,
        brightness: Brightness.light,
        side: const BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /* ======================== COMPONENT STYLES ======================= */

  // Alarm Card Styles
  static BoxDecoration alarmCardDecoration({required bool isActive}) {
    return BoxDecoration(
      gradient: isActive
          ? const LinearGradient(
              colors: [
                activeAlarmBackground, // Very light cyan
                Color.fromRGBO(208, 233, 237, 0.5), // Light cyan-gray with transparency
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      color: isActive ? null : cardColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isActive ? activeAlarmBorder : borderColor,
        width: isActive ? 2 : 1,
      ),
      boxShadow: [
        BoxShadow(
          blurRadius: isActive ? 16 : 10,
          offset: const Offset(0, 4),
          color: isActive
              ? const Color.fromRGBO(79, 124, 130, 0.15) // Dark teal shadow
              : const Color.fromRGBO(0, 0, 0, 0.04),
        ),
      ],
    );
  }

  // Chip Decoration
  static BoxDecoration chipDecoration({required bool isActive}) {
    return BoxDecoration(
      color: isActive ? activeAlarmChipBackground : borderLightColor,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isActive ? activeAlarmBorder : borderColor,
        width: isActive ? 1.5 : 1,
      ),
    );
  }

  // Badge Decoration (for active alarm count)
  static BoxDecoration badgeDecoration() {
    return BoxDecoration(
      color: accentGreen,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // Dialog Decoration
  static ShapeBorder dialogShape() {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
  }

  /* ======================== SPACING & SIZING ======================= */

  // Padding
  static const double paddingXSmall = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  static const double radiusCircular = 100.0;

  // Icon Sizes
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 20.0;
  static const double iconSizeLarge = 24.0;
  static const double iconSizeXLarge = 32.0;

  // Elevation
  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  /* ======================= HELPER METHODS ======================= */

  // Get text color based on active state
  static Color getTextColor({required bool isActive, bool isSecondary = false}) {
    if (isActive) {
      return isSecondary ? activeAlarmTextSecondary : activeAlarmText;
    }
    return isSecondary ? textSecondaryColor : textPrimaryColor;
  }

  // Get icon color based on active state
  static Color getIconColor({required bool isActive}) {
    return isActive ? activeAlarmIconColor : textSecondaryColor;
  }

  // Get border color based on active state
  static Color getBorderColor({required bool isActive}) {
    return isActive ? activeAlarmBorder : borderColor;
  }
}
