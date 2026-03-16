import 'dart:io';

import 'package:circle_flags/circle_flags.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/theme_preferences.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
import 'package:hiddify/features/intro/widget/intro_page.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/account/account_page.dart';
import 'package:hiddify/features/purchase/purchase_page.dart';
import 'package:hiddify/features/trial/trial_service.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void _openAccount(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const AccountPage()),
  );
}

void _openPurchase(BuildContext context) {
  if (Platform.isIOS || Platform.isAndroid) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PurchasePage()),
    );
  } else {
    UriUtils.tryLaunch(Uri.parse(Constants.pricingUrl));
  }
}

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final trialState = ref.watch(trialProvider);
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final isConnected = connectionStatus.valueOrNull is Connected;

    // Auto-disconnect when trial expires
    ref.listen(trialProvider, (prev, next) {
      if (next.isTrial && next.isExpired) {
        final connStatus = ref.read(connectionNotifierProvider).valueOrNull;
        if (connStatus is Connected) {
          ref.read(connectionNotifierProvider.notifier).toggleConnection();
        }
        // Show dialog only on first expiry transition
        if (!(prev?.isExpired ?? false) && context.mounted) {
          _showTrialExpiredDialog(context);
        }
      }
    });

    // Guard: if VPN connects while trial is already expired, immediately disconnect
    ref.listen(connectionNotifierProvider, (prev, next) {
      if (!trialState.isTrial || !trialState.isExpired) return;
      final wasConnected = prev?.valueOrNull is Connected;
      final nowConnected = next.valueOrNull is Connected;
      if (!wasConnected && nowConnected) {
        // Someone managed to connect despite expired trial — kill it
        ref.read(connectionNotifierProvider.notifier).toggleConnection();
      }
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : const Color(0xFFF5F7FA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Ambient glow — dark theme only
                if (isDark) _AmbientGlow(),

                // Mesh gradient — fades in when connected
                _ConnectedMeshGradient(isConnected: isConnected, isDark: isDark),

                // Main content — scrollable for small screens
                Column(
                  children: [
                    _Header(isDark: isDark),
                    if (trialState.isTrial) ...[
                      const SizedBox(height: 4),
                      _TrialInfoBar(isDark: isDark, trialState: trialState),
                    ],
                    const SizedBox(height: 8),
                    _LocationSelector(isDark: isDark),
                    const Spacer(),
                    const ConnectionButton(),
                    const Spacer(),
                    if (trialState.isTrial && trialState.isExpired)
                      _TrialExpiredBanner(isDark: isDark),
                    _Footer(isDark: isDark),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showTrialExpiredDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _TrialExpiredDialog(),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo icon — 28×28 green rounded square
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF00E5A0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Assets.images.logo.svg(
                fit: BoxFit.contain,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF0a0a0a),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Relokant',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'VPN',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isDark ? const Color(0xFF00E5A0) : const Color(0xFF00B880),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              final current = themeMode;
              final next = (current == AppThemeMode.dark || current == AppThemeMode.black)
                  ? AppThemeMode.light
                  : AppThemeMode.dark;
              ref.read(themePreferencesProvider.notifier).changeThemeMode(next);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF18181B) : Colors.white,
                border: isDark
                    ? Border.all(color: const Color(0xFF27272A))
                    : null,
                boxShadow: isDark
                    ? null
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Icon(
                isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                size: 18,
                color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
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
    var activeProxy = ref.watch(
      activeProxyNotifierProvider.select((value) => value.valueOrNull),
    );
    // Fall back to cached server list selection when disconnected
    if (activeProxy == null) {
      final cachedGroup = ref.watch(
        proxiesOverviewNotifierProvider.select((value) => value.valueOrNull),
      );
      if (cachedGroup != null && cachedGroup.selected.isNotEmpty) {
        activeProxy = cachedGroup.items
            .where((p) => p.tag == cachedGroup.selected)
            .firstOrNull;
        activeProxy ??= cachedGroup.items
            .where((p) => !_isMetaProxy(p))
            .firstOrNull;
      }
    }
    final countryCode = _detectCountryCode(activeProxy);
    final locationName = _locationName(activeProxy, countryCode);

    return GestureDetector(
      onTap: () => _showProxyPicker(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? const Color(0xFF18181B).withValues(alpha: 0.6) : Colors.white,
          border: isDark
              ? Border.all(color: const Color(0xFF3F3F46).withValues(alpha: 0.6))
              : null,
          boxShadow: isDark
              ? null
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Flag — 40×40 rounded square
            Container(
              width: 40,
              height: 40,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
              child: CircleFlag(countryCode.toLowerCase(), size: 40),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'авто',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? const Color(0xFF52525B) : const Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }

  void _showProxyPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => const _ProxyPickerSheet(),
    );
  }

  static String _detectCountryCode(OutboundInfo? proxy) {
    if (proxy == null) return 'ru';

    // For meta-groups, use the resolved server's display tag
    final rawTag = (_isMetaProxy(proxy) && proxy.groupSelectedTagDisplay.isNotEmpty)
        ? proxy.groupSelectedTagDisplay
        : proxy.tagDisplay;
    final tag = _cleanTag(rawTag).toLowerCase();

    const tagToCountry = {
      'russia': 'ru', 'россия': 'ru', 'moscow': 'ru', 'москва': 'ru', 'ru': 'ru',
      'спб': 'ru', 'петербург': 'ru', 'санкт': 'ru',
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
      'spain': 'es', 'испания': 'es', 'madrid': 'es', 'мадрид': 'es',
      'latvia': 'lv', 'латвия': 'lv', 'riga': 'lv', 'рига': 'lv',
      'estonia': 'ee', 'эстония': 'ee', 'tallinn': 'ee',
      'poland': 'pl', 'польша': 'pl', 'warsaw': 'pl', 'варшава': 'pl',
      'sweden': 'se', 'швеция': 'se', 'stockholm': 'se',
      'czech': 'cz', 'чехия': 'cz', 'prague': 'cz', 'прага': 'cz',
    };

    for (final entry in tagToCountry.entries) {
      if (tag.contains(entry.key)) return entry.value;
    }

    final ipCountry = proxy.ipinfo.countryCode;
    if (ipCountry.isNotEmpty) return ipCountry.toLowerCase();

    return 'ru';
  }

  static const _metaTags = {'lowest', 'balance', 'select'};

  static bool _isMetaProxy(OutboundInfo proxy) {
    final tag = proxy.tag.toLowerCase();
    return _metaTags.any((m) => tag == m) || proxy.tag.contains('§hide§');
  }

  /// Strip Marzban noise from server tag: emoji prefix, (username), [VLESS - tcp]
  static String _cleanTag(String raw) {
    // Remove leading emoji (non-ASCII chars before first letter/digit)
    var s = raw.replaceAll(RegExp(r'^[^\w\u0400-\u04FF]+'), '');
    // Remove (anything) — Marzban puts username here
    s = s.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    // Remove [anything] — protocol info like [VLESS - tcp]
    s = s.replaceAll(RegExp(r'\s*\[[^\]]*\]'), '');
    s = s.trim();
    // "Marz" alone is the default Marzban panel name — replace with Россия
    if (s.isEmpty || s.toLowerCase() == 'marz' || s.toLowerCase() == 'marzban') {
      return 'Россия';
    }
    return s;
  }

  /// Show the server's actual tag name (e.g. "Москва-1", "СПб")
  /// instead of generic country name. For meta-groups (balance, lowest),
  /// shows the resolved server via groupSelectedTagDisplay.
  static String _locationName(OutboundInfo? proxy, String countryCode) {
    if (proxy != null && proxy.tagDisplay.isNotEmpty && !_isMetaProxy(proxy)) {
      return _cleanTag(proxy.tagDisplay);
    }
    // Meta-group (balance, lowest, etc.) — show the actual resolved server
    if (proxy != null && _isMetaProxy(proxy) && proxy.groupSelectedTagDisplay.isNotEmpty) {
      return _cleanTag(proxy.groupSelectedTagDisplay);
    }
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
      'es': 'Испания',
      'lv': 'Латвия',
      'ee': 'Эстония',
      'pl': 'Польша',
      'se': 'Швеция',
      'cz': 'Чехия',
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
    final iconColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(64, 12, 64, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _openAccount(context),
            icon: Icon(Icons.person_outline, size: 22, color: iconColor),
          ),
          IconButton(
            onPressed: () => context.goNamed('settings'),
            icon: Icon(Icons.settings_outlined, size: 22, color: iconColor),
          ),
        ],
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
    // Use view padding-aware height; LayoutBuilder constraints may not be
    // available here since we're inside a Stack, so use MediaQuery but
    // clamp to avoid overflow in small windowed/multi-window mode.
    final availableHeight = MediaQuery.of(context).size.height;
    final top = (availableHeight * topFraction).clamp(0.0, availableHeight - 10);
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Center(
        child: IgnorePointer(
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
      ),
    );
  }
}

// ─── Proxy picker ─────────────────────────────────────────

class _ProxyPickerSheet extends ConsumerStatefulWidget {
  const _ProxyPickerSheet();

  @override
  ConsumerState<_ProxyPickerSheet> createState() => _ProxyPickerSheetState();
}

class _ProxyPickerSheetState extends ConsumerState<_ProxyPickerSheet> {
  static const _green = Color(0xFF00E5A0);
  String? _selectedTag; // null = nothing picked yet (stays on current)

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final proxies = ref.watch(proxiesOverviewNotifierProvider);
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF5F7FA);
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final sepColor = isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.arrow_back, color: textColor, size: 22),
                ),
                const SizedBox(width: 4),
                Text(
                  'Сервер',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          // Static search box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.search, size: 18, color: subColor),
                  const SizedBox(width: 8),
                  Text('Поиск страны...', style: TextStyle(color: subColor, fontSize: 14)),
                ],
              ),
            ),
          ),
          // Server list
          Expanded(
            child: proxies.when(
              data: (group) {
                final realServers = group?.items
                        .where((p) => !_LocationSelector._isMetaProxy(p))
                        .toList() ??
                    [];

                // Split servers by region
                const euCodes = {'lv', 'fi', 'de', 'nl', 'fr', 'es', 'ee', 'pl', 'se', 'cz', 'gb'};
                const usCodes = {'us'};
                final ruServers = <int>[];
                final euServers = <int>[];
                final usServers = <int>[];
                for (var i = 0; i < realServers.length; i++) {
                  final cc = _LocationSelector._detectCountryCode(realServers[i]);
                  if (euCodes.contains(cc)) {
                    euServers.add(i);
                  } else if (usCodes.contains(cc)) {
                    usServers.add(i);
                  } else {
                    ruServers.add(i);
                  }
                }

                Widget buildServerCard(List<int> indices) {
                  return Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                      boxShadow: isDark
                          ? null
                          : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      children: List.generate(indices.length, (j) {
                        final proxy = realServers[indices[j]];
                        final isCurrentlySelected = group?.selected == proxy.tag;
                        final isPicked = _selectedTag == null
                            ? isCurrentlySelected
                            : _selectedTag == proxy.tag;
                        final countryCode = _LocationSelector._detectCountryCode(proxy);
                        final locationName = _LocationSelector._locationName(proxy, countryCode);
                        final isLast = j == indices.length - 1;
                        return Column(
                          children: [
                            _ServerTile(
                              countryCode: countryCode,
                              name: locationName,
                              delay: proxy.urlTestDelay,
                              selected: isPicked,
                              isDark: isDark,
                              onTap: group == null
                                  ? null
                                  : () => setState(() => _selectedTag = proxy.tag),
                            ),
                            if (!isLast)
                              Divider(height: 1, indent: 64, color: sepColor),
                          ],
                        );
                      }),
                    ),
                  );
                }

                Widget buildLockedCard(List<(String, String)> servers) {
                  return Opacity(
                    opacity: 0.5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        children: List.generate(servers.length, (j) {
                          final isLast = j == servers.length - 1;
                          return Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pop();
                                  _openPurchase(context);
                                },
                                child: _ServerTile(
                                  countryCode: servers[j].$1,
                                  name: servers[j].$2,
                                  delay: 0,
                                  selected: false,
                                  isDark: isDark,
                                  locked: true,
                                ),
                              ),
                              if (!isLast)
                                Divider(height: 1, indent: 64, color: sepColor),
                            ],
                          );
                        }),
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    // ── Россия section ──
                    _SectionHeader(title: 'Россия', isDark: isDark),
                    const SizedBox(height: 8),
                    if (realServers.isEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Подключитесь к VPN,\nчтобы выбрать сервер',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: subColor, fontSize: 13),
                          ),
                        ),
                      )
                    else if (ruServers.isNotEmpty)
                      buildServerCard(ruServers)
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Нет серверов в этом регионе',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: subColor, fontSize: 13),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    // ── Европа section ──
                    _SectionHeader(
                      title: 'Европа',
                      isDark: isDark,
                      badge: euServers.isEmpty ? 'Семейный+' : null,
                      badgeColor: _green,
                    ),
                    const SizedBox(height: 8),
                    if (euServers.isNotEmpty)
                      buildServerCard(euServers)
                    else
                      buildLockedCard([('lv', 'Латвия'), ('fi', 'Финляндия')]),
                    const SizedBox(height: 20),
                    // ── Америка section ──
                    _SectionHeader(
                      title: 'Америка',
                      isDark: isDark,
                      badge: usServers.isEmpty ? 'Про' : null,
                      badgeColor: const Color(0xFFF97316),
                    ),
                    const SizedBox(height: 8),
                    if (usServers.isNotEmpty)
                      buildServerCard(usServers)
                    else
                      buildLockedCard([('us', 'США')]),
                  ],
                );
              },
              error: (_, __) {
                final connState = ref.watch(connectionNotifierProvider);
                final isConnecting = connState.valueOrNull is Connecting;
                final cardBg2 = isDark ? const Color(0xFF18181B) : Colors.white;
                final cardBorder2 = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
                final sepColor2 = isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9);
                final subColor2 = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    _SectionHeader(title: 'Россия', isDark: isDark),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: isConnecting
                              ? const CircularProgressIndicator(color: _green)
                              : Text(
                                  'Подключитесь к VPN,\nчтобы выбрать сервер',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: subColor2, fontSize: 13),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionHeader(
                      title: 'Европа',
                      isDark: isDark,
                      badge: 'Семейный+',
                      badgeColor: _green,
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: 0.5,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardBg2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder2),
                        ),
                        child: Column(
                          children: [
                            _ServerTile(countryCode: 'lv', name: 'Латвия', delay: 0, selected: false, isDark: isDark, locked: true),
                            Divider(height: 1, indent: 64, color: sepColor2),
                            _ServerTile(countryCode: 'fi', name: 'Финляндия', delay: 0, selected: false, isDark: isDark, locked: true),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionHeader(
                      title: 'Америка',
                      isDark: isDark,
                      badge: 'Про',
                      badgeColor: const Color(0xFFF97316),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: 0.5,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardBg2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder2),
                        ),
                        child: _ServerTile(countryCode: 'us', name: 'США', delay: 0, selected: false, isDark: isDark, locked: true),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: _green)),
            ),
          ),
          // ── Confirm button ──
          _buildConfirmButton(context, isDark),
        ],
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context, bool isDark) {
    final proxies = ref.watch(proxiesOverviewNotifierProvider);
    final group = proxies.valueOrNull;
    if (group == null) return const SizedBox.shrink();

    final currentTag = group.selected;
    final hasChange = _selectedTag != null && _selectedTag != currentTag;

    // Find selected server name for button label
    String? selectedName;
    if (hasChange) {
      final server = group.items.where((p) => p.tag == _selectedTag).firstOrNull;
      if (server != null) {
        final cc = _LocationSelector._detectCountryCode(server);
        selectedName = _LocationSelector._locationName(server, cc);
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: AnimatedOpacity(
            opacity: hasChange ? 1.0 : 0.5,
            duration: const Duration(milliseconds: 200),
            child: FilledButton(
              onPressed: hasChange
                  ? () async {
                      final tag = _selectedTag!;
                      await ref
                          .read(proxiesOverviewNotifierProvider.notifier)
                          .changeProxy(group.tag, tag);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      final connStatus = ref.read(connectionNotifierProvider);
                      if (connStatus.valueOrNull is Disconnected) {
                        // If VPN is disconnected, start connection
                        await ref.read(connectionNotifierProvider.notifier).toggleConnection();
                      } else if (connStatus.valueOrNull is Connected) {
                        // If VPN is connected, reconnect to show visual feedback
                        final profile = await ref.read(activeProfileProvider.future);
                        await ref.read(connectionNotifierProvider.notifier).reconnect(profile);
                      }
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: const Color(0xFF0a0a0a),
                disabledBackgroundColor: isDark
                    ? const Color(0xFF27272A)
                    : const Color(0xFFE2E8F0),
                disabledForegroundColor: isDark
                    ? const Color(0xFF52525B)
                    : const Color(0xFF94A3B8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                hasChange
                    ? 'Подключить — ${selectedName ?? ''}'
                    : 'Текущий сервер',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.isDark,
    this.badge,
    this.badgeColor,
  });

  final String title;
  final bool isDark;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: isDark ? const Color(0xFF52525B) : const Color(0xFF94A3B8),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor!.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    required this.countryCode,
    required this.name,
    required this.delay,
    required this.selected,
    required this.isDark,
    this.locked = false,
    this.onTap,
  });

  final String countryCode;
  final String name;
  final int delay;
  final bool selected;
  final bool isDark;
  final bool locked;
  final VoidCallback? onTap;

  static const _green = Color(0xFF00E5A0);

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: selected ? _green.withValues(alpha: 0.06) : Colors.transparent,
        child: Row(
          children: [
            // Flag
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CircleFlag(countryCode, size: 36),
            ),
            const SizedBox(width: 12),
            // Name
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            // Trailing
            if (locked)
              Icon(Icons.lock_outline, size: 16, color: subColor)
            else if (selected)
              const Icon(Icons.check_circle_rounded, size: 18, color: _green)
            else if (delay > 0 && delay < 65000)
              Text(
                '${delay}ms',
                style: TextStyle(fontSize: 12, color: subColor),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Trial info bar (3-day trial, no countdown) ──────────

class _TrialInfoBar extends StatelessWidget {
  const _TrialInfoBar({required this.isDark, required this.trialState});
  final bool isDark;
  final TrialState trialState;

  @override
  Widget build(BuildContext context) {
    final expiresAt = trialState.expiresAt;
    String remainingText = 'Пробный период';
    double progress = 1.0;

    if (expiresAt != null) {
      final now = DateTime.now();
      final total = const Duration(days: 3);
      final left = expiresAt.difference(now);
      progress = (left.inSeconds / total.inSeconds).clamp(0.0, 1.0);

      if (left.inDays >= 1) {
        final hours = left.inHours % 24;
        remainingText = 'Пробный период · ${left.inDays} д ${hours} ч';
      } else if (left.inHours >= 1) {
        remainingText = 'Пробный период · ${left.inHours} ч ${left.inMinutes % 60} мин';
      } else if (left.inMinutes >= 1) {
        remainingText = 'Пробный период · ${left.inMinutes} мин';
      } else {
        remainingText = 'Пробный период истекает';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.08),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 14,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    remainingText,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5A0)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Trial expired banner (persistent on home screen) ─────

class _TrialExpiredBanner extends StatelessWidget {
  const _TrialExpiredBanner({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF00E5A0).withValues(alpha: 0.08)
            : const Color(0xFF00E5A0).withValues(alpha: 0.06),
        border: Border.all(
          color: const Color(0xFF00E5A0).withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5A0).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('🔑', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Пробный период закончился',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Оплатите подписку для безлимитного VPN',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.45)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const CodeEntryPage()),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5A0),
                      foregroundColor: const Color(0xFF0a0a0a),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'У меня есть код',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: () => _openPurchase(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : const Color(0xFFE2E8F0),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Купить подписку',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Connected mesh gradient ──────────────────────────────

class _ConnectedMeshGradient extends StatelessWidget {
  const _ConnectedMeshGradient({required this.isConnected, required this.isDark});
  final bool isConnected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          opacity: isConnected ? 1.0 : 0.0,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: isDark ? const Alignment(-0.8, -0.8) : Alignment.topCenter,
                radius: isDark ? 1.2 : 1.4,
                colors: isDark
                    ? const [
                        Color.fromRGBO(0, 229, 160, 0.10),
                        Color.fromRGBO(0, 200, 255, 0.06),
                        Colors.transparent,
                      ]
                    : const [
                        Color.fromRGBO(0, 229, 160, 0.25),
                        Color.fromRGBO(0, 200, 160, 0.10),
                        Colors.transparent,
                      ],
                stops: isDark ? const [0.0, 0.4, 1.0] : const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Trial expired dialog ─────────────────────────────────

class _TrialExpiredDialog extends StatelessWidget {
  const _TrialExpiredDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF4444).withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.timer_off_outlined,
                size: 32,
                color: Color(0xFFFF4444),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Пробный период закончился',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '3 бесплатных дня истекли.\nОформите подписку для продолжения.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openPurchase(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5A0),
                  foregroundColor: const Color(0xFF0a0a0a),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Оформить подписку',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const CodeEntryPage()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00E5A0),
                  side: const BorderSide(color: Color(0xFF00E5A0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'У меня есть код',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
