import 'package:flutter/material.dart';
import 'package:hiddify/features/purchase/purchase_constants.dart';
import 'package:hiddify/features/purchase/purchase_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class PurchasePage extends ConsumerWidget {
  const PurchasePage({super.key});

  static const _green = Color(0xFF00E5A0);
  static const _orange = Color(0xFFF97316);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseProvider);
    final notifier = ref.read(purchaseProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF5F7FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);
    final btnBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final btnBorder = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);

    ref.listen(purchaseProvider, (prev, next) {
      if (next.purchasedProductId != null && prev?.purchasedProductId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Подписка оформлена! VPN активирован.'),
            backgroundColor: _green,
          ),
        );
        Navigator.of(context).pop();
      }
    });

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
                    onTap: () => Navigator.of(context).pop(),
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
                    'Подписка',
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
              child: _buildContent(context, state, notifier, isDark, textColor, subColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    PurchaseState state,
    PurchaseNotifier notifier,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    // Get monthly product prices (fallback to constants)
    final personalProduct = state.products[PurchaseConstants.personalMonthly];
    final familyProduct = state.products[PurchaseConstants.familyMonthly];
    final personalMonthlyPrice = personalProduct?.price ?? PurchaseConstants.productMeta[PurchaseConstants.personalMonthly]!.fallbackPrice;
    final familyMonthlyPrice = familyProduct?.price ?? PurchaseConstants.productMeta[PurchaseConstants.familyMonthly]!.fallbackPrice;
    final iapAvailable = state.products.isNotEmpty;
    final webFallback = () => launchUrl(Uri.parse('https://relokant.net/#pricing'));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active plan card (stub)
          _ActivePlanCard(isDark: isDark),
          const SizedBox(height: 20),

          // Plan cards
          _PlanCard(
            isDark: isDark,
            title: 'Базовый',
            price: personalMonthlyPrice,
            period: '/мес',
            deviceCount: '1 устройство',
            regions: 'Россия',
            features: const [
              (label: 'Серверы в России', included: true),
              (label: 'Безлимитный трафик', included: true),
              (label: 'Европейские серверы', included: false),
            ],
            isCurrent: false,
            onTap: state.isPurchasing ? null : (iapAvailable ? () => notifier.buy(PurchaseConstants.personalMonthly) : webFallback),
            isPurchasing: state.isPurchasing,
          ),
          const SizedBox(height: 12),

          _PlanCard(
            isDark: isDark,
            title: 'Семейный',
            price: familyMonthlyPrice,
            period: '/мес',
            deviceCount: '5 устройств',
            regions: 'Россия + ЕС',
            features: const [
              (label: 'Серверы в России', included: true),
              (label: 'Серверы в Европе', included: true),
              (label: '5 устройств', included: true),
            ],
            isCurrent: false,
            onTap: state.isPurchasing ? null : (iapAvailable ? () => notifier.buy(PurchaseConstants.familyMonthly) : webFallback),
            isPurchasing: state.isPurchasing,
          ),
          const SizedBox(height: 12),

          _PlanCard(
            isDark: isDark,
            title: 'Про',
            price: '\$14.99',
            period: '/мес',
            deviceCount: '10 устройств',
            regions: 'RU + EU + US',
            badge: 'ХИТ',
            badgeColor: _orange,
            features: const [
              (label: 'Россия + Европа + США', included: true),
              (label: '10 устройств', included: true),
              (label: 'Kill Switch', included: true),
            ],
            isCurrent: false,
            onTap: () => launchUrl(Uri.parse('https://relokant.net/#pricing')),
            isPurchasing: false,
          ),
          const SizedBox(height: 16),

          // Error
          if (state.error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFFF4444).withValues(alpha: 0.1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFFF4444), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: Color(0xFFFF4444), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Restore
          Center(
            child: TextButton(
              onPressed: state.isPurchasing ? null : () => notifier.restore(),
              child: Text(
                'Восстановить покупки',
                style: TextStyle(
                  color: _green.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivePlanCard extends StatelessWidget {
  const _ActivePlanCard({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                  'ТЕКУЩИЙ ПЛАН',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: const Color(0xFF00E5A0).withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Базовый · до апреля 2026',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5A0).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Активна',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF00E5A0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.isDark,
    required this.title,
    required this.price,
    required this.period,
    required this.deviceCount,
    required this.regions,
    required this.features,
    required this.isCurrent,
    required this.onTap,
    required this.isPurchasing,
    this.badge,
    this.badgeColor,
  });

  final bool isDark;
  final String title;
  final String price;
  final String period;
  final String deviceCount;
  final String regions;
  final List<({String label, bool included})> features;
  final bool isCurrent;
  final VoidCallback? onTap;
  final bool isPurchasing;
  final String? badge;
  final Color? badgeColor;

  static const _green = Color(0xFF00E5A0);

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);
    final featureColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent ? _green.withValues(alpha: 0.4) : cardBorder,
          width: isCurrent ? 1.5 : 1.0,
        ),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? _green).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeColor ?? _green,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _green,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      period,
                      style: TextStyle(fontSize: 12, color: subColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Subtitle
          Text(
            '$deviceCount · $regions',
            style: TextStyle(fontSize: 12, color: subColor),
          ),
          const SizedBox(height: 14),
          // Feature list
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      f.included ? Icons.check : Icons.close,
                      size: 14,
                      color: f.included ? _green : subColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      f.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: f.included ? featureColor : subColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          // CTA button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: isCurrent
                ? OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _green),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Текущий план',
                      style: TextStyle(color: _green, fontWeight: FontWeight.w600),
                    ),
                  )
                : ElevatedButton(
                    onPressed: isPurchasing ? null : onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: const Color(0xFF0a0a0a),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: isPurchasing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Color(0xFF0a0a0a), strokeWidth: 2),
                          )
                        : Text(
                            'Выбрать',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
