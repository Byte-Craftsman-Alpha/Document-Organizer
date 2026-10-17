import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../app/bootstrap.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/document_tile.dart';
import '../../../core/utils/format.dart';
import '../../../domain/models/document.dart';
import '../../../domain/repositories/document_repository.dart';
import '../../documents/providers/document_providers.dart';
import '../widgets/source_sheet.dart';
import '../../../domain/repositories/live_capabilities.dart';

class DocumentFormScreen extends ConsumerWidget {
  const DocumentFormScreen({super.key, this.id, this.file});
  final String? id;
  final SelectedFile? file;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (id == null) return _DocumentForm(file: file);
    return Scaffold(
      appBar: AppBar(title: const AppText('Edit document')),
      body: AsyncPanel(
        value: ref.watch(documentProvider(id!)),
        onRetry: () => ref.invalidate(documentsProvider),
        builder: (d) => d == null || d.isDeleted
            ? const EmptyState(
                title: 'Document unavailable',
                message: 'It may have moved to Trash.',
              )
            : _DocumentForm(original: d),
      ),
    );
  }
}

class _DocumentForm extends ConsumerStatefulWidget {
  const _DocumentForm({this.original, this.file});
  final Document? original;
  final SelectedFile? file;
  @override
  ConsumerState<_DocumentForm> createState() => _DocumentFormState();
}

class _DocumentFormState extends ConsumerState<_DocumentForm> {
  final form = GlobalKey<FormState>();
  late final newDocumentId = 'doc-${const Uuid().v4()}';
  late final title = TextEditingController(
    text:
        widget.original?.title ??
        widget.file?.name.replaceFirst(RegExp(r'\.[^.]+$'), '') ??
        '',
  );
  late final owner = TextEditingController(
    text: widget.original?.belongsTo ?? '',
  );
  late final expiryText = TextEditingController(
    text: widget.original?.expiry == null
        ? ''
        : dateLabel(widget.original!.expiry!),
  );
  late final uploaded = widget.original?.uploadedAt ?? DateTime.now();
  late final tags = TextEditingController(
    text: widget.original?.tags.join(', ') ?? '',
  );
  late final uploadText = TextEditingController(text: dateLabel(uploaded));
  late bool renewal = widget.original?.renewalRequired ?? false;
  late DateTime? expiry = widget.original?.expiry;
  bool busy = false, success = false;
  double progress = 0;
  String? error, savedId;
  @override
  void dispose() {
    title.dispose();
    owner.dispose();
    expiryText.dispose();
    uploadText.dispose();
    tags.dispose();
    super.dispose();
  }

  Future<void> pickExpiry() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: expiry ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 50),
    );
    if (value != null && mounted) {
      setState(() {
        expiry = value;
        expiryText.text = dateLabel(value);
      });
    }
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final tagValues = tags.text
        .split(',')
        .map((v) => v.trim().toLowerCase())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
    final old = widget.original;
    final file = widget.file;
    final doc =
        old?.copyWith(
          title: title.text.trim(),
          belongsTo: owner.text.trim(),
          expiry: expiry,
          renewalRequired: renewal,
          tags: tagValues,
        ) ??
        Document(
          id: newDocumentId,
          title: title.text.trim(),
          belongsTo: owner.text.trim(),
          kind: file!.kind,
          uploadedAt: uploaded,
          sizeBytes: file.sizeBytes,
          renewalRequired: renewal,
          tags: tagValues,
          expiry: renewal ? expiry : null,
        );
    savedId = doc.id;
    setState(() {
      busy = true;
      error = null;
    });
    final controller = ref.read(documentsProvider.notifier);
    final auth = ref.read(authRepositoryProvider);
    final operationOwner = auth is LiveAuthRepository
        ? auth.connection.vaultIdentity
        : null;
    try {
      if (old != null) {
        await controller.save(doc);
        if (!mounted) return;
        notice(
          context,
          'Changes saved',
          undo: () async {
            if (auth is LiveAuthRepository &&
                auth.connection.vaultIdentity != operationOwner) {
              return;
            }
            try {
              await controller.save(old);
            } catch (_) {
              if (mounted) notice(context, 'Couldn’t undo. Please retry.');
            }
          },
        );
        if (mounted) context.pop();
      } else {
        await for (final value
            in ref.read(documentRepositoryProvider).upload(doc, file!)) {
          if (!mounted) return;
          setState(() => progress = value);
        }
        ref.invalidate(documentsProvider);
        controller.refreshRelated();
        if (mounted) {
          setState(() {
            success = true;
            savedId = doc.id;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is VaultFailure
              ? e.message
              : 'Couldn’t save this document. Your form is still here; please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (success) {
      return AppPage(
        title: 'Safely in your vault.',
        subtitle: 'One less thing to keep track of.',
        children: [
          EmptyState(
            title: title.text,
            message: ref.watch(liveModeProvider)
                ? 'Your document is stored in your own Google Drive.'
                : 'Mock upload complete. No file was sent to Drive.',
            icon: AppIcons.check,
            action: AppButton(
              label: 'View document',
              onPressed: () {
                final target = savedId ?? newDocumentId;
                ref.invalidate(documentsProvider);
                if (target.isNotEmpty) {
                  context.go('/document/$target');
                } else {
                  context.go('/documents');
                }
              },
            ),
          ),
        ],
      );
    }
    if (widget.original == null && widget.file == null) {
      return AppPage(
        title: 'Add a document',
        children: [
          EmptyState(
            title: 'Choose a file first',
            message: 'A home for your important paperwork.',
            action: AppButton(
              label: 'Choose a source',
              onPressed: () => showSourceSheet(context),
            ),
          ),
        ],
      );
    }
    final suggestions =
        ref
            .watch(documentsProvider)
            .valueOrNull
            ?.map((d) => d.belongsTo)
            .toSet()
            .toList() ??
        <String>[];
    final body = Form(
      key: form,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: Space.page,
        children: [
          if (widget.original == null) ...[
            AppText(
              'A home for the important things.',
              style: context.type.displaySmall,
            ),
            const SizedBox(height: Space.lg),
          ],
          if (widget.original != null)
            DocumentThumbnail(document: widget.original!, hero: false)
          else
            AppCard(
              child: Row(
                children: [
                  const Icon(AppIcons.document),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.file!.name),
                        AppText(
                          '${bytesLabel(widget.file!.sizeBytes)} · Selected file',
                          style: context.mutedCaption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Space.lg),
          AbsorbPointer(
            absorbing: busy,
            child: Column(
              children: [
                AppTextField(
                  label: 'Document title *',
                  controller: title,
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'A title is required.'
                      : null,
                ),
                const SizedBox(height: Space.md),
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: owner.text),
                  optionsBuilder: (value) => suggestions.where(
                    (s) => s.toLowerCase().contains(value.text.toLowerCase()),
                  ),
                  onSelected: (v) => owner.text = v,
                  fieldViewBuilder: (context, controller, focus, onSubmitted) =>
                      TextFormField(
                        controller: controller,
                        focusNode: focus,
                        onChanged: (v) => owner.text = v,
                        onFieldSubmitted: (_) => onSubmitted(),
                        decoration: InputDecoration(
                          labelText: context.tr('Belongs to *'),
                          hintText: context.tr('Person, vehicle or property'),
                        ),
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Tell us who or what this belongs to.'
                            : null,
                      ),
                ),
                const SizedBox(height: Space.md),
                AppPress(
                  child: SwitchListTile(
                    title: const AppText('Renewal required?'),
                    subtitle: const AppText('Keep the expiry date in sight.'),
                    value: renewal,
                    onChanged: (v) => setState(() => renewal = v),
                  ),
                ),
                AnimatedSize(
                  duration: Motion.of(context, Motion.normal),
                  curve: Motion.enter,
                  child: renewal
                      ? Padding(
                          padding: const EdgeInsets.only(top: Space.md),
                          child: AppTextField(
                            label: 'Expiry date *',
                            controller: expiryText,
                            readOnly: true,
                            icon: AppIcons.calendar,
                            onTap: pickExpiry,
                            validator: (_) => renewal && expiry == null
                                ? 'Choose an expiry date.'
                                : null,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: Space.md),
                AppTextField(
                  label: 'Tags (optional)',
                  hint: 'personal, renewal',
                  controller: tags,
                ),
                const SizedBox(height: Space.md),
                AppTextField(
                  label: 'Date of upload',
                  controller: uploadText,
                  readOnly: true,
                  icon: AppIcons.calendar,
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          if (error != null) ...[
            Text(error!, style: context.dangerLabel),
            const SizedBox(height: Space.md),
          ],
          if (busy) ...[
            StatBar(value: progress, label: 'Upload progress'),
            const SizedBox(height: Space.sm),
            AppText(
              widget.original == null
                  ? 'Adding to your vault… ${(progress * 100).round()}%'
                  : 'Saving changes…',
              style: context.mutedCaption,
            ),
            const SizedBox(height: Space.md),
          ],
          AppButton(
            label: widget.original == null ? 'Add to vault' : 'Save changes',
            icon: AppIcons.check,
            onPressed: busy ? null : submit,
          ),
          const SizedBox(height: Space.lg),
          AppText(
            ref.watch(liveModeProvider)
                ? 'Uploads go directly to your private Google Drive app folder.'
                : 'UI demo · Google Drive storage is not connected.',
            style: context.mutedCaption,
          ),
        ],
      ),
    );
    return PopScope(
      canPop: !busy,
      child: widget.original != null
          ? body
          : Scaffold(
              appBar: AppBar(title: const AppText('Add document')),
              body: SafeArea(child: body),
            ),
    );
  }
}
