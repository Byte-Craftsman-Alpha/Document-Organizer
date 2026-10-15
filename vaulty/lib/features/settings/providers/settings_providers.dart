import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/bootstrap.dart';
import 'ui_preferences.dart';
import '../../../domain/repositories/auth_repository.dart';

final settingsProvider =
    AsyncNotifierProvider<SettingsController, VaultPreferences>(
      SettingsController.new,
    );
final themeModeProvider = Provider<ThemeMode>(
  (ref) => switch (ref.watch(uiPreferencesProvider).theme ??
      ref.watch(settingsProvider).valueOrNull?.theme) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  },
);

class SettingsController extends AsyncNotifier<VaultPreferences> {
  @override
  Future<VaultPreferences> build() {
    ref.watch(vaultIdentityProvider);
    return ref.watch(authRepositoryProvider).preferences();
  }

  Future<void> save(VaultPreferences value) async {
    final owner = ref.read(vaultIdentityProvider);
    final old = state;
    final securityChange = old.valueOrNull?.biometric != value.biometric;
    if (!securityChange) state = AsyncData(value);
    try {
      await ref.read(authRepositoryProvider).savePreferences(value);
      if (ref.read(vaultIdentityProvider) == owner) state = AsyncData(value);
    } catch (_) {
      if (ref.read(vaultIdentityProvider) == owner) {
        state = old;
        ref.invalidateSelf();
      }
      rethrow;
    }
  }
}
