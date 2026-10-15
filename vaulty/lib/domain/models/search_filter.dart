import 'document.dart';

enum DocumentSort { newest, title, expiry, size }

class SearchFilter {
  const SearchFilter({
    this.kind,
    this.belongsTo,
    this.uploadFrom,
    this.uploadTo,
    this.expiryFrom,
    this.expiryTo,
    this.renewal,
    this.shared,
    this.minBytes,
    this.maxBytes,
    this.tags = const [],
    this.sort = DocumentSort.newest,
  });
  final FileKind? kind;
  final String? belongsTo;
  final DateTime? uploadFrom, uploadTo, expiryFrom, expiryTo;
  final bool? renewal, shared;
  final int? minBytes, maxBytes;
  final List<String> tags;
  final DocumentSort sort;
  Map<String, String> get labels => {
    if (kind != null) 'kind': kind!.name.toUpperCase(),
    'owner': ?belongsTo,
    if (uploadFrom != null || uploadTo != null) 'upload': 'Upload dates',
    if (expiryFrom != null || expiryTo != null) 'expiry': 'Expiry dates',
    if (renewal != null) 'renewal': renewal! ? 'Needs renewal' : 'No renewal',
    if (shared != null) 'shared': shared! ? 'Shared' : 'Not shared',
    if (minBytes != null || maxBytes != null) 'size': 'Size range',
    if (tags.isNotEmpty) 'tags': tags.join(', '),
    if (sort != DocumentSort.newest) 'sort': 'Sort: ${sort.name}',
  };
  SearchFilter without(String key) => SearchFilter(
    kind: key == 'kind' ? null : kind,
    belongsTo: key == 'owner' ? null : belongsTo,
    uploadFrom: key == 'upload' ? null : uploadFrom,
    uploadTo: key == 'upload' ? null : uploadTo,
    expiryFrom: key == 'expiry' ? null : expiryFrom,
    expiryTo: key == 'expiry' ? null : expiryTo,
    renewal: key == 'renewal' ? null : renewal,
    shared: key == 'shared' ? null : shared,
    minBytes: key == 'size' ? null : minBytes,
    maxBytes: key == 'size' ? null : maxBytes,
    tags: key == 'tags' ? [] : tags,
    sort: key == 'sort' ? DocumentSort.newest : sort,
  );
}

class SavedSearch {
  const SavedSearch(this.name, this.query, this.filter);
  final String name, query;
  final SearchFilter filter;
}
