import 'bootstrap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/app_widgets.dart';
import '../core/widgets/design_gallery.dart';
import '../domain/repositories/document_repository.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/imports/screens/import_screen.dart';
import '../features/documents/screens/documents_screen.dart';
import '../features/documents/screens/document_detail_screen.dart';
import '../features/upload/screens/document_form_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/trash/screens/trash_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/providers/settings_providers.dart';
import 'home_shell.dart';

class VaultPage<T> extends Page<T> {
  const VaultPage({required this.child, super.key});
  final Widget child;
  @override
  Route<T> createRoute(BuildContext context) => _VaultRoute<T>(this);
}

class _VaultRoute<T> extends MaterialPageRoute<T> {
  _VaultRoute(VaultPage<T> page)
    : super(settings: page, builder: (_) => page.child);
  // GoRouter.replace can reuse a Page key; always read its current child.
  @override
  Widget buildContent(BuildContext context) => (settings as VaultPage<T>).child;
  @override
  Duration get transitionDuration => Motion.page;
  @override
  Duration get reverseTransitionDuration => Motion.page;
}

final routerProvider = Provider<GoRouter>((ref) {
  // A new account gets a fresh Navigator and branch/form state, not just new data providers.
  ref.watch(vaultIdentityProvider);
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    initialLocation: const bool.fromEnvironment('SHOW_GALLERY') && kDebugMode
        ? '/gallery'
        : '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      if (state.uri.path == '/gallery' && kDebugMode) return null;
      final auth = ref.read(sessionProvider);
      if (auth.isLoading) return null;
      final loggedIn = auth.valueOrNull != null;
      if (!loggedIn && state.uri.path != '/login') return '/login';
      if (loggedIn && state.uri.path == '/login') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/insights', redirect: (_, _) => '/home'),
      GoRoute(
        path: '/import',
        pageBuilder: (_, s) =>
            VaultPage(key: s.pageKey, child: const ImportScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, s) =>
            VaultPage(key: s.pageKey, child: const LoginScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (_, s) =>
                    VaultPage(key: s.pageKey, child: const HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/documents',
                pageBuilder: (_, s) =>
                    VaultPage(key: s.pageKey, child: const DocumentsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (_, s) =>
                    VaultPage(key: s.pageKey, child: const SettingsScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/upload',
        pageBuilder: (_, s) => VaultPage(
          key: s.pageKey,
          child: DocumentFormScreen(
            file: s.extra is SelectedFile ? s.extra! as SelectedFile : null,
          ),
        ),
      ),
      GoRoute(
        path: '/document/:id',
        pageBuilder: (_, s) => VaultPage(
          key: s.pageKey,
          child: DocumentDetailScreen(id: s.pathParameters['id']!),
        ),
        routes: [
          GoRoute(
            path: 'edit',
            pageBuilder: (_, s) => VaultPage(
              key: s.pageKey,
              child: DocumentFormScreen(id: s.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (_, s) =>
            VaultPage(key: s.pageKey, child: const SearchScreen()),
      ),
      GoRoute(
        path: '/trash',
        pageBuilder: (_, s) =>
            VaultPage(key: s.pageKey, child: const TrashScreen()),
      ),
      if (kDebugMode)
        GoRoute(
          path: '/gallery',
          pageBuilder: (context, s) => VaultPage(
            key: s.pageKey,
            child: DesignGallery(
              onTheme: (mode) async {
                final prefs = await ref.read(settingsProvider.future);
                try {
                  await ref
                      .read(settingsProvider.notifier)
                      .save(prefs.copyWith(theme: mode.name));
                } catch (_) {
                  if (context.mounted) {
                    notice(context, 'Couldn’t save theme. Try again.');
                  }
                }
              },
            ),
          ),
        ),
    ],
    errorBuilder: (context, _) => AppPage(
      title: 'A page out of place.',
      children: [
        EmptyState(
          title: 'This page isn’t available',
          message: 'Let’s head back to your vault.',
          action: AppButton(
            label: 'Go to vault',
            onPressed: () => context.go('/home'),
          ),
        ),
      ],
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
