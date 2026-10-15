import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/bootstrap.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/utils/format.dart';
import '../../../data/device/incoming_share.dart';
import '../../../domain/models/document.dart';
import '../../../domain/repositories/live_capabilities.dart';
import '../../documents/providers/document_providers.dart';

class _Draft {
  _Draft(this.file)
    : title = TextEditingController(
        text: file.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
      );
  final IncomingFile file;
  final TextEditingController title,
      owner = TextEditingController(),
      tags = TextEditingController();
  bool selected = true, renewal = false, done = false;
  DateTime? expiry;
  String? error;
  FileKind? detectedKind;
  double progress = 0;
  void dispose() {
    title.dispose();
    owner.dispose();
    tags.dispose();
  }
}

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});
  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final form = GlobalKey<FormState>();
  final commonOwner = TextEditingController();
  final drafts = <_Draft>[];
  bool loading = true, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    IncomingShare.instance.revision.addListener(load);
    load();
  }

  Future<void> load() async {
    if (busy) return;
    try {
      final incoming = await IncomingShare.instance.pending();
      if (!mounted) return;
      for (final file in incoming) {
        if (drafts.any((d) => d.file.id == file.id)) continue;
        final draft = _Draft(file)
          ..error = file.error
          ..selected = file.error == null;
        if (file.error == null) {
          try {
            draft.detectedKind = (await IncomingShare.instance.read(file)).kind;
          } catch (e) {
            draft.error = e is VaultFailure
                ? e.message
                : 'Unreadable attachment. Remove it and share again.';
            draft.selected = false;
          }
        }
        if (!mounted) {
          draft.dispose();
          return;
        }
        if (!drafts.any((d) => d.file.id == file.id)) {
          setState(() => drafts.add(draft));
        } else {
          draft.dispose();
        }
      }
      if (mounted) setState(() => loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          error =
              'Could not load incoming files. Share them into Vaulty again.';
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    IncomingShare.instance.revision.removeListener(load);
    commonOwner.dispose();
    for (final d in drafts) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> import() async {
    if (!form.currentState!.validate()) return;
    final chosen = drafts
        .where((d) => d.selected && !d.done && d.detectedKind != null)
        .toList();
    if (chosen.isEmpty) {
      notice(context, 'Select at least one supported file.');
      return;
    }
    if (chosen.any((d) => d.renewal && d.expiry == null)) {
      notice(context, 'Choose an expiry date for every renewal document.');
      return;
    }
    final identity = ref.read(vaultIdentityProvider);
    if (identity == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    for (final draft in chosen) {
      if (!mounted || ref.read(vaultIdentityProvider) != identity) break;
      try {
        final file = await IncomingShare.instance.read(draft.file);
        if (!mounted || ref.read(vaultIdentityProvider) != identity) break;
        final doc = Document(
          id: 'incoming-${draft.file.id}',
          title: draft.title.text.trim(),
          belongsTo: draft.owner.text.trim(),
          kind: file.kind,
          uploadedAt: DateTime.now(),
          sizeBytes: file.sizeBytes,
          renewalRequired: draft.renewal,
          expiry: draft.renewal ? draft.expiry : null,
          tags: draft.tags.text
              .split(',')
              .map((s) => s.trim().toLowerCase())
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList(),
        );
        await for (final p
            in ref.read(documentRepositoryProvider).upload(doc, file)) {
          if (!mounted) break;
          setState(() => draft.progress = p);
        }
        if (!mounted || ref.read(vaultIdentityProvider) != identity) break;
        // Uploaded entries are removed from the inbox: retrying failures never duplicates successes.
        await IncomingShare.instance.discard(draft.file.id);
        if (mounted) {
          setState(() {
            draft.done = true;
            draft.selected = false;
            draft.error = null;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(
            () => draft.error = e is VaultFailure
                ? e.message
                : 'Could not import this file. Review it and retry.',
          );
        }
      }
    }
    if (!mounted) return;
    ref.invalidate(documentsProvider);
    ref.read(documentsProvider.notifier).refreshRelated();
    setState(() => busy = false);
    await load();
  }

  Future<void> discardAll() async {
    if (!await AppDialog.confirm(
      context,
      title: 'Discard remaining imports?',
      message:
          'Only pending local attachments are removed. Uploaded documents and the sending app’s originals stay unchanged.',
      confirmLabel: 'Discard pending',
    )) {
      return;
    }
    await IncomingShare.instance.clear();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const AppText('Review imports')),
      body: SafeArea(
        child: loading
            ? const Padding(padding: Space.page, child: SkeletonBox())
            : Form(
                key: form,
                child: ListView(
                  padding: Space.page,
                  children: [
                    AppText(
                      'Choose what goes into your vault',
                      style: context.type.titleLarge,
                    ),
                    const SizedBox(height: Space.xs),
                    AppText(
                      'Account: ${ref.watch(accountConnectionProvider).valueOrNull?.email ?? 'Your current account'}',
                      style: context.mutedCaption,
                    ),
                    const SizedBox(height: Space.sm),
                    const AppText(
                      'Review each title, owner, tags and renewal date. Nothing uploads until you tap Import. Pending attachments are encrypted on this device and expire after 24 hours.',
                    ),
                    const SizedBox(height: Space.md),
                    if (error != null) Text(error!, style: context.dangerLabel),
                    if (drafts.length > 1)
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              label: 'Belongs to — apply to all',
                              controller: commonOwner,
                            ),
                            const SizedBox(height: Space.sm),
                            AppButton(
                              label: 'Apply owner to pending files',
                              secondary: true,
                              onPressed: busy
                                  ? null
                                  : () => setState(() {
                                      for (final d in drafts.where(
                                        (d) => !d.done,
                                      )) {
                                        d.owner.text = commonOwner.text;
                                      }
                                    }),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: Space.md),
                    for (final draft in drafts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.md),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      draft.file.name,
                                      style: context.type.titleMedium,
                                    ),
                                  ),
                                  if (!draft.done)
                                    Checkbox(
                                      value: draft.selected,
                                      onChanged:
                                          busy || draft.detectedKind == null
                                          ? null
                                          : (v) => setState(
                                              () => draft.selected = v!,
                                            ),
                                    )
                                  else
                                    const Icon(Icons.check_circle_outline),
                                ],
                              ),
                              AppText(
                                '${bytesLabel(draft.file.size)} · ${draft.done ? context.tr('Uploaded') : draft.detectedKind?.name.toUpperCase() ?? draft.file.mime}',
                                style: context.mutedCaption,
                              ),
                              if (draft.error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: Space.sm),
                                  child: Text(
                                    draft.error!,
                                    style: context.dangerLabel,
                                  ),
                                ),
                              if (!draft.done &&
                                  draft.detectedKind != null) ...[
                                const SizedBox(height: Space.md),
                                AppTextField(
                                  label: 'Document title',
                                  controller: draft.title,
                                  readOnly: busy,
                                  validator: (v) =>
                                      draft.selected && (v ?? '').trim().isEmpty
                                      ? 'Enter a title'
                                      : null,
                                ),
                                const SizedBox(height: Space.md),
                                AppTextField(
                                  label: 'Belongs to',
                                  controller: draft.owner,
                                  readOnly: busy,
                                  validator: (v) =>
                                      draft.selected && (v ?? '').trim().isEmpty
                                      ? 'Enter an owner'
                                      : null,
                                ),
                                const SizedBox(height: Space.md),
                                AppTextField(
                                  label: 'Tags (comma separated)',
                                  controller: draft.tags,
                                  readOnly: busy,
                                ),
                                const SizedBox(height: Space.sm),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const AppText('Renewal required'),
                                  value: draft.renewal,
                                  onChanged: busy
                                      ? null
                                      : (v) =>
                                            setState(() => draft.renewal = v),
                                ),
                                if (draft.renewal)
                                  AppButton(
                                    label: draft.expiry == null
                                        ? 'Choose expiry date'
                                        : dateLabel(draft.expiry!),
                                    secondary: true,
                                    icon: Icons.calendar_today_outlined,
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            final date = await showDatePicker(
                                              context: context,
                                              initialDate:
                                                  draft.expiry ??
                                                  DateTime.now(),
                                              firstDate: DateTime(2000),
                                              lastDate: DateTime(2100),
                                            );
                                            if (date != null && mounted) {
                                              setState(
                                                () => draft.expiry = date,
                                              );
                                            }
                                          },
                                  ),
                                if (busy && draft.selected)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: Space.sm,
                                    ),
                                    child: LinearProgressIndicator(
                                      value: draft.progress,
                                    ),
                                  ),
                              ],
                              if (!draft.done) ...[
                                const SizedBox(height: Space.sm),
                                AppButton(
                                  label: 'Remove from this batch',
                                  secondary: true,
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          await IncomingShare.instance.discard(
                                            draft.file.id,
                                          );
                                          if (mounted) {
                                            setState(
                                              () => drafts.remove(draft),
                                            );
                                          }
                                          draft.dispose();
                                        },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    if (drafts.isEmpty) ...[
                      const EmptyState(
                        title: 'No pending files',
                        message:
                            'Share a PDF, image or DOCX into Vaulty from another app.',
                      ),
                      const SizedBox(height: Space.lg),
                    ] else ...[
                      const SizedBox(height: Space.sm),
                    ],
                    AppButton(
                      label: busy ? 'Importing…' : 'Import selected files',
                      icon: Icons.upload_outlined,
                      onPressed: busy || drafts.every((d) => d.done)
                          ? null
                          : import,
                    ),
                    const SizedBox(height: Space.sm),
                    AppButton(
                      label: 'View documents',
                      secondary: true,
                      onPressed: busy ? null : () => context.go('/documents'),
                    ),
                    const SizedBox(height: Space.sm),
                    AppButton(
                      label: 'Discard pending imports',
                      danger: true,
                      onPressed: busy ? null : discardAll,
                    ),
                  ],
                ),
              ),
      ),
    ),
  );
}
