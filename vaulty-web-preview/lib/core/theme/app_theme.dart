import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_extensions.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

class VaultPageTransitions extends PageTransitionsBuilder {
  const VaultPageTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return FadeTransition(
      opacity: animation.drive(
        CurveTween(curve: const Interval(.3, 1, curve: Motion.enter)),
      ),
      child: FadeTransition(
        opacity: ReverseAnimation(
          secondaryAnimation.drive(
            CurveTween(curve: const Interval(0, .3, curve: Motion.exit)),
          ),
        ),
        child: child,
      ),
    );
  }
}

abstract final class AppTheme {
  static ThemeData get light => build(false);
  static ThemeData get dark => build(true);
  static ThemeData build(bool dark) {
    final ink = dark ? AppColors.inkDark : AppColors.ink;
    final surface = dark ? AppColors.surfaceDark : AppColors.surfaceSoft;
    final variant = dark ? AppColors.variantDark : AppColors.variant;
    final background = dark ? AppColors.backgroundDark : AppColors.background;
    final muted = dark
        ? AppColors.accessibleMutedDark
        : AppColors.accessibleMuted;
    final primary = dark ? AppColors.primaryDark : AppColors.primaryInk;
    final container = dark ? AppColors.containerDark : AppColors.container;
    final error = dark ? AppColors.dangerDark : AppColors.dangerInk;
    final line = dark ? AppColors.lineDark : AppColors.line;
    final text = AppTypography.build(ink);
    final shape = RoundedRectangleBorder(borderRadius: Corners.card);
    final scheme = ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: primary,
      onPrimary: dark ? AppColors.ink : AppColors.surfaceSoft,
      primaryContainer: container,
      onPrimaryContainer: ink,
      secondary: dark ? AppColors.mintDark : AppColors.mint,
      onSecondary: AppColors.ink,
      secondaryContainer: variant,
      onSecondaryContainer: ink,
      tertiary: dark ? AppColors.limeDark : AppColors.lime,
      onTertiary: AppColors.ink,
      error: error,
      onError: dark ? AppColors.ink : AppColors.surfaceSoft,
      errorContainer: container,
      onErrorContainer: ink,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: muted,
      surfaceContainer: variant,
      surfaceContainerLow: background,
      surfaceContainerHigh: variant,
      surfaceContainerHighest: variant,
      surfaceTint: AppColors.transparent,
      outline: muted,
      outlineVariant: line,
      shadow: AppColors.transparent,
      scrim: AppColors.ink,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: text,
      fontFamily: 'Public Sans',
      extensions: [dark ? AppTokens.dark : AppTokens.light],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: VaultPageTransitions()},
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.card,
          side: BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: variant,
        contentPadding: Space.card,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: text.bodyMedium?.copyWith(color: muted),
        hintStyle: text.bodyMedium?.copyWith(color: muted),
        border: OutlineInputBorder(
          borderRadius: Corners.card,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Corners.card,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Corners.card,
          borderSide: BorderSide(color: primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Corners.card,
          borderSide: BorderSide(color: error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(Metrics.touch, Metrics.touch),
          shape: shape,
          textStyle: text.labelLarge,
          padding: Space.row,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(Metrics.touch, Metrics.touch),
          shape: shape,
          side: BorderSide(color: line),
          textStyle: text.labelLarge,
          padding: Space.row,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(Metrics.touch, Metrics.touch),
          textStyle: text.labelLarge,
          padding: Space.row,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(Metrics.touch, Metrics.touch),
          foregroundColor: muted,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: variant,
        selectedColor: container,
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(borderRadius: Corners.pill),
        labelStyle: text.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: Space.xs),
        showCheckmark: false,
      ),
      appBarTheme: AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: background,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: background,
          systemNavigationBarIconBrightness: dark
              ? Brightness.light
              : Brightness.dark,
        ),
        backgroundColor: background,
        foregroundColor: ink,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        titleTextStyle: text.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: container,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: ink)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: AppColors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Corners.sheet),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: AppColors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Corners.sheet),
        titleTextStyle: text.titleLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: variant,
        contentTextStyle: text.bodyMedium,
        actionTextColor: primary,
        behavior: SnackBarBehavior.floating,
        shape: shape,
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: Space.row,
        textColor: ink,
        iconColor: muted,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall?.copyWith(color: muted),
        shape: shape,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.onPrimary : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : variant,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: variant,
        linearMinHeight: Metrics.bar,
        borderRadius: Corners.pill,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: variant, borderRadius: Corners.card),
        textStyle: text.bodySmall,
        padding: Space.compact,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        shape: shape,
        textStyle: text.bodyMedium,
      ),
      dividerTheme: DividerThemeData(color: line, space: Space.lg),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(textStyle: WidgetStatePropertyAll(text.labelMedium)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: AppColors.transparent,
      ),
    );
  }
}
