import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Material 3 role-based theme for OL Reader
///
/// Uses two primary colors:
/// - Dark (0xFF2E1E0F) for AppBar and primary actions
/// - Light (0xFFE1DCC5) for TabBar and surface backgrounds
class AppTheme {
  // Brand colors
  static const Color _appBarDark = Color(0xFF2E1E0F);
  static const Color _scaffold = Color(0xFF333333);
  static const Color _surfaceLightest = const Color(0xFFF8F6EA);
  static const Color _surfaceLight = Color(0xFFE1DCC5);
  static const Color _surfaceMedium = Color(0xFFB6AB9C);
  static const Color _surfaceDark = Color(0xFF8D775F);
  static const Color _surfaceDarkest = Color(0xFF6C5B49);
  static const Color _highlight = Color(0xFF3494F1);

  static final BorderRadius _buttonBorderRadius = BorderRadius.circular(8);

  // Light theme - Material 3 role-based

  static final ColorScheme lightColorScheme = ColorScheme.fromSeed(
    seedColor: _appBarDark,
    primary: _appBarDark,
    brightness: Brightness.light,
    surface: _surfaceLight,
    surfaceContainerLowest: _surfaceDark,
    surfaceContainerLow: _surfaceMedium,
    surfaceContainer: _surfaceLight,
    surfaceContainerHigh: _surfaceLight,
    surfaceContainerHighest: _surfaceLightest,
    onSurface: Colors.black,
    onSurfaceVariant: Colors.black26,
    //onPrimaryContainer: Colors.black87,
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Roboto-Regular',
    colorScheme: lightColorScheme,

    // AppBar colors are hard-coded so other elements can use Material 3 roles
    appBarTheme: AppBarTheme(
    //  backgroundColor: colorScheme.surface,
    //  foregroundColor: colorScheme.onSurface
    //  actionsIconTheme: colorScheme.onSurfaceVariant
      backgroundColor: lightColorScheme.primary,
      foregroundColor: Colors.white,
      actionsIconTheme: const IconThemeData(color: Colors.white60),
      elevation: 20,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),

    // TabBar uses surfaceContainerHigh for subtle elevation
    tabBarTheme: TabBarThemeData(
      //unselectedLabelColor: Colors.black26,
      indicatorColor: _highlight,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      //overlayColor: WidgetStateProperty.all(Colors.black12),
    ),

    scaffoldBackgroundColor: _scaffold,

    // Buttons - Material 3 style
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _highlight,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: _buttonBorderRadius,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _appBarDark,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: _buttonBorderRadius,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _appBarDark,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _appBarDark,
        side: const BorderSide(color: _appBarDark),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: _buttonBorderRadius,
        ),
      ),
    ),


    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
/*
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: _surfaceLight,
      modalBackgroundColor: _surfaceLight,
      elevation: 3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),

    // Drawer
    drawerTheme: DrawerThemeData(
      //  backgroundColor: colorScheme.surface,
      //  foregroundColor: colorScheme.onSurface
    ),
*/
    // List tiles
    listTileTheme: const ListTileThemeData(
     titleTextStyle: TextStyle(
        fontSize: 15,
      ),
      subtitleTextStyle: TextStyle(
        fontSize: 15,
      ),
      //visualDensity: VisualDensity(horizontal: 0, vertical: -4),
    ),

    // Input decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightColorScheme.surfaceContainerHighest,
      hintStyle: TextStyle(color: lightColorScheme.onSurfaceVariant),
    ),

    // Dividers
    dividerTheme: DividerThemeData(
      color: lightColorScheme.surfaceContainerLow,
      thickness: 1,
      space: 1,
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: lightColorScheme.surfaceContainerLow,
      inactiveTrackColor: Colors.grey[300],
      thumbColor: _highlight,
    ),

    textTheme: const TextTheme(
      titleLarge: TextStyle(
        color: Colors.white70,
        fontSize: 20,
      ),
    ),
  );




  // Dark theme - Material 3 role-based
  // Defined as extensions to the light theme to minimize duplication
  static final ThemeData darkTheme = lightTheme.copyWith(
    brightness: Brightness.dark,
    colorScheme: lightTheme.colorScheme.copyWith(
      brightness: Brightness.dark,
      // Dark mode surface hierarchy
      surface: _surfaceDark,
      surfaceContainerLowest: const Color(0xFF0F0E11),
      surfaceContainerLow: _surfaceDarkest,
      surfaceContainer: _surfaceDark,
      surfaceContainerHigh: _surfaceDark,
      surfaceContainerHighest: _surfaceLight,
      // Material 3 role-based text colors for dark theme
      onSurface: Colors.white,          // Default text on surfaces
      onPrimary: Colors.white,          // Text on primary color
      onSecondary: Colors.white,        // Text on secondary color
      onSurfaceVariant: Colors.black26,   // Text on surface variants
      onError: Colors.white,            // Text on error surfaces
      onPrimaryContainer: Colors.black26, // Text on primary containers
      onSecondaryContainer: Colors.white, // Text on secondary containers
      onTertiary: Colors.white,          // Text on tertiary color
      onTertiaryContainer: Colors.black, // Text on tertiary containers
    ),

    appBarTheme: lightTheme.appBarTheme.copyWith(
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),

    tabBarTheme: lightTheme.tabBarTheme.copyWith(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white60,
    ),

    listTileTheme: lightTheme.listTileTheme,

    textTheme: lightTheme.textTheme.copyWith(
      titleLarge: const TextStyle(
        color: Colors.white70,
        fontSize: 20,
      ),
    ).apply(
      bodyColor: Colors.white,    // Default text color for body text
      displayColor: Colors.white, // Default color for large/display text
    ),
  );

  /// Helper to get theme based on system brightness
  static ThemeData getTheme(Brightness brightness) {
    return brightness == Brightness.dark ? darkTheme : lightTheme;
  }
}
