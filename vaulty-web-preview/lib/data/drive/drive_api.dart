import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../domain/repositories/live_capabilities.dart';
import 'drive_codec.dart';
import 'google_identity.dart';

/// Only Google Drive endpoints are contacted. Never accepts an arbitrary API URL.
class DriveApi {
  DriveApi(this.identity, {http.Client? client})
    : client = client ?? http.Client();
  final DriveIdentity identity;
  final http.Client client;
  static final Object _leaseKey = Object();
  void verifyAccount() => _checkLease();
  void _checkLease() {
    final lease = Zone.current[_leaseKey] as (String?, int)?;
    if (lease != null &&
        (lease.$1 != identity.owner || lease.$2 != identity.generation)) {
      throw const VaultFailure(
        'Account changed. The previous account’s operation was cancelled.',
      );
    }
  }

  Future<T> guard<T>(Future<T> Function() action) async {
    _checkLease();
    if (Zone.current[_leaseKey] != null) return action();
    return runZoned(
      action,
      zoneValues: {_leaseKey: (identity.owner, identity.generation)},
    );
  }

  Stream<T> guardStream<T>(Stream<T> Function() source) {
    late StreamController<T> controller;
    bool cancelled = false;
    controller = StreamController<T>(
      onListen: () {
        unawaited(
          guard(() async {
            try {
              await for (final value in source()) {
                if (cancelled) break;
                controller.add(value);
              }
            } catch (e, st) {
              if (!cancelled) controller.addError(e, st);
            } finally {
              await controller.close();
            }
          }),
        );
      },
      onCancel: () {
        cancelled = true;
      },
    );
    return controller.stream;
  }

  static const namespace = 'vaulty-v1';
  static const fileFields =
      'id,name,mimeType,size,description,appProperties,version,modifiedTime';
  Uri uri(String path, [Map<String, String>? query]) =>
      Uri.https('www.googleapis.com', '/drive/v3/$path', query);
  Future<http.Response> request(
    String method,
    Uri uri, {
    Json? json,
    Uint8List? bytes,
    Map<String, String> headers = const {},
    Set<int> accepted = const {200, 201, 204},
  }) async {
    _checkLease();
    if (uri.scheme != 'https' || uri.host != 'www.googleapis.com') {
      throw const VaultFailure('Untrusted Drive endpoint rejected.');
    }
    final owner = identity.owner, epoch = identity.generation;
    if (owner == null) throw const VaultFailure('Connect Drive to continue.');
    final token = await identity.token();
    _checkLease();
    final request = http.Request(method, uri)
      ..headers.addAll({'Authorization': 'Bearer $token', ...headers});
    if (json != null) {
      request.headers['Content-Type'] = 'application/json; charset=UTF-8';
      request.body = jsonEncode(json);
    }
    if (bytes != null) request.bodyBytes = bytes;
    late http.Response response;
    try {
      response =
          await (() async => http.Response.fromStream(
            await client.send(request),
          ))().timeout(
            Duration(
              seconds: method == 'GET' && uri.queryParameters['alt'] != 'media'
                  ? 12
                  : 120,
            ),
          );
    } catch (_) {
      throw const DriveOfflineFailure();
    }
    if (identity.owner != owner || identity.generation != epoch) {
      throw const VaultFailure(
        'The account changed during this request. Its result was discarded.',
      );
    }
    if (!accepted.contains(response.statusCode)) {
      if (response.statusCode == 401) {
        await identity.rejectToken(token);
        throw const VaultFailure(
          'Google authorization expired. Reconnect Drive.',
        );
      }
      if (response.statusCode == 412) {
        throw const VaultFailure(
          'This file changed on another device. Refresh before editing again.',
        );
      }
      if (response.statusCode == 404) {
        throw const VaultFailure(
          'This file no longer exists in your vault. Refresh the collection.',
        );
      }
      if (response.statusCode == 403) {
        String reason = '';
        try {
          reason = response.body.toLowerCase();
        } catch (_) {
          /* Use a safe message. */
        }
        if (reason.contains('storagequota')) {
          throw const VaultFailure(
            'Your Google storage is full. Free some space before uploading.',
          );
        }
        if (reason.contains('accessnotconfigured') ||
            reason.contains('service_disabled')) {
          throw const VaultFailure(
            'The developer must enable Google Drive API in the OAuth project.',
          );
        }
        throw const VaultFailure(
          'Drive refused this request. Check access, available storage and API limits, then reconnect or retry.',
        );
      }
      if (response.statusCode == 429 || response.statusCode >= 500) {
        throw const VaultFailure(
          'Google Drive is busy. Please retry in a moment.',
        );
      }
      throw VaultFailure(
        'Drive could not complete the request (HTTP ${response.statusCode}). Nothing is being simulated.',
      );
    }
    return response;
  }

  Future<List<Json>> list({String? kind}) => guard(() => _list(kind: kind));
  Future<List<Json>> _list({String? kind}) async {
    final result = <Json>[];
    String? next;
    do {
      final response = await request(
        'GET',
        uri('files', {
          'spaces': 'appDataFolder',
          'pageSize': '1000',
          'q':
              "appProperties has { key='vaultyApp' and value='$namespace' }${kind == null ? '' : " and appProperties has { key='kind' and value='$kind' }"}",
          'fields': 'nextPageToken,files($fileFields)',
          'pageToken': ?next,
        }),
      );
      final data = jsonDecode(response.body) as Json;
      result.addAll((data['files'] as List).cast<Json>());
      next = data['nextPageToken'] as String?;
    } while (next != null);
    return result;
  }

  Future<Json> generateId() async =>
      jsonDecode(
            (await request(
              'GET',
              uri('files/generateIds', {
                'count': '1',
                'space': 'appDataFolder',
                'type': 'files',
              }),
            )).body,
          )
          as Json;
  Future<http.Response> metadata(String id) =>
      request('GET', uri('files/$id', {'fields': fileFields}));
  Future<Uint8List> download(String id) async =>
      (await request('GET', uri('files/$id', {'alt': 'media'}))).bodyBytes;
  Future<void> delete(String id) async {
    await request('DELETE', uri('files/$id'), accepted: const {204, 404});
  }

  Future<Json> createJson(String name, String kind, Json data) async {
    final response = await request(
      'POST',
      uri('files', {'fields': fileFields}),
      json: {
        'name': name,
        'mimeType': 'application/json',
        'parents': ['appDataFolder'],
        'description': jsonEncode(data),
        'appProperties': {'vaultyApp': namespace, 'kind': kind},
      },
    );
    return jsonDecode(response.body) as Json;
  }

  Future<Json> patch(Json known, Json update) async {
    final latest = await metadata(known['id']);
    final actual = jsonDecode(latest.body) as Json;
    if (known['version'] != null && known['version'] != actual['version']) {
      throw const VaultFailure(
        'This item changed on another device. Refresh and try again.',
      );
    }
    final response = await request(
      'PATCH',
      uri('files/${known['id']}', {'fields': fileFields}),
      json: update,
      headers: {
        if (latest.headers['etag'] != null) 'If-Match': latest.headers['etag']!,
      },
    );
    return jsonDecode(response.body) as Json;
  }

  Stream<(double, Json?)> upload({
    required String id,
    required Json metadata,
    required Uint8List bytes,
    required String mimeType,
    bool replace = false,
  }) async* {
    final epoch = identity.generation;
    final path = replace
        ? '/upload/drive/v3/files/$id'
        : '/upload/drive/v3/files';
    final begin = await request(
      replace ? 'PATCH' : 'POST',
      Uri.https('www.googleapis.com', path, {
        'uploadType': 'resumable',
        'fields': fileFields,
      }),
      json: metadata,
      headers: {
        'X-Upload-Content-Type': mimeType,
        'X-Upload-Content-Length': '${bytes.length}',
      },
    );
    final location = begin.headers['location'];
    if (location == null) {
      throw const VaultFailure(
        'Drive did not provide an upload session. Retry the upload.',
      );
    }
    final session = Uri.parse(location);
    const chunk = 1024 * 1024;
    for (var offset = 0; offset < bytes.length; offset += chunk) {
      if (identity.generation != epoch) {
        throw const VaultFailure('The account changed. Upload cancelled.');
      }
      final end = (offset + chunk).clamp(0, bytes.length);
      final response = await request(
        'PUT',
        session,
        bytes: Uint8List.sublistView(bytes, offset, end),
        headers: {
          'Content-Type': mimeType,
          'Content-Range': 'bytes $offset-${end - 1}/${bytes.length}',
        },
        accepted: const {200, 201, 308},
      );
      if (response.statusCode == 308) {
        if (end == bytes.length) {
          throw const VaultFailure(
            'Drive has not confirmed the full upload. Retry; the file is not marked complete.',
          );
        }
        yield (end / bytes.length, null);
      } else {
        if (end != bytes.length) {
          throw const VaultFailure(
            'Drive returned an unexpected upload result. Refresh and retry.',
          );
        }
        yield (1, jsonDecode(response.body) as Json);
      }
    }
  }
}
