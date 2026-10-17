import 'package:flutter/material.dart';
import 'app_widgets.dart';
import '../theme/abstract_art.dart';

class WelcomeBanner extends StatelessWidget {
  const WelcomeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Opacity(
              opacity: 0.12,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.primary,
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.xs + 2,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.primaryContainer,
                          borderRadius: Corners.pill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppIcons.shield,
                              size: 14,
                              color: context.colors.onPrimaryContainer,
                            ),
                            const SizedBox(width: Space.xxs),
                            Text(
                              context.tr('Private Vault'),
                              style: context.type.labelSmall?.copyWith(
                                color: context.colors.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    AppText(
                      'A little space.\nA lot of peace.',
                      style: context.type.titleLarge?.copyWith(
                        letterSpacing: -0.3,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    AppText(
                      'Your important things, together.',
                      style: context.mutedCaption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              const SizedBox(
                width: Metrics.bannerArt,
                height: Metrics.bannerArt,
                child: AbstractArt(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
