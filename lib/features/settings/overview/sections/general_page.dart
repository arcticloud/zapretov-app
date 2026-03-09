import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/auto_start/notifier/auto_start_notifier.dart';
import 'package:hiddify/features/common/general_pref_tiles.dart';
import 'package:hiddify/features/log/model/log_level.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/widget/preference_tile.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class GeneralPage extends HookConsumerWidget {
  const GeneralPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    return Scaffold(
      appBar: AppBar(title: Text(t.pages.settings.general.title)),
      body: ListView(
        children: [
          const LocalePrefTile(),
          const ThemeModePrefTile(),
          SwitchListTile.adaptive(
            title: Text(t.pages.settings.general.autoConnect),
            subtitle: Text(t.pages.settings.general.autoConnectMsg),
            secondary: const Icon(Icons.flash_on_rounded),
            value: ref.watch(Preferences.autoConnect),
            onChanged: ref.read(Preferences.autoConnect.notifier).update,
          ),
          if (PlatformUtils.isDesktop) ...[
            const ClosingPrefTile(),
            SwitchListTile.adaptive(
              title: Text(t.pages.settings.general.autoStart),
              secondary: const Icon(Icons.auto_mode_rounded),
              value: ref.watch(autoStartNotifierProvider).asData!.value,
              onChanged: (value) async => value
                  ? await ref.read(autoStartNotifierProvider.notifier).enable()
                  : await ref.read(autoStartNotifierProvider.notifier).disable(),
            ),
            SwitchListTile.adaptive(
              title: Text(t.pages.settings.general.silentStart),
              secondary: const Icon(Icons.visibility_off_rounded),
              value: ref.watch(Preferences.silentStart),
              onChanged: ref.read(Preferences.silentStart.notifier).update,
            ),
          ],
          ExpansionTile(
            leading: const Icon(Icons.build_rounded),
            title: Text(t.pages.settings.general.debugMode),
            childrenPadding: EdgeInsets.zero,
            children: [
              SwitchListTile.adaptive(
                title: Text(t.pages.settings.general.debugMode),
                secondary: const Icon(Icons.bug_report_rounded),
                value: ref.watch(debugModeNotifierProvider),
                onChanged: (value) async {
                  if (value)
                    await ref
                        .read(dialogNotifierProvider.notifier)
                        .showOk(t.pages.settings.general.debugMode, t.pages.settings.general.debugModeMsg);
                  await ref.read(debugModeNotifierProvider.notifier).update(value);
                },
              ),
              if (ref.watch(debugModeNotifierProvider))
                ChoicePreferenceWidget(
                  selected: ref.watch(ConfigOptions.logLevel),
                  preferences: ref.watch(ConfigOptions.logLevel.notifier),
                  choices: LogLevel.choices,
                  title: t.pages.settings.general.logLevel,
                  icon: Icons.description_rounded,
                  presentChoice: (value) => value.name.toUpperCase(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
