import 'package:flutter/material.dart';
import 'app_colors.dart';

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.mint,
    required this.lime,
    required this.warning,
    required this.danger,
    required this.muted,
    required this.statusInk,
  });
  final Color mint, lime, warning, danger, muted, statusInk;
  static const light = AppTokens(
    mint: AppColors.mint,
    lime: AppColors.lime,
    warning: AppColors.amber,
    danger: AppColors.danger,
    muted: AppColors.accessibleMuted,
    statusInk: AppColors.ink,
  );
  static const dark = AppTokens(
    mint: AppColors.mintDark,
    lime: AppColors.limeDark,
    warning: AppColors.amberDark,
    danger: AppColors.dangerDark,
    muted: AppColors.accessibleMutedDark,
    statusInk: AppColors.ink,
  );
  @override
  AppTokens copyWith({
    Color? mint,
    Color? lime,
    Color? warning,
    Color? danger,
    Color? muted,
    Color? statusInk,
  }) => AppTokens(
    mint: mint ?? this.mint,
    lime: lime ?? this.lime,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    muted: muted ?? this.muted,
    statusInk: statusInk ?? this.statusInk,
  );
  @override
  AppTokens lerp(covariant AppTokens? other, double t) => other == null
      ? this
      : AppTokens(
          mint: Color.lerp(mint, other.mint, t)!,
          lime: Color.lerp(lime, other.lime, t)!,
          warning: Color.lerp(warning, other.warning, t)!,
          danger: Color.lerp(danger, other.danger, t)!,
          muted: Color.lerp(muted, other.muted, t)!,
          statusInk: Color.lerp(statusInk, other.statusInk, t)!,
        );
}

extension ThemeContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get type => Theme.of(this).textTheme;
  TextStyle? get mutedBody => type.bodyMedium?.copyWith(color: tokens.muted);
  TextStyle? get mutedCaption => type.bodySmall?.copyWith(color: tokens.muted);
  TextStyle? get statusLabel =>
      type.labelMedium?.copyWith(color: tokens.statusInk);
  TextStyle? get dangerLabel => type.labelLarge?.copyWith(color: colors.error);
  TextStyle? get searchMatch => type.bodyMedium?.copyWith(
    backgroundColor: colors.primaryContainer,
    fontWeight: FontWeight.w600,
  );
}
