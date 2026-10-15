import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'renewal_bridge.dart';
import '../../core/l10n/app_strings.dart';
import '../../domain/models/document.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/live_capabilities.dart';

class DeviceServices {
  int _scheduleGeneration = 0;
  Future<bool> lockEnabled(String owner) async =>
      supported &&
      ((await SharedPreferences.getInstance()).getBool('vaulty.lock.$owner') ??
          false);
  Future<void> setLockEnabled(String owner, bool enabled) async {
    if (supported) {
      await (await SharedPreferences.getInstance()).setBool(
        'vaulty.lock.$owner',
        enabled,
      );
    }
  }

  Future<void> clearLock(String owner) async {
    if (supported) {
      await (await SharedPreferences.getInstance()).remove(
        'vaulty.lock.$owner',
      );
    }
  }

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final notifications = FlutterLocalNotificationsPlugin();
  Future<void>? _init;
  Future<void> initialize() => _init ??= _initialize();
  Future<void> _initialize() async {
    if (!supported) return;
    RenewalBridge.instance.initialize();
    await notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_vaulty'),
      ),
    );
    final p = await SharedPreferences.getInstance();
    if (p.getBool('vaulty.reminders.v4.migrated') != true) {
      await notifications.cancelAll();
      await p.setBool('vaulty.reminders.v4.migrated', true);
    }
  }

  Future<bool> enableReminders() async {
    if (!supported) {
      throw const VaultFailure(
        'Local reminders are available in the Android app, not this browser build.',
      );
    }
    await initialize();
    return await notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  Future<void> synchronize(
    List<Document> docs,
    VaultPreferences prefs, {
    String? owner,
  }) async {
    if (!supported || owner == null) return;
    final generation = ++_scheduleGeneration;
    await initialize();
    if (generation != _scheduleGeneration) return;
    await RenewalBridge.channel.invokeMethod<void>('update', {
      'owner': owner,
      'enabled': prefs.remindersEnabled,
      'days': prefs.reminderDays,
      'language': AppStrings.language,
      'dates': [
        for (final d in docs)
          if (!d.isDeleted && d.renewalRequired && d.expiry != null)
            '${d.expiry!.year.toString().padLeft(4, '0')}-${d.expiry!.month.toString().padLeft(2, '0')}-${d.expiry!.day.toString().padLeft(2, '0')}',
      ],
    });
  }

  Future<void> cancelReminders() async {
    _scheduleGeneration++;
    if (supported) {
      await initialize();
      await RenewalBridge.channel.invokeMethod<void>('clear');
    }
  }

  Future<void> unlock() async {
    if (!supported) {
      throw const VaultFailure(
        'Biometric lock is available in the Android app only.',
      );
    }
    final auth = LocalAuthentication();
    if (!await auth.canCheckBiometrics ||
        (await auth.getAvailableBiometrics()).isEmpty) {
      throw const VaultFailure(
        'Set up a fingerprint or face unlock in Android settings first.',
      );
    }
    final ok = await auth.authenticate(
      localizedReason: AppStrings.translate(
        'Unlock your private Vaulty documents',
        AppStrings.language,
      ),
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
    if (!ok) throw const VaultFailure('Vaulty remains locked.');
  }
}
