import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vaulty/app/bootstrap.dart';
import 'package:vaulty/core/theme/app_theme.dart';
import 'package:vaulty/core/widgets/app_widgets.dart';
import 'package:vaulty/data/device/incoming_share.dart';
import 'package:vaulty/domain/models/document.dart';
import 'package:vaulty/domain/repositories/document_repository.dart';
import 'package:vaulty/domain/repositories/live_capabilities.dart';
import 'package:vaulty/features/documents/widgets/quick_share_button.dart';
import 'package:vaulty/features/imports/screens/import_screen.dart';
import 'package:vaulty/data/mock/mock_repositories.dart';
import 'lock_gate_test.dart' show DeviceDocs;
import 'app_test.dart' as harness;

class ImportRepo extends DeviceDocs {
  final uploaded = <Document>[];
  bool failSecond = true;
  int shares = 0;
  @override
  Stream<double> upload(Document document, SelectedFile file) async* {
    if (document.id.endsWith('two') && failSecond) {
      failSecond = false;
      throw const VaultFailure('Temporary upload failure');
    }
    uploaded.add(document);
    yield 1;
  }

  @override
  Future<bool> shareCopy(String id) async {
    shares++;
    return true;
  }
}

void main() {
  testWidgets(
    'One tap calls system-share capability without a share-management screen',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final repo = ImportRepo();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentRepositoryProvider.overrideWithValue(repo),
            vaultIdentityProvider.overrideWithValue('a'),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: QuickShareButton(id: 'doc', full: true)),
          ),
        ),
      );
      await tester.tap(find.widgetWithText(AppButton, 'Share'));
      await tester.pump();
      expect(repo.shares, 1);
      expect(find.text('Recipient email'), findsNothing);
    },
  );
  testWidgets(
    'Batch import validates content, adjusts details, retries only failed items at 320dp',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final pending = [
        {
          'id': 'one',
          'name': 'First photo.png',
          'size': 8,
          'mime': 'image/png',
          'error': '',
        },
        {
          'id': 'two',
          'name': 'Second photo.png',
          'size': 8,
          'mime': 'application/octet-stream',
          'error': '',
        },
        {
          'id': 'bad',
          'name': 'Unsupported.exe',
          'size': 8,
          'mime': 'application/octet-stream',
          'error': '',
        },
      ];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        IncomingShare.channel,
        (call) async {
          switch (call.method) {
            case 'pending':
              return pending;
            case 'read':
              return call.arguments['id'] == 'bad'
                  ? Uint8List.fromList([1, 2, 3])
                  : Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
            case 'discard':
              pending.removeWhere((f) => f['id'] == call.arguments['id']);
              return null;
            default:
              return null;
          }
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          IncomingShare.channel,
          null,
        ),
      );
      final repo = ImportRepo();
      final store = MockStore()..user = 'Person';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(MockAuthRepository(store)),
            insightsRepositoryProvider.overrideWithValue(
              MockInsightsRepository(store),
            ),
            searchRepositoryProvider.overrideWithValue(
              MockSearchRepository(store),
            ),
            documentRepositoryProvider.overrideWithValue(repo),
            vaultIdentityProvider.overrideWithValue('a'),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const ImportScreen()),
        ),
      );
      await harness.settleData(tester);
      expect(repo.uploaded, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Belongs to — apply to all'),
        'Family',
      );
      await tester.ensureVisible(find.text('Apply owner to pending files'));
      await tester.tap(find.text('Apply owner to pending files'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Import selected files'),
        400,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 50,
      );
      await tester.tap(find.text('Import selected files'));
      await harness.settleData(tester);
      expect(repo.uploaded.map((d) => d.id), ['incoming-one']);
      expect(repo.uploaded.single.belongsTo, 'Family');
      expect(repo.uploaded.single.kind, FileKind.png);
      expect(pending.any((p) => p['id'] == 'one'), isFalse);
      await tester.ensureVisible(find.text('Import selected files'));
      await tester.tap(find.text('Import selected files'));
      await harness.settleData(tester);
      expect(repo.uploaded.map((d) => d.id), ['incoming-one', 'incoming-two']);
      expect(pending.map((p) => p['id']), ['bad']);
      expect(tester.takeException(), isNull);
    },
  );
}
