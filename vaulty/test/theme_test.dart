import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vaulty/core/theme/app_theme.dart';
import 'package:vaulty/core/theme/app_extensions.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void main() {
  testWidgets('Semantic foregrounds have at least 4.5:1 contrast', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final c = theme.colorScheme, t = theme.extension<AppTokens>()!;
      for (final surface in [
        theme.scaffoldBackgroundColor,
        c.surface,
        c.surfaceContainer,
        c.primaryContainer,
      ]) {
        expect(contrast(c.onSurface, surface), greaterThanOrEqualTo(4.5));
        expect(contrast(t.muted, surface), greaterThanOrEqualTo(4.5));
      }
      for (final surface in [t.mint, t.lime, t.warning, t.danger]) {
        expect(contrast(t.statusInk, surface), greaterThanOrEqualTo(4.5));
      }
      expect(contrast(c.onPrimary, c.primary), greaterThanOrEqualTo(4.5));
      expect(contrast(c.error, c.surface), greaterThanOrEqualTo(4.5));
    }
    await tester.runAsync(() async {
      await GoogleFonts.pendingFonts();
    });
  });
}
