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

  void _showUpgradeSheet(AccountInfo info) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);
    final borderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: subColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Сменить тариф',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor),
            ),
            const SizedBox(height: 4),
            Text(
              'Текущий: ${info.planName}',
              style: TextStyle(fontSize: 13, color: subColor),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: info.upgrades.map((u) =>
                  _upgradeCard(u, info, isDark, textColor, subColor, borderColor, ctx),
                ).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _upgradeCard(
    UpgradeOption upgrade,
    AccountInfo info,
    bool isDark,
    Color textColor,
    Color subColor,
    Color borderColor,
    BuildContext ctx,
  ) {
    final regionLabels = upgrade.regions.map((r) {
      if (r == 'ru') return 'Россия';
      if (r == 'eu') return 'Европа';
      if (r == 'us') return 'США';
      return r;
    }).join(' + ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111113) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  upgrade.name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${upgrade.devices} устр.',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _green),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(regionLabels, style: TextStyle(fontSize: 12, color: subColor)),
          const SizedBox(height: 12),
          // Price buttons
          Row(
            children: [
              _priceButton(upgrade.monthly, 'мес', info, isDark, ctx),
              const SizedBox(width: 8),
              _priceButton(upgrade.quarterly, '3 мес', info, isDark, ctx),
              const SizedBox(width: 8),
              _priceButton(upgrade.yearly, 'год', info, isDark, ctx),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceButton(UpgradePlan plan, String label, AccountInfo info, bool isDark, BuildContext ctx) {
    final priceStr = '\$${(plan.price / 100).toStringAsFixed(plan.price % 100 == 0 ? 0 : 2)}';
    return Expanded(
      child: GestureDetector(
        onTap: () => _showPaymentMethodSheet(info.activationCode, plan.key, priceStr, label, ctx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _green.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                priceStr,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? _green : const Color(0xFF00B07D),
                ),
              ),
              Text(
                '/ $label',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentMethodSheet(String code, String planKey, String price, String period, BuildContext parentCtx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);
    final borderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);

    showModalBottomSheet<void>(
      context: parentCtx,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: subColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '$price / $period',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor),
            ),
            const SizedBox(height: 4),
            Text('Выберите способ оплаты', style: TextStyle(fontSize: 13, color: subColor)),
            const SizedBox(height: 20),

            // Stripe
            _payMethodTile(
              icon: Icons.credit_card_rounded,
              iconColor: const Color(0xFF635BFF),
              iconBg: isDark ? const Color(0xFF1A1540) : const Color(0xFFF0EEFF),
              title: 'Зарубежная карта',
              sub: 'Visa, Mastercard',
              isDark: isDark,
              textColor: textColor,
              subColor: subColor,
              borderColor: borderColor,
              onTap: () async {
                Navigator.pop(ctx);
                final url = await createCheckoutByCode(code, planKey);
                if (url != null) {
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(height: 8),

            // Telegram Stars
            _payMethodTile(
              icon: Icons.star_rounded,
              iconColor: const Color(0xFFFFAA00),
              iconBg: isDark ? const Color(0xFF2A2000) : const Color(0xFFFFF8E6),
              title: 'Карта РФ',
              sub: 'Через Telegram Stars',
              isDark: isDark,
              textColor: textColor,
              subColor: subColor,
              borderColor: borderColor,
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(
                  Uri.parse('https://t.me/relokant_net_bot?start=pay'),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
            const SizedBox(height: 8),

            // Crypto
            _payMethodTile(
              icon: Icons.currency_bitcoin_rounded,
              iconColor: const Color(0xFFF7931A),
              iconBg: isDark ? const Color(0xFF2A1A00) : const Color(0xFFFFF3E0),
              title: 'Криптовалюта',
              sub: 'BTC, ETH, USDT',
              isDark: isDark,
              textColor: textColor,
              subColor: subColor,
              borderColor: borderColor,
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(
                  Uri.parse('https://relokant.net/#pricing'),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _payMethodTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String sub,
    required bool isDark,
    required Color textColor,
    required Color subColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111113) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
                  Text(sub, style: TextStyle(fontSize: 12, color: subColor)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? const Color(0xFF333333) : const Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }

  Future<void> _openPortal() async {
    if (_code == null) return;
    final url = await getPortalUrl(_code!);
    if (url != null) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      _openCabinet();
    }
  }

  void _showReferralSheet(AccountInfo info) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);
    final borderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: subColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Gift icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _green.withValues(alpha: 0.15),
                    const Color(0xFF00E5A0).withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: _green.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.card_giftcard_rounded, size: 28, color: _green),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Пригласи друга',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Вы оба получите +7 дней бесплатно',
              style: TextStyle(fontSize: 14, color: subColor),
            ),
            const SizedBox(height: 24),

            // Stats row
            Row(
              children: [
                Expanded(
                  child: _referralStatBox(
                    icon: Icons.people_alt_rounded,
                    value: '${info.referralCount}',
                    label: 'Приглашено',
                    isDark: isDark,
                    borderColor: borderColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _referralStatBox(
                    icon: Icons.calendar_today_rounded,
                    value: '+${info.referralBonusDays}',
                    label: 'Бонус дней',
                    isDark: isDark,
                    borderColor: borderColor,
                    valueColor: _green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Referral link
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: info.referralLink));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Ссылка скопирована'),
                    backgroundColor: _green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111113) : const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        info.referralLink,
                        style: TextStyle(
                          fontSize: 13,
                          color: subColor,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.content_copy_rounded, size: 14, color: isDark ? _green : const Color(0xFF00B07D)),
                          const SizedBox(width: 4),
                          Text(
                            'Копировать',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? _green : const Color(0xFF00B07D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Share button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Share.share(
                    'Попробуй Relokant VPN — российский IP за 2 минуты! '
                    'Скачай приложение и подключись бесплатно на 3 дня.\n'
                    '${info.referralLink}',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: const Color(0xFF0a0a0a),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.share_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Поделиться с другом',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // How it works
            Text(
              'Друг переходит по ссылке, активирует VPN — бонус начисляется обоим автоматически',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: subColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _referralStatBox({
    required IconData icon,
    required String value,
    required String label,
    required bool isDark,
    required Color borderColor,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111113) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: valueColor ?? (isDark ? Colors.white70 : const Color(0xFF64748B))),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: valueColor ?? (isDark ? Colors.white : const Color(0xFF1E293B)),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
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

        // Actions section (always show — enter code, upgrade, referral)
        _sectionHeader('Действия', sectionColor),
        const SizedBox(height: 8),
        _buildActionsCard(info, isDark, textColor, subColor, cardBg, cardBorder),
        const SizedBox(height: 20),

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
    AccountInfo? info,
    bool isDark,
    Color textColor,
    Color subColor,
    Color cardBg,
    Color cardBorder,
  ) {
    final tiles = <_TileData>[];

    // Show "Enter code" for trial users, expired, or when API failed
    final trialState = ref.read(trialProvider);
    {
      tiles.add(_TileData(
        icon: Icons.key_rounded,
        iconBg: isDark ? const Color(0xFF1A2E1A) : const Color(0xFFF0FFF4),
        iconColor: _green,
        label: info?.isActive == true ? 'Сменить код активации' : 'Ввести код активации',
        sub: 'Код в @relokant_net_bot или на email',
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CodeEntryPage()),
          );
          _loadData();
        },
      ));
    }

    // Buy / upgrade — always show (opens Telegram bot for payment)
    tiles.add(_TileData(
      icon: Icons.shopping_cart_rounded,
      iconBg: isDark ? const Color(0xFF0C2912) : const Color(0xFFECFDF5),
      iconColor: _green,
      label: 'Купить подписку',
      sub: info != null && info.upgrades.isNotEmpty
          ? info.upgrades.map((u) => u.name).join(', ')
          : 'Выбрать тариф и оплатить',
      onTap: info != null && info.upgrades.isNotEmpty
          ? () => _showUpgradeSheet(info)
          : () => launchUrl(Uri.parse('https://t.me/relokant_net_bot?start=pay'), mode: LaunchMode.externalApplication),
    ));

    if (info != null && info.hasStripe) {
      tiles.add(_TileData(
        icon: Icons.credit_card_outlined,
        iconBg: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF8F8F8),
        iconColor: subColor,
        label: 'Управить подпиской',
        sub: 'Stripe',
        onTap: _openPortal,
      ));
    }

    if (info != null) {
      tiles.add(_TileData(
        icon: Icons.card_giftcard_rounded,
        iconBg: isDark ? const Color(0xFF4A0E2B) : const Color(0xFFFDF2F8),
        iconColor: const Color(0xFFEC4899),
        label: 'Пригласить друга',
        sub: info.referralCount > 0
            ? '${info.referralCount} приглашено · +${info.referralBonusDays} дней'
            : '+7 дней вам и другу',
        onTap: () => _showReferralSheet(info),
      ));
    }

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
