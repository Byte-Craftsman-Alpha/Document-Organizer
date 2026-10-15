import 'dart:convert';
import 'dart:typed_data';
import '../../domain/repositories/live_capabilities.dart';

abstract final class CachedFile {
  static Uint8List encode(String version, DocumentBytes file) {
    final header = utf8.encode(
      jsonEncode({
        'version': version,
        'name': file.name,
        'mime': file.mimeType,
      }),
    );
    final length = ByteData(4)..setUint32(0, header.length);
    return (BytesBuilder(copy: false)
          ..add(length.buffer.asUint8List())
          ..add(header)
          ..add(file.bytes))
        .takeBytes();
  }

  static DocumentBytes? decode(
    Uint8List data,
    String version, {
    bool offline = false,
  }) {
    try {
      final size = ByteData.sublistView(data, 0, 4).getUint32(0);
      final header =
          jsonDecode(utf8.decode(data.sublist(4, 4 + size)))
              as Map<String, dynamic>;
      if (header['version'] != version) return null;
      return DocumentBytes(
        header['name'],
        header['mime'],
        Uint8List.sublistView(data, 4 + size),
        fromCache: true,
        offline: offline,
      );
    } catch (_) {
      return null;
    }
  }
}
