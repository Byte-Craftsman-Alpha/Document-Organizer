import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/repositories/live_capabilities.dart';

Future<void> openDocumentBytes(
  DocumentBytes content, {
  void Function()? verifyAccount,
}) async {
  verifyAccount?.call();
  await FilePicker.platform.saveFile(
    fileName: content.name,
    bytes: content.bytes,
  );
}

Future<void> clearOpenedFiles() async {}

Future<bool> shareDocumentBytes(
  DocumentBytes content, {
  void Function()? verifyAccount,
}) async {
  verifyAccount?.call();
  final result = await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          content.bytes,
          mimeType: content.mimeType,
          name: content.name,
        ),
      ],
      fileNameOverrides: [content.name],
      downloadFallbackEnabled: true,
    ),
  );
  return result.status != ShareResultStatus.dismissed;
}

Future<void> pruneOpenedFiles() async {}
