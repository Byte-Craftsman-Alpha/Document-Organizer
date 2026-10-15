import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/bootstrap.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/device/incoming_share.dart';
import '../../../domain/models/document.dart';
import '../../../domain/repositories/live_capabilities.dart';
import '../providers/document_providers.dart';

final documentBytesProvider = FutureProvider.autoDispose
    .family<DocumentBytes, String>((ref, id) {
      ref.watch(vaultIdentityProvider);
      ref.watch(
        documentProvider(id).select((value) => value.valueOrNull?.modifiedAt),
      );
      return (ref.watch(documentRepositoryProvider) as LiveDocumentRepository)
          .read(id);
    });
final pdfPreviewProvider = FutureProvider.autoDispose.family<Uint8List, String>(
  (ref, id) async {
    final file = await ref.watch(documentBytesProvider(id).future);
    if (kIsWeb) {
      throw const VaultFailure(
        'Use Open / download to view the PDF in your browser.',
      );
    }
    return (await IncomingShare.channel.invokeMethod<Uint8List>('renderPdf', {
      'bytes': file.bytes,
    }))!;
  },
);

class LiveFilePreview extends ConsumerWidget {
  const LiveFilePreview({super.key, required this.document});
  final Document document;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(documentBytesProvider(document.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroMode(
          enabled: !MediaQuery.disableAnimationsOf(context),
          child: Hero(
            tag: 'document-${document.id}',
            child: Material(
              color: context.colors.surfaceContainer,
              borderRadius: Corners.card,
              child: SizedBox(
                height: Metrics.preview,
                child: value.when(
                  loading: () => const SkeletonBox(height: Metrics.preview),
                  error: (e, _) => Padding(
                    padding: Space.card,
                    child: Center(
                      child: Text(
                        e is VaultFailure
                            ? e.message
                            : 'Preview unavailable. Try Open / download.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  data: (file) {
                    Widget image(Uint8List bytes) => ClipRRect(
                      borderRadius: Corners.card,
                      child: Image.memory(
                        bytes,
                        cacheWidth: Metrics.previewCache,
                        fit: BoxFit.contain,
                        semanticLabel: document.title,
                        errorBuilder: (_, _, _) => const Center(
                          child: AppText(
                            'Use Open / download for this image format.',
                          ),
                        ),
                      ),
                    );
                    if (document.kind == FileKind.pdf) {
                      return ref
                          .watch(pdfPreviewProvider(document.id))
                          .when(
                            data: image,
                            loading: () =>
                                const SkeletonBox(height: Metrics.preview),
                            error: (_, _) => const Padding(
                              padding: Space.card,
                              child: Center(
                                child: AppText(
                                  'Use Open / download to view this PDF.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          );
                    }
                    if (document.kind == FileKind.docx) {
                      return const Center(
                        child: Padding(
                          padding: Space.card,
                          child: AppText(
                            'DOCX ready. Use Open / download to view it in a compatible app.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return image(file.bytes);
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        if (value.valueOrNull != null)
          AppText(
            '${document.kind == FileKind.pdf ? '${context.tr('Page 1 preview')} · ' : ''}${context.tr(value.valueOrNull!.offline
                ? 'Offline cached copy — changes elsewhere are not checked'
                : value.valueOrNull!.fromCache
                ? 'Cached file · checked against Drive'
                : 'Downloaded and cached for next time')}',
            style: context.mutedCaption,
          ),
      ],
    );
  }
}
