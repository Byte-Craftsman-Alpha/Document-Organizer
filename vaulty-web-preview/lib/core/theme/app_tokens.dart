import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class Space {
  static const xxs = 4.0, xs = 8.0, sm = 12.0, md = 16.0, lg = 24.0, xl = 32.0;
  static const page = EdgeInsets.all(lg);
  static const card = EdgeInsets.all(md);
  static const compact = EdgeInsets.all(sm);
  static const row = EdgeInsets.symmetric(horizontal: md, vertical: sm);
}

abstract final class Corners {
  static const card = BorderRadius.all(Radius.circular(24));
  static const sheet = BorderRadius.all(Radius.circular(28));
  static const pill = BorderRadius.all(Radius.circular(999));
}

abstract final class Motion {
  static const micro = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 220);
  static const page = Duration(milliseconds: 320);
  static const stagger = Duration(milliseconds: 40);
  static const hold = Duration(milliseconds: 1400);
  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const pressedScale = .97;
  static const spring = Curves.easeOutBack;
  static const routeScale = .985;
  static const slide = Offset(0, .045);
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

abstract final class Metrics {
  static const touch = 48.0,
      icon = 24.0,
      logo = 64.0,
      bannerArt = 96.0,
      onboardingArt = 180.0,
      actionHeight = 72.0,
      preview = 200.0,
      thumbnail = 56.0,
      bar = 8.0,
      content = 840.0,
      table = 620.0,
      filterWidth = 260.0,
      skeleton = 88.0,
      gridExtent = 280.0,
      sheetFraction = .92;
  static const gridBreakpoint = 320.0;
  static const thumbnailCache = 192;
  static const previewCache = 1024;
  static const gridTitleLines = 3, gridOwnerLines = 2;
}

abstract final class AppShadows {
  static final low = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: .06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  static final high = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: .09),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];
}

abstract final class FeedbackTiming {
  static Duration forMessage(String text) =>
      Duration(seconds: (4 + text.runes.length ~/ 20).clamp(4, 10));
}
