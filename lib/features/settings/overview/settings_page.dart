import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/theme_preferences.dart';
import 'package:hiddify/features/purchase/purchase_page.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

void _openPurchaseFromSettings(BuildContext context) {
  if (Platform.isIOS || Platform.isAndroid) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PurchasePage()),
    );
  } else {
    UriUtils.tryLaunch(Uri.parse(Constants.pricingUrl));
  }
}

class SettingsPage extends HookConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF5F7FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);
    final btnBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final btnBorder = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);

    final autoConnect = ref.watch(Preferences.autoConnect);
    final autoCheckIp = ref.watch(Preferences.autoCheckIp);
    final themeMode = ref.watch(themePreferencesProvider);

    final themeIcon = themeMode == AppThemeMode.dark
        ? Icons.dark_mode_outlined
        : themeMode == AppThemeMode.light
            ? Icons.light_mode_outlined
            : Icons.brightness_auto_outlined;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Custom app bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.goNamed('home'),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: btnBg,
                        border: Border.all(color: btnBorder),
                      ),
                      child: Icon(Icons.arrow_back, size: 18, color: textColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Настройки',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  // ── Subscription card ──
                  _SubscriptionCard(isDark: isDark),
                  const SizedBox(height: 16),

                  // ── Connection section ──
                  _SectionLabel(label: 'Подключение', isDark: isDark),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      _ToggleRow(
                        isDark: isDark,
                        icon: Icons.sync_rounded,
                        label: 'Автоподключение',
                        value: autoConnect,
                        onChanged: (v) => ref.read(Preferences.autoConnect.notifier).update(v),
                      ),
                      _Divider(isDark: isDark),
                      _ToggleRow(
                        isDark: isDark,
                        icon: Icons.location_searching_rounded,
                        label: 'Проверка IP',
                        value: autoCheckIp,
                        onChanged: (v) => ref.read(Preferences.autoCheckIp.notifier).update(v),
                      ),
                      _Divider(isDark: isDark),
                      _NavRow(
                        isDark: isDark,
                        icon: Icons.tune_rounded,
                        label: 'Режим сервиса',
                        onTap: () => context.go(context.namedLocation('inboundOptions')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Interface section ──
                  _SectionLabel(label: 'Интерфейс', isDark: isDark),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      _NavRow(
                        isDark: isDark,
                        icon: themeIcon,
                        label: 'Тема',
                        trailing: Text(
                          _themeName(themeMode),
                          style: TextStyle(fontSize: 13, color: subColor),
                        ),
                        onTap: () {
                          final next = themeMode == AppThemeMode.dark
                              ? AppThemeMode.light
                              : AppThemeMode.dark;
                          ref.read(themePreferencesProvider.notifier).changeThemeMode(next);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Advanced section (accordion) ──
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: Icon(Icons.build_outlined, size: 20, color: subColor),
                          title: Text(
                            'Дополнительно',
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          iconColor: subColor,
                          collapsedIconColor: subColor,
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          childrenPadding: EdgeInsets.zero,
                          children: [
                            _Divider(isDark: isDark),
                            _NavRow(
                              isDark: isDark,
                              icon: Icons.dns_rounded,
                              label: 'DNS',
                              onTap: () => context.go(context.namedLocation('dnsOptions')),
                            ),
                            _Divider(isDark: isDark),
                            _NavRow(
                              isDark: isDark,
                              icon: Icons.alt_route_rounded,
                              label: 'Маршруты',
                              onTap: () => context.go(context.namedLocation('routeOptions')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── About section ──
                  _SectionLabel(label: 'О приложении', isDark: isDark),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      _NavRow(
                        isDark: isDark,
                        icon: Icons.send_outlined,
                        label: 'Telegram канал',
                        onTap: () => UriUtils.tryLaunch(Uri.parse('https://t.me/relokant_net')),
                      ),
                      _Divider(isDark: isDark),
                      _NavRow(
                        isDark: isDark,
                        icon: Icons.description_outlined,
                        label: 'Условия использования',
                        onTap: () => UriUtils.tryLaunch(Uri.parse('https://relokant.net/terms.html')),
                      ),
                      _Divider(isDark: isDark),
                      _NavRow(
                        isDark: isDark,
                        icon: Icons.shield_outlined,
                        label: 'Конфиденциальность',
                        onTap: () => UriUtils.tryLaunch(Uri.parse('https://relokant.net/privacy.html')),
                      ),
                      _Divider(isDark: isDark),
                      _VersionRow(isDark: isDark),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _themeName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return 'Тёмная';
      case AppThemeMode.light:
        return 'Светлая';
      default:
        return 'Системная';
    }
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPurchaseFromSettings(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF00E5A0).withValues(alpha: 0.15),
              const Color(0xFF00B480).withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(color: const Color(0xFF00E5A0).withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E5A0).withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.check_circle_outline, color: Color(0xFF00E5A0), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Базовый план',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Активна · до апреля 2026',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5A0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Продлить',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0a0a0a),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: isDark ? const Color(0xFF52525B) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.isDark, required this.children});
  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });
  final bool isDark;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final iconColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);
    final chevronColor = isDark ? const Color(0xFF52525B) : const Color(0xFFCBD5E1);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 15, color: textColor)),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 4),
            ],
            Icon(Icons.chevron_right_rounded, size: 18, color: chevronColor),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final bool isDark;
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final iconColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 15, color: textColor)),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF00E5A0),
            activeTrackColor: const Color(0xFF00E5A0).withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '–';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Версия',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              Text(
                version,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Keep for external usage (router references SettingsSection)
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
