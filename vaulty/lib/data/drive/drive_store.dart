import 'dart:convert';
import '../../domain/models/document.dart';
import '../../domain/models/audit_event.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/live_capabilities.dart';
import 'drive_api.dart';
import 'drive_codec.dart';
import '../cache/vault_cache.dart';
import 'google_identity.dart';

class DriveStore {
  DriveStore(this.api, {VaultCache? cache})
    : cache = cache ?? MemoryVaultCache();
  final VaultCache cache;
  bool offline = false;
  final DriveApi api;
  final Map<String, Json> files = {};
  final Map<String, String> pendingUploads = {};
  String? _owner;
  int? _generation;
  String? activityWarning;
  void scope() {
    if (_owner != api.identity.owner ||
        _generation != api.identity.generation) {
      offline = false;
      files.clear();
      pendingUploads.clear();
      activityWarning = null;
      _owner = api.identity.owner;
      _generation = api.identity.generation;
    }
    if (_owner == null) {
      throw const VaultFailure('Connect Google Drive to open your vault.');
    }
  }

  static Json description(Json file) {
    final value = jsonDecode(file['description'] as String? ?? '{}');
    if (value is! Json) {
      throw const VaultFailure(
        'A vault metadata record could not be read. No files were changed.',
      );
    }
    return value;
  }

  Future<List<Document>> documents({bool purge = true}) =>
      api.guard(() => _documents(purge: purge));
  Future<List<Document>> _documents({bool purge = true}) async {
    scope();
    late List<Json> list;
    try {
      list = await api.list(kind: 'document');
      offline = false;
    } on DriveOfflineFailure {
      api.verifyAccount();
      final saved = await cache.json(_owner!, 'index');
      api.verifyAccount();
      if (saved == null) rethrow;
      list = (saved as List).cast<Json>();
      offline = true;
    }
    final docs = <Document>[];
    final entries = <String, Json>{};
    for (final f in list) {
      Document d;
      try {
        d = DriveCodec.readDocument(
          description(f),
          int.tryParse('${f['size']}') ?? 0,
        );
      } catch (_) {
        throw const VaultFailure(
          'A document has unsupported or damaged metadata. No files were overwritten.',
        );
      }
      if (!offline &&
          purge &&
          d.deletedAt != null &&
          DateTime.now().difference(d.deletedAt!).inDays >= 30) {
        await api.delete(f['id']);
        await cache.remove(_owner!, 'file:${d.id}');
        continue;
      }
      entries[d.id] = f;
      docs.add(d);
    }
    if (!offline) {
      final previous = await cache.json(_owner!, 'index') as List? ?? [];
      api.verifyAccount();
      for (final old in previous.cast<Json>()) {
        final id = description(old)['id'] as String;
        if (entries[id] == null ||
            entries[id]!['version'] != old['version'] ||
            description(entries[id]!)['deletedAt'] != null) {
          await cache.remove(_owner!, 'file:$id');
        }
      }
    }
    api.verifyAccount();
    files
      ..clear()
      ..addAll(entries);
    if (!offline) await persist();
    docs.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return docs;
  }

  Future<Json> find(String logicalId) async {
    scope();
    if (!files.containsKey(logicalId)) await documents(purge: false);
    final f = files[logicalId];
    if (f == null) {
      throw const VaultFailure(
        'This document is no longer in your vault. Refresh to see the latest files.',
      );
    }
    return f;
  }

  Future<void> save(Document d) async {
    final old = await find(d.id);
    files[d.id] = await api.patch(old, {
      'name': fileName(d),
      'description': jsonEncode(
        DriveCodec.document(d.copyWith(modifiedAt: DateTime.now())),
      ),
    });
    await invalidateFile(d.id);
    await persist();
  }

  static String fileName(Document d) =>
      '${d.title.replaceAll(RegExp(r"[^a-zA-Z0-9._ -]"), '_').trim().replaceAll(RegExp(r'\.(pdf|jpg|jpeg|docx|png|webp|gif|heic)$', caseSensitive: false), '')}.${d.kind.name}';
  Future<Json?> record(String kind) async {
    scope();
    final list = await api.list(kind: kind);
    list.sort(
      (a, b) => '${b['modifiedTime']}'.compareTo('${a['modifiedTime']}'),
    );
    return list.firstOrNull;
  }

  Future<Json> readSetting(String kind) async {
    scope();
    try {
      final r = await record(kind);
      final value = r == null ? <String, dynamic>{} : description(r);
      api.verifyAccount();
      await cache.putJson(_owner!, 'setting:$kind', value);
      return value;
    } on DriveOfflineFailure {
      api.verifyAccount();
      return (await cache.json(_owner!, 'setting:$kind') as Json?) ?? {};
    }
  }

  Future<void> writeSetting(String kind, Json data) =>
      api.guard(() => _writeSetting(kind, data));
  Future<void> _writeSetting(String kind, Json data) async {
    final r = await record(kind);
    if (r == null) {
      await api.createJson('vaulty.$kind.json', kind, data);
    } else {
      await api.patch(r, {'description': jsonEncode(data)});
    }
    api.verifyAccount();
    await cache.putJson(_owner!, 'setting:$kind', data);
  }

  Future<VaultPreferences> preferences() async =>
      DriveCodec.readPreferences(await readSetting('preferences'));
  Future<void> log(String event, Document doc) async {}
  Future<List<AuditEvent>> events({String? documentId}) async => [];

  Future<void> invalidateFile(String id) async {
    api.verifyAccount();
    await cache.remove(_owner!, 'file:$id');
  }

  Future<void> persist() async {
    api.verifyAccount();
    final owner = _owner!;
    await cache.putJson(owner, 'index', files.values.toList());
    api.verifyAccount();
    final identity = api.identity;
    if (identity is GoogleIdentity && !identity.connection.offline) {
      await cache.rememberAccount({
        'id': owner,
        'name': identity.connection.name,
        'email': identity.connection.email,
      });
    }
  }

  Future<Map<String, DateTime>> browsed() => api.guard(() async {
    scope();
    final saved = await cache.json(_owner!, 'browsed') as Json? ?? {};
    api.verifyAccount();
    return saved.map((k, v) => MapEntry(k, DateTime.parse(v as String)));
  });
  Future<void> markBrowsed(String id) => api.guard(() async {
    scope();
    final values = await browsed();
    api.verifyAccount();
    values[id] = DateTime.now();
    final sorted = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    await cache.putJson(_owner!, 'browsed', {
      for (final e in sorted.take(100))
        e.key: e.value.toUtc().toIso8601String(),
    });
  });
}
