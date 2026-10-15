class StorageInfo {
  const StorageInfo({
    required this.totalBytes,
    required this.otherBytes,
    required this.vaultBytes,
    this.reportedUsedBytes,
    this.cachedAt,
  });
  final DateTime? cachedAt;
  final int? totalBytes, reportedUsedBytes;
  final int otherBytes, vaultBytes;
  int get usedBytes => reportedUsedBytes ?? otherBytes + vaultBytes;
  double get usedFraction =>
      totalBytes == null || totalBytes! <= 0 ? 0 : usedBytes / totalBytes!;
}
