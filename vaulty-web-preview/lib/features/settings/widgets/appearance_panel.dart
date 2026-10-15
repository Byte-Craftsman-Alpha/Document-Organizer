import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_widgets.dart';
import '../providers/ui_preferences.dart';
import '../providers/settings_providers.dart';
class AppearancePanel extends ConsumerWidget {
  const AppearancePanel({super.key,this.compact=false});
  final bool compact;
  @override
  Widget build(BuildContext context,WidgetRef ref) {
    final ui=ref.watch(uiPreferencesProvider);
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      if(!compact) const SectionHeader('Appearance & language',subtitle:'Make this device feel like yours'),
      DropdownButtonFormField<String>(key:ValueKey(ui.language),initialValue:ui.language,isExpanded:true,decoration:InputDecoration(labelText:context.tr('Language')),
        items:[DropdownMenuItem(value:'system',child:AppText('Device language')),const DropdownMenuItem(value:'en',child:AppText('English')),const DropdownMenuItem(value:'hi',child:AppText('हिन्दी'))],
        onChanged:(value) async {if(value==null)return;try {await ref.read(uiPreferencesProvider.notifier).save(language:value);}catch(_){if(context.mounted)notice(context,'Couldn’t save that preference. Please retry.');}}),
      const SizedBox(height:Space.md),
      Wrap(
        spacing: Space.xs,
        runSpacing: Space.xs,
        children: [
          for (final mode in ThemeMode.values)
            AppChip(
              label: switch (mode) {
                ThemeMode.system => 'System',
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
              },
              selected: ref.watch(themeModeProvider) == mode,
              onTap: () async {
                try {
                  await ref.read(uiPreferencesProvider.notifier).save(theme: mode.name);
                  final current = ref.read(settingsProvider).valueOrNull;
                  if (current != null) {
                    await ref.read(settingsProvider.notifier).save(current.copyWith(theme: mode.name));
                  }
                } catch (_) {
                  if (context.mounted) {
                    notice(context, 'Couldn’t save that preference. Please retry.');
                  }
                }
              },
            ),
        ],
      ),
    ]);
  }
}
