import 'package:material_ui/material_ui.dart';

abstract final class CampusConnectTheme {
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF245A80),
      surface: const Color(0xFFF6F8FB),
    ),
    scaffoldBackgroundColor: const Color(0xFFF6F8FB),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF6F8FB),
      foregroundColor: Color(0xFF18364D),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
