import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/bootstrap.dart';
import '../../../domain/models/share_record.dart';
import '../../insights/providers/insights_providers.dart';

final sharesProvider =
    AsyncNotifierProvider<SharesController, List<ShareRecord>>(
      SharesController.new,
    );

class SharesController extends AsyncNotifier<List<ShareRecord>> {
  @override
  Future<List<ShareRecord>> build() {
    ref.watch(vaultIdentityProvider);
    return ref.watch(shareRepositoryProvider).list();
  }

  Future<void> create(ShareRecord share) async {
    await ref.read(shareRepositoryProvider).create(share);
    ref.invalidateSelf();
    ref.invalidate(activityProvider);
    ref.invalidate(auditProvider);
  }

  Future<void> revoke(ShareRecord share) async {
    final before = state.requireValue;
    state = AsyncData(
      before.map((s) => s.id == share.id ? s.revoke() : s).toList(),
    );
    try {
      await ref.read(shareRepositoryProvider).revoke(share.id);
      ref.invalidate(activityProvider);
      ref.invalidate(auditProvider);
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    }
  }
}
