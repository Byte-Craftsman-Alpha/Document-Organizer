import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vaulty/main.dart';
import 'package:vaulty/app/router.dart';
import 'package:vaulty/data/mock/mock_repositories.dart';
import 'package:vaulty/domain/repositories/auth_repository.dart';
import 'app_test.dart' as harness;

void main() {
  testWidgets('Grid handles long real-world names at 1.3x text scale', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = MockStore()..user = 'Tester';
    store.prefs = const VaultPreferences(noticeSeen: true);
    store.documents[0] = store.documents[0].copyWith(
      title: List.filled(12, 'Long property document title').join(' '),
      belongsTo: List.filled(8, 'Gomti Nagar family property').join(' '),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides(store),
        child: const VaultyApp(),
      ),
    );
    await harness.settleData(tester);
    ProviderScope.containerOf(
      tester.element(find.byType(VaultyApp)),
    ).read(routerProvider).go('/documents');
    await harness.settleData(tester);
    await tester.tap(find.byTooltip('Switch to grid'));
    await harness.settleData(tester);
    expect(tester.takeException(), isNull);
  });
}
