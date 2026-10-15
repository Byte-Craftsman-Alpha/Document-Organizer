import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/bootstrap.dart';
import '../../../domain/models/search_filter.dart';
import '../../documents/providers/document_providers.dart';
import '../../share/providers/share_providers.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');
final searchFilterProvider = StateProvider<SearchFilter>(
  (ref) => const SearchFilter(),
);
final searchResultsProvider = FutureProvider((ref) {
  ref.watch(documentsProvider);
  ref.watch(sharesProvider);
  return ref
      .watch(searchRepositoryProvider)
      .search(ref.watch(searchQueryProvider), ref.watch(searchFilterProvider));
});
final recentSearchesProvider = FutureProvider((ref) {
  ref.watch(vaultIdentityProvider);
  return ref.watch(searchRepositoryProvider).recent();
});
final savedSearchesProvider = FutureProvider((ref) {
  ref.watch(vaultIdentityProvider);
  return ref.watch(searchRepositoryProvider).saved();
});
final ownerSuggestionsProvider = Provider(
  (ref) =>
      (ref.watch(documentsProvider).valueOrNull ?? [])
          .where((d) => !d.isDeleted)
          .map((d) => d.belongsTo)
          .toSet()
          .toList()
        ..sort(),
);
