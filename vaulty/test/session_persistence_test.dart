import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:vaulty/app/bootstrap.dart';
import 'package:vaulty/app/router.dart';
import 'package:vaulty/data/cache/vault_cache.dart';
import 'package:vaulty/data/device/device_services.dart';
import 'package:vaulty/data/drive/drive_api.dart';
import 'package:vaulty/data/drive/drive_store.dart';
import 'package:vaulty/data/drive/google_identity.dart';
import 'package:vaulty/data/drive/live_repositories.dart';
import 'package:vaulty/features/auth/providers/auth_providers.dart';
import 'package:vaulty/data/device/incoming_share.dart';

class TestDeviceServices extends DeviceServices {
  @override
  bool get supported => false;
}

class FakeGoogleSignInPlatform extends GoogleSignInPlatform {
  @override
  Future<void> init(InitParameters params) async {}

  @override
  Future<void> signOut(SignOutParams params) async {}

  @override
  Future<void> disconnect(DisconnectParams params) async {}

  @override
  Stream<AuthenticationEvent>? get authenticationEvents => const Stream.empty();

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) =>
      null;

  @override
  bool supportsAuthenticate() => true;

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<AuthenticationResults> authenticate(AuthenticateParameters params) async =>
      throw UnimplementedError();

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async =>
      null;

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async =>
      null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleSignInPlatform.instance = FakeGoogleSignInPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(IncomingShare.channel, (call) async => null);
  });

  group('Session Persistence Tests', () {
    test('Session is restored from cache on app startup without showing login', () async {
      final cache = MemoryVaultCache();
      // Simulate previously saved account in secure storage
      await cache.rememberAccount({
        'id': 'user_123',
        'name': 'Aditya Chaudhari',
        'email': 'aditya@teamparadox.in',
      });

      final identity = GoogleIdentity(webClientId: 'test.apps.googleusercontent.com');
      final store = DriveStore(DriveApi(identity), cache: cache);
      final device = TestDeviceServices();
      final auth = GoogleAuthRepository(identity, store, device);

      // Initialize should restore session automatically
      await auth.initialize();

      expect(auth.connection.driveReady, isTrue);
      expect(auth.connection.email, 'aditya@teamparadox.in');
      expect(auth.connection.name, 'Aditya Chaudhari');
      expect(await auth.currentUser(), 'Aditya Chaudhari');

      // Verify router initializes to /home when session exists
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);

      final session = container.read(sessionProvider);
      expect(session.valueOrNull, 'Aditya Chaudhari');

      final router = container.read(routerProvider);
      // initialLocation should be /home because initialLoggedIn is true
      expect(router.routeInformationProvider.value.uri.path, '/home');
    });

    test('First-time app launch without saved session defaults to /login', () async {
      final cache = MemoryVaultCache();
      // No saved account in cache

      final identity = GoogleIdentity(webClientId: 'test.apps.googleusercontent.com');
      final store = DriveStore(DriveApi(identity), cache: cache);
      final device = TestDeviceServices();
      final auth = GoogleAuthRepository(identity, store, device);

      await auth.initialize();

      expect(auth.connection.driveReady, isFalse);
      expect(await auth.currentUser(), isNull);

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);

      final session = container.read(sessionProvider);
      expect(session.valueOrNull, isNull);

      final router = container.read(routerProvider);
      expect(router.routeInformationProvider.value.uri.path, '/login');
    });

    test('Explicit sign-out clears remembered account and persists across restarts', () async {
      final cache = MemoryVaultCache();
      await cache.rememberAccount({
        'id': 'user_123',
        'name': 'Aditya Chaudhari',
        'email': 'aditya@teamparadox.in',
      });

      final identity = GoogleIdentity(webClientId: 'test.apps.googleusercontent.com');
      final store = DriveStore(DriveApi(identity), cache: cache);
      final device = TestDeviceServices();
      final auth = GoogleAuthRepository(identity, store, device);

      // Restore session
      await auth.initialize();
      expect(auth.connection.driveReady, isTrue);

      // Explicitly sign out
      await auth.signOut();

      // Verify connection is cleared
      expect(auth.connection.driveReady, isFalse);
      expect(auth.connection.email, isNull);

      // Verify cache is cleared
      final savedAccount = await cache.lastAccount();
      expect(savedAccount, isNull);

      // Simulate subsequent cold start: fresh GoogleAuthRepository on same cache
      final identityRestart = GoogleIdentity(webClientId: 'test.apps.googleusercontent.com');
      final storeRestart = DriveStore(DriveApi(identityRestart), cache: cache);
      final authRestart = GoogleAuthRepository(identityRestart, storeRestart, device);

      await authRestart.initialize();

      // Should NOT be logged in
      expect(authRestart.connection.driveReady, isFalse);
      expect(await authRestart.currentUser(), isNull);
    });
  });
}
