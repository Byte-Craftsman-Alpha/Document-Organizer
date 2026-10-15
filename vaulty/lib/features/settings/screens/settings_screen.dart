import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/appearance_panel.dart';
import '../widgets/reminder_panel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/bootstrap.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../documents/providers/document_providers.dart';
import '../../insights/providers/insights_providers.dart';
import '../../insights/widgets/storage_card.dart';
import '../../search/providers/search_providers.dart';
import '../providers/settings_providers.dart';
import '../../../domain/repositories/live_capabilities.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool busy = false;
  Future<void> save(VaultPreferences p) async {
    try {
      await ref.read(settingsProvider.notifier).save(p);
    } catch (_) {
      if (mounted) {
        notice(context, 'Couldn’t save that preference. Please retry.');
      }
    }
  }

  Future<void> export() async {
    setState(() => busy = true);
    try {
      await ref.read(documentRepositoryProvider).exportBackup();
      if (mounted) {
        notice(
          context,
          ref.read(liveModeProvider)
              ? 'Backup prepared. Save it using your device’s download or file picker.'
              : 'Backup export preview complete. No archive is created in this demo.',
        );
      }
    } catch (_) {
      if (mounted) {
        notice(context, 'Couldn’t preview the export. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> signOut() async {
    if (!await AppDialog.confirm(
      context,
      title: 'Sign out?',
      message:
          'Your Drive documents stay safe. Encrypted offline files, pending imports and local recent browsing history are cleared on this device.',
      confirmLabel: 'Sign out',
      destructive: false,
    )) {
      return;
    }
    try {
      await ref.read(sessionProvider.notifier).signOut();
      if (mounted) context.go('/login');
    } catch (_) {
      if (mounted) notice(context, 'Couldn’t sign out. Please try again.');
    }
  }

  Future<void> deleteData() async {
    if (!await AppDialog.confirm(
      context,
      title: 'Delete all your data?',
      message: ref.read(liveModeProvider)
          ? 'This permanently deletes all Vaulty documents, settings and legacy app records in your connected Google Drive app folder. It cannot be undone. Other Drive files are not touched. Copies already exported are not deleted.'
          : 'This permanently deletes every document, share and audit record in this demo. It cannot be undone. This does not touch Google Drive.',
      confirmLabel: 'Delete my data',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await ref.read(authRepositoryProvider).deleteMyData();
      ref.invalidate(documentsProvider);
      ref.read(documentsProvider.notifier).refreshRelated();
      ref.invalidate(settingsProvider);
      ref.invalidate(recentSearchesProvider);
      ref.invalidate(savedSearchesProvider);
      ref.invalidate(sessionProvider);
      if (mounted) context.go('/login');
    } catch (_) {
      if (mounted) notice(context, 'Couldn’t delete your data. Please retry.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Make yourself at home.',
    subtitle: 'A vault that feels like yours.',
    children: [
      const AppCard(child:AppearancePanel()),
      if (ref.watch(liveModeProvider))
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('Connected Google account'),
              Text(
                ref.watch(accountConnectionProvider).valueOrNull?.email ??
                    'Google account',
              ),
              const SizedBox(height: Space.md),
              AppButton(
                label: 'Reconnect Drive',
                secondary: true,
                onPressed: () async {
                  await ref.read(sessionProvider.notifier).signIn();
                  ref.invalidate(documentsProvider);
                  ref.invalidate(settingsProvider);
                },
              ),
            ],
          ),
        ),
      AsyncPanel(
        value: ref.watch(settingsProvider),
        onRetry: () => ref.invalidate(settingsProvider),
        builder: (prefs) => AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPress(
                child: SwitchListTile(
                  title: const AppText('Biometric lock'),
                  subtitle: AppText(
                    ref.watch(liveModeProvider)
                        ? 'Lock access to this app on this device'
                        : 'UI only · no device authentication',
                  ),
                  value: prefs.biometric,
                  onChanged: (v) async {
                    final repository = ref.read(documentRepositoryProvider);
                    if (repository is LiveDocumentRepository) {
                      try {
                        await repository.lockChallenge();
                      } catch (e) {
                        if (context.mounted) {
                          notice(
                            context,
                            e is VaultFailure
                                ? e.message
                                : 'Device authentication unavailable.',
                          );
                        }
                        return;
                      }
                    }
                    await save(prefs.copyWith(biometric: v));
                  },
                ),
              ),
              const SizedBox(height: Space.md),
              const Divider(),
              const SizedBox(height: Space.md),
              DropdownButtonFormField<int>(
                initialValue: prefs.reminderDays,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.tr('Remind me before expiry'),
                ),
                items: [7, 14, 30]
                    .map(
                      (n) => DropdownMenuItem(
                        value: n,
                        child: AppText('$n days before'),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) save(prefs.copyWith(reminderDays: v));
                },
              ),
              const SizedBox(height: Space.md),
              if (ref.watch(liveModeProvider))
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: prefs.remindersEnabled
                        ? 'Disable renewal reminders'
                        : 'Allow renewal reminders',
                    secondary: true,
                    onPressed: () async {
                      final repo =
                          ref.read(documentRepositoryProvider)
                              as LiveDocumentRepository;
                      try {
                        final allowed = prefs.remindersEnabled
                            ? false
                            : await repo.enableReminders();
                        if (!allowed &&
                            !prefs.remindersEnabled &&
                            context.mounted) {
                          notice(
                            context,
                            'Notifications were not allowed. You can enable them in Android settings.',
                          );
                        }
                        await save(prefs.copyWith(remindersEnabled: allowed));
                      } catch (e) {
                        if (context.mounted) {
                          notice(
                            context,
                            e is VaultFailure
                                ? e.message
                                : 'Couldn’t update device reminders.',
                          );
                        }
                      }
                    },
                  ),
                ),
              const SizedBox(height: Space.md),
              if(ref.watch(liveModeProvider)) const ReminderPanel(),
            ],
          ),
        ),
      ),
      AsyncPanel(
        value: ref.watch(storageProvider),
        onRetry: () => ref.invalidate(storageProvider),
        builder: (s) => StorageCard(storage: s),
      ),
      if (ref.watch(documentRepositoryProvider) is CachedDocumentRepository)
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                'Offline files',
                subtitle: 'Encrypted Android cache · cleared on sign-out',
              ),
              const AppText(
                'Only previously downloaded versions work offline. Changes made elsewhere cannot be detected until you reconnect. Browser caching lasts only for this session.',
              ),
              const SizedBox(height: Space.md),
              AppButton(
                label: 'Clear offline cache',
                secondary: true,
                onPressed: busy
                    ? null
                    : () async {
                        if (!await AppDialog.confirm(
                          context,
                          title: 'Clear offline files?',
                          message:
                              'Drive originals stay untouched. Cached files and local browsing recents will be removed from this device.',
                          confirmLabel: 'Clear cache',
                        )) {
                          return;
                        }
                        try {
                          await (ref.read(documentRepositoryProvider)
                                  as CachedDocumentRepository)
                              .clearCache();
                          ref.read(documentsProvider.notifier).refreshRelated();
                          if (context.mounted) {
                            notice(context, 'Offline cache cleared');
                          }
                        } catch (_) {
                          if (context.mounted) {
                            notice(
                              context,
                              'Could not clear the cache. Try again.',
                            );
                          }
                        }
                      },
              ),
            ],
          ),
        ),
      AppCard(
        child: Column(
          children: [
            AppListTile(
              leading: const Icon(Icons.delete_outline),
              title: const AppText('Trash'),
              subtitle: const AppText('Restore recently deleted documents'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/trash'),
            ),
            AppListTile(
              leading: const Icon(Icons.download_outlined),
              title: const AppText('Export backup'),
              subtitle: AppText(
                ref.watch(liveModeProvider)
                    ? 'ZIP of files and metadata · keep the backup private'
                    : 'Preview only',
              ),
              onTap: busy ? null : export,
            ),
            if (busy) const SkeletonBox(height: Metrics.touch),
            if (kDebugMode)
              AppListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const AppText('Design gallery'),
                subtitle: const AppText('Debug · tokens & components'),
                onTap: () => context.push('/gallery'),
              ),
          ],
        ),
      ),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('A note about your Drive'),
            AppText(
              'Clearing Vaulty’s hidden app data in Google Drive deletes all documents. Vaulty is designed to use your own Drive appData folder, not a separate storage account.',
              style: context.mutedBody,
            ),
            const SizedBox(height: Space.sm),
            AppText(
              ref.watch(liveModeProvider)
                  ? 'Drive holds your originals. Android caches recently opened files encrypted on this device (up to 256 MB, oldest evicted first). Cached versions are checked online before use. Opening or sharing creates temporary decrypted copies for other apps; those apps can keep their own copies. This is not end-to-end encryption. Browser cache is session-only.'
                  : 'In this demo, all data is temporary and resets when the app restarts.',
              style: context.mutedCaption,
            ),
          ],
        ),
      ),
      AppButton(
        label: 'Sign out',
        secondary: true,
        onPressed: busy ? null : signOut,
      ),
      AppButton(
        label: 'Delete my data',
        danger: true,
        onPressed: busy ? null : deleteData,
      ),
    ],
  );
}
