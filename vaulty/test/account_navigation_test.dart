import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vaulty/app/bootstrap.dart';
import 'package:vaulty/app/router.dart';
import 'package:vaulty/data/mock/mock_repositories.dart';
import 'package:vaulty/domain/repositories/auth_repository.dart';
import 'package:vaulty/features/documents/providers/collection_providers.dart';
import 'package:vaulty/main.dart';
import 'app_test.dart' as harness;

final account = StateProvider<String>((ref) => 'account-a');
void main() {
  testWidgets(
    'Account switches replace navigation state and clear private search input',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final store = MockStore()..user = 'Tester';
      store.prefs = const VaultPreferences(noticeSeen: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...harness.overrides(store),
            vaultIdentityProvider.overrideWith((ref) => ref.watch(account)),
          ],
          child: const VaultyApp(),
        ),
      );
      await harness.settleData(tester);
      final c = ProviderScope.containerOf(
        tester.element(find.byType(VaultyApp)),
      );
      final old = c.read(routerProvider);
      old.go('/documents');
      await harness.settleData(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Find a document'),
        'private account A search',
      );
      await tester.pump();
      expect(c.read(quickQueryProvider), 'private account A search');
      c.read(account.notifier).state = 'account-b';
      await harness.settleData(tester);
      final next = c.read(routerProvider);
      expect(identical(old, next), isFalse);
      expect(c.read(quickQueryProvider), '');
      next.go('/documents');
      await harness.settleData(tester);
      expect(find.text('private account A search'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
