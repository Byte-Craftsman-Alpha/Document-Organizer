import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/bootstrap.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/repositories/live_capabilities.dart';
import '../providers/auth_providers.dart';
import 'google_button.dart';

class LiveLoginControls extends ConsumerWidget {
  const LiveLoginControls({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(authRepositoryProvider) as LiveAuthRepository;
    final connection =
        ref.watch(accountConnectionProvider).valueOrNull ?? repo.connection;
    final session = ref.watch(sessionProvider);
    if (repo.configurationError != null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Google connection not configured'),
            Text(repo.configurationError!, style: context.mutedBody),
            const SizedBox(height: Space.sm),
            AppText(
              'No account is connected and no sample files are being substituted.',
              style: context.mutedCaption,
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (session.isLoading)
          const SkeletonBox(height: Metrics.touch)
        else if (kIsWeb && connection.id == null)
          Center(child: googleSdkButton())
        else
          AppButton(
            label: connection.id == null
                ? 'Continue with Google'
                : 'Connect Google Drive',
            icon: AppIcons.login,
            onPressed: () => ref.read(sessionProvider.notifier).signIn(),
          ),
        if (!kIsWeb && repo is OfflineAuthRepository) ...[
          const SizedBox(height: Space.sm),
          AppButton(
            label: 'Open offline vault',
            secondary: true,
            icon: AppIcons.check,
            onPressed: session.isLoading
                ? null
                : () async {
                    try {
                      await (repo as OfflineAuthRepository).openOffline();
                    } catch (e) {
                      if (context.mounted) {
                        notice(
                          context,
                          e is VaultFailure
                              ? e.message
                              : 'Offline vault is unavailable. Connect online first.',
                        );
                      }
                    }
                  },
          ),
        ],
        if (connection.email != null) ...[
          const SizedBox(height: Space.sm),
          AppText('Account: ${connection.email}', style: context.mutedCaption),
          AppTextButton(
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
            child: const AppText('Use another account'),
          ),
        ],
        if (session.hasError || connection.error != null) ...[
          const SizedBox(height: Space.sm),
          Text(
            connection.error ?? '${session.error}',
            style: context.dangerLabel,
          ),
        ],
        const SizedBox(height: Space.md),
        AppText(
          'Sign-in identifies your account. Drive consent lets Vaulty access only its own hidden app data. No Vaulty server receives your documents.',
          style: context.mutedCaption,
        ),
      ],
    );
  }
}
