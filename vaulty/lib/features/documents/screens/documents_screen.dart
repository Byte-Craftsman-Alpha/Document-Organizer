import '../widgets/quick_share_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/document_tile.dart';
import '../../../domain/models/document.dart';
import '../../../domain/models/search_filter.dart';
import '../providers/document_providers.dart';
import '../providers/collection_providers.dart';
import '../widgets/document_actions.dart';
import '../../upload/widgets/source_sheet.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});
  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen>
    with SingleTickerProviderStateMixin {
  late final filterMotion = AnimationController(
    vsync: this,
    duration: Motion.normal,
    value: 1,
  );
  void animateChange() {
    filterMotion.duration = Motion.of(context, Motion.normal);
    filterMotion.forward(from: 0);
  }

  @override
  void dispose() {
    filterMotion.dispose();
    super.dispose();
  }

  bool grid = false, refreshing = false;
  final selected = <String>{};
  final seen = <String>{};
  void toggle(String id) => setState(() {
    if (!selected.add(id)) selected.remove(id);
  });
  @override
  Widget build(BuildContext context) {
    ref.listen(quickTypeProvider, (_, _) => animateChange());
    ref.listen(quickSortProvider, (_, _) => animateChange());
    final value = ref.watch(visibleDocumentsProvider);
    final kind = ref.watch(quickTypeProvider);
    return Scaffold(
      appBar: AppBar(
        title: AppText(
          selected.isEmpty ? 'vaulty' : '${selected.length} selected',
        ),
        actions: [
          if (selected.isNotEmpty) ...[
            AppIconButton(
              label: 'Cancel selection',
              icon: Icons.close,
              onPressed: () => setState(selected.clear),
            ),
            AppIconButton(
              label: 'Move selected to Trash',
              icon: Icons.delete_outline,
              onPressed: () async {
                await trashDocuments(context, ref, Set.of(selected));
                if (mounted) setState(selected.clear);
              },
            ),
          ] else
            AppIconButton(
              label: 'Advanced search',
              icon: Icons.manage_search,
              onPressed: () => context.push('/search'),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: filterMotion,
        child: SafeArea(
          top: false,
          child: RefreshIndicator.noSpinner(
            onRefresh: () async {
              setState(() => refreshing = true);
              try {
                await ref.read(documentsProvider.notifier).refresh();
              } finally {
                if (mounted) setState(() => refreshing = false);
              }
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: Space.page,
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'Your documents',
                          style: context.type.displaySmall,
                        ),
                        const SizedBox(height: Space.xs),
                        AppText(
                          'The important things, all together.',
                          style: context.mutedBody,
                        ),
                        const SizedBox(height: Space.lg),
                        AppTextField(
                          label: 'Find a document',
                          icon: Icons.search,
                          onChanged: (v) =>
                              ref.read(quickQueryProvider.notifier).state = v,
                        ),
                        const SizedBox(height: Space.sm),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              AppChip(
                                label: 'All files',
                                selected: kind == null,
                                onTap: () =>
                                    ref.read(quickTypeProvider.notifier).state =
                                        null,
                              ),
                              for (final k in FileKind.values)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: Space.xs,
                                  ),
                                  child: AppChip(
                                    label: k.name.toUpperCase(),
                                    selected: kind == k,
                                    onTap: () =>
                                        ref
                                                .read(
                                                  quickTypeProvider.notifier,
                                                )
                                                .state =
                                            k,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Space.sm),
                        Row(
                          children: [
                            Expanded(
                              child: AppText(
                                '${value.valueOrNull?.length ?? '—'} documents',
                                style: context.mutedCaption,
                              ),
                            ),
                            AppPress(
                              child: PopupMenuButton<DocumentSort>(
                                tooltip: context.tr('Sort documents'),
                                icon: const Icon(Icons.sort),
                                onSelected: (s) =>
                                    ref.read(quickSortProvider.notifier).state =
                                        s,
                                itemBuilder: (_) => DocumentSort.values
                                    .map(
                                      (s) => PopupMenuItem(
                                        value: s,
                                        child: AppText('By ${s.name}'),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            AppIconButton(
                              label: grid ? 'Switch to list' : 'Switch to grid',
                              icon: grid
                                  ? Icons.view_list_outlined
                                  : Icons.grid_view,
                              onPressed: () {
                                animateChange();
                                setState(() => grid = !grid);
                              },
                            ),
                          ],
                        ),
                        if (refreshing) const SkeletonBox(height: Metrics.bar),
                      ],
                    ),
                  ),
                ),
                value.when(
                  skipLoadingOnRefresh: false,
                  loading: () => const SliverPadding(
                    padding: Space.page,
                    sliver: SliverToBoxAdapter(child: LoadingList()),
                  ),
                  error: (_, _) => SliverPadding(
                    padding: Space.page,
                    sliver: SliverToBoxAdapter(
                      child: EmptyState(
                        title: 'Couldn’t open your collection',
                        message: 'Try again. Your documents haven’t changed.',
                        action: AppButton(
                          label: 'Try again',
                          onPressed: () => ref.invalidate(documentsProvider),
                        ),
                      ),
                    ),
                  ),
                  data: (docs) {
                    if (docs.isEmpty) {
                      return SliverPadding(
                        padding: Space.page,
                        sliver: SliverToBoxAdapter(
                          child: EmptyState(
                            title: 'A little room for something important',
                            message: 'Add a document, or adjust your filters.',
                            action: AppButton(
                              label: 'Add document',
                              icon: Icons.add,
                              onPressed: () => showSourceSheet(context),
                            ),
                          ),
                        ),
                      );
                    }
                    Widget item(BuildContext context, int i) {
                      final d = docs[i];
                      final firstAppearance = seen.add(d.id);
                      final tile = grid
                          ? AppCard(
                              onTap: () => selected.isEmpty
                                  ? context.push('/document/${d.id}')
                                  : toggle(d.id),
                              child: GestureDetector(
                                onLongPress: () => toggle(d.id),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        DocumentThumbnail(document: d),
                                        const Spacer(),
                                        if (selected.isEmpty)
                                          QuickShareButton(id: d.id),
                                        if (selected.contains(d.id))
                                          const Icon(
                                            Icons.check_circle_outline,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: Space.md),
                                    Text(
                                      d.title,
                                      style: context.type.titleMedium,
                                      maxLines: Metrics.gridTitleLines,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: Space.xs),
                                    Text(
                                      d.belongsTo,
                                      style: context.mutedCaption,
                                      maxLines: Metrics.gridOwnerLines,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: Space.sm),
                                    ExpiryPill(document: d),
                                  ],
                                ),
                              ),
                            )
                          : Dismissible(
                              key: ValueKey(d.id),
                              background: const _SwipeBackground(share: true),
                              secondaryBackground: const _SwipeBackground(
                                share: false,
                              ),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  await quickShare(context, ref, d.id);
                                } else {
                                  await trashDocuments(context, ref, {d.id});
                                }
                                return false;
                              },
                              child: DocumentTile(
                                document: d,
                                trailing: selected.isEmpty
                                    ? QuickShareButton(id: d.id)
                                    : null,
                                selected: selected.contains(d.id),
                                query: ref.watch(quickQueryProvider),
                                onTap: () => selected.isEmpty
                                    ? context.push('/document/${d.id}')
                                    : toggle(d.id),
                                onLongPress: () => toggle(d.id),
                              ),
                            );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: Space.sm),
                        child: Reveal(
                          key: ValueKey('reveal-${d.id}'),
                          index: firstAppearance ? i : 0,
                          animate: firstAppearance,
                          child: tile,
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) =>
                            grid &&
                                constraints.crossAxisExtent >=
                                    Metrics.gridBreakpoint
                            ? SliverGrid.builder(
                                itemCount: docs.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisExtent:
                                          Metrics.gridExtent *
                                          MediaQuery.textScalerOf(
                                            context,
                                          ).scale(1),
                                      crossAxisSpacing: Space.sm,
                                    ),
                                itemBuilder: item,
                              )
                            : SliverList.builder(
                                itemCount: docs.length,
                                itemBuilder: item,
                              ),
                      ),
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.share});
  final bool share;
  @override
  Widget build(BuildContext context) => Container(
    padding: Space.page,
    alignment: share ? Alignment.centerLeft : Alignment.centerRight,
    decoration: BoxDecoration(
      color: share ? context.colors.primaryContainer : context.tokens.danger,
      borderRadius: Corners.card,
    ),
    child: Icon(
      share ? Icons.ios_share : Icons.delete_outline,
      semanticLabel: share ? 'Share' : 'Move to Trash',
      color: context.tokens.statusInk,
    ),
  );
}
