enum FileKind { pdf, jpg, docx, png, webp, gif, heic }

extension FileKindInfo on FileKind {
  bool get isImage => this != FileKind.pdf && this != FileKind.docx;
}

class Document {
  const Document({
    required this.id,
    required this.title,
    required this.belongsTo,
    required this.kind,
    required this.uploadedAt,
    required this.sizeBytes,
    this.modifiedAt,
    this.expiry,
    this.renewalRequired = false,
    this.tags = const [],
    this.deletedAt,
  });
  final String id, title, belongsTo;
  final FileKind kind;
  final DateTime uploadedAt;
  final int sizeBytes;
  final DateTime? expiry, deletedAt, modifiedAt;
  final bool renewalRequired;
  final List<String> tags;
  bool get isDeleted => deletedAt != null;
  int? daysUntil(DateTime now) => expiry == null
      ? null
      : DateTime.utc(
          expiry!.year,
          expiry!.month,
          expiry!.day,
        ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  Document copyWith({
    DateTime? modifiedAt,
    String? title,
    String? belongsTo,
    DateTime? expiry,
    bool? renewalRequired,
    DateTime? deletedAt,
    bool restore = false,
    DateTime? uploadedAt,
    List<String>? tags,
  }) => Document(
    id: id,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    title: title ?? this.title,
    belongsTo: belongsTo ?? this.belongsTo,
    kind: kind,
    uploadedAt: uploadedAt ?? this.uploadedAt,
    sizeBytes: sizeBytes,
    expiry: (renewalRequired ?? this.renewalRequired)
        ? expiry ?? this.expiry
        : null,
    renewalRequired: renewalRequired ?? this.renewalRequired,
    tags: tags ?? this.tags,
    deletedAt: restore ? null : deletedAt ?? this.deletedAt,
  );
}
