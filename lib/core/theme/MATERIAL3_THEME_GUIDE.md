# Material 3 Theming Guide for OL Reader

This guide explains how Material 3 color roles map to Flutter theme components.

## Table of Contents

- [ColorScheme Roles](#colorscheme-roles)
- [Component Mappings](#component-mappings)
  - [AppBarTheme](#appbartheme)
  - [TabBarTheme](#tabbartheme)
  - [Button Themes](#button-themes)
  - [CardTheme](#cardtheme)
  - [DialogTheme](#dialogtheme)
  - [TextTheme](#texttheme)
  - [Other Components](#other-components)
- [Best Practices](#best-practices)
- [Resources](#resources)

## ColorScheme Roles

The `ColorScheme` is the foundation of Material 3 theming. These are the primary color roles:

**Note:** All of these color roles are actively supported in Flutter 3.38.4 and Material 3. The `surfaceVariant` and related surface colors are not deprecated and continue to be the recommended way to create surface hierarchy in Material 3 designs.

### Surface Color Hierarchy

Material 3 introduces a sophisticated surface color system for creating depth and hierarchy:

```
surface (base) → surfaceContainerLowest → surfaceContainerLow → surfaceContainer → 
surfaceContainerHigh → surfaceContainerHighest
```

This hierarchy allows you to create visual depth without relying on elevation shadows alone.

=======

```dart
ColorScheme(
  // Brand Colors
  primary: Color(0xFF6750A4),          // Main brand color
  onPrimary: Color(0xFFFFFFFF),       // Text/icons on primary
  primaryContainer: Color(0xFFEADDFF), // Light version of primary
  onPrimaryContainer: Color(0xFF21005D), // Text on primary container

  // Secondary Colors
  secondary: Color(0xFF625B71),        // Secondary brand color
  onSecondary: Color(0xFFFFFFFF),      // Text/icons on secondary
  secondaryContainer: Color(0xFFE8DEF8), // Light version of secondary
  onSecondaryContainer: Color(0xFF1D192B), // Text on secondary container

  // Surface Colors (Backgrounds)
  surface: Color(0xFFFFFBFE),         // Main surface/background
  onSurface: Color(0xFF1C1B1F),        // Text/icons on surfaces
  surfaceVariant: Color(0xFFE7E0EC),   // Variant surfaces (cards, sheets, menus)
  onSurfaceVariant: Color(0xFF49454F), // Text/icons on surface variants
  surfaceContainer: Color(0xFFF7F2FA), // Container surfaces (cards, dialogs)
  surfaceContainerHigh: Color(0xFFECE6F0), // Higher elevation containers
  surfaceContainerHighest: Color(0xFFE6E0E9), // Highest elevation containers
  surfaceContainerLow: Color(0xFFF2EDF6), // Low elevation containers
  surfaceContainerLowest: Color(0xFFFFFBFE), // Lowest elevation containers
=======

  // Error Colors
  error: Color(0xFFB3261E),           // Error state color
  onError: Color(0xFFFFFFFF),         // Text/icons on error
  errorContainer: Color(0xFFF9DEDC),  // Light error background
  onErrorContainer: Color(0xFF410E0B), // Text on error container

  // Tertiary Colors (Optional)
  tertiary: Color(0xFF7D5260),         // Tertiary brand color
  onTertiary: Color(0xFFFFFFFF),      // Text/icons on tertiary
  tertiaryContainer: Color(0xFFFFD8E4), // Light version of tertiary
  onTertiaryContainer: Color(0xFF31111D), // Text on tertiary container

  // Other Properties
  outline: Color(0xFF79747E),          // Borders, dividers, outlines
  outlineVariant: Color(0xFFCAC4D0),  // Subtle borders
  shadow: Color(0xFF000000),          // Shadows
  scrim: Color(0xFF000000),           // Scrims (modal overlays)
  inverseSurface: Color(0xFF313033),  // Inverse surface color
  onInverseSurface: Color(0xFFF4EFF4), // Text on inverse surface
  inversePrimary: Color(0xFFD0BCFF),  // Inverse primary color

  brightness: Brightness.light,       // light or dark
)
```

## Component Mappings

### AppBarTheme

```dart
AppBarTheme(
  backgroundColor: colorScheme.primary, // Material 3: App bars typically use primary color
  // Alternative: colorScheme.surfaceContainer for a more subtle look
  foregroundColor: colorScheme.onPrimary, // Text/icons on primary background
  elevation: 0, // Material 3 uses minimal elevation
  systemOverlayStyle: brightness == Brightness.light
    ? SystemUiOverlayStyle.dark
    : SystemUiOverlayStyle.light,
  iconTheme: IconThemeData(color: colorScheme.onPrimary),
  actionsIconTheme: IconThemeData(color: colorScheme.onPrimary),
  titleTextStyle: TextStyle(
    color: colorScheme.onPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w500,
  ),
  toolbarTextStyle: TextStyle(color: colorScheme.onPrimary),
)
```

**Note:** In Material 3, app bars typically use the primary color for better brand visibility. However, you can also use `surfaceContainer` for a more subtle appearance that still follows Material 3 guidelines.

**Color Scheme Options:**
- `colorScheme.primary` - Strong brand presence (recommended for Material 3)
- `colorScheme.surfaceContainer` - Subtle, blends with surface hierarchy
- `colorScheme.surface` - Minimal contrast (use with caution)
=======

### TabBarTheme

```dart
TabBarTheme(
  indicatorColor: colorScheme.primary, // Selected tab indicator
  labelColor: colorScheme.onSurface,   // Selected tab text
  unselectedLabelColor: colorScheme.onSurfaceVariant, // Unselected tab text
  dividerColor: Colors.transparent,   // Remove divider for Material 3
  overlayColor: WidgetStateProperty.all(colorScheme.primary.withOpacity(0.1)),
)
```

### Button Themes

#### ElevatedButton
```dart
ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    backgroundColor: colorScheme.primary,      // Button background
    foregroundColor: colorScheme.onPrimary,    // Button text/icons
    elevation: 1,                              // Subtle elevation
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: TextStyle(fontWeight: FontWeight.w500),
  ),
)
```

#### FilledButton
```dart
FilledButtonThemeData(
  style: FilledButton.styleFrom(
    backgroundColor: colorScheme.primary,      // Button background
    foregroundColor: colorScheme.onPrimary,    // Button text/icons
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
)
```

#### TextButton
```dart
TextButtonThemeData(
  style: TextButton.styleFrom(
    foregroundColor: colorScheme.primary,      // Button text
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    textStyle: TextStyle(fontWeight: FontWeight.w500),
  ),
)
```

#### OutlinedButton
```dart
OutlinedButtonThemeData(
  style: OutlinedButton.styleFrom(
    foregroundColor: colorScheme.primary,      // Button text
    side: BorderSide(color: colorScheme.outline), // Button border
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
)
```

#### IconButton
```dart
IconButtonThemeData(
  style: IconButton.styleFrom(
    foregroundColor: colorScheme.onSurfaceVariant, // Icon color
  ),
)
```

### CardTheme

```dart
CardTheme(
  color: colorScheme.surfaceVariant, // Card background
  surfaceTintColor: colorScheme.primary, // Surface tint (subtle color)
  shadowColor: colorScheme.shadow,      // Shadow color
  elevation: 1,                        // Subtle elevation
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  margin: EdgeInsets.all(4),           // Card margins
)
```

### DialogTheme

```dart
DialogTheme(
  backgroundColor: colorScheme.surface, // Dialog background
  surfaceTintColor: colorScheme.primary, // Surface tint
  elevation: 3,                        // Dialog elevation
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  titleTextStyle: TextStyle(
    color: colorScheme.onSurface,      // Dialog title color
    fontSize: 20,
    fontWeight: FontWeight.w600,
  ),
  contentTextStyle: TextStyle(
    color: colorScheme.onSurface,      // Dialog content color
    fontSize: 14,
  ),
)
```

### TextTheme

```dart
TextTheme(
  // Display styles (large text)
  displayLarge: TextStyle(
    color: colorScheme.onSurface,
    fontSize: 57,
    fontWeight: FontWeight.w400,
    height: 1.12,
  ),
  displayMedium: TextStyle(
    color: colorScheme.onSurface,
    fontSize: 45,
    fontWeight: FontWeight.w400,
    height: 1.16,
  ),
  displaySmall: TextStyle(
    color: colorScheme.onSurface,
    fontSize: 36,
    fontWeight: FontWeight.w400,
    height: 1.22,
  ),

  // Headline styles
  headlineLarge: TextStyle(
    color: colorScheme.onSurface,
    fontSize: 32,
    fontWeight: FontWeight.w400,
    height: 1.25,
  ),
  headlineMedium: TextStyle(
    color: colorScheme.onSurface,
    fontSize: 28,
    fontWeight: FontWeight.w400,
    height: 1.29,
  ),
  headlineSmall: TextStyle(
    color: colorScheme.onSurface,
    fontSize: 24,
    fontWeight: FontWeight.w400,
    height: 1.33,
  ),

  // Title styles
  titleLarge: TextStyle(
    color: colorScheme.onSurface,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.27,
  ),
  titleMedium: TextStyle(
    color: colorScheme.onSurface,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
  ),
  titleSmall: TextStyle(
    color: colorScheme.onSurface,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.43,
  ),

  // Body styles (most common)
  bodyLarge: TextStyle(
    color: colorScheme.onSurface,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  ),
  bodyMedium: TextStyle(
    color: colorScheme.onSurface,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.43,
  ),
  bodySmall: TextStyle(
    color: colorScheme.onSurface,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.33,
  ),

  // Label styles (buttons, input labels)
  labelLarge: TextStyle(
    color: colorScheme.onSurface,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.43,
  ),
  labelMedium: TextStyle(
    color: colorScheme.onSurface,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.33,
  ),
  labelSmall: TextStyle(
    color: colorScheme.onSurface,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.45,
  ),
)
```

### Other Components

#### BottomSheetTheme
```dart
BottomSheetThemeData(
  backgroundColor: colorScheme.surface,
  modalBackgroundColor: colorScheme.surface,
  elevation: 3,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
)
```

#### DrawerTheme
```dart
DrawerThemeData(
  backgroundColor: colorScheme.surface,
  elevation: 16,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
)
```

#### ListTileTheme
```dart
ListTileThemeData(
  iconColor: colorScheme.onSurfaceVariant,
  textColor: colorScheme.onSurface,
  tileColor: colorScheme.surfaceVariant.withOpacity(0.05),
  selectedTileColor: colorScheme.primary.withOpacity(0.1),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
)
```

#### InputDecorationTheme
```dart
InputDecorationTheme(
  filled: true,
  fillColor: colorScheme.surfaceVariant,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide.none,
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: colorScheme.primary, width: 2),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: colorScheme.error, width: 1),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: colorScheme.outline, width: 1),
  ),
  hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
  labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
  prefixStyle: TextStyle(color: colorScheme.onSurface),
  suffixStyle: TextStyle(color: colorScheme.onSurface),
)
```

#### DividerTheme
```dart
DividerThemeData(
  color: colorScheme.outlineVariant,
  thickness: 1,
  space: 1,
  indent: 16,
  endIndent: 16,
)
```

#### SliderTheme
```dart
SliderThemeData(
  activeTrackColor: colorScheme.primary,
  inactiveTrackColor: colorScheme.surfaceVariant,
  thumbColor: colorScheme.primary,
  overlayColor: colorScheme.primary.withOpacity(0.2),
  valueIndicatorColor: colorScheme.primary,
  trackHeight: 4,
  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
)
```

#### SwitchTheme
```dart
SwitchThemeData(
  thumbColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.selected)) {
      return colorScheme.onPrimary;
    }
    return colorScheme.outline;
  }),
  trackColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.selected)) {
      return colorScheme.primary;
    }
    return colorScheme.surfaceVariant;
  }),
)
```

#### CheckboxTheme
```dart
CheckboxThemeData(
  fillColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.selected)) {
      return colorScheme.primary;
    }
    return colorScheme.surfaceVariant;
  }),
  checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
  overlayColor: WidgetStateProperty.all(colorScheme.primary.withOpacity(0.1)),
)
```

## Best Practices

### 1. Start with ColorScheme
Get your `ColorScheme` right first, then let it cascade to other components.

### 2. Use copyWith()
Always use `copyWith()` to modify existing themes rather than creating new ones from scratch.

### 3. Leverage Defaults
Many components automatically use the right colors from `ColorScheme`. Only override when necessary.

### 4. Test Contrast
Ensure text is readable on all backgrounds:
- Use [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
- Aim for at least 4.5:1 contrast ratio for normal text
- Aim for at least 3:1 for large text

### 5. Use Material 3 Tools
- [Material Theme Builder](https://m3.material.io/theme-builder) - Create and export themes
- [Material Color Tool](https://material.io/resources/color/#!/) - Generate color palettes
- [Flutter Theme Preview](https://github.com/bluefireteam/flutter_theme_preview) - Preview themes in your app

### 6. Dark Theme Strategy
For dark themes:
- Set `onSurface` to white (or near-white)
- Use darker surface colors
- Maintain proper contrast
- Test in both light and dark modes

### 7. Accessibility
- Ensure all interactive elements have sufficient contrast
- Provide alternative text for icons
- Support dynamic text sizing
- Consider color blindness (avoid red-green combinations)

## Resources

### Official Documentation
- [Material 3 Design Guidelines](https://m3.material.io/)
- [Flutter Material 3 Theming](https://docs.flutter.dev/ui/design/material-3)
- [ColorScheme Documentation](https://api.flutter.dev/flutter/material/ColorScheme-class.html)

### Tools
- [Material Theme Builder](https://m3.material.io/theme-builder)
- [Material Color Tool](https://material.io/resources/color)
- [Color Contrast Checker](https://webaim.org/resources/contrastchecker/)

### Flutter Packages
- [flex_color_scheme](https://pub.dev/packages/flex_color_scheme) - Advanced theming
- [dynamic_color](https://pub.dev/packages/dynamic_color) - Dynamic theming
- [flutter_theme_preview](https://pub.dev/packages/flutter_theme_preview) - Theme preview

### Articles & Tutorials
- [Material 3 in Flutter](https://medium.com/flutter/material-3-in-flutter-2a9a7e9c7d7d)
- [Flutter Theming Guide](https://flutter.dev/docs/cookbook/design/themes)
- [Advanced Flutter Theming](https://medium.com/flutter/advanced-flutter-theming-1a76b86d5e4d)

## OL Reader Specific Notes

### Our Color Palette
- **Primary (Dark)**: `Color(0xFF2E1E0F)` - Used for app bars and primary actions
- **Surface Light**: `Color(0xFFE1DCC5)` - Used for tab bars and surfaces
- **Surface Medium**: `Color(0xFFB6AB9C)` - Used for borders and dividers
- **Surface Dark**: `Color(0xFF8D775F)` - Used for surface variants
- **Highlight**: `Color(0xFF3494F1)` - Used for accents and indicators

### AppBar Implementation Note

**Current Implementation:** Our app uses a custom AppBar background color (`_appBarDark`) rather than the standard Material 3 approach. This is perfectly valid and gives us our distinctive brand identity.

**Standard Material 3 Approach:**
```dart
AppBarTheme(
  backgroundColor: colorScheme.primary, // Standard M3 approach
  foregroundColor: colorScheme.onPrimary,
)
```

**Our Custom Approach:**
```dart
AppBarTheme(
  backgroundColor: _appBarDark, // Custom brand color
  foregroundColor: Colors.white,
)
```

Both approaches are valid. The custom approach provides stronger brand identity, while the standard approach offers better integration with Material 3's dynamic color system.

### Surface Color Usage in OL Reader

Our theme uses surface colors strategically:

- **`surface`**: `_surfaceLight` (0xFFE1DCC5) - Main background
- **`surfaceContainer`**: `_surfaceLight` - Cards and containers
- **`surfaceContainerHigh`**: `_surfaceLight` - Elevated surfaces
- **`surfaceContainerHighest`**: 0xFFF8F3EA - Highest elevation surfaces
- **`surfaceVariant`**: `_surfaceDark` (0xFF8D775F) - Variant surfaces

This creates a subtle but effective surface hierarchy while maintaining our brand's warm, earthy color palette.
=======

### Our Theme Structure
- Light theme defines all base styles
- Dark theme extends light theme with `copyWith()`
- Material 3 is enabled with `useMaterial3: true`
- Role-based colors are properly configured

### Custom Components
For custom widgets, use:
```dart
Text(
  'Hello',
  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
)

Container(
  color: Theme.of(context).colorScheme.surfaceVariant,
  child: Icon(
    Icons.star,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  ),
)
```

This ensures your custom widgets respect the current theme.
