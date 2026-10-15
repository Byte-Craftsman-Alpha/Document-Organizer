import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../../domain/models/document.dart';
import '../../domain/repositories/live_capabilities.dart';

abstract final class FileValidation {
  static const extensions = [
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'heic',
    'heif',
    'docx',
  ];
  static const maxBytes = 50 * 1024 * 1024;
  static FileKind detect(Uint8List b) {
    if (b.isEmpty || b.length > maxBytes) {
      throw const VaultFailure('Choose a non-empty file up to 50 MB.');
    }
    bool starts(List<int> magic) =>
        b.length >= magic.length &&
        List.generate(magic.length, (i) => b[i] == magic[i]).every((v) => v);
    String part(int a, int end) => b.length >= end
        ? ascii.decode(b.sublist(a, end), allowInvalid: true)
        : '';
    if (part(0, 5) == '%PDF-') return FileKind.pdf;
    if (starts([255, 216, 255])) return FileKind.jpg;
    if (starts([137, 80, 78, 71, 13, 10, 26, 10])) return FileKind.png;
    if (part(0, 4) == 'RIFF' && part(8, 12) == 'WEBP') return FileKind.webp;
    if (part(0, 6) == 'GIF87a' || part(0, 6) == 'GIF89a') return FileKind.gif;
    if (part(4, 8) == 'ftyp' &&
        [
          'heic',
          'heix',
          'hevc',
          'hevx',
          'mif1',
          'msf1',
        ].contains(part(8, 12))) {
      return FileKind.heic;
    }
    if (starts([80, 75, 3, 4])) {
      try {
        // Inspect ZIP directory only; never inflate arbitrary archive entries.
        final directory = ZipDirectory()..read(InputMemoryStream(b));
        final names = directory.fileHeaders.map((f) => f.filename).toSet();
        if (names.contains('[Content_Types].xml') &&
            names.contains('word/document.xml')) {
          return FileKind.docx;
        }
      } catch (_) {
        /* Not a valid DOCX container. */
      }
    }
    throw const VaultFailure(
      'Unsupported or damaged file. Use PDF, JPEG, PNG, WebP, GIF, HEIC or DOCX. Renaming an extension does not convert a file.',
    );
  }

  static String mime(FileKind kind) => switch (kind) {
    FileKind.pdf => 'application/pdf',
    FileKind.jpg => 'image/jpeg',
    FileKind.png => 'image/png',
    FileKind.webp => 'image/webp',
    FileKind.gif => 'image/gif',
    FileKind.heic => 'image/heic',
    FileKind.docx =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  };
  static String safeName(String name, FileKind kind) {
    final base = name
        .split(RegExp(r'[/\\]'))
        .last
        .replaceAll(RegExp(r'[\x00-\x1f]'), '')
        .replaceFirst(RegExp(r'\.[^.]+$'), '')
        .trim();
    return '${base.isEmpty ? 'Document' : base}.${kind.name}';
  }
}
