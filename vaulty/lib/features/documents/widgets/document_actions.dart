import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_widgets.dart';
import '../providers/document_providers.dart';
import '../../../app/bootstrap.dart';
import '../../../domain/repositories/live_capabilities.dart';

Future<bool> trashDocuments(
  BuildContext context,
  WidgetRef ref,
  Set<String> ids,
) async {
  final confirmed = await AppDialog.confirm(
    context,
    title:
        'Move ${ids.length == 1 ? 'document' : '${ids.length} documents'} to Trash?',
    message: ref.read(liveModeProvider)
        ? 'You can restore this file for 30 days before the next sync purges it. Copies already exported to other people cannot be recalled.'
        : 'You can restore documents for 30 days. Active shares are revoked and won’t reopen when restored.',
  );
  if (!confirmed || !context.mounted) return false;
  final controller = ref.read(documentsProvider.notifier);
  final auth = ref.read(authRepositoryProvider);
  final operationOwner = auth is LiveAuthRepository
      ? auth.connection.vaultIdentity
      : null;
  try {
    await controller.trash(ids);
    if (!context.mounted) return true;
  notice(
    context,
    'Moved to Trash',
    undo: () async {
      if (auth is LiveAuthRepository &&
          auth.connection.vaultIdentity != operationOwner) {
        return;
      }
      try {
        await controller.restore(ids);
      } catch (_) {
        if (context.mounted) {
          notice(context, 'Couldn’t restore. Please retry in Trash.');
        }
      }
    },
  );
    return true;
  } catch (_) {
    if (context.mounted) {
      notice(
        context,
        'Couldn’t finish all changes. Refreshing the vault; check Trash before retrying.',
      );
    }
    return false;
  }
}
