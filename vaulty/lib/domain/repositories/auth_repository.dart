class VaultPreferences {
  const VaultPreferences({
    this.theme = 'system',
    this.biometric = false,
    this.reminderDays = 30,
    this.noticeSeen = false,
    this.remindersEnabled = false,
  });
  final String theme;
  final bool biometric, noticeSeen, remindersEnabled;
  final int reminderDays;
  VaultPreferences copyWith({
    String? theme,
    bool? biometric,
    int? reminderDays,
    bool? noticeSeen,
    bool? remindersEnabled,
  }) => VaultPreferences(
    theme: theme ?? this.theme,
    biometric: biometric ?? this.biometric,
    reminderDays: reminderDays ?? this.reminderDays,
    noticeSeen: noticeSeen ?? this.noticeSeen,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
  );
}

abstract interface class AuthRepository {
  Future<String?> currentUser();
  Future<String> signIn();
  Future<void> signOut();
  Future<VaultPreferences> preferences();
  Future<void> savePreferences(VaultPreferences value);
  Future<void> deleteMyData();
}
