import 'package:flutter/material.dart';
import 'package:wood_quote/utils/colors.dart';

ThemeData get theme {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      surface: surface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),
    scaffoldBackgroundColor: neutral,
    fontFamily: 'Inter',
  );
}
