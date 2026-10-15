import '../models/share_record.dart';

abstract interface class ShareRepository {
  Future<List<ShareRecord>> list();
  Future<void> create(ShareRecord record);
  Future<void> revoke(String id);
}
