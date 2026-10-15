import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/utils/format.dart';
import '../../../domain/models/share_record.dart';
import '../providers/share_providers.dart';

class ShareCard extends ConsumerStatefulWidget {
  const ShareCard({super.key, required this.share});
  final ShareRecord share;
  @override
  ConsumerState<ShareCard> createState() => _ShareCardState();
}

class _ShareCardState extends ConsumerState<ShareCard> {
  bool busy = false;
  Future<void> revoke() async {
    if (!await AppDialog.confirm(
      context,
      title: 'Revoke access?',
      message:
          'Recipients will no longer have access through this share. You can create a new share later.',
      confirmLabel: 'Revoke share',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await ref.read(sharesProvider.notifier).revoke(widget.share);
      if (mounted) notice(context, 'Share revoked');
    } catch (_) {
      if (mounted) {
        notice(context, 'Couldn’t revoke this share. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final share = widget.share, status = widget.share.status(DateTime.now());
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(share.documentTitle, style: context.type.titleMedium),
          const SizedBox(height: Space.xs),
          Text(share.recipients.join(', ')),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              StatusPill(
                status,
                tone: status == 'Active'
                    ? StatusTone.healthy
                    : StatusTone.neutral,
              ),
              StatusPill(
                share.role == ShareRole.view ? 'View only' : 'Can edit',
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          AppText(
            'Expires ${dateLabel(share.expiresAt)}',
            style: context.mutedCaption,
          ),
          AppText(
            share.restrictDownload
                ? 'Download & copy restricted (UI only)'
                : 'Download allowed (UI only)',
            style: context.mutedCaption,
          ),
          if (status == 'Active') ...[
            const SizedBox(height: Space.md),
            AppButton(
              label: 'Revoke access',
              danger: true,
              onPressed: busy ? null : revoke,
            ),
          ],
        ],
      ),
    );
  }
}
