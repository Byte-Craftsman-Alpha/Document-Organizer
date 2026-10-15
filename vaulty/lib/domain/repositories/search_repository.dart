import '../models/document.dart';
import '../models/search_filter.dart';

abstract interface class SearchRepository {
  Future<List<Document>> search(String query, SearchFilter filter);
  Future<List<String>> recent();
  Future<void> remember(String query);
  Future<List<SavedSearch>> saved();
  Future<void> save(SavedSearch search);
}
