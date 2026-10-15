import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/l10n/app_strings.dart';
import 'features/settings/providers/ui_preferences.dart';
import 'features/onboarding/onboarding_gate.dart';
import 'data/device/renewal_bridge.dart';

import 'data/device/file_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app/live_bootstrap.dart';
import 'features/auth/widgets/app_lock_gate.dart';
import 'app/router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_tokens.dart';
import 'features/settings/providers/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  unawaited(pruneOpenedFiles().catchError((Object _) {}));
  final ui = await UiPreferencesController.load();
  runApp(
    ProviderScope(
      overrides: [
        ...await liveOverrides(),
        uiPreferencesProvider.overrideWith((ref) => ui),
      ],
      child: const VaultyApp(),
    ),
  );
}

class VaultyApp extends ConsumerWidget {
  const VaultyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Vaulty',
    locale: ref.watch(localeProvider),
    supportedLocales: const [Locale('en'), Locale('hi')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) {
      final language = Localizations.localeOf(context).languageCode;
      if (AppStrings.language != language) {
        AppStrings.language = language;
        unawaited(
          RenewalBridge.instance.language(language).catchError((Object _) {}),
        );
      }
      return OnboardingGate(child: AppLockGate(child: child!));
    },
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ref.watch(themeModeProvider),
    themeAnimationDuration:
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations
        ? Duration.zero
        : Motion.page,
    themeAnimationCurve: Motion.enter,
    routerConfig: ref.watch(routerProvider),
  );
}
