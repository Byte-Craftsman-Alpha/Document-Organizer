import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/bootstrap.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/repositories/document_repository.dart';
import '../../../domain/repositories/live_capabilities.dart';

Future<SelectedFile?> pickSource(BuildContext context) =>
    AppBottomSheet.show<SelectedFile>(context, const SourceSheet());
Future<void> showSourceSheet(BuildContext context) async {
  final file = await pickSource(context);
  if (file != null && context.mounted) context.push('/upload', extra: file);
}

class SourceSheet extends ConsumerStatefulWidget {
  const SourceSheet({super.key});
  @override
  ConsumerState<SourceSheet> createState() => _SourceSheetState();
}

class _SourceSheetState extends ConsumerState<SourceSheet> {
  bool busy = false;
  String? error;
  Future<void> select(FileSource source) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final file = await ref
          .read(documentRepositoryProvider)
          .selectFile(source);
      if (mounted) Navigator.pop(context, file);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e is VaultFailure
              ? e.message
              : 'Couldn’t select a file. Please try a source again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: Space.page,
    children: [
      AppText('Keep something safe.', style: context.type.displaySmall),
      const SizedBox(height: Space.xs),
      AppText('Choose a source to add a document.', style: context.mutedBody),
      const SizedBox(height: Space.lg),
      if (busy)
        const LoadingList()
      else ...[
        for (final source in FileSource.values.where(
          (s) => !ref.watch(liveModeProvider) || s != FileSource.scan,
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: AppCard(
              onTap: () => select(source),
              child: Row(
                children: [
                  Icon(switch (source) {
                    FileSource.files => AppIcons.folderOpen,
                    FileSource.gallery => AppIcons.image,
                    FileSource.camera => AppIcons.camera,
                    FileSource.scan => AppIcons.scanner,
                  }),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: AppText(switch (source) {
                      FileSource.files => 'Files',
                      FileSource.gallery => 'Gallery',
                      FileSource.camera => 'Camera',
                      FileSource.scan => 'Scan',
                    }, style: context.type.titleMedium),
                  ),
                  const Icon(AppIcons.forward),
                ],
              ),
            ),
          ),
        if (error != null) Text(error!, style: context.dangerLabel),
      ],
      const SizedBox(height: Space.lg),
      AppText(
        ref.watch(liveModeProvider)
            ? 'PDF, JPEG, PNG, WebP, GIF, HEIC and DOCX · up to 50 MB. Camera captures a photo; automated scanning/OCR is not included.'
            : 'Demo sources return a sample file. No camera, gallery or storage permissions are requested.',
        style: context.mutedCaption,
      ),
    ],
  );
}
