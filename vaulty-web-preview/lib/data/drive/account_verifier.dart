import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/repositories/live_capabilities.dart';

/// A login hint is not an account-isolation boundary. Confirm the Drive token's
/// actual owner before exposing a vault, including after token refresh.
class DriveAccountVerifier {
  DriveAccountVerifier({http.Client? client})
    : client = client ?? http.Client();
  final http.Client client;
  Future<void> verify(String token, String expectedEmail) async {
    late http.Response response;
    try {
      response = await client
          .get(
            Uri.https('www.googleapis.com', '/drive/v3/about', {
              'fields': 'user(emailAddress)',
            }),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const VaultFailure(
        'Couldn’t verify the connected Drive account. Check your connection and try again.',
      );
    }
    if (response.statusCode != 200) {
      final body = response.body.toLowerCase();
      if (body.contains('accessnotconfigured') ||
          body.contains('service_disabled')) {
        throw const VaultFailure(
          'Enable Google Drive API in the Google Cloud project, then connect again.',
        );
      }
      throw const VaultFailure(
        'Google Drive authorization could not be verified. Grant Drive access and check that this account is an allowed test user.',
      );
    }
    String? actual;
    try {
      actual =
          (jsonDecode(response.body)
                  as Map<String, dynamic>)['user']?['emailAddress']
              as String?;
    } catch (_) {
      throw const VaultFailure(
        'Drive returned an unreadable account response. Try again.',
      );
    }
    if (actual == null ||
        actual.trim().toLowerCase() != expectedEmail.trim().toLowerCase()) {
      throw const VaultFailure(
        'Drive was authorized with a different Google account. Use the same account for sign-in and Drive permission. No vault was opened.',
      );
    }
  }
}
