import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/document.dart';
import '../../../domain/models/search_filter.dart';
import 'document_providers.dart';

final quickQueryProvider = StateProvider<String>((ref) => '');
final quickTypeProvider = StateProvider<FileKind?>((ref) => null);
final quickSortProvider = StateProvider<DocumentSort>(
  (ref) => DocumentSort.newest,
);
final visibleDocumentsProvider = Provider<AsyncValue<List<Document>>>((ref) {
  final query = ref.watch(quickQueryProvider).toLowerCase();
  final type = ref.watch(quickTypeProvider),
      sort = ref.watch(quickSortProvider);
  return ref.watch(documentsProvider).whenData((docs) {
    final list = docs
        .where(
          (d) =>
              !d.isDeleted &&
              (type == null || type == d.kind) &&
              '${d.title} ${d.belongsTo}'.toLowerCase().contains(query),
        )
        .toList();
    list.sort(switch (sort) {
      DocumentSort.newest => (a, b) => b.uploadedAt.compareTo(a.uploadedAt),
      DocumentSort.title => (a, b) => a.title.compareTo(b.title),
      DocumentSort.expiry => (a, b) => (a.expiry ?? DateTime(9999)).compareTo(
        b.expiry ?? DateTime(9999),
      ),
      DocumentSort.size => (a, b) => b.sizeBytes.compareTo(a.sizeBytes),
    });
    return list;
  });
});
