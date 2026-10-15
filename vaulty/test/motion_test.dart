import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vaulty/core/theme/app_theme.dart';
import 'package:vaulty/core/widgets/app_widgets.dart';

void main() {
  testWidgets('Reduce motion stops skeletons and removes reveal delays', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(
            body: Column(
              children: [
                Reveal(index: 5, child: Text('Ready')),
                SkeletonBox(),
                StatBar(value: .5, label: 'Storage'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(Reveal),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fade.opacity.value, 1);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
