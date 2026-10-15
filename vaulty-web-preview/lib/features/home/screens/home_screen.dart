import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/bootstrap.dart';
import '../../../core/widgets/welcome_banner.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/document_tile.dart';
import '../../../domain/models/document.dart';
import '../../../domain/repositories/live_capabilities.dart';
import '../../documents/providers/document_providers.dart';
import '../../documents/widgets/quick_share_button.dart';
import '../../insights/providers/insights_providers.dart';
import '../../insights/widgets/storage_card.dart';

final browsedProvider = FutureProvider<Map<String, DateTime>>((ref) {
  ref.watch(vaultIdentityProvider);
  final repo = ref.watch(documentRepositoryProvider);
  return repo is CachedDocumentRepository ? repo.browsed() : Future.value({});
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int recent = 0;
  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(documentsProvider);
    final browsed = ref.watch(browsedProvider).valueOrNull ?? {};
    final repo = ref.watch(documentRepositoryProvider);
    return AppPage(
      title: 'Your home for important things.',
      subtitle: 'Storage, recent files and renewals.',
      onRefresh: () async {
        await ref.read(documentsProvider.notifier).refresh();
        ref.invalidate(storageProvider);
        ref.invalidate(browsedProvider);
      },
      actions: [
        if (ref.watch(liveModeProvider))
          AppIconButton(
            label: 'Pending imports',
            icon: Icons.move_to_inbox_outlined,
            onPressed: () => context.push('/import'),
          ),
        AppIconButton(
          label: 'Search vault',
          icon: Icons.search,
          onPressed: () => context.push('/search'),
        ),
        AppIconButton(
          label: 'Refresh vault',
          icon: Icons.refresh,
          onPressed: () {
            ref.invalidate(documentsProvider);
            ref.invalidate(storageProvider);
            ref.invalidate(browsedProvider);
          },
        ),
      ],
      children: [
        const WelcomeBanner(),
        if (repo is CachedDocumentRepository && repo.isOffline)
          const AppCard(
            child: AppText(
              'Offline · showing the last saved collection. Only cached files can open or share. Reconnect Drive in Settings to sync.',
            ),
          ),
        AsyncPanel(
          value: ref.watch(storageProvider),
          onRetry: () => ref.invalidate(storageProvider),
          builder: (s) => StorageCard(storage: s),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              'Renewal attention',
              subtitle: 'Overdue and due in the next 30 days',
            ),
            AsyncPanel(
              value: docs,
              onRetry: () => ref.invalidate(documentsProvider),
              builder: (values) {
                final attention =
                    values
                        .where(
                          (d) =>
                              !d.isDeleted &&
                              d.renewalRequired &&
                              (d.daysUntil(DateTime.now()) ?? 31) <= 30,
                        )
                        .toList()
                      ..sort((a, b) => a.expiry!.compareTo(b.expiry!));
                if (attention.isEmpty) {
                  return const EmptyState(
                    title: 'All caught up',
                    message: 'No renewals need your attention.',
                    icon: Icons.task_alt,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final d in attention)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.sm),
                        child: DocumentTile(
                          document: d,
                          hero: false,
                          onTap: () => context.push('/document/${d.id}'),
                          trailing: AppIconButton(
                            label: 'Renew ${d.title}',
                            icon: Icons.edit_calendar_outlined,
                            onPressed: () =>
                                context.push('/document/${d.id}/edit'),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              'Recent files',
              subtitle: 'Pick up where you left off.',
            ),
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (final (i, label) in [
                  'Uploaded',
                  'Modified',
                  'Browsed',
                ].indexed)
                  AppChip(
                    label: label,
                    selected: recent == i,
                    onTap: () => setState(() => recent = i),
                  ),
              ],
            ),
            const SizedBox(height: Space.md),
            AsyncPanel(
              value: docs,
              onRetry: () => ref.invalidate(documentsProvider),
              builder: (values) {
                final files = values
                    .where(
                      (d) =>
                          !d.isDeleted &&
                          (recent != 1 || d.modifiedAt != null) &&
                          (recent != 2 || browsed.containsKey(d.id)),
                    )
                    .toList();
                DateTime time(Document d) => recent == 0
                    ? d.uploadedAt
                    : recent == 1
                    ? d.modifiedAt!
                    : browsed[d.id]!;
                files.sort((a, b) => time(b).compareTo(time(a)));
                if (files.isEmpty) {
                  return EmptyState(
                    title: recent == 0
                        ? 'Your vault is ready'
                        : 'Nothing here yet',
                    message: recent == 0
                        ? 'Use Upload or share a file into Vaulty to get started.'
                        : recent == 1
                        ? 'Documents appear here when their file or details change.'
                        : 'Recently browsed files on this device will appear here.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final d in files.take(6))
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.sm),
                        child: DocumentTile(
                          document: d,
                          hero: false,
                          onTap: () => context.push('/document/${d.id}'),
                          trailing: QuickShareButton(id: d.id),
                        ),
                      ),
                    AppButton(
                      label: 'All documents',
                      secondary: true,
                      onPressed: () => context.go('/documents'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
