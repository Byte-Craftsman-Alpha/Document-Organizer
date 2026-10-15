import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vaulty/main.dart';
import 'package:vaulty/app/router.dart';
import 'package:vaulty/data/mock/mock_repositories.dart';
import 'package:vaulty/domain/repositories/auth_repository.dart';
import 'app_test.dart' as harness;

void main() {
  testWidgets(
    'Render Android UI preview frames',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final key = GlobalKey();
      final store = MockStore()..user = 'Ananya';
      store.prefs = const VaultPreferences(theme: 'light', noticeSeen: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: harness.overrides(store),
          child: RepaintBoundary(key: key, child: const VaultyApp()),
        ),
      );
      await tester.runAsync(() async {
        await GoogleFonts.pendingFonts();
      });
      await harness.settleData(tester);
      final router = ProviderScope.containerOf(
        tester.element(find.byType(VaultyApp)),
      ).read(routerProvider);
      for (final entry in {
        'home': '/home',
        'documents': '/documents',
        'detail': '/document/doc-2',
        'settings': '/settings',
      }.entries) {
        router.go(entry.value);
        await harness.settleData(tester);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('docs/screens').create(recursive: true);
          await File(
            'docs/screens/${entry.key}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
      }
    },
    skip: Platform.environment['CAPTURE_UI'] != '1',
  );
}
