import 'package:flutter/material.dart';
import '../../domain/models/document.dart';
import '../utils/format.dart';
import 'app_widgets.dart';

class DocumentThumbnail extends StatelessWidget {
  const DocumentThumbnail({
    super.key,
    required this.document,
    this.hero = true,
    this.large = false,
  });
  final Document document;
  final bool hero, large;
  @override
  Widget build(BuildContext context) {
    final tile = Material(
      color: context.colors.surfaceContainer,
      borderRadius: Corners.card,
      child: SizedBox(
        width: large ? double.infinity : Metrics.thumbnail,
        height: large ? Metrics.preview : Metrics.thumbnail,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              document.kind.isImage
                  ? AppIcons.image
                  : AppIcons.document,
              size: large ? Metrics.logo : Metrics.icon,
              color: context.colors.primary,
            ),
            Text(
              document.kind.name.toUpperCase(),
              style: context.type.labelSmall,
            ),
            if (large) ...[
              const SizedBox(height: Space.sm),
              AppText('File preview', style: context.mutedCaption),
            ],
          ],
        ),
      ),
    );
    return hero
        ? HeroMode(
            enabled: !MediaQuery.disableAnimationsOf(context),
            child: Hero(tag: 'document-${document.id}', child: tile),
          )
        : tile;
  }
}

class ExpiryPill extends StatelessWidget {
  const ExpiryPill({super.key, required this.document});
  final Document document;
  @override
  Widget build(BuildContext context) {
    final days = document.daysUntil(DateTime.now());
    return StatusPill(
      days == null
          ? 'No renewal'
          : days < 0
          ? 'Overdue'
          : days == 0
          ? 'Due today'
          : days <= 30
          ? 'Due in $days days'
          : 'Up to date',
      tone: days == null
          ? StatusTone.neutral
          : days < 0
          ? StatusTone.danger
          : days <= 30
          ? StatusTone.warning
          : StatusTone.healthy,
    );
  }
}

class DocumentTile extends StatelessWidget {
  const DocumentTile({
    super.key,
    required this.document,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.hero = true,
    this.trailing,
    this.query = '',
  });
  final Document document;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected, hero;
  final Widget? trailing;
  final String query;
  @override
  Widget build(BuildContext context) => AppPress(
    child: Card(
      clipBehavior: Clip.antiAlias,
      color: selected
          ? context.colors.primaryContainer.withValues(alpha: 0.15)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: Corners.card,
        side: selected
            ? BorderSide(color: context.colors.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: Space.card,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selected)
                Container(
                  width: Metrics.thumbnail,
                  height: Metrics.thumbnail,
                  decoration: BoxDecoration(
                    color: context.colors.primaryContainer,
                    borderRadius: Corners.card,
                  ),
                  child: Icon(
                    AppIcons.check,
                    color: context.colors.primary,
                  ),
                )
              else
                DocumentThumbnail(document: document, hero: hero),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HighlightedText(
                      document.title,
                      query: query,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Space.xxs),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            document.belongsTo,
                            style: context.mutedCaption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          ' · ${bytesLabel(document.sizeBytes)}',
                          style: context.mutedCaption,
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    ExpiryPill(document: document),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    ),
  );
}

class HighlightedText extends StatelessWidget {
  const HighlightedText(
    this.text, {
    super.key,
    required this.query,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
    this.style,
  });
  final String text, query;
  final int? maxLines;
  final TextOverflow overflow;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? context.type.bodyLarge;
    final index = query.isEmpty
        ? -1
        : text.toLowerCase().indexOf(query.toLowerCase());
    if (index < 0) {
      return Text(
        text,
        style: effectiveStyle,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: context.searchMatch,
          ),
          TextSpan(text: text.substring(index + query.length)),
        ],
      ),
      style: effectiveStyle,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
