import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaulty/app/bootstrap.dart';
import 'package:vaulty/data/mock/mock_repositories.dart';
import 'package:vaulty/domain/models/document.dart';
import 'package:vaulty/domain/repositories/auth_repository.dart';
import 'package:vaulty/features/documents/providers/document_providers.dart';
import 'package:vaulty/features/settings/providers/settings_providers.dart';

final identity = StateProvider<String>((ref) => 'a');

class DelayedDocs extends MockDocumentRepository {
  DelayedDocs(this.owner) : super(MockStore());
  final String Function() owner;
  final started = Completer<void>(), pending = Completer<void>();
  @override
  Future<List<Document>> list() async => [
    Document(
      id: owner(),
      title: owner(),
      belongsTo: owner(),
      kind: FileKind.pdf,
      uploadedAt: DateTime(2026),
      sizeBytes: 1,
    ),
  ];
  @override
  Future<void> save(Document d) {
    started.complete();
    return pending.future;
  }
}

class DelayedSettings extends MockAuthRepository {
  DelayedSettings(this.owner) : super(MockStore());
  final String Function() owner;
  final started = Completer<void>(), pending = Completer<void>();
  @override
  Future<VaultPreferences> preferences() async => VaultPreferences(
    theme: owner() == 'a' ? 'dark' : 'light',
    biometric: owner() == 'b',
  );
  @override
  Future<void> savePreferences(VaultPreferences p) {
    started.complete();
    return pending.future;
  }
}

void main() {
  test(
    'A failed old-account write cannot restore old documents into the new account',
    () async {
      late ProviderContainer c;
      final repo = DelayedDocs(() => c.read(identity));
      c = ProviderContainer(
        overrides: [
          documentRepositoryProvider.overrideWithValue(repo),
          vaultIdentityProvider.overrideWith((ref) => ref.watch(identity)),
        ],
      );
      addTearDown(c.dispose);
      final a = (await c.read(documentsProvider.future)).single;
      final operation = c
          .read(documentsProvider.notifier)
          .save(a.copyWith(title: 'A edited'));
      final failure = expectLater(operation, throwsStateError);
      await repo.started.future;
      c.read(identity.notifier).state = 'b';
      expect((await c.read(documentsProvider.future)).single.id, 'b');
      repo.pending.completeError(StateError('old account failed'));
      await failure;
      expect(c.read(documentsProvider).requireValue.single.id, 'b');
    },
  );
  test(
    'An old-account settings rollback cannot disable the new account lock',
    () async {
      late ProviderContainer c;
      final repo = DelayedSettings(() => c.read(identity));
      c = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          vaultIdentityProvider.overrideWith((ref) => ref.watch(identity)),
        ],
      );
      addTearDown(c.dispose);
      final a = await c.read(settingsProvider.future);
      final operation = c
          .read(settingsProvider.notifier)
          .save(a.copyWith(reminderDays: 7));
      final failure = expectLater(operation, throwsStateError);
      await repo.started.future;
      c.read(identity.notifier).state = 'b';
      expect((await c.read(settingsProvider.future)).biometric, isTrue);
      repo.pending.completeError(StateError('old account failed'));
      await failure;
      expect(c.read(settingsProvider).requireValue.biometric, isTrue);
      expect(c.read(settingsProvider).requireValue.theme, 'light');
    },
  );
}
