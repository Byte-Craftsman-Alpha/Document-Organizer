import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vaulty/data/drive/account_verifier.dart';
import 'package:vaulty/domain/repositories/live_capabilities.dart';

void main() {
  test(
    'Drive access token must belong to the signed-in Google account',
    () async {
      final verifier = DriveAccountVerifier(
        client: MockClient((r) async {
          expect(r.url.host, 'www.googleapis.com');
          expect(r.url.queryParameters['fields'], 'user(emailAddress)');
          expect(r.headers['Authorization'], 'Bearer token');
          return http.Response(
            '{"user":{"emailAddress":"owner@example.com"}}',
            200,
          );
        }),
      );
      await verifier.verify('token', 'OWNER@example.com');
      await expectLater(
        verifier.verify('token', 'another@example.com'),
        throwsA(isA<VaultFailure>()),
      );
    },
  );
  test('A missing Drive identity does not unlock a vault', () async {
    final verifier = DriveAccountVerifier(
      client: MockClient((_) async => http.Response('{"user":{}}', 200)),
    );
    await expectLater(
      verifier.verify('token', 'owner@example.com'),
      throwsA(isA<VaultFailure>()),
    );
  });
  test(
    'Disabled Drive API produces an actionable configuration error',
    () async {
      final verifier = DriveAccountVerifier(
        client: MockClient(
          (_) async =>
              http.Response('{"error":{"reason":"accessNotConfigured"}}', 403),
        ),
      );
      await expectLater(
        verifier.verify('token', 'owner@example.com'),
        throwsA(
          isA<VaultFailure>().having(
            (e) => e.message,
            'message',
            contains('Enable Google Drive API'),
          ),
        ),
      );
    },
  );
}
