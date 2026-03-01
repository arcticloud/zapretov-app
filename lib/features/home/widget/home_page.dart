import 'package:circle_flags/circle_flags.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
import 'package:hiddify/features/proxy/active/active_proxy_delay_indicator.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider).requireValue;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Assets.images.logo.svg(height: 22),
            const SizedBox(width: 8),
            Text(
              t.common.appTitle,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: () => context.goNamed('settings'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/world_map.png'),
            fit: BoxFit.cover,
            opacity: 0.09,
            colorFilter: theme.brightness == Brightness.dark
                ? ColorFilter.mode(Colors.white.withValues(alpha: .15), BlendMode.srcIn)
                : ColorFilter.mode(Colors.grey.withValues(alpha: 1), BlendMode.srcATop),
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LocationSelector(),
              SizedBox(height: 32),
              ConnectionButton(),
              SizedBox(height: 12),
              ActiveProxyDelayIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationSelector extends ConsumerWidget {
  const _LocationSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeProxy = ref.watch(
      activeProxyNotifierProvider.select((value) => value.valueOrNull),
    );

    final countryCode = _detectCountryCode(activeProxy);
    final locationName = _locationName(activeProxy, countryCode);

    return GestureDetector(
      onTap: () => _showProxyPicker(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleFlag(countryCode.toLowerCase(), size: 24),
            const SizedBox(width: 10),
            Text(
              locationName,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _showProxyPicker(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _ProxyPickerSheet(),
    );
  }

  static String _detectCountryCode(OutboundInfo? proxy) {
    if (proxy == null) return 'ru';

    final tag = proxy.tagDisplay.toLowerCase();

    // Check for country keywords in tag name
    const tagToCountry = {
      'russia': 'ru', 'россия': 'ru', 'moscow': 'ru', 'москва': 'ru', 'ru': 'ru',
      'usa': 'us', 'сша': 'us', 'united states': 'us', 'america': 'us',
      'germany': 'de', 'германия': 'de', 'berlin': 'de', 'frankfurt': 'de',
      'netherlands': 'nl', 'нидерланды': 'nl', 'amsterdam': 'nl',
      'uk': 'gb', 'britain': 'gb', 'великобритания': 'gb', 'london': 'gb',
      'france': 'fr', 'франция': 'fr', 'paris': 'fr',
      'turkey': 'tr', 'турция': 'tr', 'istanbul': 'tr',
      'belarus': 'by', 'беларусь': 'by', 'minsk': 'by',
      'kazakhstan': 'kz', 'казахстан': 'kz',
      'ukraine': 'ua', 'украина': 'ua', 'kiev': 'ua', 'kyiv': 'ua',
      'finland': 'fi', 'финляндия': 'fi', 'helsinki': 'fi',
    };

    for (final entry in tagToCountry.entries) {
      if (tag.contains(entry.key)) return entry.value;
    }

    // Fall back to ipinfo country code if available
    final ipCountry = proxy.ipinfo.countryCode;
    if (ipCountry.isNotEmpty) return ipCountry.toLowerCase();

    // Default to Russia (our primary server location)
    return 'ru';
  }

  static String _locationName(OutboundInfo? proxy, String countryCode) {
    const names = {
      'ru': 'Россия',
      'us': 'США',
      'gb': 'Великобритания',
      'de': 'Германия',
      'nl': 'Нидерланды',
      'by': 'Беларусь',
      'kz': 'Казахстан',
      'ua': 'Украина',
      'fr': 'Франция',
      'tr': 'Турция',
      'fi': 'Финляндия',
    };
    return names[countryCode] ?? countryCode.toUpperCase();
  }
}

class _ProxyPickerSheet extends ConsumerWidget {
  const _ProxyPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final proxies = ref.watch(proxiesOverviewNotifierProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Выберите локацию',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: proxies.when(
                data: (group) {
                  if (group == null || group.items.isEmpty) {
                    return const Center(child: Text('Нет доступных серверов'));
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: group.items.length,
                    itemBuilder: (context, index) {
                      final proxy = group.items[index];
                      final selected = group.selected == proxy.tag;
                      final countryCode = _LocationSelector._detectCountryCode(proxy);
                      final locationName = _LocationSelector._locationName(proxy, countryCode);

                      return ListTile(
                        leading: CircleFlag(countryCode.toLowerCase(), size: 32),
                        title: Text(
                          locationName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        subtitle: proxy.urlTestDelay > 0 && proxy.urlTestDelay < 65000
                            ? Text('${proxy.urlTestDelay} ms')
                            : null,
                        trailing: selected
                            ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                            : null,
                        selected: selected,
                        selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onTap: () async {
                          await ref.read(proxiesOverviewNotifierProvider.notifier).changeProxy(
                            group.tag,
                            proxy.tag,
                          );
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      );
                    },
                  );
                },
                error: (_, __) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Подключитесь к VPN,\nчтобы выбрать локацию',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        );
      },
    );
  }
}