import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/purchase/purchase_constants.dart';
import 'package:hiddify/features/purchase/purchase_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchasePage extends ConsumerWidget {
  const PurchasePage({super.key});

  static const _green = Color(0xFF00E5A0);
  static const _dark = Color(0xFF0a0a0a);
  static const _surface = Color(0xFF141414);
  static const _border = Color(0xFF222222);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseProvider);
    final notifier = ref.read(purchaseProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show success and pop
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
      backgroundColor: isDark ? _dark : Colors.white,
      appBar: AppBar(
        title: const Text('Подписка'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : state.products.isEmpty
              ? _buildUnavailable(context, state.error)
              : _buildPlans(context, state, notifier, isDark),
    );
  }

  Widget _buildUnavailable(BuildContext context, String? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_outlined, size: 48, color: Colors.white.withValues(alpha: 0.3)),
            const Gap(16),
            Text(
              error ?? 'Подписки недоступны',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlans(BuildContext context, PurchaseState state, PurchaseNotifier notifier, bool isDark) {
    final personalProducts = <String, ProductDetails>{};
    final familyProducts = <String, ProductDetails>{};

    for (final entry in state.products.entries) {
      final meta = PurchaseConstants.productMeta[entry.key];
      if (meta == null) continue;
      if (meta.plan == 'personal') {
        personalProducts[entry.key] = entry.value;
      } else {
        familyProducts[entry.key] = entry.value;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal plan
          _PlanSection(
            title: 'Личный',
            subtitle: '2 устройства',
            icon: Icons.person_outline,
            products: personalProducts,
            isPurchasing: state.isPurchasing,
            onBuy: notifier.buy,
            isDark: isDark,
          ),
          const Gap(24),

          // Family plan
          _PlanSection(
            title: 'Семейный',
            subtitle: '5 устройств',
            icon: Icons.group_outlined,
            products: familyProducts,
            isPurchasing: state.isPurchasing,
            onBuy: notifier.buy,
            isDark: isDark,
          ),
          const Gap(24),

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
                  const Gap(8),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: Color(0xFFFF4444), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),
          ],

          // Restore
          Center(
            child: TextButton(
              onPressed: state.isPurchasing ? null : () => notifier.restore(),
              child: Text(
                'Восстановить покупки',
                style: TextStyle(
                  color: isDark ? _green.withValues(alpha: 0.6) : _green,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSection extends StatelessWidget {
  const _PlanSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.products,
    required this.isPurchasing,
    required this.onBuy,
    required this.isDark,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Map<String, ProductDetails> products;
  final bool isPurchasing;
  final Future<void> Function(String) onBuy;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? PurchasePage._surface : Colors.grey.shade50,
        border: Border.all(
          color: isDark ? PurchasePage._border : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: PurchasePage._green, size: 24),
              const Gap(10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : PurchasePage._dark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Gap(16),
          ...products.entries.map((entry) {
            final meta = PurchaseConstants.productMeta[entry.key]!;
            final product = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PriceButton(
                period: meta.period,
                price: product.price,
                productId: entry.key,
                isPurchasing: isPurchasing,
                onBuy: onBuy,
                isDark: isDark,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PriceButton extends StatelessWidget {
  const _PriceButton({
    required this.period,
    required this.price,
    required this.productId,
    required this.isPurchasing,
    required this.onBuy,
    required this.isDark,
  });

  final String period;
  final String price;
  final String productId;
  final bool isPurchasing;
  final Future<void> Function(String) onBuy;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: isPurchasing ? null : () => onBuy(productId),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : PurchasePage._dark,
          side: BorderSide(
            color: isDark
                ? PurchasePage._green.withValues(alpha: 0.3)
                : PurchasePage._green.withValues(alpha: 0.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              period,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            Text(
              price,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: PurchasePage._green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
