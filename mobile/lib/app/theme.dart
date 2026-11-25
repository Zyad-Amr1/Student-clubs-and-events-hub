import 'package:material_ui/material_ui.dart';

import 'design.dart';

abstract final class CampusConnectTheme {
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: CampusColors.purple,
      primary: CampusColors.purple,
      onSurface: CampusColors.ink,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: CampusColors.canvas,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: CampusColors.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.1,
      ),
      headlineMedium: TextStyle(
        color: CampusColors.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.7,
      ),
      headlineSmall: TextStyle(
        color: CampusColors.ink,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.45,
      ),
      titleLarge: TextStyle(
        color: CampusColors.ink,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      titleMedium: TextStyle(
        color: CampusColors.ink,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: CampusColors.ink, height: 1.45),
      bodyMedium: TextStyle(color: CampusColors.inkMuted, height: 1.4),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: CampusColors.ink,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        color: CampusColors.ink,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: CampusColors.purple,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 12,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      shadowColor: const Color(0x12391B50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: CampusColors.line),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      height: 64,
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFE9D6FA),
      elevation: 0,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: const DividerThemeData(color: CampusColors.line),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: CampusColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: CampusColors.lavenderActive,
      side: const BorderSide(color: CampusColors.line),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: CampusColors.purple,
      linearTrackColor: CampusColors.lavender,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: CampusColors.purple,
      selectionColor: CampusColors.lavenderActive,
      selectionHandleColor: CampusColors.purple,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: CampusColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: CampusColors.purple, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: CampusColors.redFg),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: CampusColors.redFg, width: 1.5),
      ),
      prefixIconColor: CampusColors.purple,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: const BorderSide(color: CampusColors.line),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}
