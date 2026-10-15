import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import '../../domain/repositories/live_capabilities.dart';
import 'account_verifier.dart';

abstract interface class DriveIdentity {
  String? get owner;
  int get generation;
  Future<String> token();
  Future<void> rejectToken(String token);
}

class GoogleIdentity implements DriveIdentity {
  GoogleIdentity({required this.webClientId});
  final String webClientId;
  String? startupError;
  final _verifier = DriveAccountVerifier();
  String? _verifiedToken, _verifiedAccount;
  static const scopes = ['https://www.googleapis.com/auth/drive.appdata'];
  final _changes = StreamController<AccountConnection>.broadcast();
  Stream<AccountConnection> get changes => _changes.stream;
  AccountConnection connection = const AccountConnection();
  GoogleSignInAccount? _user;
  Future<void>? _initialization;
  bool _interactive = false;
  void Function(Map<String, dynamic> account)? onAccountAuthorized;

  @override
  int generation = 0;
  @override
  String? get owner => connection.vaultIdentity;
  String? get configurationError =>
      startupError ??
      (webClientId.isEmpty ||
              !webClientId.endsWith('.apps.googleusercontent.com')
          ? 'This build is not configured for Google. The developer must set GOOGLE_WEB_CLIENT_ID and register the Android signing certificate or this website’s origin. See START_HERE.md.'
          : null);

  void _emit({bool ready = false, String? error}) {
    connection = AccountConnection(
      id: _user?.id ?? connection.id,
      name: _user?.displayName ?? connection.name,
      email: _user?.email ?? connection.email,
      driveReady: ready,
      error: error,
    );
    _changes.add(connection);
  }

  void restoreSession(Map<String, dynamic> account) {
    _verifiedToken = null;
    _verifiedAccount = null;
    connection = AccountConnection(
      id: account['id'] as String?,
      name: account['name'] as String?,
      email: account['email'] as String?,
      driveReady: true,
      offline: false,
    );
    _changes.add(connection);
  }

  Future<void> initialize({bool skipLightweightAuth = false}) =>
      _initialization ??= _initialize(skipLightweightAuth: skipLightweightAuth);

  Future<void> _initialize({bool skipLightweightAuth = false}) async {
    if (configurationError != null) {
      return;
    }
    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? webClientId : null,
      serverClientId: kIsWeb ? null : webClientId,
    );
    GoogleSignIn.instance.authenticationEvents.listen(
      (event) {
        if (_interactive) {
          return;
        }
        if (event is GoogleSignInAuthenticationEventSignIn) {
          unawaited(_accept(event.user));
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          generation++;
          _user = null;
          _emit();
        }
      },
      onError: (Object e) => _emit(
        error:
            'Google sign-in failed. Check the app’s OAuth configuration, then try again.',
      ),
    );
    if (!skipLightweightAuth) {
      final attempt = GoogleSignIn.instance.attemptLightweightAuthentication();
      if (attempt != null) {
        try {
          final user = await attempt;
          if (user != null) {
            await _accept(user);
          }
        } catch (_) {
          /* User may sign in explicitly. */
        }
      }
    }
  }

  Future<void> _verify(
    String accountId,
    String email,
    String accessToken,
  ) async {
    final epoch = generation;
    final currentId = _user?.id ?? connection.id;
    if (currentId != null && currentId != accountId) {
      throw const VaultFailure('The Google account changed. Try again.');
    }
    if (_verifiedToken == accessToken && _verifiedAccount == accountId) {
      return;
    }
    try {
      await _verifier.verify(accessToken, email);
    } catch (e) {
      await rejectToken(accessToken);
      if (epoch == generation) {
        _emit(error: e is VaultFailure ? e.message : 'Reconnect Google Drive.');
      }
      rethrow;
    }
    if (epoch != generation) {
      throw const VaultFailure('The Google account changed. Try again.');
    }
    _verifiedToken = accessToken;
    _verifiedAccount = accountId;
  }

  Future<void> _accept(GoogleSignInAccount user) async {
    if (_user?.id == user.id && connection.driveReady) {
      return;
    }
    if (_user?.id != user.id) {
      generation++;
    }
    _user = user;
    _emit();
    final epoch = generation;
    try {
      final grant = await user.authorizationClient.authorizationForScopes(
        scopes,
      );
      if (grant != null) {
        await _verify(user.id, user.email, grant.accessToken);
      }
      if (epoch == generation) {
        _emit(ready: grant != null);
        if (grant != null) {
          onAccountAuthorized?.call({
            'id': user.id,
            'name': user.displayName,
            'email': user.email,
          });
        }
      }
    } catch (e) {
      if (epoch == generation) {
        _emit(error: e is VaultFailure ? e.message : null);
      }
    }
  }

  Future<String> authorize() async {
    if (_interactive) {
      throw const VaultFailure(
        'Finish the current Google sign-in prompt first.',
      );
    }
    if (configurationError != null) {
      throw VaultFailure(configurationError!);
    }
    await initialize();
    _interactive = true;
    try {
      if (_user == null) {
        if (kIsWeb) {
          throw const VaultFailure(
            'Use the Google sign-in button first, then connect Drive.',
          );
        }
        final user = await GoogleSignIn.instance.authenticate();
        if (_user?.id != user.id) {
          generation++;
        }
        _user = user;
      }
      final user = _user!;
      final epoch = generation;
      final grant = await user.authorizationClient.authorizeScopes(scopes);
      if (epoch != generation || _user?.id != user.id) {
        throw const VaultFailure(
          'Sign-in stopped because the account changed. Please try again.',
        );
      }
      await _verify(user.id, user.email, grant.accessToken);
      _emit(ready: true);
      onAccountAuthorized?.call({
        'id': user.id,
        'name': user.displayName,
        'email': user.email,
      });
      return user.displayName ?? user.email;
    } on GoogleSignInException catch (e) {
      _emit(
        error: e.code == GoogleSignInExceptionCode.canceled
            ? 'Sign-in was cancelled or could not complete. If this repeats after selecting an account, check the package name, signing SHA-1 and Web client ID.'
            : 'Google could not authorize this app. Check the OAuth client and signing certificate.',
      );
      throw VaultFailure(connection.error!);
    } finally {
      _interactive = false;
    }
  }

  void useOffline(Map<String, dynamic> account) {
    generation++;
    _user = null;
    _verifiedToken = null;
    _verifiedAccount = null;
    connection = AccountConnection(
      id: account['id'],
      name: account['name'],
      email: account['email'],
      driveReady: true,
      offline: true,
    );
    _changes.add(connection);
  }

  @override
  Future<String> token() async {
    if (connection.offline) {
      throw const DriveOfflineFailure();
    }
    final epoch = generation;
    if (!connection.driveReady) {
      throw const VaultFailure('Connect Google Drive to continue.');
    }
    final accountId = connection.id ?? connection.email;
    if (accountId == null) {
      throw const VaultFailure('Connect Google Drive to continue.');
    }
    if (_verifiedToken != null && _verifiedAccount == accountId) {
      return _verifiedToken!;
    }
    String? accessToken;
    final user = _user;
    if (user != null) {
      final grant = await user.authorizationClient.authorizationForScopes(
        scopes,
      );
      accessToken = grant?.accessToken;
    } else if (connection.email != null) {
      try {
        final tokenData = await GoogleSignInPlatform.instance
            .clientAuthorizationTokensForScopes(
              ClientAuthorizationTokensForScopesParameters(
                request: AuthorizationRequestDetails(
                  scopes: scopes,
                  userId: connection.id,
                  email: connection.email,
                  promptIfUnauthorized: false,
                ),
              ),
            );
        accessToken = tokenData?.accessToken;
      } catch (_) {
        _emit(
          error: 'Drive access is missing or expired. Connect Drive again.',
        );
        throw const VaultFailure(
          'Drive access is missing or expired. Connect Drive again.',
        );
      }
    }
    if (epoch != generation) {
      throw const VaultFailure('The Google account changed. Please retry.');
    }
    if (accessToken == null) {
      _emit(error: 'Drive access is missing or expired. Connect Drive again.');
      throw const VaultFailure(
        'Drive access is missing or expired. Connect Drive again.',
      );
    }
    await _verify(accountId, connection.email!, accessToken);
    return accessToken;
  }

  @override
  Future<void> rejectToken(String token) async {
    _verifiedToken = null;
    _verifiedAccount = null;
    try {
      if (_user != null) {
        await _user?.authorizationClient.clearAuthorizationToken(
          accessToken: token,
        );
      } else {
        await GoogleSignInPlatform.instance.clearAuthorizationToken(
          ClearAuthorizationTokenParams(accessToken: token),
        );
      }
    } finally {
      _emit(
        error: 'Your Google session needs permission again. Reconnect Drive.',
      );
    }
  }

  Future<void> signOut() async {
    _verifiedToken = null;
    _verifiedAccount = null;
    generation++;
    _user = null;
    connection = const AccountConnection();
    _changes.add(connection);
    await GoogleSignIn.instance.signOut();
  }
}
