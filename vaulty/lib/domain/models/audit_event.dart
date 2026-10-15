class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.event,
    required this.documentTitle,
    required this.actor,
    required this.at,
    this.documentId,
  });
  final String id, event, documentTitle, actor;
  final String? documentId;
  final DateTime at;
}
