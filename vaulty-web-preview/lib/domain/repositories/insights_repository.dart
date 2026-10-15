import '../models/audit_event.dart';
import '../models/storage_info.dart';

abstract interface class InsightsRepository {
  Future<StorageInfo> storage();
  Future<List<AuditEvent>> activity();
  Future<List<AuditEvent>> audit({String? documentId});
}
