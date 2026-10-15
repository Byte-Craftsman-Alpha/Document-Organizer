import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vaulty/main.dart';
import 'package:vaulty/app/bootstrap.dart';
import 'package:vaulty/app/router.dart';
import 'package:vaulty/data/mock/mock_repositories.dart';
import 'package:vaulty/domain/repositories/auth_repository.dart';
import 'package:vaulty/domain/models/document.dart';
import 'app_test.dart' as harness;
import 'package:vaulty/domain/repositories/live_capabilities.dart';

class CaptureAuth extends MockAuthRepository implements LiveAuthRepository {
  CaptureAuth(super.store);
  @override
  AccountConnection get connection => const AccountConnection(
    id: 'fixture',
    name: 'Demo',
    email: 'demo@example.com',
    driveReady: true,
  );
  @override
  Stream<AccountConnection> get connections => const Stream.empty();
  @override
  String? get configurationError => null;
  @override
  Future<void> initialize() async {}
}

void main() {
  testWidgets(
    'Capture v3 Home and Settings using explicitly mock fixture data',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      for (final theme in ['light', 'dark']) {
        final key = GlobalKey();
        final store = MockStore()..user = 'Demo';
        store.prefs = VaultPreferences(theme: theme, noticeSeen: true);
        store.documents
          ..clear()
          ..add(
            Document(
              id: 'example',
              title: 'Travel document',
              belongsTo: 'Personal',
              kind: FileKind.pdf,
              uploadedAt: DateTime(2026, 10, 15),
              sizeBytes: 420000,
            ),
          );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(CaptureAuth(store)),
              documentRepositoryProvider.overrideWithValue(
                MockDocumentRepository(store),
              ),
              insightsRepositoryProvider.overrideWithValue(
                MockInsightsRepository(store),
              ),
              shareRepositoryProvider.overrideWithValue(
                MockShareRepository(store),
              ),
              searchRepositoryProvider.overrideWithValue(
                MockSearchRepository(store),
              ),
              liveModeProvider.overrideWithValue(true),
            ],
            child: RepaintBoundary(key: key, child: const VaultyApp()),
          ),
        );
        await tester.runAsync(() => GoogleFonts.pendingFonts());
        await harness.settleData(tester);
        final router = ProviderScope.containerOf(
          tester.element(find.byType(VaultyApp)),
        ).read(routerProvider);
        for (final route in ['home', 'settings']) {
          router.go('/$route');
          await harness.settleData(tester);
          if (route == 'settings') {
            await tester.drag(
              find.byType(Scrollable).hitTestable().first,
              const Offset(0, -220),
            );
            await harness.settleData(tester);
          }
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('docs/screens/v3').create(recursive: true);
            await File(
              'docs/screens/v3/$route-$theme-mock.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
    skip: Platform.environment['CAPTURE_UI'] != '1',
  );
}
