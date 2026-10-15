import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'vault_cache.dart';

VaultCache createVaultCache() => EncryptedVaultCache();

Future<Uint8List> _crypt((Uint8List, List<int>, String, bool) input) async {
  final cipher = AesGcm.with256bits();
  final key = SecretKey(input.$2);
  final aad = utf8.encode(input.$3);
  if (input.$4) {
    return (await cipher.encrypt(
      input.$1,
      secretKey: key,
      aad: aad,
    )).concatenation();
  }
  final box = SecretBox.fromConcatenation(
    input.$1,
    nonceLength: 12,
    macLength: 16,
  );
  return Uint8List.fromList(
    await cipher.decrypt(box, secretKey: key, aad: aad),
  );
}

Future<Uint8List> _cryptOffUi((Uint8List, List<int>, String, bool) input) =>
    input.$1.length > 256 * 1024
    ? Isolate.run(() => _crypt(input))
    : _crypt(input);

/// AES-256-GCM, unique random nonce per write, AAD binds owner and record.
/// Keys are protected by Android Keystore via flutter_secure_storage.
class EncryptedVaultCache extends VaultCache {
  EncryptedVaultCache({this.directory});
  final Directory? directory;
  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _cipher = AesGcm.with256bits();
  Future<void> _tail = Future.value();
  static const maxBytes = 256 * 1024 * 1024;
  Future<T> _serial<T>(Future<T> Function() job) {
    final next = _tail.then((_) => job());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();
  Future<Directory> _dir(String owner) async => Directory(
    '${(directory ?? await getApplicationSupportDirectory()).path}/vaulty-cache/${_hash(owner)}',
  );
  Future<File> _file(String owner, String key) async => File(
    '${(await _dir(owner)).path}/${key.startsWith('file:') ? 'file-' : 'meta-'}${_hash(key)}',
  );
  Future<SecretKey> _key(String owner) async {
    final name = 'vaulty.cache.key.${_hash(owner)}';
    final saved = await _secure.read(key: name);
    if (saved != null) return SecretKey(base64Decode(saved));
    final key = await _cipher.newSecretKey();
    await _secure.write(
      key: name,
      value: base64Encode(await key.extractBytes()),
    );
    return key;
  }

  @override
  Future<Uint8List?> read(String owner, String key) => _serial(() async {
    final file = await _file(owner, key);
    if (!await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      final plain = await _cryptOffUi((
        bytes,
        await (await _key(owner)).extractBytes(),
        '$owner\u0000$key',
        false,
      ));
      await file.setLastModified(DateTime.now());
      return plain;
    } catch (_) {
      // A damaged/tampered cache is never displayed as a valid document.
      if (await file.exists()) await file.delete();
      return null;
    }
  });
  @override
  Future<void> write(String owner, String key, Uint8List value) =>
      _serial(() async {
        final dir = await _dir(owner);
        await dir.create(recursive: true);
        final file = await _file(owner, key);
        final encrypted = await _cryptOffUi((
          value,
          await (await _key(owner)).extractBytes(),
          '$owner\u0000$key',
          true,
        ));
        final temp = File('${file.path}.tmp');
        await temp.writeAsBytes(encrypted, flush: true);
        await temp.rename(file.path);
        final files = <(File, FileStat)>[];
        await for (final entry in dir.list()) {
          if (entry is File && entry.path.split('/').last.startsWith('file-')) {
            files.add((entry, await entry.stat()));
          }
        }
        files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
        var size = files.fold<int>(0, (s, f) => s + f.$2.size);
        for (final entry in files) {
          if (size <= maxBytes) break;
          await entry.$1.delete();
          size -= entry.$2.size;
        }
      });
  @override
  Future<void> remove(String owner, String key) => _serial(() async {
    final file = await _file(owner, key);
    if (await file.exists()) await file.delete();
  });
  @override
  Future<void> clear(String owner) => _serial(() async {
    final dir = await _dir(owner);
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } finally {
      await _secure.delete(key: 'vaulty.cache.key.${_hash(owner)}');
    }
  });
  @override
  Future<Map<String, dynamic>?> lastAccount() async {
    final s = await _secure.read(key: 'vaulty.last.account');
    return s == null ? null : jsonDecode(s) as Map<String, dynamic>;
  }

  @override
  Future<void> rememberAccount(Map<String, dynamic>? account) async {
    if (account == null) {
      await _secure.delete(key: 'vaulty.last.account');
    } else {
      await _secure.write(
        key: 'vaulty.last.account',
        value: jsonEncode(account),
      );
    }
  }
}
