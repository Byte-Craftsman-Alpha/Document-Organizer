import 'package:flutter/material.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/utils/format.dart';
import '../../../domain/models/storage_info.dart';

class StorageCard extends StatelessWidget {
  const StorageCard({super.key, required this.storage});
  final StorageInfo storage;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          'Your Drive, at a glance',
          action: Icon(Icons.cloud_outlined),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: Space.xs,
          children: [
            Text(
              bytesLabel(storage.usedBytes),
              style: context.type.displaySmall,
            ),
            AppText(
              storage.totalBytes == null
                  ? 'used · quota not supplied by Google'
                  : 'of ${bytesLabel(storage.totalBytes!)} used',
              style: context.mutedBody,
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        if (storage.totalBytes != null && storage.totalBytes! > 0)
          StatBar(
            value: storage.usedFraction,
            secondary: storage.vaultBytes / storage.totalBytes!,
            label: 'Drive storage',
          ),
        const SizedBox(height: Space.md),
        Wrap(
          spacing: Space.md,
          runSpacing: Space.xs,
          children: [
            StatusPill(
              'Vaulty · ${bytesLabel(storage.vaultBytes)}',
              tone: StatusTone.healthy,
            ),
            AppText(
              'Other · ${bytesLabel(storage.otherBytes)}',
              style: context.mutedCaption,
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        AppText(
          storage.cachedAt == null
              ? 'Total Google account quota includes Drive, Gmail and Photos.'
              : 'Offline · last known quota from ${dateLabel(storage.cachedAt!)}. Reconnect to refresh.',
          style: context.mutedCaption,
        ),
      ],
    ),
  );
}
