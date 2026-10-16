import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/drive/google_identity.dart';
import '../data/drive/drive_api.dart';
import '../data/drive/drive_store.dart';
import '../data/drive/live_repositories.dart';
import '../data/device/device_services.dart';
import 'bootstrap.dart';
import '../data/cache/cache_factory.dart';
import '../data/device/incoming_share.dart';

Future<List<Override>> liveOverrides({String? clientId}) async {
  const definedId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  String bundledId = '';
  if (clientId == null && definedId.isEmpty) {
    try {
      final config =
          jsonDecode(await rootBundle.loadString('assets/config/google.json'))
              as Map<String, dynamic>;
      bundledId = (config['GOOGLE_WEB_CLIENT_ID'] as String? ?? '').trim();
    } catch (_) {
      /* Missing configuration shows a setup screen; never switches to demo. */
    }
  }
  IncomingShare.instance.initialize();
  final google = GoogleIdentity(
    webClientId: clientId ?? (definedId.isNotEmpty ? definedId : bundledId),
  );
  final store = DriveStore(DriveApi(google), cache: createVaultCache());
  final device = DeviceServices();
  final auth = GoogleAuthRepository(google, store, device);
  try {
    await auth.initialize().timeout(const Duration(seconds: 4));
  } catch (e) {
    debugPrint('auth.initialize non-fatal startup notice: $e');
  }
  return [
    authRepositoryProvider.overrideWithValue(auth),
    documentRepositoryProvider.overrideWithValue(
      DriveDocumentRepository(store, device),
    ),
    insightsRepositoryProvider.overrideWithValue(
      DriveInsightsRepository(store),
    ),
    shareRepositoryProvider.overrideWithValue(PrivateShareRepository()),
    searchRepositoryProvider.overrideWithValue(DriveSearchRepository(store)),
  ];
}
