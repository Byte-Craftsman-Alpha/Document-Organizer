import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vaulty/app/live_bootstrap.dart';
import 'package:vaulty/main.dart';
import 'package:vaulty/core/widgets/app_widgets.dart';

void main() {
  testWidgets('Missing OAuth configuration never opens a fake vault', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final overrides = await liveOverrides(clientId: '');
    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const VaultyApp()),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.scrollUntilVisible(
      find.text('Google connection not configured'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Google connection not configured'), findsOneWidget);
    expect(
      find.widgetWithText(AppButton, 'Continue with Google'),
      findsNothing,
    );
    expect(find.text('Your documents'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
