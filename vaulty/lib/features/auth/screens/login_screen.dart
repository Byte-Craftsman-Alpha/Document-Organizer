import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_widgets.dart';
import '../providers/auth_providers.dart';
import '../../../app/bootstrap.dart';
import '../widgets/live_login_controls.dart';
import '../../settings/providers/ui_preferences.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Metrics.content),
            child: ListView(
              shrinkWrap: true,
              padding: Space.page,
              children: [
                Reveal(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: Space.card,
                            decoration: BoxDecoration(
                              color: context.colors.primaryContainer,
                              borderRadius: Corners.sheet,
                            ),
                            child: Icon(
                              AppIcons.documents,
                              size: Metrics.logo,
                              color: context.colors.primary,
                            ),
                          ),
                          const _LoginLanguageSelector(),
                        ],
                      ),
                      const SizedBox(height: Space.xl),
                      AppText('vaulty', style: context.type.displaySmall),
                      const SizedBox(height: Space.lg),
                      AppText(
                        'Life has paperwork.\nGive it a little peace.',
                        style: context.type.displaySmall,
                      ),
                      const SizedBox(height: Space.md),
                      AppText(
                        'Your important documents, renewal dates and careful handovers. All together.',
                        style: context.mutedBody,
                      ),
                      const SizedBox(height: Space.xl),
                      const StatusPill(
                        'Your Drive. Your space.',
                        tone: StatusTone.healthy,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.xl),
                if (ref.watch(liveModeProvider))
                  const LiveLoginControls()
                else if (session.isLoading)
                  const SkeletonBox(height: Metrics.touch)
                else
                  AppButton(
                    label: 'Continue with Google',
                    icon: AppIcons.login,
                    onPressed: () async {
                      await ref.read(sessionProvider.notifier).signIn();
                      if (context.mounted &&
                          ref.read(sessionProvider).valueOrNull != null) {
                        context.go('/insights');
                      }
                    },
                  ),
                if (session.hasError && !ref.watch(liveModeProvider)) ...[
                  const SizedBox(height: Space.sm),
                  AppText(
                    'Couldn’t sign in. Tap the button to try again.',
                    style: context.dangerLabel,
                  ),
                ],
                const SizedBox(height: Space.md),
                AppText(
                  'Designed to keep data in your own Google Drive.',
                  style: context.mutedCaption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.sm),
                AppText(
                  ref.watch(liveModeProvider)
                      ? 'Your device ↔ your Google Drive · no Vaulty backend'
                      : 'UI preview · mock sign-in · no Google connection',
                  style: context.mutedCaption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginLanguageSelector extends ConsumerWidget {
  const _LoginLanguageSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(uiPreferencesProvider).language;
    final isHindi = lang == 'hi';
    return PopupMenuButton<String>(
      tooltip: 'Language / भाषा',
      initialValue: isHindi ? 'hi' : 'en',
      onSelected: (code) {
        ref.read(uiPreferencesProvider.notifier).save(language: code);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'en', child: Text('English')),
        PopupMenuItem(value: 'hi', child: Text('हिन्दी')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: Space.xxs,
        ),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainer,
          borderRadius: Corners.pill,
          border: Border.all(
            color: context.colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.language,
              size: 16,
              color: context.colors.primary,
            ),
            const SizedBox(width: Space.xxs),
            Text(
              isHindi ? 'हिन्दी' : 'English',
              style: context.type.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              AppIcons.chevronDown,
              size: 14,
              color: context.colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

