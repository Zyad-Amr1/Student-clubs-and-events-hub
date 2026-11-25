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
      backgroundColor: CampusColors.canvas,
      foregroundColor: CampusColors.ink,
      centerTitle: false,
      elevation: 0,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: CampusColors.purple,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 12,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shadowColor: const Color(0x12391B50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: CampusColors.line),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFE9D6FA),
      elevation: 0,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
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
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}
