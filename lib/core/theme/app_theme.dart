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
/*
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
*/
  static final ColorScheme lightColorScheme = ColorScheme(
    primary: Color(0xFF2E260F),
    onPrimary: Color(0xFFffffff),
    secondary: Color(0xFF655E51),
    onSecondary: Color(0xFFffffff),
    tertiary: Color(0xFF3494F1),
    error: Color(0xFFba1a1a),
    onError: Color(0xFFffffff),
    surface: Color(0xFFE1DCC5),
    onSurface: Color(0xFF1c1b1a),
    onSurfaceVariant: Color(0xFFA9A09A),
    surfaceContainer: Color(0xFFEEEBDF),
    inverseSurface: Color(0xFF333333),
    onInverseSurface: Color(0xFFEEEBDF),
    brightness: Brightness.light,
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Roboto-Regular',
    colorScheme: lightColorScheme,
    scaffoldBackgroundColor: lightColorScheme.inverseSurface,

    // AppBar colors are hard-coded so other elements can use Material 3 roles
    appBarTheme: AppBarTheme(
      backgroundColor: lightColorScheme.primary,
      foregroundColor: Colors.white,
      actionsIconTheme: const IconThemeData(color: Colors.white60),
      elevation: 20,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),

    tabBarTheme: TabBarThemeData(
      unselectedLabelColor: lightColorScheme.secondary,
      indicatorColor: lightColorScheme.tertiary,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
    ),

    drawerTheme: DrawerThemeData(
      backgroundColor: lightColorScheme.surface,
    ),

    // Buttons - Material 3 style
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightColorScheme.tertiary,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: _buttonBorderRadius,
        ),
      ),
    ),
/*
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

*/
    dialogTheme: DialogThemeData(
      backgroundColor: lightColorScheme.surface,
    ),

    // List tiles
    listTileTheme: ListTileThemeData(
     titleTextStyle: TextStyle(
        fontSize: 15,
        color: lightColorScheme.onSurface,
        fontFamily: 'Roboto-Regular',
      ),
      subtitleTextStyle: TextStyle(
        fontSize: 15,
        fontFamily: 'Roboto-Regular',
      ),
    ),

    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return lightColorScheme.tertiary;
        }
        return lightColorScheme.surfaceContainer;
      }),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: lightColorScheme.secondary,
      inactiveTrackColor: lightColorScheme.secondaryContainer,
      thumbColor: lightColorScheme.tertiary,
    ),

    // Input decoration for text inputs
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightColorScheme.surfaceContainer,
      hintStyle: TextStyle(color: lightColorScheme.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),

    // Dividers
    dividerTheme: DividerThemeData(
      color: lightColorScheme.onSurfaceVariant,
      thickness: 1,
      space: 1,
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: lightColorScheme.primary,
      contentTextStyle: TextStyle(
        color: lightColorScheme.onPrimary,
        fontSize: 14,
      ),
      actionTextColor: lightColorScheme.tertiary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),

    textTheme: TextTheme(
      // Display styles - largest text
      displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400),
      displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400),

      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: lightColorScheme.onPrimary),

      // Body styles - main content
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),

      // Label styles - buttons, tabs
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ).apply(
      fontFamily: 'Roboto-Regular',
    ),


  );


  // Dark theme - Material 3 role-based
  // Defined as extensions to the light theme to minimize duplication
  static final darkColorScheme = lightColorScheme.copyWith(
    onPrimary: Color(0xFFeeeeee),
    secondary: Color(0xFF766254),
    onSecondary: Color(0xFFeeeeee),
    secondaryContainer: Color(0xFFACA496),
    surface: Color(0xFF655E51),
    onSurface: Color(0xFFEEEBDF),
    onSurfaceVariant: Color(0xFF938978),
    surfaceContainer: Color(0xFFACA496),
  );

  static final ThemeData darkTheme = lightTheme.copyWith(
    brightness: Brightness.dark,
    colorScheme: darkColorScheme,

    appBarTheme: lightTheme.appBarTheme.copyWith(
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),

    tabBarTheme: lightTheme.tabBarTheme.copyWith(
      labelColor: darkColorScheme.onSecondary,
      unselectedLabelColor: darkColorScheme.onSurfaceVariant,
    ),

    drawerTheme: lightTheme.drawerTheme.copyWith(
      backgroundColor: darkColorScheme.surface,
    ),

    listTileTheme: lightTheme.listTileTheme.copyWith(
      titleTextStyle: lightTheme.listTileTheme.titleTextStyle?.copyWith(
        color: darkColorScheme.onSurface,
      ),
    ),

    sliderTheme: lightTheme.sliderTheme.copyWith(
      activeTrackColor: darkColorScheme.secondary,
      inactiveTrackColor: darkColorScheme.secondaryContainer,
      thumbColor: darkColorScheme.tertiary,
    ),

    inputDecorationTheme: lightTheme.inputDecorationTheme.copyWith(
      fillColor: darkColorScheme.surfaceContainer,
      hintStyle: TextStyle(color: darkColorScheme.onSurfaceVariant),
    ),

    dividerTheme: lightTheme.dividerTheme.copyWith(
      color: darkColorScheme.onSurfaceVariant,
    ),

    dialogTheme: lightTheme.dialogTheme.copyWith(
      backgroundColor: darkColorScheme.surface,
    ),

    textTheme: lightTheme.textTheme.copyWith(
      titleLarge: lightTheme.textTheme.titleLarge?.copyWith(
        color: darkColorScheme.onPrimary,
      ),
    ).apply(
      bodyColor: darkColorScheme.onPrimary,
      displayColor: darkColorScheme.onPrimary,
    ),
  );

  /// Helper to get theme based on system brightness
  static ThemeData getTheme(Brightness brightness) {
    return brightness == Brightness.dark ? darkTheme : lightTheme;
  }
}
