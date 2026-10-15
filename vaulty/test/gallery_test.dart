import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vaulty/core/theme/app_theme.dart';
import 'package:vaulty/core/widgets/design_gallery.dart';

void main() {
  testWidgets('Design gallery light and dark render without overflow', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final dark in [false, true]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          home: RepaintBoundary(
            key: key,
            child: DesignGallery(onTheme: (_) {}),
          ),
        ),
      );
      await tester.runAsync(() async {
        await GoogleFonts.pendingFonts();
      });
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      if (Platform.environment['CAPTURE_GALLERY'] == '1') {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'docs/gallery-${dark ? 'dark' : 'light'}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
        });
      }
    }
  });
}
