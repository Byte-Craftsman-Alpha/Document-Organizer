import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../domain/repositories/live_capabilities.dart';

Future<void> openDocumentBytes(
  DocumentBytes content, {
  void Function()? verifyAccount,
}) async {
  verifyAccount?.call();
  final root = Directory('${(await getTemporaryDirectory()).path}/vaulty-open');
  verifyAccount?.call();
  await root.create(recursive: true);
  await pruneOpenedFiles();
  final dir = await root.createTemp('document-');
  try {
    verifyAccount?.call();
    final path =
        '${dir.path}/${content.name.replaceAll(RegExp(r"[^a-zA-Z0-9._ -]"), '_')}';
    await File(path).writeAsBytes(content.bytes, flush: true);
    verifyAccount?.call();
    final result = await OpenFilex.open(path, type: content.mimeType);
    if (result.type != ResultType.done) {
      throw const VaultFailure(
        'No compatible viewer could open this file. Try Share a copy or export it.',
      );
    }
  } catch (_) {
    if (await dir.exists()) await dir.delete(recursive: true);
    rethrow;
  }
}

Future<void> clearOpenedFiles() async {
  try {
    final root = await getTemporaryDirectory();
    for (final name in ['vaulty-open', 'share_plus']) {
      final dir = Directory('${root.path}/$name');
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  } catch (_) {
    /* Best effort cleanup; never break sign-out. */
  }
}

Future<bool> shareDocumentBytes(
  DocumentBytes content, {
  void Function()? verifyAccount,
}) async {
  verifyAccount?.call();
  final root = Directory('${(await getTemporaryDirectory()).path}/vaulty-open');
  await root.create(recursive: true);
  await pruneOpenedFiles();
  final dir = await root.createTemp('share-');
  final file = File(
    '${dir.path}/${content.name.replaceAll(RegExp(r"[^a-zA-Z0-9._ -]"), '_')}',
  );
  try {
    await file.writeAsBytes(content.bytes, flush: true);
    verifyAccount?.call();
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: content.mimeType)],
        fileNameOverrides: [content.name],
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  } catch (_) {
    if (await dir.exists()) await dir.delete(recursive: true);
    rethrow;
  }
}

Future<void> pruneOpenedFiles() async {
  final root = await getTemporaryDirectory();
  for (final name in ['vaulty-open', 'share_plus']) {
    final dir = Directory('${root.path}/$name');
    if (!await dir.exists()) continue;
    await for (final entry in dir.list()) {
      if (DateTime.now().difference((await entry.stat()).modified) >
          const Duration(hours: 24)) {
        await entry.delete(recursive: true);
      }
    }
  }
  await for (final entry in root.list()) {
    if (entry is File &&
        entry.path.split('/').last.startsWith('vaulty-preview-') &&
        DateTime.now().difference((await entry.stat()).modified) >
            const Duration(hours: 24)) {
      await entry.delete();
    }
  }
}
