import '../../documents/widgets/quick_share_button.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/bootstrap.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/document_tile.dart';
import '../../../domain/models/search_filter.dart';
import '../providers/search_providers.dart';
import '../widgets/advanced_search_sheet.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final text = TextEditingController(text: ref.read(searchQueryProvider));
  Timer? debounce;
  @override
  void dispose() {
    debounce?.cancel();
    text.dispose();
    super.dispose();
  }

  void change(String q) {
    debounce?.cancel();
    debounce = Timer(Motion.normal, () {
      ref.read(searchQueryProvider.notifier).state = q;
    });
  }

  void search(String q) {
    debounce?.cancel();
    text.text = q;
    ref.read(searchQueryProvider.notifier).state = q;
    remember(q);
  }

  Future<void> remember(String q) async {
    try {
      await ref.read(searchRepositoryProvider).remember(q);
      if (mounted) ref.invalidate(recentSearchesProvider);
    } catch (_) {
      if (mounted) notice(context, 'Couldn’t remember this search.');
    }
  }

  Future<void> advanced() async {
    final filter = await AppBottomSheet.show<SearchFilter>(
      context,
      AdvancedSearchSheet(initial: ref.read(searchFilterProvider)),
    );
    if (filter != null && mounted) {
      ref.read(searchFilterProvider.notifier).state = filter;
    }
  }

  Future<void> save() async {
    final controller = TextEditingController(
      text: text.text.isEmpty ? 'My search' : text.text,
    );
    final name = await showAppDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Save this search'),
        content: AppTextField(label: 'Search name', controller: controller),
        actions: [
          AppTextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('Cancel'),
          ),
          AppButton(
            label: 'Save search',
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
          ),
        ],
      ),
    );
    Future<void>.delayed(Motion.page, controller.dispose);
    if (name == null || !mounted) return;
    try {
      await ref
          .read(searchRepositoryProvider)
          .save(SavedSearch(name, text.text, ref.read(searchFilterProvider)));
      ref.invalidate(savedSearchesProvider);
      if (mounted) notice(context, 'Search saved');
    } catch (_) {
      if (mounted) notice(context, 'Couldn’t save the search. Please retry.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(searchFilterProvider),
        query = ref.watch(searchQueryProvider);
    final result = ref.watch(searchResultsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Search your vault'),
        actions: [
          AppIconButton(
            label: 'Advanced filters',
            icon: AppIcons.settings,
            onPressed: advanced,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: Space.page,
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: 'Title, person or tag',
                    controller: text,
                    icon: AppIcons.search,
                    autofocus: false,
                    onChanged: change,
                    onSubmitted: search,
                  ),
                  const SizedBox(height: Space.sm),
                  AnimatedSize(
                    duration: Motion.of(context, Motion.normal),
                    curve: Motion.enter,
                    child: Wrap(
                      spacing: Space.xs,
                      children: filter.labels.entries
                          .map(
                            (e) => AppChip(
                              label: e.value,
                              onDeleted: () =>
                                  ref
                                      .read(searchFilterProvider.notifier)
                                      .state = filter.without(
                                    e.key,
                                  ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  SectionHeader(
                    'Saved searches',
                    action: AppIconButton(
                      label: 'Save current search',
                      icon: AppIcons.copy,
                      onPressed: save,
                    ),
                  ),
                  AsyncPanel(
                    value: ref.watch(savedSearchesProvider),
                    onRetry: () => ref.invalidate(savedSearchesProvider),
                    builder: (saved) => saved.isEmpty
                        ? AppText(
                            'Save useful filters for next time.',
                            style: context.mutedCaption,
                          )
                        : Wrap(
                            spacing: Space.xs,
                            children: saved
                                .map(
                                  (s) => AppChip(
                                    label: s.name,
                                    onTap: () {
                                      ref
                                          .read(searchFilterProvider.notifier)
                                          .state = s
                                          .filter;
                                      search(s.query);
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: Space.md),
                  const SectionHeader('Recent searches'),
                  AsyncPanel(
                    value: ref.watch(recentSearchesProvider),
                    onRetry: () => ref.invalidate(recentSearchesProvider),
                    builder: (recent) => recent.isEmpty
                        ? AppText(
                            'Your recent searches will appear here.',
                            style: context.mutedCaption,
                          )
                        : Wrap(
                            spacing: Space.xs,
                            children: recent
                                .map(
                                  (q) =>
                                      AppChip(label: q, onTap: () => search(q)),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: Space.lg),
                  AppText(
                    '${result.valueOrNull?.length ?? '…'} results',
                    style: context.type.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          result.when(
            skipLoadingOnRefresh: false,
            loading: () => const SliverPadding(
              padding: Space.page,
              sliver: SliverToBoxAdapter(child: LoadingList()),
            ),
            error: (_, _) => SliverPadding(
              padding: Space.page,
              sliver: SliverToBoxAdapter(
                child: EmptyState(
                  title: 'Search needs another try',
                  message: 'Your query and filters are saved here.',
                  action: AppButton(
                    label: 'Try again',
                    onPressed: () => ref.invalidate(searchResultsProvider),
                  ),
                ),
              ),
            ),
            data: (docs) => docs.isEmpty
                ? const SliverPadding(
                    padding: Space.page,
                    sliver: SliverToBoxAdapter(
                      child: EmptyState(
                        title: 'No matches, yet',
                        message: 'Try a different name or remove a filter.',
                        icon: AppIcons.searchOff,
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: Space.page,
                    sliver: SliverList.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: Space.sm),
                        child: DocumentTile(
                          document: docs[index],
                          trailing: QuickShareButton(id: docs[index].id),
                          query: query,
                          onTap: () {
                            remember(query);
                            context.push('/document/${docs[index].id}');
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
