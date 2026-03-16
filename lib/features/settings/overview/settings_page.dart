import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/router/go_router/helper/active_breakpoint_notifier.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/theme_preferences.dart';
import 'package:hiddify/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:hiddify/features/settings/notifier/reset_tunnel/reset_tunnel_notifier.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum ConfigOptionSection {
  warp,
  fragment;

  static final _warpKey = GlobalKey(debugLabel: "warp-section-key");
  static final _fragmentKey = GlobalKey(debugLabel: "fragment-section-key");

  GlobalKey get key => switch (this) {
    ConfigOptionSection.warp => _warpKey,
    ConfigOptionSection.fragment => _fragmentKey,
  };
}

class SettingsPage extends HookConsumerWidget {
  SettingsPage({super.key, String? section})
    : section = section != null ? ConfigOptionSection.values.byName(section) : null;

  final ConfigOptionSection? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final autoCheckIp = ref.watch(Preferences.autoCheckIp);
    final themeMode = ref.watch(themePreferencesProvider);

    // Compute isDark from provider — avoids race with MaterialApp rebuild
    final sysDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final isDark = themeMode == AppThemeMode.dark ||
        themeMode == AppThemeMode.black ||
        (themeMode == AppThemeMode.system && sysDark);

    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF5F7FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);
    final btnBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final btnBorder = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);

    final themeIcon = themeMode == AppThemeMode.light
        ? Icons.light_mode_outlined
        : Icons.dark_mode_outlined;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom app bar ──
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
                    t.pages.settings.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  // Import / Export / Reset menu
                  _OverflowMenu(isDark: isDark, ref: ref, t: t),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  // ── Connection section ──
                  _SectionLabel(label: t.pages.settings.general.title, isDark: isDark),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      _ToggleRow(
                        isDark: isDark,
                        icon: Icons.location_searching_rounded,
                        label: t.pages.settings.general.autoIpCheck,
                        value: autoCheckIp,
                        onChanged: (v) => ref.read(Preferences.autoCheckIp.notifier).update(v),
                      ),
                      _Divider(isDark: isDark),
                      _NavRow(
                        isDark: isDark,
                        icon: Icons.layers_rounded,
                        label: t.pages.settings.general.title,
                        onTap: () => context.go(context.namedLocation('general')),
                      ),
                      _Divider(isDark: isDark),
                      _NavRow(
                        isDark: isDark,
                        icon: Icons.input_rounded,
                        label: t.pages.settings.inbound.title,
                        onTap: () => context.go(context.namedLocation('inboundOptions')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Interface section ──
                  _SectionLabel(label: t.pages.settings.general.themeMode, isDark: isDark),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      _NavRow(
                        isDark: isDark,
                        icon: themeIcon,
                        label: t.pages.settings.general.themeMode,
                        trailing: Text(
                          _themeName(themeMode, t),
                          style: TextStyle(fontSize: 13, color: subColor),
                        ),
                        onTap: () {
                          final next = themeMode == AppThemeMode.light
                              ? AppThemeMode.dark
                              : AppThemeMode.light;
                          ref.read(themePreferencesProvider.notifier).changeThemeMode(next);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Networking section ──
                  _SectionLabel(label: t.pages.settings.routing.title, isDark: isDark),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      _NavRow(
                        isDark: isDark,
                        icon: Icons.route_rounded,
                        label: t.pages.settings.routing.title,
                        onTap: () => context.go(context.namedLocation('routeOptions')),
                      ),
                      _Divider(isDark: isDark),
                      _NavRow(
                        isDark: isDark,
                        icon: Icons.dns_rounded,
                        label: t.pages.settings.dns.title,
                        onTap: () => context.go(context.namedLocation('dnsOptions')),
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
                            t.pages.settings.tlsTricks.title,
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
                              icon: Icons.content_cut_rounded,
                              label: t.pages.settings.tlsTricks.title,
                              onTap: () => context.go(context.namedLocation('tlsTricks')),
                            ),
                            _Divider(isDark: isDark),
                            _NavRow(
                              isDark: isDark,
                              icon: Icons.cloud_rounded,
                              label: t.pages.settings.warp.title,
                              onTap: () => context.go(context.namedLocation('warpOptions')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── iOS reset tunnel ──
                  if (PlatformUtils.isIOS) ...[
                    _SettingsCard(
                      isDark: isDark,
                      children: [
                        _NavRow(
                          isDark: isDark,
                          icon: Icons.autorenew_rounded,
                          label: t.pages.settings.resetTunnel,
                          onTap: () async {
                            await ref.read(resetTunnelNotifierProvider.notifier).run();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── About section ──
                  _SectionLabel(label: t.pages.about.title, isDark: isDark),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      if (Breakpoint(context).isMobile()) ...[
                        _NavRow(
                          isDark: isDark,
                          icon: Icons.description_rounded,
                          label: t.pages.logs.title,
                          onTap: () => context.go(context.namedLocation('logs')),
                        ),
                        _Divider(isDark: isDark),
                        _NavRow(
                          isDark: isDark,
                          icon: Icons.info_rounded,
                          label: t.pages.about.title,
                          onTap: () => context.go(context.namedLocation('about')),
                        ),
                        _Divider(isDark: isDark),
                      ],
                      _NavRow(
                        isDark: isDark,
                        icon: Icons.send_outlined,
                        label: 'Telegram',
                        onTap: () => UriUtils.tryLaunch(Uri.parse('https://t.me/relokant_net')),
                      ),
                      _Divider(isDark: isDark),
                      _NavRow(
                        isDark: isDark,
                        icon: Icons.shield_outlined,
                        label: 'relokant.net/privacy',
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

  String _themeName(AppThemeMode mode, Translations t) {
    return mode.present(t);
  }
}

// ── Overflow menu (import / export / reset) ──

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.isDark, required this.ref, required this.t});
  final bool isDark;
  final WidgetRef ref;
  final Translations t;

  @override
  Widget build(BuildContext context) {
    final iconColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);

    return MenuAnchor(
      menuChildren: <Widget>[
        SubmenuButton(
          menuChildren: <Widget>[
            MenuItemButton(
              onPressed: () async => await ref
                  .read(dialogNotifierProvider.notifier)
                  .showConfirmation(
                    title: t.common.msg.import.confirm,
                    message: t.dialogs.confirmation.settings.import.msg,
                  )
                  .then((shouldImport) async {
                    if (shouldImport) {
                      await ref.read(configOptionNotifierProvider.notifier).importFromClipboard();
                    }
                  }),
              child: Text(t.pages.settings.options.import.clipboard),
            ),
            MenuItemButton(
              onPressed: () async => await ref
                  .read(dialogNotifierProvider.notifier)
                  .showConfirmation(
                    title: t.common.msg.import.confirm,
                    message: t.dialogs.confirmation.settings.import.msg,
                  )
                  .then((shouldImport) async {
                    if (shouldImport) {
                      await ref.read(configOptionNotifierProvider.notifier).importFromJsonFile();
                    }
                  }),
              child: Text(t.pages.settings.options.import.file),
            ),
          ],
          child: Text(t.common.import),
        ),
        SubmenuButton(
          menuChildren: <Widget>[
            MenuItemButton(
              onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonClipboard(),
              child: Text(t.pages.settings.options.export.anonymousToClipboard),
            ),
            MenuItemButton(
              onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(),
              child: Text(t.pages.settings.options.export.anonymousToFile),
            ),
            const PopupMenuDivider(),
            MenuItemButton(
              onPressed: () async => await ref
                  .read(configOptionNotifierProvider.notifier)
                  .exportJsonClipboard(excludePrivate: false),
              child: Text(t.pages.settings.options.export.allToClipboard),
            ),
            MenuItemButton(
              onPressed: () async =>
                  await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(excludePrivate: false),
              child: Text(t.pages.settings.options.export.allToFile),
            ),
          ],
          child: Text(t.common.export),
        ),
        const PopupMenuDivider(),
        MenuItemButton(
          child: Text(t.pages.settings.options.reset),
          onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).resetOption(),
        ),
      ],
      builder: (context, controller, child) => GestureDetector(
        onTap: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
          ),
          child: Icon(Icons.more_vert_rounded, size: 18, color: iconColor),
        ),
      ),
    );
  }
}

// ── Reusable widgets ──

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
        final version = snapshot.data?.version ?? '';
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
                  'Relokant',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              Text(
                'v$version',
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

// Keep for external usage (router or other files may reference SettingsSection)
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
