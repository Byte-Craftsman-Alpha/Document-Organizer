import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vaulty/main.dart';
import 'package:vaulty/app/router.dart';
import 'package:vaulty/data/mock/mock_repositories.dart';
import 'package:vaulty/domain/repositories/auth_repository.dart';
import 'package:vaulty/domain/repositories/document_repository.dart';
import 'package:vaulty/domain/models/document.dart';
import 'package:vaulty/core/widgets/app_widgets.dart';
import 'app_test.dart' as harness;

Future<void> show(WidgetTester tester, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.scrollUntilVisible(
    target,
    350,
    scrollable: find.byType(Scrollable).hitTestable().first,
  );
  await tester.pump();
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('Login, disclosure, tab state, theme and grid', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = MockStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides(store),
        child: const VaultyApp(),
      ),
    );
    await harness.settleData(tester);
    await tester.tap(find.text('Continue with Google'));
    await harness.settleData(tester);
    expect(find.text('Your Drive. Your documents.'), findsOneWidget);
    await tester.tap(find.text('I understand'));
    await harness.settleData(tester);
    await tester.tap(find.text('Documents'));
    await harness.settleData(tester);
    await tester.tap(find.byTooltip('Switch to grid'));
    await harness.settleData(tester);
    for (var i = 0; i < 8; i++) {
      await tester.drag(
        find.byType(Scrollable).hitTestable().first,
        const Offset(0, -600),
      );
      await harness.settleData(tester);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Settings'));
    await harness.settleData(tester);
    await tester.tap(find.text('Dark'));
    await harness.settleData(tester);
    expect(store.prefs.theme, 'dark');
    expect(store.prefs.noticeSeen, isTrue);
    await tester.tap(find.text('Documents'));
    await harness.settleData(tester);
    await tester.drag(
      find.byType(Scrollable).hitTestable().first,
      const Offset(0, 10000),
    );
    await harness.settleData(tester);
    expect(find.byTooltip('Switch to list'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Upload validates, completes, then edit and undo', (
    tester,
  ) async {
    final store = MockStore()..user = 'Ananya';
    store.prefs = const VaultPreferences(noticeSeen: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides(store),
        child: const VaultyApp(),
      ),
    );
    await harness.settleData(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(VaultyApp)),
    );
    final router = container.read(routerProvider);
    router.go(
      '/upload',
      extra: const SelectedFile('test.pdf', FileKind.pdf, 2500000),
    );
    await harness.settleData(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Document title *'),
      '',
    );
    await show(tester, find.text('Add to vault'));
    await tester.tap(find.text('Add to vault'));
    await tester.pump();
    expect(find.text('A title is required.'), findsOneWidget);
    await show(tester, find.widgetWithText(TextFormField, 'Document title *'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Document title *'),
      'Test policy',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Belongs to *'),
      'Ananya',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await show(tester, find.text('Add to vault'));
    await tester.tap(find.text('Add to vault'));
    await harness.settleData(tester);
    expect(find.text('Safely in your vault.'), findsOneWidget);
    final id = store.documents.first.id;
    expect(store.documents.first.title, 'Test policy');
    router.go('/document/$id/edit');
    await harness.settleData(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Document title *'),
      'Updated policy',
    );
    await show(tester, find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await harness.settleData(tester);
    expect(store.documents.first.title, 'Test policy');
    expect(tester.takeException(), isNull);
  });
  testWidgets('Trash requires confirmation and Undo restores safely', (
    tester,
  ) async {
    final store = MockStore()..user = 'Ananya';
    store.prefs = const VaultPreferences(noticeSeen: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides(store),
        child: const VaultyApp(),
      ),
    );
    await harness.settleData(tester);
    final router = ProviderScope.containerOf(
      tester.element(find.byType(VaultyApp)),
    ).read(routerProvider);
    router.go('/document/doc-1');
    await harness.settleData(tester);
    await show(tester, find.text('Move to Trash'));
    await tester.tap(find.text('Move to Trash'));
    await tester.pumpAndSettle();
    expect(store.documents.first.isDeleted, isFalse);
    await tester.tap(find.widgetWithText(AppButton, 'Move to Trash').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Undo'));
    await harness.settleData(tester);
    expect(store.documents.first.isDeleted, isFalse);
    expect(store.shares.first.revoked, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Home replaces Insights; no Copies or activity/audit screens', (
    tester,
  ) async {
    final store = MockStore()..user = 'Ananya';
    store.prefs = const VaultPreferences(noticeSeen: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides(store),
        child: const VaultyApp(),
      ),
    );
    await harness.settleData(tester);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Copies'), findsNothing);
    expect(find.text('Insights'), findsNothing);
    final router = ProviderScope.containerOf(
      tester.element(find.byType(VaultyApp)),
    ).read(routerProvider);
    router.go('/document/doc-2');
    await harness.settleData(tester);
    await show(tester, find.widgetWithText(AppButton, 'Share'));
    expect(find.text('Activity history'), findsNothing);
    expect(find.text('Share securely'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
