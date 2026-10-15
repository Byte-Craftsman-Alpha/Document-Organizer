import 'dart:typed_data';
import 'auth_repository.dart';
import 'document_repository.dart';

class AccountConnection {
  const AccountConnection({
    this.id,
    this.name,
    this.email,
    this.driveReady = false,
    this.offline = false,
    this.error,
  });
  final String? id, name, email, error;
  final bool driveReady, offline;
  String? get vaultIdentity => driveReady ? id : null;
}

abstract interface class LiveAuthRepository implements AuthRepository {
  AccountConnection get connection;
  Stream<AccountConnection> get connections;
  String? get configurationError;
  Future<void> initialize();
}

class DocumentBytes {
  const DocumentBytes(
    this.name,
    this.mimeType,
    this.bytes, {
    this.fromCache = false,
    this.offline = false,
  });
  final bool fromCache, offline;
  final String name, mimeType;
  final Uint8List bytes;
}

abstract interface class LiveDocumentRepository implements DocumentRepository {
  Future<DocumentBytes> read(String id);
  Future<void> open(String id);
  Future<bool> shareCopy(String id);
  Future<bool> enableReminders();
  Future<void> syncReminders();
  Future<void> lockChallenge();
  bool get supportsDeviceFeatures;
}

class VaultFailure implements Exception {
  const VaultFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class DriveOfflineFailure extends VaultFailure {
  const DriveOfflineFailure()
    : super(
        'Drive is offline. Cached files are available; reconnect to upload or edit.',
      );
}

abstract interface class OfflineAuthRepository implements AuthRepository {
  Future<void> openOffline();
}

abstract interface class CachedDocumentRepository
    implements DocumentRepository {
  bool get isOffline;
  Future<void> clearCache();
  Future<void> markBrowsed(String id);
  Future<Map<String, DateTime>> browsed();
}
