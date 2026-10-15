import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/utils/format.dart';
import '../../documents/providers/document_providers.dart';
import '../providers/trash_providers.dart';
import '../../../app/bootstrap.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: 'A little breathing room.',
    subtitle: ref.watch(liveModeProvider)
        ? 'Files remain in your hidden Drive folder while in Trash. After 30 days they are permanently removed when Vaulty next syncs. Nothing runs on a Vaulty server.'
        : 'Documents in Trash are scheduled for automatic deletion after 30 days. This demo does not run background purges.',
    children: ref
        .watch(trashProvider)
        .when(
          skipLoadingOnRefresh: false,
          loading: () => [const LoadingList()],
          error: (_, _) => [
            EmptyState(
              title: 'Couldn’t load Trash',
              message: 'Try again when you’re ready.',
              action: AppButton(
                label: 'Try again',
                onPressed: () => ref.invalidate(documentsProvider),
              ),
            ),
          ],
          data: (docs) => docs.isEmpty
              ? [
                  const EmptyState(
                    title: 'Nothing left behind',
                    message: 'Your Trash is empty.',
                    icon: Icons.delete_outline,
                  ),
                ]
              : docs
                    .map(
                      (d) => AppCard(
                        key: ValueKey(d.id),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.title, style: context.type.titleMedium),
                            const SizedBox(height: Space.xs),
                            AppText(
                              d.belongsTo,
                              style: context.mutedCaption,
                            ),
                            AppText(
                              'Deleted ${dateLabel(d.deletedAt!)}',
                              style: context.mutedCaption,
                            ),
                            const SizedBox(height: Space.md),
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    label: 'Restore',
                                    secondary: true,
                                    onPressed: () async {
                                      final controller = ref.read(
                                        documentsProvider.notifier,
                                      );
                                      try {
                                        await controller.restore({d.id});
                                        if (context.mounted) {
                                          notice(context, 'Restored to Documents');
                                        }
                                      } catch (_) {
                                        if (context.mounted) {
                                          notice(
                                            context,
                                            'Couldn’t restore. Please try again.',
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: Space.sm),
                                Expanded(
                                  child: HoldToConfirm(
                                    label: 'Delete forever',
                                    onConfirmed: () async {
                                      try {
                                        await ref
                                            .read(documentsProvider.notifier)
                                            .purge(d.id);
                                        if (context.mounted) {
                                          notice(context, 'Permanently deleted');
                                        }
                                      } catch (_) {
                                        if (context.mounted) {
                                          notice(
                                            context,
                                            'Couldn’t delete. Please try again.',
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
        ),
  );
}
