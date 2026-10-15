import 'package:flutter/material.dart';
import 'app_widgets.dart';

class TokenGallery extends StatelessWidget {
  const TokenGallery({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Typography / Public Sans'),
            AppText('Display · 28 / 600', style: context.type.displaySmall),
            AppText('Title · 20 / 600', style: context.type.titleLarge),
            AppText('Subtitle · 16 / 500', style: context.type.titleMedium),
            AppText('Body · 14 / 400', style: context.type.bodyMedium),
            AppText('Caption · 12 / 400', style: context.type.bodySmall),
            AppText('Label · 13 / 600', style: context.type.labelMedium),
          ],
        ),
      ),
      const SizedBox(height: Space.lg),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Semantic palette'),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                _Swatch(
                  'Background',
                  Theme.of(context).scaffoldBackgroundColor,
                ),
                _Swatch('Surface', context.colors.surface),
                _Swatch('Variant', context.colors.surfaceContainer),
                _Swatch('On surface', context.colors.onSurface),
                _Swatch('Muted text', context.tokens.muted),
                _Swatch('Primary', context.colors.primary),
                _Swatch('Primary container', context.colors.primaryContainer),
                _Swatch('Mint', context.tokens.mint),
                _Swatch('Lime', context.tokens.lime),
                _Swatch('Warning', context.tokens.warning),
                _Swatch('Danger', context.tokens.danger),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: Space.lg),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Spacing / 4pt grid'),
            Wrap(
              spacing: Space.md,
              runSpacing: Space.md,
              children: [
                for (final space in [
                  Space.xxs,
                  Space.xs,
                  Space.sm,
                  Space.md,
                  Space.lg,
                  Space.xl,
                ])
                  Column(
                    children: [
                      Container(
                        width: space,
                        height: Metrics.touch,
                        color: context.colors.primaryContainer,
                      ),
                      AppText('${space.toInt()}', style: context.mutedCaption),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
            const SectionHeader('Shape / radius'),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final entry in {
                  'Card · 12': Corners.card,
                  'Sheet · 20': Corners.sheet,
                  'Pill · 999': Corners.pill,
                }.entries)
                  Container(
                    padding: Space.card,
                    decoration: BoxDecoration(
                      color: context.colors.surfaceContainer,
                      borderRadius: entry.value,
                    ),
                    child: Text(entry.key),
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
            const SectionHeader('Motion'),
            AppText(
              'Micro ${Motion.micro.inMilliseconds}ms · Default ${Motion.normal.inMilliseconds}ms · Page ${Motion.page.inMilliseconds}ms',
            ),
            AppText(
              'easeOutCubic in / easeInCubic out. System reduce-motion is respected.',
              style: context.mutedCaption,
            ),
          ],
        ),
      ),
      const SizedBox(height: Space.lg),
      const SectionHeader('Elevation / two quiet levels'),
      Wrap(
        spacing: Space.lg,
        runSpacing: Space.lg,
        children: [
          for (final entry in {
            'Level 1': AppShadows.low,
            'Level 2': AppShadows.high,
          }.entries)
            Container(
              padding: Space.page,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: Corners.card,
                boxShadow: Theme.of(context).brightness == Brightness.dark
                    ? null
                    : entry.value,
              ),
              child: Text(entry.key),
            ),
        ],
      ),
    ],
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: Metrics.skeleton,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: Metrics.touch,
          decoration: BoxDecoration(
            color: color,
            borderRadius: Corners.card,
            border: Border.all(color: context.colors.outlineVariant),
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(label, style: context.mutedCaption),
      ],
    ),
  );
}
