import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../cache/cached_file.dart';
import '../device/file_validation.dart';
import '../device/incoming_share.dart';
import '../../domain/models/document.dart';
import '../../domain/models/share_record.dart';
import '../../domain/models/audit_event.dart';
import '../../domain/models/storage_info.dart';
import '../../domain/models/search_filter.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/document_repository.dart';
import '../../domain/repositories/share_repository.dart';
import '../../domain/repositories/insights_repository.dart';
import '../../domain/repositories/search_repository.dart';
import '../../domain/repositories/live_capabilities.dart';
import '../device/file_actions.dart';
import '../device/device_services.dart';
import 'google_identity.dart';
import 'drive_store.dart';
import 'drive_codec.dart';
import 'drive_api.dart';

class GoogleAuthRepository
    implements LiveAuthRepository, OfflineAuthRepository {
  GoogleAuthRepository(this.google, this.store, this.device);
  final GoogleIdentity google;
  final DriveStore store;
  final DeviceServices device;
  @override
  AccountConnection get connection => google.connection;
  @override
  Stream<AccountConnection> get connections => google.changes;
  @override
  String? get configurationError => google.configurationError;
  @override
  Future<void> initialize() => google.initialize();
  @override
  Future<String?> currentUser() async =>
      connection.driveReady ? connection.name ?? connection.email : null;
  @override
  Future<String> signIn() => google.authorize();
  @override
  Future<void> openOffline() async {
    final saved = await store.cache.lastAccount();
    if (saved == null ||
        await store.cache.json(saved['id'] as String, 'index') == null) {
      throw const VaultFailure(
        'No offline vault is available. Sign in online and browse files first.',
      );
    }
    // AppLockGate enforces the same device lock before painting this offline vault.
    google.useOffline(saved);
  }

  @override
  Future<void> signOut() async {
    final owner = google.owner;
    try {
      await google.signOut();
    } finally {
      try {
        if (owner != null) await store.cache.clear(owner);
      } finally {
        await store.cache.rememberAccount(null);
        await IncomingShare.instance.clear();
        await device.cancelReminders();
        await clearOpenedFiles();
      }
    }
  }

  @override
  Future<VaultPreferences> preferences() async {
    final owner = google.owner;
    if (owner == null) return const VaultPreferences();
    return store.api.guard(
      () async => (await store.preferences()).copyWith(
        biometric: await device.lockEnabled(owner),
      ),
    );
  }

  @override
  Future<void> savePreferences(VaultPreferences value) =>
      store.api.guard(() async {
        final owner = google.owner!;
        final payload = DriveCodec.preferences(value)..remove('biometric');
        await store.writeSetting('preferences', payload);
        store.api.verifyAccount();
        await device.setLockEnabled(owner, value.biometric);
        try {
          final docs = await store.documents();
          store.api.verifyAccount();
          await device.synchronize(docs, value, owner: owner);
        } catch (_) {
          /* Preference persisted; OS reminders can be retried. */
        }
      });

  @override
  Future<void> deleteMyData() => store.api.guard(() async {
    store.scope();
    final owner = google.owner!;
    final files = await store.api.list();
    // Only files tagged as Vaulty data in this app's appData space. Never empties Drive Trash.
    for (final f in files) {
      await store.api.delete(f['id']);
    }
    store.api.verifyAccount();
    await device.clearLock(owner);
    await signOut();
  });
}

class PickedDocument extends SelectedFile {
  const PickedDocument(super.name, super.kind, super.sizeBytes, this.bytes);
  final Uint8List bytes;
}

class DriveDocumentRepository
    implements LiveDocumentRepository, CachedDocumentRepository {
  DriveDocumentRepository(this.store, this.device);
  final DriveStore store;
  final DeviceServices device;
  static const maxFileBytes = 50 * 1024 * 1024;
  static const maxBackupBytes = 150 * 1024 * 1024;
  static String mime(FileKind kind) => FileValidation.mime(kind);
  @override
  bool get isOffline =>
      store.offline ||
      (store.api.identity is GoogleIdentity &&
          (store.api.identity as GoogleIdentity).connection.offline);
  @override
  Future<Map<String, DateTime>> browsed() => store.browsed();
  @override
  Future<void> markBrowsed(String id) => store.markBrowsed(id);
  @override
  Future<void> clearCache() => store.api.guard(() async {
    store.scope();
    await store.cache.clear(store.api.identity.owner!);
    await clearOpenedFiles();
  });
  @override
  bool get supportsDeviceFeatures => device.supported;
  Future<List<Document>> _list() async {
    final docs = await store.documents();
    try {
      final prefs = await store.preferences();
      store.api.verifyAccount();
      await device.synchronize(docs, prefs, owner: store.api.identity.owner);
    } catch (_) {
      /* Do not hide a successfully loaded vault over OS notification errors. */
    }
    return docs;
  }

  Future<SelectedFile?> _selectFile(FileSource source) async {
    Uint8List bytes;
    String name;
    if (source == FileSource.scan) {
      throw const VaultFailure(
        'Automatic scanning is not implemented. Use Camera to capture a document photo.',
      );
    }
    if (source == FileSource.files) {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: FileValidation.extensions,
        withData: true,
      );
      if (picked == null) return null;
      final f = picked.files.single;
      name = f.name;
      if (f.size > maxFileBytes) {
        throw const VaultFailure('Choose a file up to 50 MB.');
      }
      bytes = f.bytes ?? await picked.xFiles.single.readAsBytes();
    } else {
      final f = await ImagePicker().pickImage(
        source: source == FileSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
      );
      if (f == null) return null;
      if (await f.length() > maxFileBytes) {
        throw const VaultFailure('Choose an image up to 50 MB.');
      }
      bytes = await f.readAsBytes();
      name = f.name;
    }
    if (bytes.isEmpty || bytes.length > maxFileBytes) {
      throw const VaultFailure('Choose a non-empty file up to 50 MB.');
    }
    final kind = FileValidation.detect(bytes);
    return PickedDocument(
      FileValidation.safeName(name, kind),
      kind,
      bytes.length,
      bytes,
    );
  }

  Stream<double> _upload(Document document, SelectedFile file) async* {
    if (file is! PickedDocument) {
      throw const VaultFailure('Choose the file again before uploading.');
    }
    store.scope();
    await store.documents(purge: false);
    if (store.files.containsKey(document.id)) {
      final existing = store.files[document.id]!;
      if (int.tryParse('${existing['size']}') != file.sizeBytes) {
        throw const VaultFailure(
          'This upload has an incomplete or changed file in Drive. Refresh and inspect it before retrying.',
        );
      }
      yield 1;
      return;
    } // Lost final response; retry does not duplicate.
    final id = store.pendingUploads[document.id] ??=
        ((await store.api.generateId())['ids'] as List).first as String;
    final metadata = <String, dynamic>{
      'id': id,
      'name': DriveStore.fileName(document),
      'mimeType': mime(file.kind),
      'parents': ['appDataFolder'],
      'description': jsonEncode(DriveCodec.document(document)),
      'appProperties': {
        'vaultyApp': DriveApi.namespace,
        'kind': 'document',
        'logicalId': document.id,
      },
    };
    await for (final result in store.api.upload(
      id: id,
      metadata: metadata,
      bytes: file.bytes,
      mimeType: mime(file.kind),
    )) {
      if (result.$2 != null) store.files[document.id] = result.$2!;
      yield result.$1;
    }
    store.pendingUploads.remove(document.id);
    await store.persist();
    await store.cache.write(
      store.api.identity.owner!,
      'file:${document.id}',
      CachedFile.encode(
        '${store.files[document.id]?['version']}',
        DocumentBytes(
          DriveStore.fileName(document),
          mime(file.kind),
          file.bytes,
        ),
      ),
    );
    await _reminders();
  }

  Future<void> _save(Document d) async {
    await store.save(d);
    await store.log('Edited', d);
    await _reminders();
  }

  Future<void> _replace(String id, SelectedFile file) async {
    if (file is! PickedDocument) {
      throw const VaultFailure('Choose a file again.');
    }
    final record = await store.find(id);
    final old = DriveCodec.readDocument(
      DriveStore.description(record),
      int.parse(record['size'] ?? '0'),
    );
    final d = Document(
      id: old.id,
      title: old.title,
      belongsTo: old.belongsTo,
      kind: file.kind,
      uploadedAt: old.uploadedAt,
      modifiedAt: DateTime.now(),
      sizeBytes: file.sizeBytes,
      renewalRequired: old.renewalRequired,
      expiry: old.expiry,
      tags: old.tags,
    );
    final actual =
        jsonDecode((await store.api.metadata(record['id'])).body) as Json;
    if (actual['version'] != record['version']) {
      throw const VaultFailure(
        'This document changed on another device. Refresh first.',
      );
    }
    await for (final result in store.api.upload(
      id: record['id'],
      replace: true,
      metadata: {
        'name': DriveStore.fileName(d),
        'mimeType': mime(file.kind),
        'description': jsonEncode(DriveCodec.document(d)),
      },
      bytes: file.bytes,
      mimeType: mime(file.kind),
    )) {
      if (result.$2 != null) store.files[id] = result.$2!;
    }
    await store.invalidateFile(id);
    await store.persist();
    await _reminders();
  }

  Future<void> _change(Set<String> ids, bool restore) async {
    for (final id in ids) {
      final f = await store.find(id);
      final d = DriveCodec.readDocument(
        DriveStore.description(f),
        int.parse(f['size'] ?? '0'),
      );
      await store.save(
        restore
            ? d.copyWith(restore: true)
            : d.copyWith(deletedAt: DateTime.now()),
      );
      await store.log(restore ? 'Restored' : 'Moved to Trash', d);
    }
    await _reminders();
  }

  Future<void> _trash(Set<String> ids) => _change(ids, false);
  Future<void> _restore(Set<String> ids) => _change(ids, true);
  Future<void> _permanentlyDelete(String id) async {
    final f = await store.find(id);
    final d = DriveCodec.readDocument(
      DriveStore.description(f),
      int.parse(f['size'] ?? '0'),
    );
    if (!d.isDeleted) {
      throw const VaultFailure(
        'Move this document to Trash before permanently deleting it.',
      );
    }
    await store.api.delete(f['id']);
    store.files.remove(id);
    await store.invalidateFile(id);
    await store.persist();
  }

  final _reads = <(String, int, String), Future<DocumentBytes>>{};
  Future<DocumentBytes> _read(String id) async {
    store.scope();
    final key = (store.api.identity.owner!, store.api.identity.generation, id);
    if (_reads[key] != null) return _reads[key]!;
    final read = _readOnce(id);
    _reads[key] = read;
    try {
      return await read;
    } finally {
      _reads.remove(key);
    }
  }

  Future<DocumentBytes> _readOnce(String id) async {
    var f = await store.find(id);
    final owner = store.api.identity.owner!;
    bool offline = false;
    try {
      final latest =
          jsonDecode((await store.api.metadata(f['id'] as String)).body)
              as Json;
      store.api.verifyAccount();
      if (latest['version'] != f['version']) await store.invalidateFile(id);
      f = latest;
      store.files[id] = f;
      store.offline = false;
      await store.persist();
    } on DriveOfflineFailure {
      store.api.verifyAccount();
      offline = true;
      store.offline = true;
    } catch (_) {
      store.api.verifyAccount();
      await store.invalidateFile(id);
      rethrow;
    }
    final d = DriveCodec.readDocument(
      DriveStore.description(f),
      int.parse('${f['size'] ?? 0}'),
    );
    if (d.isDeleted) {
      await store.invalidateFile(id);
      throw const VaultFailure(
        'Restore this document before opening or sharing it.',
      );
    }
    final version = '${f['version']}';
    final saved = await store.cache.read(owner, 'file:$id');
    store.api.verifyAccount();
    final cached = saved == null
        ? null
        : CachedFile.decode(saved, version, offline: offline);
    if (cached != null) return cached;
    if (offline) {
      throw const VaultFailure(
        'This version is not cached. Reconnect to download it once.',
      );
    }
    final bytes = await store.api.download(f['id'] as String);
    // Recheck after downloading: never tag bytes from a concurrent replacement with an old version.
    final after =
        jsonDecode((await store.api.metadata(f['id'] as String)).body) as Json;
    if (after['version'] != f['version']) {
      throw const VaultFailure(
        'File changed while downloading. Please open it again.',
      );
    }
    store.api.verifyAccount();
    final content = DocumentBytes(
      DriveStore.fileName(d),
      f['mimeType'] as String? ?? mime(d.kind),
      bytes,
    );
    await store.cache.write(
      owner,
      'file:$id',
      CachedFile.encode(version, content),
    );
    store.api.verifyAccount();
    return content;
  }

  Future<void> _open(String id) async {
    final content = await read(id);
    store.api.verifyAccount();
    await openDocumentBytes(content, verifyAccount: store.api.verifyAccount);
    await store.markBrowsed(id);
  }

  Future<bool> _shareCopy(String id) async {
    final content = await read(id);
    store.api.verifyAccount();
    return shareDocumentBytes(content, verifyAccount: store.api.verifyAccount);
  }

  Future<void> _exportBackup() async {
    final docs = await store.documents(purge: false);
    if (docs.fold<int>(0, (s, d) => s + d.sizeBytes) > maxBackupBytes) {
      throw const VaultFailure(
        'This vault is too large for an in-memory backup (150 MB limit). Export individual files instead.',
      );
    }
    final archive = Archive();
    final manifest = utf8.encode(
      jsonEncode({
        'schema': 1,
        'documents': docs.map(DriveCodec.document).toList(),
        'preferences': DriveCodec.preferences(await store.preferences()),
        'recent': await store.readSetting('recent'),
        'savedSearches': (await store.api.list(
          kind: 'saved-search',
        )).map(DriveStore.description).toList(),
      }),
    );
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    for (final d in docs) {
      final f = await store.find(d.id);
      final bytes = await store.api.download(f['id']);
      archive.addFile(
        ArchiveFile(
          'files/${Uri.encodeComponent(d.id)}/${DriveStore.fileName(d)}',
          bytes.length,
          bytes,
        ),
      );
    }
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    store.api.verifyAccount();
    await FilePicker.platform.saveFile(
      fileName: 'Vaulty-backup.zip',
      dialogTitle: 'Save your Vaulty backup',
      type: FileType.custom,
      allowedExtensions: ['zip'],
      bytes: bytes,
    );
  }

  Future<void> _reminders() async {
    try {
      await syncReminders();
    } catch (_) {
      /* OS reminders do not roll back a completed Drive write. */
    }
  }

  @override
  Future<bool> enableReminders() => device.enableReminders();
  Future<void> _syncReminders() async {
    final docs = await store.documents(purge: false);
    final prefs = await store.preferences();
    store.api.verifyAccount();
    await device.synchronize(docs, prefs, owner: store.api.identity.owner);
  }

  @override
  Future<void> lockChallenge() => device.unlock();

  @override
  Future<List<Document>> list() => store.api.guard(_list);
  @override
  Future<SelectedFile?> selectFile(FileSource source) => _selectFile(source);
  @override
  Future<void> save(Document d) => store.api.guard(() => _save(d));
  @override
  Stream<double> upload(Document d, SelectedFile f) =>
      store.api.guardStream(() => _upload(d, f));
  @override
  Future<void> replace(String id, SelectedFile f) =>
      store.api.guard(() => _replace(id, f));
  @override
  Future<void> trash(Set<String> ids) => store.api.guard(() => _trash(ids));
  @override
  Future<void> restore(Set<String> ids) => store.api.guard(() => _restore(ids));
  @override
  Future<void> permanentlyDelete(String id) =>
      store.api.guard(() => _permanentlyDelete(id));
  @override
  Future<DocumentBytes> read(String id) => store.api.guard(() => _read(id));
  @override
  Future<void> open(String id) => store.api.guard(() => _open(id));
  @override
  Future<bool> shareCopy(String id) => store.api.guard(() => _shareCopy(id));
  @override
  Future<void> exportBackup() => store.api.guard(_exportBackup);
  @override
  Future<void> syncReminders() => store.api.guard(_syncReminders);
}

class DriveInsightsRepository implements InsightsRepository {
  DriveInsightsRepository(this.store);
  final DriveStore store;
  @override
  Future<StorageInfo> storage() => store.api.guard(_storage);
  Future<StorageInfo> _storage() async {
    store.scope();
    try {
      return await _onlineStorage();
    } on DriveOfflineFailure {
      store.api.verifyAccount();
      final q =
          await store.cache.json(store.api.identity.owner!, 'quota') as Json?;
      if (q == null) rethrow;
      return StorageInfo(
        totalBytes: q['total'],
        otherBytes: q['other'],
        vaultBytes: q['vault'],
        reportedUsedBytes: q['used'],
        cachedAt: DateTime.parse(q['at']),
      );
    }
  }

  Future<StorageInfo> _onlineStorage() async {
    final about =
        jsonDecode(
              (await store.api.request(
                'GET',
                store.api.uri('about', {'fields': 'storageQuota'}),
              )).body,
            )
            as Json;
    final q = about['storageQuota'] as Json? ?? {};
    final limit = int.tryParse('${q['limit']}');
    final used = int.tryParse('${q['usage']}');
    if (used == null) {
      throw const VaultFailure(
        'Google did not return storage usage for this account.',
      );
    }
    final files = await store.api.list();
    final vault = files.fold<int>(
      0,
      (n, f) => n + (int.tryParse('${f['size']}') ?? 0),
    );
    await store.cache.putJson(store.api.identity.owner!, 'quota', {
      'total': limit,
      'other': (used - vault).clamp(0, used),
      'vault': vault,
      'used': used,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    return StorageInfo(
      totalBytes: limit,
      reportedUsedBytes: used,
      otherBytes: (used - vault).clamp(0, used),
      vaultBytes: vault,
    );
  }

  @override
  Future<List<AuditEvent>> activity() async =>
      (await store.events()).take(10).toList();
  @override
  Future<List<AuditEvent>> audit({String? documentId}) =>
      store.events(documentId: documentId);
}

class PrivateShareRepository implements ShareRepository {
  @override
  Future<List<ShareRecord>> list() async => [];
  @override
  Future<void> create(ShareRecord record) async => throw const VaultFailure(
    'Hidden Drive files do not support access-controlled sharing. Share a copy instead.',
  );
  @override
  Future<void> revoke(String id) async =>
      throw const VaultFailure('Copies already exported cannot be revoked.');
}

class DriveSearchRepository implements SearchRepository {
  DriveSearchRepository(this.store);
  final DriveStore store;
  @override
  Future<List<Document>> search(String query, SearchFilter filter) async {
    final q = query.trim().toLowerCase();
    bool within(DateTime? value, DateTime? from, DateTime? to) =>
        (from == null && to == null) ||
        (value != null &&
            (from == null || !value.isBefore(from)) &&
            (to == null || value.isBefore(to.add(const Duration(days: 1)))));
    final result = (await store.documents(purge: false))
        .where(
          (d) =>
              !d.isDeleted &&
              (q.isEmpty ||
                  '${d.title} ${d.belongsTo} ${d.tags.join(' ')}'
                      .toLowerCase()
                      .contains(q)) &&
              (filter.kind == null || d.kind == filter.kind) &&
              (filter.belongsTo == null || d.belongsTo == filter.belongsTo) &&
              (filter.renewal == null || d.renewalRequired == filter.renewal) &&
              filter.shared != true &&
              (filter.minBytes == null || d.sizeBytes >= filter.minBytes!) &&
              (filter.maxBytes == null || d.sizeBytes <= filter.maxBytes!) &&
              filter.tags.every((t) => d.tags.contains(t.toLowerCase())) &&
              within(d.uploadedAt, filter.uploadFrom, filter.uploadTo) &&
              within(d.expiry, filter.expiryFrom, filter.expiryTo),
        )
        .toList();
    result.sort(switch (filter.sort) {
      DocumentSort.newest => (a, b) => b.uploadedAt.compareTo(a.uploadedAt),
      DocumentSort.title => (a, b) => a.title.compareTo(b.title),
      DocumentSort.expiry => (a, b) => (a.expiry ?? DateTime(9999)).compareTo(
        b.expiry ?? DateTime(9999),
      ),
      DocumentSort.size => (a, b) => b.sizeBytes.compareTo(a.sizeBytes),
    });
    return result;
  }

  @override
  Future<List<String>> recent() async =>
      ((await store.readSetting('recent'))['queries'] as List? ?? [])
          .cast<String>();
  @override
  Future<void> remember(String query) =>
      store.api.guard(() => _remember(query));
  Future<void> _remember(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final old = await recent();
    await store.writeSetting('recent', {
      'queries': [q, ...old.where((s) => s != q)].take(6).toList(),
    });
  }

  @override
  Future<List<SavedSearch>> saved() async =>
      (await store.api.list(kind: 'saved-search')).map((f) {
        final j = DriveStore.description(f);
        return SavedSearch(
          j['name'],
          j['query'],
          DriveCodec.readFilter(j['filter'] as Json),
        );
      }).toList();
  @override
  Future<void> save(SavedSearch search) => store.api.guard(() => _save(search));
  Future<void> _save(SavedSearch search) async {
    final files = await store.api.list(kind: 'saved-search');
    final old = files
        .where((f) => DriveStore.description(f)['name'] == search.name)
        .firstOrNull;
    final j = {
      'name': search.name,
      'query': search.query,
      'filter': DriveCodec.filter(search.filter),
    };
    if (old == null) {
      await store.api.createJson('vaulty.search.json', 'saved-search', j);
    } else {
      await store.api.patch(old, {'description': jsonEncode(j)});
    }
  }
}
