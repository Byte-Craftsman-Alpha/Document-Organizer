import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_widgets.dart';
import 'token_gallery.dart';

class DesignGallery extends StatefulWidget {
  const DesignGallery({super.key, required this.onTheme});
  final ValueChanged<ThemeMode> onTheme;
  @override
  State<DesignGallery> createState() => _DesignGalleryState();
}

class _DesignGalleryState extends State<DesignGallery> {
  bool toggle = true;
  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Quietly considered.',
    subtitle: 'VAULTY / DESIGN SYSTEM\nPublic Sans · 4pt rhythm · Material 3',
    actions: [
      AppIconButton(
        label: 'Light theme',
        icon: AppIcons.lightMode,
        onPressed: () => widget.onTheme(ThemeMode.light),
      ),
      AppIconButton(
        label: 'Dark theme',
        icon: AppIcons.darkMode,
        onPressed: () => widget.onTheme(ThemeMode.dark),
      ),
    ],
    children: [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              'Made for peace of mind',
              subtitle: 'Accessible, warm, deliberately simple.',
            ),
            AppText(
              'A place for what matters.',
              style: context.type.displaySmall,
            ),
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: const [
                StatusPill('Healthy', tone: StatusTone.healthy),
                StatusPill('Expiring soon', tone: StatusTone.warning),
                StatusPill('Overdue', tone: StatusTone.danger),
                StatusPill('No renewal'),
              ],
            ),
            const SizedBox(height: Space.lg),
            const StatBar(value: .64, secondary: .16, label: 'Storage preview'),
            const SizedBox(height: Space.sm),
            AppText('9.6 GB of 15 GB used', style: context.mutedCaption),
          ],
        ),
      ),
      Wrap(
        spacing: Space.xs,
        runSpacing: Space.xs,
        children: [
          AppButton(label: 'Add document', icon: AppIcons.add, onPressed: () {}),
          AppButton(label: 'Secondary', secondary: true, onPressed: () {}),
          AppButton(label: 'Destructive', danger: true, onPressed: () {}),
        ],
      ),
      const AppTextField(
        label: 'Document title',
        hint: 'e.g. Vehicle insurance',
        icon: AppIcons.document,
      ),
      AppCard(
        child: Column(
          children: [
            const SectionHeader('Small details, consistent everywhere'),
            Wrap(
              spacing: Space.xs,
              children: [
                AppChip(label: 'All files', selected: true, onTap: () {}),
                AppChip(label: 'PDF', onTap: () {}),
                AppChip(label: 'Removable', onDeleted: () {}),
              ],
            ),
            SwitchListTile(
              title: const AppText('Renewal reminders'),
              value: toggle,
              onChanged: (v) => setState(() => toggle = v),
            ),
            Wrap(
              spacing: Space.xs,
              children: [
                AppButton(
                  label: 'Bottom sheet',
                  secondary: true,
                  onPressed: () => AppBottomSheet.show<void>(
                    context,
                    const Padding(
                      padding: Space.page,
                      child: EmptyState(
                        title: 'Room to breathe',
                        message: 'Sheets share the same theme and motion.',
                      ),
                    ),
                  ),
                ),
                AppButton(
                  label: 'Dialog',
                  secondary: true,
                  onPressed: () => AppDialog.confirm(
                    context,
                    title: 'A careful confirmation',
                    message: 'No action is taken in the gallery.',
                    confirmLabel: 'Confirm',
                    destructive: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const AppCard(
        child: AppTable(
          headers: ['Event', 'Document', 'Time'],
          rows: [
            ['Uploaded', 'Vehicle insurance', 'Today'],
            ['Renewed', 'Passport', 'Yesterday'],
          ],
        ),
      ),
      const SkeletonBox(),
      const EmptyState(
        title: 'A fresh start',
        message: 'Empty states are calm and actionable.',
      ),
      const TokenGallery(),
      if (kDebugMode)
        AppText(
          'Debug gallery · All tokens live in core/theme',
          style: context.mutedCaption,
        ),
    ],
  );
}
