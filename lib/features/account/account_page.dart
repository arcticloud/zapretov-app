import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/features/account/account_service.dart';
import 'package:hiddify/features/intro/widget/intro_page.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/trial/trial_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  static const _green = Color(0xFF00E5A0);
  static const _accountUrl = 'https://relokant.net/account';

  AccountInfo? _info;
  bool _loading = true;
  String? _code;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = ref.read(activeProfileProvider).valueOrNull;
    if (profile == null) {
      setState(() => _loading = false);
      return;
    }

    // Extract code from profile URL: https://api.relokant.net/activate/CODE
    String? code;
    if (profile is RemoteProfileEntity) {
      final url = profile.url;
      if (url.contains('/activate/')) {
        code = url.split('/activate/').last;
      }
    }

    if (code == null || code.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    _code = code;
    final info = await fetchAccountInfo(code);
    if (mounted) {
      setState(() {
        _info = info;
        _loading = false;
      });
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Код скопирован'),
        backgroundColor: _green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openCabinet() {
    launchUrl(Uri.parse(_accountUrl), mode: LaunchMode.externalApplication);
  }

  void _shareReferral(String link) {
    Share.share('Попробуй Relokant VPN — российский IP за 2 минуты!\n$link');
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    const months = [
      '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final codeBg = isDark ? const Color(0xFF111113) : const Color(0xFFF8F8F8);
    final sectionColor = isDark ? const Color(0xFF52525B) : const Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cardBg,
                        border: Border.all(color: cardBorder),
                      ),
                      child: Icon(Icons.arrow_back, size: 18, color: textColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Аккаунт',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _green),
                    )
                  : _buildContent(
                      isDark, textColor, subColor, cardBg, cardBorder, codeBg, sectionColor,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    bool isDark,
    Color textColor,
    Color subColor,
    Color cardBg,
    Color cardBorder,
    Color codeBg,
    Color sectionColor,
  ) {
    final info = _info;
    final code = info?.activationCode ?? _code ?? '—';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Hero card
        _buildHeroCard(info, code, isDark, textColor, subColor, cardBg, cardBorder, codeBg),
        const SizedBox(height: 20),

        // Actions section
        if (info != null) ...[
          _sectionHeader('Действия', sectionColor),
          const SizedBox(height: 8),
          _buildActionsCard(info, isDark, textColor, subColor, cardBg, cardBorder),
          const SizedBox(height: 20),
        ],

        // More section
        _sectionHeader('Ещё', sectionColor),
        const SizedBox(height: 8),
        _buildMoreCard(isDark, textColor, subColor, cardBg, cardBorder),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _sectionHeader(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    AccountInfo? info,
    String code,
    bool isDark,
    Color textColor,
    Color subColor,
    Color cardBg,
    Color cardBorder,
    Color codeBg,
  ) {
    final isActive = info?.isActive ?? true;
    final daysText = info != null ? '${info.daysRemaining} дн.' : null;
    final planText = info?.planName ?? 'Загрузка...';
    final devicesText = info != null ? '${info.devices} устр.' : '';
    final dateText = info != null ? _formatDate(info.expiresAt) : null;
    final serverCount = info?.servers.length ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: status + plan + days
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? _green : const Color(0xFFEF4444),
                  boxShadow: [
                    BoxShadow(
                      color: isActive
                          ? _green.withValues(alpha: 0.4)
                          : const Color(0xFFEF4444).withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$planText · $devicesText',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              if (daysText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? _green.withValues(alpha: 0.1)
                        : _green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    daysText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? _green : const Color(0xFF00B07D),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Code row
          GestureDetector(
            onTap: () => _copyCode(code),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: codeBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'КОД АКТИВАЦИИ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: subColor,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          code,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4,
                            color: isDark ? _green : const Color(0xFF00B07D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? _green.withValues(alpha: 0.08)
                          : _green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? _green.withValues(alpha: 0.12)
                            : _green.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Icon(
                      Icons.content_copy_rounded,
                      size: 18,
                      color: isDark ? _green : const Color(0xFF00B07D),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Meta row: date + servers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (dateText != null)
                Text(
                  'до $dateText',
                  style: TextStyle(fontSize: 12, color: subColor),
                ),
              if (serverCount > 0)
                Text(
                  'Россия · $serverCount серв.',
                  style: TextStyle(fontSize: 12, color: subColor),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(
    AccountInfo info,
    bool isDark,
    Color textColor,
    Color subColor,
    Color cardBg,
    Color cardBorder,
  ) {
    final tiles = <_TileData>[];

    // Show "Enter code" for trial users or expired subscriptions
    final trialState = ref.read(trialProvider);
    if (trialState.isTrial || !info.isActive) {
      tiles.add(_TileData(
        icon: Icons.key_rounded,
        iconBg: isDark ? const Color(0xFF1A2E1A) : const Color(0xFFF0FFF4),
        iconColor: _green,
        label: 'Ввести код активации',
        sub: 'Купили подписку? Введите код',
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CodeEntryPage()),
          );
          _loadData(); // Reload account info after activation
        },
      ));
    }

    if (info.upgrades.isNotEmpty) {
      final upgradeNames = info.upgrades.map((u) => u.name).join(', ');
      tiles.add(_TileData(
        icon: Icons.upgrade_rounded,
        iconBg: isDark ? const Color(0xFF2E1065) : const Color(0xFFF3F0FF),
        iconColor: const Color(0xFF8B5CF6),
        label: 'Сменить тариф',
        sub: upgradeNames,
        onTap: _openCabinet,
      ));
    }

    if (info.hasStripe) {
      tiles.add(_TileData(
        icon: Icons.credit_card_outlined,
        iconBg: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF8F8F8),
        iconColor: subColor,
        label: 'Управить подпиской',
        sub: 'Stripe',
        onTap: _openCabinet,
      ));
    }

    tiles.add(_TileData(
      icon: Icons.card_giftcard_rounded,
      iconBg: isDark ? const Color(0xFF4A0E2B) : const Color(0xFFFDF2F8),
      iconColor: const Color(0xFFEC4899),
      label: 'Пригласить друга',
      sub: '+7 дней вам и другу',
      onTap: () => _shareReferral(info.referralLink),
    ));

    return _buildTileList(tiles, isDark, textColor, subColor, cardBg, cardBorder);
  }

  Widget _buildMoreCard(
    bool isDark,
    Color textColor,
    Color subColor,
    Color cardBg,
    Color cardBorder,
  ) {
    return _buildTileList(
      [
        _TileData(
          icon: Icons.language_rounded,
          iconBg: isDark ? const Color(0xFF0C1929) : const Color(0xFFEFF6FF),
          iconColor: const Color(0xFF3B82F6),
          label: 'Личный кабинет',
          sub: 'Открыть в браузере',
          onTap: _openCabinet,
        ),
      ],
      isDark,
      textColor,
      subColor,
      cardBg,
      cardBorder,
    );
  }

  Widget _buildTileList(
    List<_TileData> tiles,
    bool isDark,
    Color textColor,
    Color subColor,
    Color cardBg,
    Color cardBorder,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(tiles.length, (i) {
          final tile = tiles[i];
          return Column(
            children: [
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 16,
                  color: cardBorder.withValues(alpha: 0.5),
                ),
              InkWell(
                onTap: tile.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: tile.iconBg,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(tile.icon, size: 18, color: tile.iconColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tile.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                            if (tile.sub != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text(
                                  tile.sub!,
                                  style: TextStyle(fontSize: 12, color: subColor),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: isDark
                            ? const Color(0xFF333333)
                            : const Color(0xFFCCCCCC),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _TileData {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String? sub;
  final VoidCallback onTap;

  _TileData({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    this.sub,
    required this.onTap,
  });
}
