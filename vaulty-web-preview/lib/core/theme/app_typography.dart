import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTypography {
  static TextTheme build(Color ink) {
    TextStyle style(double size, FontWeight weight) => GoogleFonts.publicSans(
      fontSize: size,
      fontWeight: weight,
      height: 1.45,
      color: ink,
    ).copyWith(
      fontFamilyFallback: const ['NotoSansDevanagari'],
    );
    final display = style(28, FontWeight.w600);
    final title = style(20, FontWeight.w600);
    final subtitle = style(16, FontWeight.w500);
    final body = style(14, FontWeight.w400);
    final caption = style(12, FontWeight.w400);
    final label = style(13, FontWeight.w600);
    return TextTheme(
      displayLarge: display,
      displayMedium: display,
      displaySmall: display,
      headlineLarge: display,
      headlineMedium: title,
      headlineSmall: title,
      titleLarge: title,
      titleMedium: subtitle,
      titleSmall: subtitle,
      bodyLarge: body,
      bodyMedium: body,
      bodySmall: caption,
      labelLarge: label,
      labelMedium: label,
      labelSmall: caption,
    );
  }
}
