import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette « NYC Transit » (Unimark / Vignelli).
class C {
  static const black = Color(0xFF000000);
  static const card = Color(0xFF1C1C1E);
  static const card2 = Color(0xFF18181A);
  static const raised = Color(0xFF2C2C2E);
  static const stroke = Color(0xFF2E2E31);
  static const grey = Color(0xFF8E8E93);
  static const dim = Color(0xFF5A5A5E);

  static const yellow = Color(0xFFFFCC00);
  static const green = Color(0xFF34C759);
  static const red = Color(0xFFEE352E);
  static const orange = Color(0xFFFF6319);
  static const purple = Color(0xFFB933AD);
  static const blue = Color(0xFF0039A6);

  /// Puce TER
  static const ter = Color(0xFF0062B0);
}

TextStyle ts(
  double size, {
  FontWeight w = FontWeight.w500,
  Color c = Colors.white,
  double ls = 0,
  double? h,
  TextDecoration? deco,
}) =>
    GoogleFonts.inter(
      fontSize: size,
      fontWeight: w,
      color: c,
      letterSpacing: ls,
      height: h,
      decoration: deco,
      decorationColor: c,
      decorationThickness: 2,
    );

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: C.black,
    colorScheme: const ColorScheme.dark(
      primary: C.yellow,
      onPrimary: Colors.black,
      secondary: C.yellow,
      onSecondary: Colors.black,
      surface: C.card,
      onSurface: Colors.white,
      error: C.red,
    ),
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
    dividerColor: C.stroke,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: C.yellow,
      selectionHandleColor: C.yellow,
      selectionColor: Color(0x66FFCC00),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: C.yellow,
      contentTextStyle:
          TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

InputDecoration inputDeco(String hint, IconData icon) => InputDecoration(
      hintText: hint,
      hintStyle: ts(14, c: C.grey),
      prefixIcon: Icon(icon, color: C.grey),
      filled: true,
      fillColor: C.card2,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: C.yellow, width: 2),
      ),
    );
