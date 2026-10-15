import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/bootstrap.dart';
import '../../../domain/models/audit_event.dart';
import '../../../domain/models/storage_info.dart';

final storageProvider = FutureProvider<StorageInfo>((ref) {
  ref.watch(vaultIdentityProvider);
  return ref.watch(insightsRepositoryProvider).storage();
});
final activityProvider = FutureProvider<List<AuditEvent>>((ref) {
  ref.watch(vaultIdentityProvider);
  return ref.watch(insightsRepositoryProvider).activity();
});
final auditProvider = FutureProvider.family<List<AuditEvent>, String?>((
  ref,
  id,
) {
  ref.watch(vaultIdentityProvider);
  return ref.watch(insightsRepositoryProvider).audit(documentId: id);
});
