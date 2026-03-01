import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SettingsPage extends HookConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('home'),
        ),
        title: Text(t.pages.settings.title),
      ),
      body: ListView(
        children: [
          SettingsSection(
            title: t.pages.settings.general.title,
            icon: Icons.layers_rounded,
            namedLocation: context.namedLocation('general'),
          ),
          SettingsSection(
            title: t.pages.logs.title,
            icon: Icons.description_rounded,
            namedLocation: context.namedLocation('logs'),
          ),
          SettingsSection(
            title: t.pages.about.title,
            icon: Icons.info_rounded,
            namedLocation: context.namedLocation('about'),
          ),
        ],
      ),
    );
  }
}

class SettingsSection extends HookConsumerWidget {
  const SettingsSection({super.key, required this.title, required this.icon, required this.namedLocation});

  final String title;
  final IconData icon;
  final String namedLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.go(namedLocation),
    );
  }
}
