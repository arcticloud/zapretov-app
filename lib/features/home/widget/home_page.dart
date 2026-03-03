import 'package:circle_flags/circle_flags.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/theme_preferences.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0a0a0a) : const Color(0xFF00E5A0),
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative elements
            if (isDark)
              _AmbientGlow()
            else ...[
              _DecoCircle(size: 320, topFraction: 0.20, opacity: 1.0),
              _DecoCircle(size: 440, topFraction: 0.14, opacity: 0.4),
            ],

            // Main content
            Column(
              children: [
                _Header(isDark: isDark),
                const SizedBox(height: 8),
                _LocationSelector(isDark: isDark),
                const Spacer(),
                const ConnectionButton(),
                const Spacer(),
                _Footer(isDark: isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themePreferencesProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Assets.images.logo.svg(
            height: 22,
            colorFilter: ColorFilter.mode(
              isDark ? const Color(0xFF00E5A0) : const Color(0xFF0a0a0a),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Relokant',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0a0a0a),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            'VPN',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 5,
              color: isDark
                  ? const Color(0xFF00E5A0)
                  : const Color(0xFF0a0a0a).withValues(alpha: 0.5),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              // Toggle between light and dark
              final current = themeMode;
              final next = (current == AppThemeMode.dark || current == AppThemeMode.black)
                  ? AppThemeMode.light
                  : AppThemeMode.dark;
              ref.read(themePreferencesProvider.notifier).changeThemeMode(next);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.06),
              ),
              child: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Location selector ────────────────────────────────────

class _LocationSelector extends ConsumerWidget {
  const _LocationSelector({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProxy = ref.watch(
      activeProxyNotifierProvider.select((value) => value.valueOrNull),
    );
    final proxiesOverview = ref.watch(proxiesOverviewNotifierProvider);
    final serverCount = proxiesOverview.valueOrNull?.items.length ?? 0;

    final countryCode = _detectCountryCode(activeProxy);
    final locationName = _locationName(activeProxy, countryCode);

    return GestureDetector(
      onTap: () => _showProxyPicker(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.06),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.06))
              : null,
        ),
        child: Row(
          children: [
            // Flag
            Container(
              width: 28,
              height: 18,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
              ),
              child: CircleFlag(countryCode.toLowerCase(), size: 28),
            ),
            const SizedBox(width: 12),
            // Server info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locationName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0a0a0a),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$serverCount сервер${_pluralServers(serverCount)} доступно',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }

  static String _pluralServers(int count) {
    if (count == 1) return '';
    if (count >= 2 && count <= 4) return 'а';
    return 'ов';
  }

  void _showProxyPicker(BuildContext context) {
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

    final ipCountry = proxy.ipinfo.countryCode;
    if (ipCountry.isNotEmpty) return ipCountry.toLowerCase();

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

// ─── Footer ───────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : const Color(0xFF0a0a0a),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: isDark
            ? Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06)))
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      child: Row(
        children: [
          _FooterItem(
            icon: Icons.settings_outlined,
            label: 'Настройки',
            isDark: isDark,
            onTap: () => context.goNamed('settings'),
          ),
          const SizedBox(width: 10),
          _FooterItem(
            icon: Icons.credit_card_outlined,
            label: 'Подписка',
            isDark: isDark,
            onTap: () {
              // TODO: navigate to subscription page
            },
          ),
          const SizedBox(width: 10),
          _FooterItem(
            icon: Icons.bar_chart_rounded,
            label: 'Статистика',
            isDark: isDark,
            onTap: () {
              // TODO: navigate to stats page
            },
          ),
        ],
      ),
    );
  }
}

class _FooterItem extends StatelessWidget {
  const _FooterItem({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.white.withValues(alpha: 0.05),
            border: isDark
                ? Border.all(color: Colors.white.withValues(alpha: 0.05))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: Colors.white.withValues(alpha: isDark ? 0.45 : 0.55),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: isDark ? 0.35 : 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Decorative elements ──────────────────────────────────

class _AmbientGlow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, -40),
          child: Container(
            width: 340,
            height: 340,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color.fromRGBO(0, 229, 160, 0.08),
                  Colors.transparent,
                ],
                stops: [0.0, 0.65],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DecoCircle extends StatelessWidget {
  const _DecoCircle({
    required this.size,
    required this.topFraction,
    required this.opacity,
  });

  final double size;
  final double topFraction;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Positioned(
      top: screenHeight * topFraction,
      left: 0,
      right: 0,
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Proxy picker (unchanged) ─────────────────────────────

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
