import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/bootstrap.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/repositories/live_capabilities.dart';

final sharingProvider = StateProvider<Set<String>>((ref) {
  ref.watch(vaultIdentityProvider);
  return {};
});
Future<void> quickShare(BuildContext context, WidgetRef ref, String id) async {
  if (ref.read(sharingProvider).contains(id)) return;
  final repo = ref.read(documentRepositoryProvider);
  if (repo is! LiveDocumentRepository) {
    notice(
      context,
      'System sharing is available in the connected app, not the demo.',
    );
    return;
  }
  final controller = ref.read(sharingProvider.notifier);
  controller.state = {...ref.read(sharingProvider), id};
  try {
    await repo.shareCopy(id);
  } catch (e) {
    if (context.mounted) {
      notice(
        context,
        e is VaultFailure
            ? e.message
            : 'Could not prepare the file for sharing. Please retry.',
      );
    }
  } finally {
    if (controller.mounted) {
      controller.state = {...controller.state}..remove(id);
    }
  }
}

class QuickShareButton extends ConsumerWidget {
  const QuickShareButton({super.key, required this.id, this.full = false});
  final String id;
  final bool full;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(sharingProvider).contains(id);
    return full
        ? AppButton(
            label: busy ? 'Preparing file…' : 'Share',
            icon: AppIcons.share,
            onPressed: busy ? null : () => quickShare(context, ref, id),
          )
        : AppIconButton(
            label: busy ? 'Preparing file' : 'Share document',
            icon: busy ? AppIcons.refresh : AppIcons.share,
            onPressed: busy ? null : () => quickShare(context, ref, id),
          );
  }
}
