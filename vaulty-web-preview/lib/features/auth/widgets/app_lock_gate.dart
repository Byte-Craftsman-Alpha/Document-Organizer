import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/bootstrap.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/repositories/live_capabilities.dart';
import '../../settings/providers/settings_providers.dart';
import '../../documents/providers/collection_providers.dart';
import '../../search/providers/search_providers.dart';
import '../providers/auth_providers.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool unlocked = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!busy &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden)) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => unlocked = false);
    }
  }

  Future<void> unlock(LiveDocumentRepository repo) async {
    setState(() => busy = true);
    try {
      await repo.lockChallenge();
      if (mounted) setState(() => unlocked = true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is VaultFailure
              ? e.message
              : 'Device authentication could not complete.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // Keep Navigator/form/picker futures alive while hiding paint, focus and semantics.
  // Removing the child here would discard a picked file whenever Android pauses for the system picker.
  Widget protect(Widget? overlay) => Stack(
    fit: StackFit.expand,
    children: [
      Offstage(
        offstage: overlay != null,
        child: TickerMode(enabled: overlay == null, child: widget.child),
      ),
      ?overlay,
    ],
  );
  @override
  Widget build(BuildContext context) {
    ref.listen(vaultIdentityProvider, (previous, next) {
      if (previous != next) {
        unlocked = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            clearNotices(context);
          }
        });
        ref.invalidate(quickQueryProvider);
        ref.invalidate(quickTypeProvider);
        ref.invalidate(quickSortProvider);
        ref.invalidate(searchQueryProvider);
        ref.invalidate(searchFilterProvider);
      }
    });
    final repo = ref.watch(documentRepositoryProvider);
    final live = repo is LiveDocumentRepository && repo.supportsDeviceFeatures;
    final connected = ref.watch(vaultIdentityProvider) != null;
    final prefs = ref.watch(settingsProvider);
    if (!live || !connected) return protect(null);
    if (prefs.isLoading) {
      return protect(
        const Scaffold(
          body: SafeArea(
            child: Padding(padding: Space.page, child: LoadingList()),
          ),
        ),
      );
    }
    if (prefs.hasError) {
      return protect(
        Scaffold(
          body: SafeArea(
            child: Padding(
              padding: Space.page,
              child: EmptyState(
                title: 'Couldn’t open your vault',
                message: prefs.error is VaultFailure
                    ? (prefs.error as VaultFailure).message
                    : 'Reconnect Drive or retry before opening the vault.',
                action: Column(
                  children: [
                    AppButton(
                      label: 'Retry',
                      onPressed: () => ref.invalidate(settingsProvider),
                    ),
                    AppTextButton(
                      onPressed: () =>
                          ref.read(sessionProvider.notifier).signOut(),
                      child: const AppText('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (!(prefs.valueOrNull?.biometric ?? false) || unlocked) {
      return protect(null);
    }
    return protect(
      Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: Space.page,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: Metrics.logo),
                  const SizedBox(height: Space.lg),
                  AppText(
                    'Your vault is locked',
                    style: context.type.titleLarge,
                  ),
                  const SizedBox(height: Space.lg),
                  AppButton(
                    label: 'Unlock Vaulty',
                    onPressed: busy ? null : () => unlock(repo),
                  ),
                  if (error != null) Text(error!, style: context.dangerLabel),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
