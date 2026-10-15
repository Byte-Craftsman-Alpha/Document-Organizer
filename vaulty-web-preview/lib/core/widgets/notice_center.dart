import 'dart:collection';
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import '../l10n/app_strings.dart';

class _Notice {
  _Notice(this.message, this.undo, this.undoLabel);
  final String message, undoLabel;
  final VoidCallback? undo;
}

class _NoticeQueue {
  final items = Queue<_Notice>();
  String? active;
  int generation = 0;
  bool showing = false;
}

final _queues = Expando<_NoticeQueue>();
void notice(BuildContext context, String message, {VoidCallback? undo}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final queue = _queues[messenger] ??= _NoticeQueue();
  final text = context.tr(message);
  // Informational duplicates coalesce. Undo actions remain separate and ordered.
  if (undo == null &&
      (queue.active == text ||
          queue.items.any((e) => e.undo == null && e.message == text))) {
    return;
  }
  queue.items.add(_Notice(text, undo, context.tr('Undo')));
  _showNext(messenger, queue);
}

void _showNext(ScaffoldMessengerState messenger, _NoticeQueue queue) {
  if (!messenger.mounted || queue.showing || queue.items.isEmpty) return;
  final item = queue.items.removeFirst();
  final generation = queue.generation;
  queue.showing = true;
  queue.active = item.message;
  final controller = messenger.showSnackBar(
    SnackBar(
      content: Text(item.message),
      duration: FeedbackTiming.forMessage(item.message),
      persist: false,
      behavior: SnackBarBehavior.floating,
      showCloseIcon: true,
      dismissDirection: DismissDirection.horizontal,
      action: item.undo == null
          ? null
          : SnackBarAction(label: item.undoLabel, onPressed: item.undo!),
    ),
  );
  controller.closed.then((_) {
    if (generation != queue.generation) return;
    queue.showing = false;
    queue.active = null;
    _showNext(messenger, queue);
  });
}

void clearNotices(BuildContext context) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final queue = _queues[messenger];
  if (queue != null) {
    queue.generation++;
    queue.items.clear();
    queue.active = null;
    queue.showing = false;
  }
  messenger.clearSnackBars();
  messenger.removeCurrentSnackBar();
}
