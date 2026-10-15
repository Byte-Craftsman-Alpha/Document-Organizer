import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/bootstrap.dart';
import '../../../domain/models/document.dart';
import '../../../domain/repositories/live_capabilities.dart';
import '../../insights/providers/insights_providers.dart';
import '../../home/screens/home_screen.dart';
import '../widgets/live_file_preview.dart';

final documentsProvider =
    AsyncNotifierProvider<DocumentsController, List<Document>>(
      DocumentsController.new,
    );
final documentProvider = Provider.family<AsyncValue<Document?>, String>(
  (ref, id) => ref
      .watch(documentsProvider)
      .whenData((docs) => docs.where((d) => d.id == id).firstOrNull),
);

class DocumentsController extends AsyncNotifier<List<Document>> {
  Future<void> _queue = Future.value();
  String? _queueOwner;
  @override
  Future<List<Document>> build() {
    final owner = ref.watch(vaultIdentityProvider);
    if (owner != _queueOwner) {
      _queue = Future.value();
      _queueOwner = owner;
    }
    return ref.watch(documentRepositoryProvider).list();
  }

  void refreshRelated() {
    ref.invalidate(storageProvider);
    ref.invalidate(browsedProvider);
    ref.invalidate(documentBytesProvider);
  }

  Future<void> _mutate(
    List<Document> Function(List<Document>) update,
    Future<void> Function() commit,
  ) async {
    final owner = ref.read(vaultIdentityProvider);
    final before = state.requireValue;
    state = AsyncData(update(before));
    // Serialize writes, including Undo tapped before the original request finishes.
    final future = _queue.then((_) {
      if (ref.read(vaultIdentityProvider) != owner) {
        throw const VaultFailure(
          'Account changed; the pending edit was cancelled.',
        );
      }
      return commit();
    });
    _queue = future.catchError((Object _) {});
    try {
      await future;
      refreshRelated();
    } catch (_) {
      // Re-fetch on a race rather than overwrite newer optimistic changes.
      if (ref.read(vaultIdentityProvider) == owner) {
        state = AsyncData(before);
        ref.invalidateSelf();
      }
      rethrow;
    }
  }

  Future<void> save(Document d) {
    final updated = d.copyWith(modifiedAt: DateTime.now());
    return _mutate(
      (docs) => docs.map((v) => v.id == d.id ? updated : v).toList(),
      () => ref.read(documentRepositoryProvider).save(updated),
    );
  }

  Future<void> trash(Set<String> ids) => _mutate(
    (docs) => docs
        .map(
          (d) => ids.contains(d.id) ? d.copyWith(deletedAt: DateTime.now()) : d,
        )
        .toList(),
    () => ref.read(documentRepositoryProvider).trash(ids),
  );
  Future<void> restore(Set<String> ids) => _mutate(
    (docs) => docs
        .map((d) => ids.contains(d.id) ? d.copyWith(restore: true) : d)
        .toList(),
    () => ref.read(documentRepositoryProvider).restore(ids),
  );
  Future<void> purge(String id) => _mutate(
    (docs) => docs.where((d) => d.id != id).toList(),
    () => ref.read(documentRepositoryProvider).permanentlyDelete(id),
  );
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
