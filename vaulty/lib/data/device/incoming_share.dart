import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../drive/live_repositories.dart';
import 'file_validation.dart';

class IncomingFile {
  const IncomingFile({
    required this.id,
    required this.name,
    required this.size,
    required this.mime,
    this.kind,
    this.error,
  });
  final String id, name, mime;
  final String? kind;
  final int size;
  final String? error;
}

class IncomingShare {
  static final instance = IncomingShare();
  static const channel = MethodChannel('app.vaulty/incoming');
  final revision = ValueNotifier(0);
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  void initialize() {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') revision.value++;
    });
  }

  Future<List<IncomingFile>> pending() async {
    if (!supported) return [];
    final list = await channel.invokeListMethod<dynamic>('pending') ?? [];
    return list
        .map(
          (dynamic row) => IncomingFile(
            id: row['id'] as String,
            name: row['name'] as String,
            size: (row['size'] as num).toInt(),
            mime: row['mime'] as String,
            kind: (row['kind'] as String?)?.isEmpty == true
                ? null
                : row['kind'] as String?,
            error: (row['error'] as String).isEmpty
                ? null
                : row['error'] as String,
          ),
        )
        .toList();
  }

  Future<PickedDocument> read(IncomingFile file) async {
    final bytes = await channel.invokeMethod<Uint8List>('read', {
      'id': file.id,
    });
    final kind = FileValidation.detect(bytes!);
    return PickedDocument(
      FileValidation.safeName(file.name, kind),
      kind,
      bytes.length,
      bytes,
    );
  }

  Future<void> discard(String id) async {
    await channel.invokeMethod<void>('discard', {'id': id});
  }

  Future<void> clear() async {
    if (supported) await channel.invokeMethod<void>('clear');
  }
}
