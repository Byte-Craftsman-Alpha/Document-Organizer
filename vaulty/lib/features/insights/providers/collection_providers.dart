import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/document.dart';
import '../../documents/providers/document_providers.dart';

class CollectionSummary {
  CollectionSummary(List<Document> docs) {
    final active = docs.where((d) => !d.isDeleted).toList();
    total = active.length;
    for (final d in active) {
      owners.update(d.belongsTo, (n) => n + 1, ifAbsent: () => 1);
      kinds.update(d.kind, (n) => n + 1, ifAbsent: () => 1);
    }
    attention =
        active
            .where(
              (d) => d.expiry != null && d.daysUntil(DateTime.now())! <= 30,
            )
            .toList()
          ..sort((a, b) => a.expiry!.compareTo(b.expiry!));
  }
  late final int total;
  final owners = <String, int>{};
  final kinds = <FileKind, int>{};
  late final List<Document> attention;
}

final collectionProvider = Provider(
  (ref) => ref.watch(documentsProvider).whenData(CollectionSummary.new),
);
