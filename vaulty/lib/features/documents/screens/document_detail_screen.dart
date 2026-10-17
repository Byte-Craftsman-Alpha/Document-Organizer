import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/bootstrap.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/document_tile.dart';
import '../../../core/utils/format.dart';
import '../providers/document_providers.dart';
import '../widgets/document_actions.dart';
import '../../home/screens/home_screen.dart';
import '../widgets/quick_share_button.dart';
import '../../upload/widgets/source_sheet.dart';
import '../../../domain/repositories/live_capabilities.dart';
import '../widgets/live_file_preview.dart';

class DocumentDetailScreen extends ConsumerStatefulWidget {
  const DocumentDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<DocumentDetailScreen> createState() =>
      _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  bool busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = ref.read(documentRepositoryProvider);
      if (repo is CachedDocumentRepository) {
        try {
          await repo.markBrowsed(widget.id);
          if (mounted) ref.invalidate(browsedProvider);
        } catch (_) {
          /* Reading a document is not blocked by recents. */
        }
      }
    });
  }

  Future<void> replaceFile() async {
    final file = await pickSource(context);
    if (file == null || !mounted) return;
    if (!await AppDialog.confirm(
      context,
      title: 'Replace this file?',
      message:
          'Metadata will stay the same. The previous file will be replaced.',
      confirmLabel: 'Replace file',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await ref.read(documentRepositoryProvider).replace(widget.id, file);
      ref.invalidate(documentsProvider);
      ref.invalidate(documentBytesProvider(widget.id));
      ref.read(documentsProvider.notifier).refreshRelated();
      if (mounted) {
        notice(
          context,
          ref.read(liveModeProvider)
              ? 'File replaced in Drive'
              : 'File replaced (demo)',
        );
      }
    } catch (_) {
      if (mounted) {
        notice(context, 'Couldn’t replace the file. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const AppText('Document'),
      leading: IconButton(
        icon: const Icon(AppIcons.back),
        onPressed: () {
          HapticFeedback.lightImpact();
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/documents');
          }
        },
      ),
    ),
    body: Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      child: AsyncPanel(
        value: ref.watch(documentProvider(widget.id)),
        onRetry: () => ref.invalidate(documentsProvider),
        builder: (d) {
          if (d == null || d.isDeleted) {
            return EmptyState(
              title: 'Document unavailable',
              message: 'Look in Trash for recently deleted documents.',
              action: AppButton(
                label: 'Open Trash',
                secondary: true,
                onPressed: () => context.push('/trash'),
              ),
            );
          }
          return ListView(
            children: [
              if (ref.watch(liveModeProvider))
                LiveFilePreview(document: d)
              else
                DocumentThumbnail(document: d, large: true),
              if (ref.watch(liveModeProvider)) ...[
                const SizedBox(height: Space.md),
                AppButton(
                  label: 'Open / download file',
                  secondary: true,
                  icon: AppIcons.openInNew,
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          try {
                            await (ref.read(documentRepositoryProvider)
                                    as LiveDocumentRepository)
                                .open(d.id);
                            ref
                                .read(documentsProvider.notifier)
                                .refreshRelated();
                          } catch (e) {
                            if (context.mounted) {
                              notice(
                                context,
                                e is VaultFailure
                                    ? e.message
                                    : 'Couldn’t open the file.',
                              );
                            }
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                ),
              ],
              const SizedBox(height: Space.lg),
              Text(d.title, style: context.type.displaySmall),
              const SizedBox(height: Space.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: ExpiryPill(document: d),
              ),
              const SizedBox(height: Space.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader('The details'),
                    _Metadata('Belongs to', d.belongsTo),
                    _Metadata(
                      'File',
                      '${d.kind.name.toUpperCase()} · ${bytesLabel(d.sizeBytes)}',
                    ),
                    _Metadata('Uploaded', dateLabel(d.uploadedAt)),
                    _Metadata(
                      'Renewal',
                      d.renewalRequired ? 'Required' : 'Not required',
                    ),
                    if (d.expiry != null)
                      _Metadata('Expiry date', dateLabel(d.expiry!)),
                    if (d.tags.isNotEmpty)
                      Wrap(
                        spacing: Space.xs,
                        children: d.tags.map((t) => AppChip(label: t)).toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.lg),
              QuickShareButton(id: d.id, full: true),
              const SizedBox(height: Space.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    label: 'Edit details',
                    icon: AppIcons.edit,
                    secondary: true,
                    onPressed: () => context.push('/document/${d.id}/edit'),
                  ),
                  const SizedBox(height: Space.sm),
                  AppButton(
                    label: 'Replace file',
                    secondary: true,
                    onPressed: busy ? null : replaceFile,
                  ),
                ],
              ),
              if (busy) const SkeletonBox(),
              const SizedBox(height: Space.lg),
              AppButton(
                label: 'Move to Trash',
                icon: AppIcons.trash,
                danger: true,
                onPressed: busy
                    ? null
                    : () async {
                        if (await trashDocuments(context, ref, {d.id}) &&
                            context.mounted) {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/documents');
                          }
                        }
                      },
              ),
              const SizedBox(height: Space.xl),
            ],
          );
        },
      ),
    ),
  );
}

class _Metadata extends StatelessWidget {
  const _Metadata(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, style: context.mutedCaption),
        const SizedBox(height: Space.xxs),
        AppText(value),
      ],
    ),
  );
}
