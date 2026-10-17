import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_extensions.dart';
import '../l10n/app_strings.dart';
import '../../domain/repositories/live_capabilities.dart';
import '../theme/app_tokens.dart';
import '../theme/app_icons.dart';

export '../theme/app_extensions.dart';
export '../theme/app_tokens.dart';
export '../theme/app_icons.dart';
export 'notice_center.dart';
export '../l10n/app_strings.dart';

class AppPress extends StatefulWidget {
  const AppPress({super.key, required this.child});
  final Widget child;
  @override
  State<AppPress> createState() => _AppPressState();
}

class _AppPressState extends State<AppPress> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => setState(() => pressed = true),
    onPointerUp: (_) => setState(() => pressed = false),
    onPointerCancel: (_) => setState(() => pressed = false),
    child: AnimatedScale(
      scale: pressed && !MediaQuery.disableAnimationsOf(context)
          ? Motion.pressedScale
          : 1.0,
      duration: Motion.of(
        context,
        pressed
            ? const Duration(milliseconds: 90)
            : const Duration(milliseconds: 240),
      ),
      curve: pressed ? Curves.easeOutCubic : Curves.easeOutBack,
      child: widget.child,
    ),
  );
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = Space.card,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
    return onTap == null ? card : AppPress(child: card);
  }
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.secondary = false,
    this.danger = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary, danger;
  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: danger ? context.colors.error : null),
          const SizedBox(width: Space.xs),
        ],
        Flexible(
          child: AppText(
            label,
            textAlign: TextAlign.center,
            style: danger ? context.dangerLabel : null,
          ),
        ),
      ],
    );
    void tap() {
      HapticFeedback.lightImpact();
      onPressed?.call();
    }

    return AppPress(
      child: secondary || danger
          ? OutlinedButton(
              onPressed: onPressed == null ? null : tap,
              child: child,
            )
          : FilledButton(
              onPressed: onPressed == null ? null : tap,
              child: child,
            ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => AppPress(
    child: IconButton(
      tooltip: context.tr(label),
      onPressed: onPressed,
      icon: Icon(icon, semanticLabel: label),
    ),
  );
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.onTap,
    this.icon,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.autofocus = false,
    this.suffix,
  });
  final String label;
  final String? hint, errorText;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged, onSubmitted;
  final bool readOnly, autofocus;
  final VoidCallback? onTap;
  final IconData? icon;
  final TextInputType? keyboardType;
  final Widget? suffix;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator == null
        ? null
        : (v) {
            final error = validator!(v);
            return error == null ? null : context.tr(error);
          },
    onChanged: onChanged,
    onFieldSubmitted: onSubmitted,
    readOnly: readOnly,
    onTap: onTap,
    keyboardType: keyboardType,
    autofocus: autofocus,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    decoration: InputDecoration(
      labelText: context.tr(label),
      hintText: hint == null ? null : context.tr(hint!),
      errorText: errorText,
      prefixIcon: icon == null ? null : Icon(icon),
      suffixIcon: suffix,
    ),
  );
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onDeleted,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap, onDeleted;
  @override
  Widget build(BuildContext context) => AppPress(
    child: onDeleted != null
        ? InputChip(
            label: AppText(label),
            onDeleted: onDeleted,
            deleteButtonTooltipMessage: 'Remove $label',
          )
        : FilterChip(
            label: AppText(label),
            selected: selected,
            onSelected: onTap == null ? null : (_) => onTap!(),
          ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(title, style: context.type.titleMedium),
              if (subtitle != null)
                AppText(subtitle!, style: context.mutedCaption),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = AppIcons.inbox,
    this.action,
  });
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Padding(
      padding: Space.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: Metrics.logo, color: context.tokens.muted),
          const SizedBox(height: Space.md),
          AppText(
            title,
            style: context.type.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.xs),
          AppText(
            message,
            style: context.mutedBody,
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: Space.md), action!],
        ],
      ),
    ),
  );
}

class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.height = Metrics.skeleton});
  final double height;
  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: Motion.page,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.stop();
    } else {
      controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, _) => Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: Corners.card,
            color: Color.lerp(
              context.colors.surfaceContainer,
              context.colors.surface,
              controller.value,
            ),
          ),
        ),
      ),
    ),
  );
}

class LoadingList extends StatelessWidget {
  const LoadingList({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      SkeletonBox(),
      SizedBox(height: Space.sm),
      SkeletonBox(),
      SizedBox(height: Space.sm),
      SkeletonBox(),
    ],
  );
}

class AsyncPanel<T> extends StatelessWidget {
  const AsyncPanel({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
  });
  final AsyncValue<T> value;
  final Widget Function(T) builder;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => value.when(
    skipLoadingOnRefresh: false,
    data: builder,
    loading: () => const LoadingList(),
    error: (error, _) => EmptyState(
      title: 'Couldn’t load this yet',
      message: error is VaultFailure
          ? error.message
          : 'Your vault is safe. Try again when you’re ready.',
      icon: AppIcons.cloudOff,
      action: AppButton(
        label: 'Try again',
        secondary: true,
        onPressed: onRetry,
      ),
    ),
  );
}

class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.animate = true,
  });
  final Widget child;
  final int index;
  final bool animate;
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: Motion.page,
  );
  late final curved = CurvedAnimation(parent: controller, curve: Motion.enter);
  Timer? timer;
  bool started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      controller.value = 1;
      started = true;
    }
    if (!started) {
      started = true;
      timer = Timer(Motion.stagger * widget.index.clamp(0, 5), () {
        if (mounted) controller.forward();
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    curved.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween(begin: Motion.slide, end: Offset.zero).animate(curved),
      child: widget.child,
    ),
  );
}

class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.value,
    required this.label,
    this.secondary = 0,
  });
  final double value, secondary;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: '${(value * 100).round()} percent',
    child: RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: Motion.of(context, Motion.page),
        curve: Motion.enter,
        builder: (_, v, _) => ClipRRect(
          borderRadius: Corners.pill,
          child: SizedBox(
            height: Metrics.bar,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(color: context.colors.surfaceContainer),
                ),
                FractionallySizedBox(
                  widthFactor: v,
                  child: ColoredBox(
                    color: context.tokens.mint,
                    child: const SizedBox.expand(),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (secondary * (value == 0 ? 0 : v / value)).clamp(
                    0,
                    1,
                  ),
                  child: ColoredBox(
                    color: context.tokens.lime,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AppTable extends StatelessWidget {
  const AppTable({
    super.key,
    required this.headers,
    required this.rows,
    this.emptyMessage = 'No activity yet.',
  });
  final List<String> headers;
  final List<List<String>> rows;
  final String emptyMessage;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return EmptyState(title: 'Nothing here yet', message: emptyMessage);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: Metrics.table,
        child: Column(
          children: [
            Padding(
              padding: Space.row,
              child: Row(
                children: [
                  for (final h in headers)
                    Expanded(child: Text(h, style: context.type.labelMedium)),
                ],
              ),
            ),
            const Divider(),
            for (final row in rows)
              Padding(
                padding: Space.row,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final cell in row)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: Space.xs),
                          child: Text(cell, style: context.mutedCaption),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum StatusTone { healthy, warning, danger, neutral }

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = StatusTone.neutral});
  final String label;
  final StatusTone tone;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: Space.sm,
      vertical: Space.xxs,
    ),
    decoration: BoxDecoration(
      borderRadius: Corners.pill,
      color: switch (tone) {
        StatusTone.healthy => context.tokens.mint,
        StatusTone.warning => context.tokens.warning,
        StatusTone.danger => context.tokens.danger,
        StatusTone.neutral => context.colors.surfaceContainer,
      },
    ),
    child: AppText(
      label,
      style: tone == StatusTone.neutral
          ? context.type.labelMedium
          : context.statusLabel,
    ),
  );
}

class AppBottomSheet {
  static Future<T?> show<T>(BuildContext context, Widget child) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        sheetAnimationStyle: AnimationStyle(
          duration: Motion.of(context, Motion.page),
          reverseDuration: Motion.of(context, Motion.page),
        ),
        builder: (context) => FractionallySizedBox(
          heightFactor: Metrics.sheetFraction,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: child,
          ),
        ),
      );
}

class AppDialog {
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Move to Trash',
    bool destructive = true,
  }) async =>
      await showAppDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: AppText(title),
          content: AppText(message),
          actions: [
            AppTextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('Cancel'),
            ),
            AppButton(
              label: confirmLabel,
              danger: destructive,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ) ??
      false;
}

class HoldToConfirm extends StatefulWidget {
  const HoldToConfirm({
    super.key,
    required this.onConfirmed,
    required this.label,
  });
  final VoidCallback onConfirmed;
  final String label;
  @override
  State<HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends State<HoldToConfirm>
    with SingleTickerProviderStateMixin {
  late final controller =
      AnimationController(vsync: this, duration: Motion.hold)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) {
            HapticFeedback.heavyImpact();
            widget.onConfirmed();
          }
        });
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${widget.label}. Hold to confirm, or activate for an accessible confirmation dialog.',
    child: GestureDetector(
      onLongPressStart: (_) {
        HapticFeedback.selectionClick();
        controller.forward(from: 0);
      },
      onLongPressEnd: (_) => controller.reset(),
      onLongPressCancel: controller.reset,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: widget.label,
              danger: true,
              onPressed: () async {
                if (await AppDialog.confirm(
                  context,
                  title: 'Permanently delete?',
                  message: 'This cannot be undone.',
                  confirmLabel: 'Delete permanently',
                )) {
                  widget.onConfirmed();
                }
              },
            ),
          ),
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) => controller.value > 0
                ? Positioned(
                    left: Space.md,
                    right: Space.md,
                    bottom: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: controller.value,
                        minHeight: 3,
                        backgroundColor: context.colors.error.withValues(
                          alpha: 0.2,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.colors.error,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
}

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.children,
    this.onRefresh,
  });
  final String title;
  final String? subtitle;
  final List<Widget> actions, children;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    Widget scroll = CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverPadding(
          padding: Space.page,
          sliver: SliverList.builder(
            itemCount: children.length + 1,
            itemBuilder: (context, index) => Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Metrics.content),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Space.lg),
                    child: index == 0
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(title, style: context.type.displaySmall),
                              if (subtitle != null) ...[
                                const SizedBox(height: Space.xs),
                                AppText(subtitle!, style: context.mutedBody),
                              ],
                            ],
                          )
                        : children[index - 1],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    if (onRefresh != null) {
      scroll = RefreshIndicator.noSpinner(onRefresh: onRefresh!, child: scroll);
    }
    return Scaffold(
      appBar: AppBar(title: const AppText('vaulty'), actions: actions),
      body: SafeArea(top: false, child: scroll),
    );
  }
}

class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.onPressed,
    required this.child,
  });
  final VoidCallback? onPressed;
  final Widget child;
  @override
  Widget build(BuildContext context) => AppPress(
    child: TextButton(onPressed: onPressed, child: child),
  );
}

class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    this.leading,
    this.trailing,
    required this.title,
    this.subtitle,
    this.onTap,
  });
  final Widget? leading, trailing, subtitle;
  final Widget title;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => AppPress(
    child: ListTile(
      leading: leading,
      trailing: trailing,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    ),
  );
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  builder: builder,
  barrierDismissible: barrierDismissible,
  animationStyle: AnimationStyle(
    duration: Motion.of(context, Motion.page),
    reverseDuration: Motion.of(context, Motion.page),
    curve: Motion.enter,
    reverseCurve: Motion.exit,
  ),
);

class UploadActionIcon extends StatelessWidget {
  const UploadActionIcon({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: Metrics.touch,
    height: Metrics.touch,
    decoration: BoxDecoration(
      color: context.colors.primaryContainer,
      borderRadius: Corners.pill,
    ),
    child: Icon(
      AppIcons.add,
      color: context.colors.primary,
      semanticLabel: 'Add document',
    ),
  );
}
