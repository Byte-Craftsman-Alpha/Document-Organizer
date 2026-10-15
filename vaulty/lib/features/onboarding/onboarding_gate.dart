import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/theme/abstract_art.dart';
import '../settings/providers/ui_preferences.dart';
import '../settings/widgets/appearance_panel.dart';

class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(uiPreferencesProvider).onboarded
      ? child
      : const OnboardingScreen();
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int step = 0;
  bool busy = false;
  Future<void> finish() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ref.read(uiPreferencesProvider.notifier).save(onboarded: true);
    } catch (_) {
      if (mounted) {
        notice(context, 'Couldn’t save that preference. Please retry.');
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Metrics.content),
          child: SingleChildScrollView(
            padding: Space.page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        'Vaulty',
                        style: context.type.headlineLarge,
                      ),
                    ),
                    AppTextButton(
                      onPressed: busy ? null : finish,
                      child: const AppText('Skip'),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                Center(
                  child: AnimatedRotation(
                    turns: step / 16,
                    duration: Motion.of(context, Motion.page),
                    curve: Motion.spring,
                    child: const SizedBox(
                      width: Metrics.onboardingArt,
                      height: Metrics.onboardingArt,
                      child: AbstractArt(),
                    ),
                  ),
                ),
                const SizedBox(height: Space.lg),
                AnimatedSwitcher(
                  duration: Motion.of(context, Motion.page),
                  switchInCurve: Motion.enter,
                  child: Column(
                    key: ValueKey(step),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppText(
                        [
                          'Your own little vault.',
                          'Keep the important things close.',
                          'A gentle nudge, right on time.',
                        ][step],
                        style: context.type.headlineLarge,
                      ),
                      const SizedBox(height: Space.md),
                      AppText(
                        [
                          'Your documents live in a hidden folder in your Google Drive. No Vaulty server stores your files.',
                          'Recently opened files are encrypted on Android for offline use. Shared copies leave your vault and cannot be recalled.',
                          'Optional Android reminders check your last synced renewal dates, even after a restart. Android may delay delivery.',
                        ][step],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.lg),
                if (step == 0) const AppearancePanel(compact: true),
                const SizedBox(height: Space.lg),
                AppText(
                  'Step ${step + 1} of 3',
                  textAlign: TextAlign.center,
                  style: context.mutedCaption,
                ),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    if (step > 0) ...[
                      Expanded(
                        child: AppButton(
                          label: 'Back',
                          secondary: true,
                          onPressed: busy ? null : () => setState(() => step--),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                    ],
                    Expanded(
                      child: AppButton(
                        label: step == 2 ? 'Get started' : 'Next',
                        icon: Icons.arrow_forward,
                        onPressed: busy
                            ? null
                            : step == 2
                            ? finish
                            : () => setState(() => step++),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
