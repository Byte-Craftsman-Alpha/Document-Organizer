import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vaulty/data/drive/drive_api.dart';
import 'package:vaulty/data/drive/drive_store.dart';
import 'package:vaulty/data/drive/drive_codec.dart';
import 'package:vaulty/data/drive/google_identity.dart';
import 'package:vaulty/domain/models/document.dart';
import 'package:vaulty/domain/repositories/live_capabilities.dart';

class Identity implements DriveIdentity {
  @override
  String? owner = 'account-a';
  @override
  int generation = 0;
  bool rejected = false;
  @override
  Future<String> token() async => 'test-token';
  @override
  Future<void> rejectToken(String token) async {
    rejected = true;
  }
}

void main() {
  test(
    'Requests are private appData requests and paginate correctly',
    () async {
      final identity = Identity();
      var calls = 0;
      final api = DriveApi(
        identity,
        client: MockClient((r) async {
          calls++;
          expect(r.headers['Authorization'], 'Bearer test-token');
          expect(r.url.host, 'www.googleapis.com');
          expect(r.url.queryParameters['spaces'], 'appDataFolder');
          expect(r.url.queryParameters['q'], contains("value='vaulty-v1'"));
          if (calls == 1) {
            return http.Response(
              jsonEncode({
                'files': [
                  {'id': 'first'},
                ],
                'nextPageToken': 'next',
              }),
              200,
            );
          }
          expect(r.url.queryParameters['pageToken'], 'next');
          return http.Response(
            jsonEncode({
              'files': [
                {'id': 'second'},
              ],
            }),
            200,
          );
        }),
      );
      expect((await api.list(kind: 'document')).map((f) => f['id']), [
        'first',
        'second',
      ]);
    },
  );
  test('Rejects unknown upload hosts before sending an access token', () async {
    var sent = false;
    final api = DriveApi(
      Identity(),
      client: MockClient((r) async {
        sent = true;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      api.request(
        'PUT',
        Uri.parse('https://example.com/upload'),
        bytes: Uint8List(1),
      ),
      throwsA(isA<VaultFailure>()),
    );
    expect(sent, isFalse);
  });
  test('Discards an old account response after account switch', () async {
    final identity = Identity();
    final api = DriveApi(
      identity,
      client: MockClient((r) async {
        identity.owner = 'account-b';
        identity.generation++;
        return http.Response('{"files":[]}', 200);
      }),
    );
    await expectLater(api.list(), throwsA(isA<VaultFailure>()));
  });
  test('Expired access is rejected; raw token is not shown to users', () async {
    final identity = Identity();
    final api = DriveApi(
      identity,
      client: MockClient((r) async => http.Response('secret-token', 401)),
    );
    await expectLater(
      api.list(),
      throwsA(
        isA<VaultFailure>().having(
          (e) => e.message,
          'message',
          isNot(contains('secret-token')),
        ),
      ),
    );
    expect(identity.rejected, isTrue);
  });
  test('Metadata edits detect conflicting versions before writing', () async {
    var writes = 0;
    final api = DriveApi(
      Identity(),
      client: MockClient((r) async {
        if (r.method == 'PATCH') writes++;
        return http.Response(
          '{"id":"file-1","version":"2"}',
          200,
          headers: {'etag': 'new'},
        );
      }),
    );
    await expectLater(
      api.patch({'id': 'file-1', 'version': '1'}, {'name': 'updated'}),
      throwsA(isA<VaultFailure>()),
    );
    expect(writes, 0);
  });
  test(
    'Successful metadata writes carry the concurrency precondition',
    () async {
      final api = DriveApi(
        Identity(),
        client: MockClient((r) async {
          if (r.method == 'GET') {
            return http.Response(
              '{"id":"file-1","version":"1"}',
              200,
              headers: {'etag': 'expected-etag'},
            );
          }
          expect(r.headers['If-Match'], 'expected-etag');
          return http.Response('{"id":"file-1","version":"2"}', 200);
        }),
      );
      expect(
        (await api.patch(
          {'id': 'file-1', 'version': '1'},
          {'name': 'updated'},
        ))['version'],
        '2',
      );
    },
  );
  test(
    'Resumable upload reports acknowledged bytes and final metadata',
    () async {
      final progress = <double>[];
      final bytes = Uint8List(1024 * 1024 + 12);
      final api = DriveApi(
        Identity(),
        client: MockClient((r) async {
          if (r.method == 'POST') {
            final j = jsonDecode(r.body) as Map<String, dynamic>;
            expect(j['parents'], ['appDataFolder']);
            return http.Response(
              '',
              200,
              headers: {
                'location':
                    'https://www.googleapis.com/upload/drive/v3/files?upload_id=test',
              },
            );
          }
          if (r.headers['Content-Range']!.startsWith('bytes 0-')) {
            return http.Response(
              '',
              308,
              headers: {'range': 'bytes=0-1048575'},
            );
          }
          expect(r.bodyBytes.length, 12);
          return http.Response('{"id":"remote-id"}', 200);
        }),
      );
      await for (final p in api.upload(
        id: 'remote-id',
        metadata: {
          'parents': ['appDataFolder'],
        },
        bytes: bytes,
        mimeType: 'application/pdf',
      )) {
        progress.add(p.$1);
      }
      expect(progress.length, 2);
      expect(progress.last, 1);
      expect(progress.first, lessThan(1));
    },
  );
  test('Document metadata survives JSON and uses actual Drive file size', () {
    final d = Document(
      id: 'one',
      title: 'My policy',
      belongsTo: 'Family',
      kind: FileKind.pdf,
      uploadedAt: DateTime(2026, 10, 15),
      sizeBytes: 999,
      renewalRequired: true,
      expiry: DateTime(2027, 1, 5),
      tags: ['personal'],
    );
    final restored = DriveCodec.readDocument(
      jsonDecode(jsonEncode(DriveCodec.document(d))) as Json,
      12345,
    );
    expect(restored.sizeBytes, 12345);
    expect(restored.title, d.title);
    expect(restored.expiry, DateTime(2027, 1, 5));
  });
  test(
    'Corrupt metadata fails safely rather than substituting seed data',
    () async {
      final store = DriveStore(
        DriveApi(
          Identity(),
          client: MockClient(
            (r) async => http.Response(
              '{"files":[{"id":"broken","description":"not-json","size":"12"}]}',
              200,
            ),
          ),
        ),
      );
      await expectLater(store.documents(), throwsA(isA<VaultFailure>()));
    },
  );
  test('Account change clears cached file identifiers', () {
    final id = Identity();
    final store = DriveStore(DriveApi(id));
    store.scope();
    store.files['doc'] = {'id': 'old-account-file'};
    id.owner = 'another-account';
    id.generation++;
    store.scope();
    expect(store.files, isEmpty);
  });
  test(
    'Whole transactions cannot start a later request under another account',
    () async {
      final identity = Identity();
      var calls = 0;
      final api = DriveApi(
        identity,
        client: MockClient((r) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        api.guard(() async {
          await api.request('GET', api.uri('about'));
          identity.owner = 'account-b';
          identity.generation++;
          await api.request('DELETE', api.uri('files/old-account-file'));
        }),
        throwsA(isA<VaultFailure>()),
      );
      expect(calls, 1);
    },
  );
  test('Preference decoder rejects unsupported reminder intervals', () {
    expect(DriveCodec.readPreferences({'reminderDays': -999}).reminderDays, 30);
    expect(DriveCodec.readPreferences({'reminderDays': 7}).reminderDays, 7);
  });
  test('Editable tags survive document copies and Drive serialization', () {
    final original = Document(
      id: 'd',
      title: 'Policy',
      belongsTo: 'Family',
      kind: FileKind.pdf,
      uploadedAt: DateTime(2026, 10, 15),
      sizeBytes: 100,
    );
    final updated = original.copyWith(tags: ['personal', 'renewal']);
    expect(DriveCodec.readDocument(DriveCodec.document(updated), 100).tags, [
      'personal',
      'renewal',
    ]);
  });
  test('Renewal counts use calendar dates rather than hours of the day', () {
    final doc = Document(
      id: 'd',
      title: 'Policy',
      belongsTo: 'Family',
      kind: FileKind.pdf,
      uploadedAt: DateTime(2026, 1, 1),
      sizeBytes: 100,
      renewalRequired: true,
      expiry: DateTime(2026, 3, 31),
    );
    expect(doc.daysUntil(DateTime(2026, 3, 1, 23, 59)), 30);
  });
}
