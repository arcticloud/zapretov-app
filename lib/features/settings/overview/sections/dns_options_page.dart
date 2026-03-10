import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/widget/preference_tile.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DnsOptionsPage extends HookConsumerWidget {
  const DnsOptionsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF5F7FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final iconColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          t.pages.settings.dns.title,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: textColor),
        ),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            onSurface: textColor,
            onSurfaceVariant: iconColor,
            surface: bg,
          ),
          listTileTheme: ListTileThemeData(
            tileColor: Colors.transparent,
            iconColor: iconColor,
            textColor: textColor,
          ),
        ),
        child: ListView(
        children: [
          ValuePreferenceWidget(
            value: ref.watch(ConfigOptions.remoteDnsAddress),
            icon: Icons.vpn_lock_rounded,
            preferences: ref.watch(ConfigOptions.remoteDnsAddress.notifier),
            title: t.pages.settings.dns.remoteDns,
          ),
          ChoicePreferenceWidget(
            selected: ref.watch(ConfigOptions.remoteDnsDomainStrategy),
            preferences: ref.watch(ConfigOptions.remoteDnsDomainStrategy.notifier),
            choices: DomainStrategy.values,
            title: t.pages.settings.dns.remoteDnsDomainStrategy,
            icon: Icons.sync_alt_rounded,
            presentChoice: (value) => value.present(t),
          ),
          SwitchListTile.adaptive(
            title: Text(t.pages.settings.dns.enableFakeDns),
            secondary: const Icon(Icons.private_connectivity_rounded),
            value: ref.watch(ConfigOptions.enableFakeDns),
            onChanged: ref.read(ConfigOptions.enableFakeDns.notifier).update,
          ),
          ValuePreferenceWidget(
            title: t.pages.settings.dns.directDns,
            icon: Icons.public_rounded,
            value: ref.watch(ConfigOptions.directDnsAddress),
            preferences: ref.watch(ConfigOptions.directDnsAddress.notifier),
          ),
          ChoicePreferenceWidget(
            selected: ref.watch(ConfigOptions.directDnsDomainStrategy),
            preferences: ref.watch(ConfigOptions.directDnsDomainStrategy.notifier),
            choices: DomainStrategy.values,
            title: t.pages.settings.dns.directDnsDomainStrategy,
            icon: Icons.sync_alt_rounded,
            presentChoice: (value) => value.present(t),
          ),
          // SwitchListTile.adaptive(
          //   title: Text(t.pages.settings.dns.enableDnsRouting),
          //   secondary: const Icon(Icons.private_connectivity_rounded),
          //   value: ref.watch(ConfigOptions.enableDnsRouting),
          //   onChanged: ref.read(ConfigOptions.enableDnsRouting.notifier).update,
          // ),
        ],
        ),
      ),
    );
  }
}
