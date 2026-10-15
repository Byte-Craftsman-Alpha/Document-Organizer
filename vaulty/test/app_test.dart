import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vaulty/main.dart';
import 'package:vaulty/app/bootstrap.dart';
import 'package:vaulty/app/router.dart';
import 'package:vaulty/data/mock/mock_repositories.dart';
import 'package:vaulty/domain/repositories/auth_repository.dart';
import 'package:vaulty/domain/repositories/document_repository.dart';
import 'package:vaulty/domain/models/document.dart';
import 'package:vaulty/features/search/widgets/advanced_search_sheet.dart';
import 'package:vaulty/domain/models/search_filter.dart';
import 'package:vaulty/core/widgets/app_widgets.dart';

List<Override> overrides(MockStore store) => [
  authRepositoryProvider.overrideWithValue(MockAuthRepository(store)),
  documentRepositoryProvider.overrideWithValue(MockDocumentRepository(store)),
  shareRepositoryProvider.overrideWithValue(MockShareRepository(store)),
  insightsRepositoryProvider.overrideWithValue(MockInsightsRepository(store)),
  searchRepositoryProvider.overrideWithValue(MockSearchRepository(store)),
];
Future<void> settleData(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  for (final theme in ['light', 'dark']) {
    testWidgets('Every route at 320dp, 1.3x text, $theme theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = MockStore()..user = 'Ananya';
      store.prefs = VaultPreferences(theme: theme, noticeSeen: true);
      await tester.pumpWidget(
        ProviderScope(overrides: overrides(store), child: const VaultyApp()),
      );
      await tester.runAsync(() async {
        await GoogleFonts.pendingFonts();
      });
      await settleData(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(VaultyApp)),
      );
      final router = container.read(routerProvider);
      for (final path in [
        '/home',
        '/documents',
        '/document/doc-2',
        '/document/doc-2/edit',
        '/search',
        '/trash',
        '/settings',
        '/gallery',
      ]) {
        router.go(path);
        await settleData(tester);
        expect(tester.takeException(), isNull, reason: path);
        // Exercise offscreen content, not only each route's first viewport.
        final scroll = find.byType(Scrollable).hitTestable().first;
        if (scroll.evaluate().isNotEmpty) {
          for (var i = 0; i < 4; i++) {
            await tester.drag(scroll, const Offset(0, -600));
            await settleData(tester);
            expect(tester.takeException(), isNull, reason: '$path scroll $i');
          }
        }
      }
      router.go(
        '/upload',
        extra: const SelectedFile('policy.pdf', FileKind.pdf, 2400000),
      );
      await settleData(tester);
      expect(tester.takeException(), isNull);
      router.go('/search');
      await settleData(tester);
      await tester.tap(find.byTooltip('Advanced filters'));
      await settleData(tester);
      expect(find.byType(AdvancedSearchSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView).last, const Offset(0, -1600));
      await settleData(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final scenario in [MockScenario.empty, MockScenario.error]) {
    testWidgets('Every list handles ${scenario.name}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MockStore(scenario: scenario)..user = 'Ananya';
      store.prefs = const VaultPreferences(noticeSeen: true);
      await tester.pumpWidget(
        ProviderScope(overrides: overrides(store), child: const VaultyApp()),
      );
      await settleData(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(VaultyApp)),
      );
      final router = container.read(routerProvider);
      for (final path in ['/home', '/documents', '/search', '/trash']) {
        router.go(path);
        await settleData(tester);
        expect(tester.takeException(), isNull, reason: path);
        expect(find.byType(EmptyState), findsWidgets, reason: path);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('Advanced filter validates inverted sizes', (tester) async {
    final store = MockStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(store),
        child: MaterialApp(
          home: Scaffold(
            body: AdvancedSearchSheet(initial: const SearchFilter()),
          ),
        ),
      ),
    );
    await settleData(tester);
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'Minimum size (MB)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Minimum size (MB)'),
      '20',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Maximum size (MB)'),
      '2',
    );
    await tester.scrollUntilVisible(
      find.text('Apply filters'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Apply filters'));
    await tester.pump();
    expect(find.text('Maximum must be at least the minimum.'), findsOneWidget);
  });
}
