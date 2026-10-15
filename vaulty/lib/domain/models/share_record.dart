enum ShareRole { view, edit }

class ShareRecord {
  const ShareRecord({
    required this.id,
    required this.documentId,
    required this.documentTitle,
    required this.recipients,
    required this.role,
    required this.expiresAt,
    this.restrictDownload = true,
    this.revoked = false,
  });
  final String id, documentId, documentTitle;
  final List<String> recipients;
  final ShareRole role;
  final DateTime expiresAt;
  final bool restrictDownload, revoked;
  String status(DateTime now) => revoked
      ? 'Revoked'
      : expiresAt.isBefore(now)
      ? 'Expired'
      : 'Active';
  ShareRecord revoke() => ShareRecord(
    id: id,
    documentId: documentId,
    documentTitle: documentTitle,
    recipients: recipients,
    role: role,
    expiresAt: expiresAt,
    restrictDownload: restrictDownload,
    revoked: true,
  );
}
