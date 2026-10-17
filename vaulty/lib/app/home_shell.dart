import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/app_widgets.dart';
import '../features/settings/providers/settings_providers.dart';
import '../features/upload/widgets/source_sheet.dart';
import 'bootstrap.dart';
import '../data/device/incoming_share.dart';
import '../data/device/renewal_bridge.dart';
import '../domain/repositories/auth_repository.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    duration: Motion.normal,
    value: 1,
  );
  @override
  void initState() {
    super.initState();
    IncomingShare.instance.revision.addListener(checkIncoming);
    RenewalBridge.instance.requests.addListener(checkRenewal);
    WidgetsBinding.instance.addPostFrameCallback((_) => checkRenewal());
    WidgetsBinding.instance.addPostFrameCallback((_) => checkIncoming());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      VaultPreferences prefs;
      try {
        prefs = await ref.read(settingsProvider.future);
      } catch (_) {
        return;
      }
      if (!mounted || prefs.noticeSeen) return;
      await showAppDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const AppText('Your Drive. Your documents.'),
          content: AppText(
            ref.read(liveModeProvider)
                ? 'Your files and document metadata are stored in the hidden appData folder of your Google Drive. No Vaulty backend stores them. Clearing Vaulty’s hidden app data in Drive deletes your vault. Share a copy exports data outside the vault and cannot be revoked. Trash is purged after 30 days when the app next syncs.'
                : 'Vaulty is designed to use the hidden appData folder in your own Google Drive. Clearing Vaulty’s hidden app data in Drive deletes all your documents.\n\nThis demo uses temporary mock data only. No files are sent to Google Drive.',
          ),
          actions: [
            AppButton(
              label: 'I understand',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      if (!mounted) return;
      try {
        await ref
            .read(settingsProvider.notifier)
            .save(prefs.copyWith(noticeSeen: true));
      } catch (_) {
        if (mounted) notice(context, 'Couldn’t save the notice preference.');
      }
    });
  }

  Future<void> checkRenewal() async {
    if (!mounted) return;
    if (!ref.read(liveModeProvider)) return;
    try {
      if (await RenewalBridge.instance.takeOpen() && mounted) {
        context.go('/home');
      }
      await RenewalBridge.instance.check();
    } catch (_) {}
  }

  bool reviewing = false;
  Future<void> checkIncoming() async {
    if (!mounted) return;
    if (!ref.read(liveModeProvider) || reviewing) return;
    try {
      final pending = await IncomingShare.instance.pending();
      if (!mounted || reviewing || pending.isEmpty) return;
      reviewing = true;
      await context.push('/import');
      reviewing = false;
    } catch (_) {
      reviewing = false;
    }
  }

  @override
  void dispose() {
    IncomingShare.instance.revision.removeListener(checkIncoming);
    RenewalBridge.instance.requests.removeListener(checkRenewal);
    animation.dispose();
    super.dispose();
  }

  void select(int index) {
    HapticFeedback.selectionClick();
    if (index == 2) {
      showSourceSheet(context);
      return;
    }
    final branch = index > 2 ? index - 1 : index;
    if (branch == widget.shell.currentIndex) return;
    animation.duration = Motion.of(context, Motion.normal);
    animation.forward(from: 0);
    widget.shell.goBranch(branch);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: FadeTransition(opacity: animation, child: widget.shell),
    bottomNavigationBar: NavigationBar(
      selectedIndex: widget.shell.currentIndex >= 2
          ? widget.shell.currentIndex + 1
          : widget.shell.currentIndex,
      onDestinationSelected: select,
      destinations: [
        NavigationDestination(
          icon: const Icon(AppIcons.home),
          selectedIcon: const Icon(AppIcons.homeActive),
          label: context.tr('Home'),
        ),
        NavigationDestination(
          icon: const Icon(AppIcons.documents),
          selectedIcon: const Icon(AppIcons.documentsActive),
          label: context.tr('Documents'),
        ),
        NavigationDestination(
          icon: const Icon(AppIcons.upload),
          selectedIcon: const Icon(AppIcons.uploadActive),
          label: context.tr('Upload'),
        ),
        NavigationDestination(
          icon: const Icon(AppIcons.settings),
          selectedIcon: const Icon(AppIcons.settingsActive),
          label: context.tr('Settings'),
        ),
      ],
    ),
  );
}
