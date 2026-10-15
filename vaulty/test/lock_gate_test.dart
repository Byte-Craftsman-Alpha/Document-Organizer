import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vaulty/app/bootstrap.dart';
import 'package:vaulty/core/theme/app_theme.dart';
import 'package:vaulty/data/mock/mock_repositories.dart';
import 'package:vaulty/domain/repositories/auth_repository.dart';
import 'package:vaulty/domain/repositories/live_capabilities.dart';
import 'package:vaulty/features/auth/widgets/app_lock_gate.dart';
import 'package:vaulty/features/settings/providers/settings_providers.dart';

class DeviceDocs extends MockDocumentRepository
    implements LiveDocumentRepository {
  DeviceDocs() : super(MockStore());
  @override
  bool get supportsDeviceFeatures => true;
  @override
  Future<void> lockChallenge() async {}
  @override
  Future<DocumentBytes> read(String id) => throw UnimplementedError();
  @override
  Future<void> open(String id) async {}
  @override
  Future<bool> shareCopy(String id) async => true;
  @override
  Future<bool> enableReminders() async => true;
  @override
  Future<void> syncReminders() async {}
}

class LockedSettings extends SettingsController {
  @override
  Future<VaultPreferences> build() async =>
      const VaultPreferences(biometric: true);
}

class Draft extends StatefulWidget {
  const Draft({super.key, required this.onMounted});
  final VoidCallback onMounted;
  @override
  State<Draft> createState() => _DraftState();
}

class _DraftState extends State<Draft> {
  @override
  void initState() {
    super.initState();
    widget.onMounted();
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Editing draft')));
}

void main() {
  testWidgets(
    'Biometric overlay preserves the navigator/form subtree across an external picker pause',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      var mounts = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentRepositoryProvider.overrideWithValue(DeviceDocs()),
            vaultIdentityProvider.overrideWithValue('account-a'),
            settingsProvider.overrideWith(LockedSettings.new),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: AppLockGate(child: Draft(onMounted: () => mounts++)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Your vault is locked'), findsOneWidget);
      expect(mounts, 1);
      expect(find.text('Editing draft'), findsNothing);
      expect(find.text('Editing draft', skipOffstage: false), findsOneWidget);
      await tester.tap(find.text('Unlock Vaulty'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Editing draft'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Your vault is locked'), findsOneWidget);
      expect(mounts, 1);
      await tester.tap(find.text('Unlock Vaulty'));
      await tester.pump();
      expect(find.text('Editing draft'), findsOneWidget);
      expect(mounts, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
