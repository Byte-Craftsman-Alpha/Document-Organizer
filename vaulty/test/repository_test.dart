import 'package:flutter_test/flutter_test.dart';
import 'package:vaulty/data/mock/mock_repositories.dart';
import 'package:vaulty/domain/models/search_filter.dart';
import 'package:vaulty/domain/models/document.dart';

void main() {
  test('40 seeds cover files, owners, expiration and Trash', () {
    final docs = MockStore().documents;
    expect(docs.length, 40);
    expect(docs.map((d) => d.kind).toSet().length, 3);
    expect(docs.map((d) => d.belongsTo).toSet().length, 6);
    expect(docs.where((d) => d.isDeleted).length, 2);
    expect(docs.any((d) => (d.daysUntil(DateTime.now()) ?? 999) < 0), isTrue);
    expect(docs.any((d) => d.expiry == null), isTrue);
  });
  test('Search honors combined constraints and excludes Trash', () async {
    final store = MockStore();
    final repo = MockSearchRepository(store);
    final docs = await repo.search(
      '',
      const SearchFilter(
        kind: FileKind.pdf,
        renewal: true,
        minBytes: 1000000,
        maxBytes: 7000000,
        tags: ['renewal'],
        sort: DocumentSort.size,
      ),
    );
    expect(docs, isNotEmpty);
    for (final d in docs) {
      expect(d.kind, FileKind.pdf);
      expect(d.renewalRequired, isTrue);
      expect(d.isDeleted, isFalse);
    }
    final shared = await repo.search('', const SearchFilter(shared: true));
    expect(shared.length, 4);
    expect(
      (await repo.search('not a real file', const SearchFilter())).isEmpty,
      isTrue,
    );
  });
  test(
    'Trash revokes shares; restore does not reopen access; purge is guarded',
    () async {
      final store = MockStore();
      final repo = MockDocumentRepository(store);
      await repo.trash({'doc-1'});
      expect(store.documents.first.isDeleted, isTrue);
      expect(store.shares.first.revoked, isTrue);
      await repo.restore({'doc-1'});
      expect(store.documents.first.isDeleted, isFalse);
      expect(store.shares.first.revoked, isTrue);
      await expectLater(repo.permanentlyDelete('doc-1'), throwsStateError);
      await repo.trash({'doc-1'});
      await repo.permanentlyDelete('doc-1');
      expect(store.documents.any((d) => d.id == 'doc-1'), isFalse);
    },
  );
  test('Error scenario fails once per endpoint, then retry succeeds', () async {
    final repo = MockDocumentRepository(
      MockStore(scenario: MockScenario.error),
    );
    await expectLater(repo.list(), throwsStateError);
    expect((await repo.list()).length, 40);
  });
  test('Disabling renewal clears expiry', () {
    final doc = MockStore().documents.firstWhere((d) => d.renewalRequired);
    expect(doc.copyWith(renewalRequired: false).expiry, isNull);
  });
}
