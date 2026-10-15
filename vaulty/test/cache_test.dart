import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:archive/archive.dart';
import 'package:vaulty/data/cache/cache_factory_native.dart';
import 'package:vaulty/data/cache/vault_cache.dart';
import 'package:vaulty/data/cache/cached_file.dart';
import 'package:vaulty/data/device/device_services.dart';
import 'package:vaulty/data/device/file_validation.dart';
import 'package:vaulty/data/drive/drive_api.dart';
import 'package:vaulty/data/drive/drive_store.dart';
import 'package:vaulty/data/drive/drive_codec.dart';
import 'package:vaulty/data/drive/live_repositories.dart';
import 'package:vaulty/domain/models/document.dart';
import 'package:vaulty/domain/repositories/live_capabilities.dart';
import 'drive_api_test.dart' show Identity;

class NoDevice extends DeviceServices {
  @override
  bool get supported => false;
}

class Fixture {
  final identity = Identity();
  final cache = MemoryVaultCache();
  int downloads = 0, version = 1, status = 200;
  bool offline = false;
  Document document = Document(
    id: 'd1',
    title: 'Policy',
    belongsTo: 'Owner',
    kind: FileKind.pdf,
    uploadedAt: DateTime(2026, 1, 1),
    sizeBytes: 14,
  );
  Json get record => {
    'id': 'remote',
    'size': '14',
    'mimeType': 'application/pdf',
    'version': '$version',
    'description': jsonEncode(DriveCodec.document(document)),
  };
  late final client = MockClient((request) async {
    if (offline) throw http.ClientException('network down');
    if (status != 200) return http.Response('{}', status);
    if (request.method == 'PATCH') {
      version++;
      document = DriveCodec.readDocument(
        jsonDecode((jsonDecode(request.body) as Json)['description']) as Json,
        14,
      );
      return http.Response(jsonEncode(record), 200);
    }
    if (request.url.queryParameters['alt'] == 'media') {
      downloads++;
      return http.Response('%PDF-1.7 body $version', 200);
    }
    if (request.url.path.endsWith('/files')) {
      return http.Response(
        jsonEncode({
          'files': [record],
        }),
        200,
      );
    }
    return http.Response(jsonEncode(record), 200);
  });
  DriveDocumentRepository repository() => DriveDocumentRepository(
    DriveStore(DriveApi(identity, client: client), cache: cache),
    NoDevice(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Encrypted cache survives recreation, contains no plaintext, isolates owners and detects tampering',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final dir = await Directory.systemTemp.createTemp('vaulty-test-');
      addTearDown(() => dir.delete(recursive: true));
      final cache = EncryptedVaultCache(directory: dir);
      final bytes = Uint8List.fromList(utf8.encode('secret document contents'));
      await cache.write('account-a', 'file:one', bytes);
      final files = await dir
          .list(recursive: true)
          .where((e) => e is File)
          .cast<File>()
          .toList();
      expect(files, hasLength(1));
      expect(
        utf8.decode(await files.single.readAsBytes(), allowMalformed: true),
        isNot(contains('secret document')),
      );
      expect(
        await EncryptedVaultCache(directory: dir).read('account-a', 'file:one'),
        bytes,
      );
      expect(await cache.read('account-b', 'file:one'), isNull);
      final cipher = await files.single.readAsBytes();
      cipher[cipher.length - 1] ^= 1;
      await files.single.writeAsBytes(cipher);
      expect(await cache.read('account-a', 'file:one'), isNull);
      await cache.write('account-a', 'file:one', bytes);
      await cache.clear('account-a');
      expect(await cache.read('account-a', 'file:one'), isNull);
    },
  );
  test(
    'Large-file encryption/decryption runs through the worker isolate',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final dir = await Directory.systemTemp.createTemp('vaulty-large-test-');
      addTearDown(() => dir.delete(recursive: true));
      final cache = EncryptedVaultCache(directory: dir);
      final bytes = Uint8List(300 * 1024)..[0] = 42;
      await cache.write('a', 'file:large', bytes);
      expect(await cache.read('a', 'file:large'), bytes);
    },
  );
  test(
    'Same-version previews reuse bytes without downloading; simultaneous reads coalesce',
    () async {
      final f = Fixture(),
          repo = Fixture(); // independent fixtures do not share caches
      final r = f.repository();
      await Future.wait([r.read('d1'), r.read('d1')]);
      expect(f.downloads, 1);
      expect((await r.read('d1')).fromCache, isTrue);
      expect(f.downloads, 1);
      expect(repo.downloads, 0);
    },
  );
  test(
    'File/detail version change invalidates cache and refreshes name and bytes',
    () async {
      final f = Fixture();
      final r = f.repository();
      await r.read('d1');
      f.version = 2;
      f.document = f.document.copyWith(
        title: 'Updated policy',
        modifiedAt: DateTime.now(),
      );
      final current = await r.read('d1');
      expect(current.name, 'Updated policy.pdf');
      expect(f.downloads, 2);
      expect(utf8.decode(current.bytes), contains('body 2'));
      await r.save(f.document.copyWith(title: 'Local edit'));
      expect(await f.cache.read('account-a', 'file:d1'), isNull);
      await r.read('d1');
      expect(f.downloads, 3);
    },
  );
  test(
    'Offline restart reads saved index and exact cached file version',
    () async {
      final f = Fixture();
      await f.repository().read('d1');
      f.offline = true;
      final restarted = f.repository();
      expect((await restarted.list()).single.title, 'Policy');
      final file = await restarted.read('d1');
      expect(file.offline, isTrue);
      expect(file.fromCache, isTrue);
      expect(f.downloads, 1);
    },
  );
  test(
    'Uncached offline files fail clearly; another account cannot reuse an index',
    () async {
      final f = Fixture();
      await f.repository().list();
      f.offline = true;
      await expectLater(
        f.repository().read('d1'),
        throwsA(
          isA<VaultFailure>().having(
            (e) => e.message,
            'message',
            contains('not cached'),
          ),
        ),
      );
      f.identity.owner = 'account-b';
      f.identity.generation++;
      await expectLater(
        f.repository().list(),
        throwsA(isA<DriveOfflineFailure>()),
      );
    },
  );
  for (final status in [401, 403, 404]) {
    test('HTTP $status never falls back to cached bytes', () async {
      final f = Fixture();
      final r = f.repository();
      await r.read('d1');
      f.status = status;
      await expectLater(r.read('d1'), throwsA(isA<VaultFailure>()));
      expect(await f.cache.read('account-a', 'file:d1'), isNull);
    });
  }
  test(
    'Cached envelope rejects mismatched metadata version and corruption',
    () {
      final file = DocumentBytes(
        'a.pdf',
        'application/pdf',
        Uint8List.fromList([1, 2, 3]),
      );
      final blob = CachedFile.encode('1', file);
      expect(CachedFile.decode(blob, '1')!.bytes, file.bytes);
      expect(CachedFile.decode(blob, '2'), isNull);
      expect(CachedFile.decode(Uint8List.fromList([0]), '1'), isNull);
    },
  );
  test(
    'Browsing recents are account-specific and contain timestamps, not action/audit events',
    () async {
      final f = Fixture();
      final r = f.repository();
      await r.markBrowsed('d1');
      expect((await r.browsed()).keys, ['d1']);
      f.identity.owner = 'account-b';
      f.identity.generation++;
      expect(await r.browsed(), isEmpty);
    },
  );
  test(
    'File sniffing handles real supported types and rejects renamed ZIPs/unknown data',
    () {
      expect(
        FileValidation.detect(Uint8List.fromList(utf8.encode('%PDF-1.7'))),
        FileKind.pdf,
      );
      expect(
        FileValidation.detect(Uint8List.fromList([255, 216, 255])),
        FileKind.jpg,
      );
      expect(
        FileValidation.detect(
          Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
        ),
        FileKind.png,
      );
      final archive = Archive()
        ..addFile(ArchiveFile('[Content_Types].xml', 4, utf8.encode('test')))
        ..addFile(ArchiveFile('word/document.xml', 4, utf8.encode('test')));
      expect(
        FileValidation.detect(Uint8List.fromList(ZipEncoder().encode(archive))),
        FileKind.docx,
      );
      final zip = Archive()
        ..addFile(ArchiveFile('random.txt', 4, utf8.encode('test')));
      expect(
        () =>
            FileValidation.detect(Uint8List.fromList(ZipEncoder().encode(zip))),
        throwsA(isA<VaultFailure>()),
      );
      expect(
        () => FileValidation.detect(Uint8List(0)),
        throwsA(isA<VaultFailure>()),
      );
      expect(FileValidation.safeName('../file.png', FileKind.jpg), 'file.jpg');
    },
  );
}
