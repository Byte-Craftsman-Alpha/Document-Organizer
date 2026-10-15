import 'dart:math';
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
import 'seed_data.dart';

enum MockScenario { normal, empty, error }

class MockStore {
  MockStore({this.scenario = MockScenario.normal}) {
    final now = DateTime.now();
    documents = scenario == MockScenario.empty ? [] : seedDocuments(now);
    shares = documents.isEmpty ? [] : seedShares(documents, now);
    events = documents.isEmpty ? [] : seedEvents(documents, now);
  }
  final MockScenario scenario;
  final random = Random(7);
  final failed = <String>{};
  late List<Document> documents;
  late List<ShareRecord> shares;
  late List<AuditEvent> events;
  final recentSearches = <String>[];
  final savedSearches = <SavedSearch>[];
  String? user;
  VaultPreferences prefs = const VaultPreferences();
  Future<void> delay(String operation) async {
    await Future<void>.delayed(
      Duration(milliseconds: 300 + random.nextInt(501)),
    );
    if (scenario == MockScenario.error && !failed.contains(operation)) {
      failed.add(operation);
      throw StateError('Simulated $operation failure. Retry succeeds.');
    }
  }

  void log(String event, Document doc) => events.insert(
    0,
    AuditEvent(
      id: 'event-${DateTime.now().microsecondsSinceEpoch}',
      event: event,
      documentTitle: doc.title,
      documentId: doc.id,
      actor: 'You',
      at: DateTime.now(),
    ),
  );
}

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this.store);
  final MockStore store;
  @override
  Future<String?> currentUser() async => store.user;
  @override
  Future<String> signIn() async {
    await store.delay('sign-in');
    return store.user = 'Ananya Sharma';
  }

  @override
  Future<void> signOut() async {
    await store.delay('sign-out');
    store.user = null;
  }

  @override
  Future<VaultPreferences> preferences() async => store.prefs;
  @override
  Future<void> savePreferences(VaultPreferences value) async {
    await store.delay('preferences');
    store.prefs = value;
  }

  @override
  Future<void> deleteMyData() async {
    await store.delay('delete-data');
    store.documents.clear();
    store.shares.clear();
    store.events.clear();
    store.recentSearches.clear();
    store.savedSearches.clear();
    store.user = null;
    store.prefs = const VaultPreferences();
  }
}

class MockDocumentRepository implements DocumentRepository {
  MockDocumentRepository(this.store);
  final MockStore store;
  @override
  Future<List<Document>> list() async {
    await store.delay('documents');
    return List.unmodifiable(store.documents);
  }

  @override
  Future<SelectedFile?> selectFile(FileSource source) async {
    await store.delay('select-file');
    return SelectedFile(
      switch (source) {
        FileSource.files => 'insurance-policy.pdf',
        FileSource.gallery => 'document-photo.jpg',
        FileSource.camera => 'camera-capture.jpg',
        FileSource.scan => 'scanned-document.pdf',
      },
      source == FileSource.gallery || source == FileSource.camera
          ? FileKind.jpg
          : FileKind.pdf,
      2400000,
    );
  }

  @override
  Future<void> save(Document document) async {
    await store.delay('save');
    final i = store.documents.indexWhere((d) => d.id == document.id);
    if (i < 0) {
      store.documents.insert(0, document);
    } else {
      store.documents[i] = document;
    }
    store.log(i < 0 ? 'Uploaded' : 'Edited', document);
  }

  @override
  Stream<double> upload(Document document, SelectedFile file) async* {
    for (var i = 1; i <= 4; i++) {
      await store.delay('upload');
      yield i / 5;
    }
    await save(document);
    yield 1;
  }

  @override
  Future<void> replace(String id, SelectedFile file) async {
    await store.delay('replace');
    final i = store.documents.indexWhere((d) => d.id == id);
    final old = store.documents[i];
    store.documents[i] = Document(
      id: old.id,
      title: old.title,
      belongsTo: old.belongsTo,
      kind: file.kind,
      sizeBytes: file.sizeBytes,
      uploadedAt: DateTime.now(),
      renewalRequired: old.renewalRequired,
      expiry: old.expiry,
      tags: old.tags,
    );
    store.log('File replaced', old);
  }

  @override
  Future<void> trash(Set<String> ids) async {
    await store.delay('trash');
    store.documents = store.documents.map((d) {
      if (!ids.contains(d.id)) return d;
      store.log('Moved to Trash', d);
      return d.copyWith(deletedAt: DateTime.now());
    }).toList();
    // Trash also revokes access; restoring never silently reopens a share.
    store.shares = store.shares
        .map((s) => ids.contains(s.documentId) ? s.revoke() : s)
        .toList();
  }

  @override
  Future<void> restore(Set<String> ids) async {
    await store.delay('restore');
    store.documents = store.documents.map((d) {
      if (!ids.contains(d.id)) return d;
      store.log('Restored', d);
      return d.copyWith(restore: true);
    }).toList();
  }

  @override
  Future<void> permanentlyDelete(String id) async {
    await store.delay('permanent-delete');
    final doc = store.documents.firstWhere((d) => d.id == id);
    if (!doc.isDeleted) {
      throw StateError('Only trashed documents can be purged.');
    }
    store.log('Permanently deleted', doc);
    store.documents.removeWhere((d) => d.id == id);
    store.shares.removeWhere((s) => s.documentId == id);
  }

  @override
  Future<void> exportBackup() async {
    await store.delay('export');
  }
}

class MockShareRepository implements ShareRepository {
  MockShareRepository(this.store);
  final MockStore store;
  @override
  Future<List<ShareRecord>> list() async {
    await store.delay('shares');
    return List.unmodifiable(store.shares);
  }

  @override
  Future<void> create(ShareRecord record) async {
    await store.delay('share');
    store.shares.insert(0, record);
    store.log(
      'Shared with ${record.recipients.join(', ')}',
      store.documents.firstWhere((d) => d.id == record.documentId),
    );
  }

  @override
  Future<void> revoke(String id) async {
    await store.delay('revoke');
    final i = store.shares.indexWhere((s) => s.id == id);
    store.shares[i] = store.shares[i].revoke();
    store.log(
      'Share revoked',
      store.documents.firstWhere((d) => d.id == store.shares[i].documentId),
    );
  }
}

class MockInsightsRepository implements InsightsRepository {
  MockInsightsRepository(this.store);
  final MockStore store;
  @override
  Future<StorageInfo> storage() async {
    await store.delay('storage');
    return StorageInfo(
      totalBytes: 15000000000,
      otherBytes: 8200000000,
      vaultBytes: store.documents.fold(0, (sum, d) => sum + d.sizeBytes),
    );
  }

  @override
  Future<List<AuditEvent>> activity() async {
    await store.delay('activity');
    return List.unmodifiable(store.events.take(10));
  }

  @override
  Future<List<AuditEvent>> audit({String? documentId}) async {
    await store.delay('audit-${documentId ?? 'all'}');
    return List.unmodifiable(
      store.events.where(
        (e) => documentId == null || e.documentId == documentId,
      ),
    );
  }
}

class MockSearchRepository implements SearchRepository {
  MockSearchRepository(this.store);
  final MockStore store;
  @override
  Future<List<Document>> search(String query, SearchFilter filter) async {
    await store.delay('search');
    final q = query.trim().toLowerCase();
    final now = DateTime.now();
    final sharedIds = store.shares
        .where((s) => s.status(now) == 'Active')
        .map((s) => s.documentId)
        .toSet();
    bool within(DateTime? value, DateTime? from, DateTime? to) =>
        (from == null && to == null) ||
        (value != null &&
            (from == null || !value.isBefore(from)) &&
            (to == null || value.isBefore(to.add(const Duration(days: 1)))));
    final result = store.documents
        .where(
          (d) =>
              !d.isDeleted &&
              (q.isEmpty ||
                  '${d.title} ${d.belongsTo} ${d.tags.join(' ')}'
                      .toLowerCase()
                      .contains(q)) &&
              (filter.kind == null || filter.kind == d.kind) &&
              (filter.belongsTo == null || filter.belongsTo == d.belongsTo) &&
              (filter.renewal == null || filter.renewal == d.renewalRequired) &&
              (filter.shared == null ||
                  filter.shared == sharedIds.contains(d.id)) &&
              (filter.minBytes == null || d.sizeBytes >= filter.minBytes!) &&
              (filter.maxBytes == null || d.sizeBytes <= filter.maxBytes!) &&
              filter.tags.every((tag) => d.tags.contains(tag.toLowerCase())) &&
              within(d.uploadedAt, filter.uploadFrom, filter.uploadTo) &&
              within(d.expiry, filter.expiryFrom, filter.expiryTo),
        )
        .toList();
    result.sort(switch (filter.sort) {
      DocumentSort.newest => (a, b) => b.uploadedAt.compareTo(a.uploadedAt),
      DocumentSort.title => (a, b) => a.title.compareTo(b.title),
      DocumentSort.size => (a, b) => b.sizeBytes.compareTo(a.sizeBytes),
      DocumentSort.expiry => (a, b) => (a.expiry ?? DateTime(9999)).compareTo(
        b.expiry ?? DateTime(9999),
      ),
    });
    return result;
  }

  @override
  Future<List<String>> recent() async {
    await store.delay('recent');
    return List.unmodifiable(store.recentSearches);
  }

  @override
  Future<void> remember(String query) async {
    if (query.trim().isEmpty) return;
    store.recentSearches.remove(query);
    store.recentSearches.insert(0, query);
    if (store.recentSearches.length > 6) store.recentSearches.removeLast();
  }

  @override
  Future<List<SavedSearch>> saved() async {
    await store.delay('saved-searches');
    return List.unmodifiable(store.savedSearches);
  }

  @override
  Future<void> save(SavedSearch search) async {
    await store.delay('save-search');
    store.savedSearches.removeWhere((s) => s.name == search.name);
    store.savedSearches.add(search);
  }
}
