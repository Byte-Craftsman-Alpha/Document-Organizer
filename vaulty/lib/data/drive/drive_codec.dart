import '../../domain/models/document.dart';
import '../../domain/models/search_filter.dart';
import '../../domain/models/audit_event.dart';
import '../../domain/repositories/auth_repository.dart';

typedef Json = Map<String, dynamic>;

abstract final class DriveCodec {
  static String? day(DateTime? d) => d?.toIso8601String().substring(0, 10);
  static DateTime? date(dynamic d) =>
      d is String ? DateTime.tryParse(d)?.toLocal() : null;
  static Json document(Document d) => {
    'schema': 1,
    'id': d.id,
    'title': d.title,
    'belongsTo': d.belongsTo,
    'kind': d.kind.name,
    'modifiedAt': d.modifiedAt?.toUtc().toIso8601String(),
    'uploadedAt': d.uploadedAt.toUtc().toIso8601String(),
    'renewalRequired': d.renewalRequired,
    'expiry': day(d.expiry),
    'tags': d.tags,
    'deletedAt': d.deletedAt?.toUtc().toIso8601String(),
  };
  static Document readDocument(Json json, int actualBytes) => Document(
    id: json['id'] as String,
    title: json['title'] as String,
    belongsTo: json['belongsTo'] as String,
    kind: FileKind.values.byName(json['kind'] as String),
    sizeBytes: actualBytes,
    uploadedAt: date(json['uploadedAt'])!,
    modifiedAt: date(json['modifiedAt']),
    renewalRequired: json['renewalRequired'] == true,
    expiry: date(json['expiry']),
    deletedAt: date(json['deletedAt']),
    tags: (json['tags'] as List? ?? []).cast<String>(),
  );
  static Json preferences(VaultPreferences p) => {
    'theme': p.theme,
    'biometric': p.biometric,
    'reminderDays': p.reminderDays,
    'noticeSeen': p.noticeSeen,
    'remindersEnabled': p.remindersEnabled,
  };
  static VaultPreferences readPreferences(Json j) => VaultPreferences(
    theme: j['theme'] as String? ?? 'system',
    biometric: j['biometric'] == true,
    reminderDays: const [7, 14, 30].contains(j['reminderDays'])
        ? (j['reminderDays'] as num).toInt()
        : 30,
    noticeSeen: j['noticeSeen'] == true,
    remindersEnabled: j['remindersEnabled'] == true,
  );
  static Json event(AuditEvent e) => {
    'id': e.id,
    'event': e.event,
    'documentTitle': e.documentTitle,
    'documentId': e.documentId,
    'actor': e.actor,
    'at': e.at.toUtc().toIso8601String(),
  };
  static AuditEvent readEvent(Json j) => AuditEvent(
    id: j['id'],
    event: j['event'],
    documentTitle: j['documentTitle'],
    documentId: j['documentId'],
    actor: j['actor'],
    at: date(j['at'])!,
  );
  static Json filter(SearchFilter f) => {
    'kind': f.kind?.name,
    'owner': f.belongsTo,
    'renewal': f.renewal,
    'uploadFrom': day(f.uploadFrom),
    'uploadTo': day(f.uploadTo),
    'expiryFrom': day(f.expiryFrom),
    'expiryTo': day(f.expiryTo),
    'shared': f.shared,
    'min': f.minBytes,
    'max': f.maxBytes,
    'tags': f.tags,
    'sort': f.sort.name,
  };
  static SearchFilter readFilter(Json j) => SearchFilter(
    kind: j['kind'] == null ? null : FileKind.values.byName(j['kind']),
    belongsTo: j['owner'],
    renewal: j['renewal'],
    shared: j['shared'],
    uploadFrom: date(j['uploadFrom']),
    uploadTo: date(j['uploadTo']),
    expiryFrom: date(j['expiryFrom']),
    expiryTo: date(j['expiryTo']),
    minBytes: j['min'],
    maxBytes: j['max'],
    tags: (j['tags'] as List? ?? []).cast<String>(),
    sort: DocumentSort.values.byName(j['sort'] ?? 'newest'),
  );
}
