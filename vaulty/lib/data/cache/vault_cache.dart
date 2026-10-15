import 'dart:convert';
import 'dart:typed_data';

/// Account-scoped cache. Implementations never store authentication tokens.
abstract class VaultCache {
  Future<Uint8List?> read(String owner, String key);
  Future<void> write(String owner, String key, Uint8List value);
  Future<void> remove(String owner, String key);
  Future<void> clear(String owner);
  Future<Map<String, dynamic>?> lastAccount();
  Future<void> rememberAccount(Map<String, dynamic>? account);
  Future<dynamic> json(String owner, String key) async {
    final bytes = await read(owner, key);
    return bytes == null ? null : jsonDecode(utf8.decode(bytes));
  }

  Future<void> putJson(String owner, String key, Object value) =>
      write(owner, key, Uint8List.fromList(utf8.encode(jsonEncode(value))));
}

/// Browser cache is deliberately memory-only: closing/reloading clears it.
class MemoryVaultCache extends VaultCache {
  final _data = <(String, String), Uint8List>{};
  Map<String, dynamic>? _account;
  static const limit = 150 * 1024 * 1024;
  @override
  Future<Uint8List?> read(String owner, String key) async =>
      _data[(owner, key)];
  @override
  Future<void> write(String owner, String key, Uint8List value) async {
    _data.remove((owner, key));
    while (_data.isNotEmpty &&
        _data.values.fold<int>(0, (n, b) => n + b.length) + value.length >
            limit) {
      _data.remove(_data.keys.first);
    }
    if (value.length <= limit) _data[(owner, key)] = value;
  }

  @override
  Future<void> remove(String owner, String key) async =>
      _data.remove((owner, key));
  @override
  Future<void> clear(String owner) async =>
      _data.removeWhere((k, _) => k.$1 == owner);
  @override
  Future<Map<String, dynamic>?> lastAccount() async => _account;
  @override
  Future<void> rememberAccount(Map<String, dynamic>? account) async =>
      _account = account;
}
