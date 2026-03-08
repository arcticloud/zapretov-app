import 'dart:io';

abstract class PurchaseConstants {
  static const apiBase = 'https://api.relokant.net';

  // Product IDs — must match App Store Connect / Google Play Console
  static const personalMonthly = 'relokant_personal_monthly';
  static const personalQuarterly = 'relokant_personal_quarterly';
  static const personalYearly = 'relokant_personal_yearly';
  static const familyMonthly = 'relokant_family_monthly';
  static const familyQuarterly = 'relokant_family_quarterly';
  static const familyYearly = 'relokant_family_yearly';

  static const allProductIds = {
    personalMonthly,
    personalQuarterly,
    personalYearly,
    familyMonthly,
    familyQuarterly,
    familyYearly,
  };

  static const productMeta = <String, ProductMeta>{
    personalMonthly: ProductMeta(
      plan: 'personal',
      name: 'Личный',
      devices: 2,
      period: '1 месяц',
      fallbackPrice: '\$6.99',
    ),
    personalQuarterly: ProductMeta(
      plan: 'personal',
      name: 'Личный',
      devices: 2,
      period: '3 месяца',
      fallbackPrice: '\$17.99',
    ),
    personalYearly: ProductMeta(
      plan: 'personal',
      name: 'Личный',
      devices: 2,
      period: '1 год',
      fallbackPrice: '\$59.99',
    ),
    familyMonthly: ProductMeta(
      plan: 'family',
      name: 'Семейный',
      devices: 5,
      period: '1 месяц',
      fallbackPrice: '\$9.99',
    ),
    familyQuarterly: ProductMeta(
      plan: 'family',
      name: 'Семейный',
      devices: 5,
      period: '3 месяца',
      fallbackPrice: '\$24.99',
    ),
    familyYearly: ProductMeta(
      plan: 'family',
      name: 'Семейный',
      devices: 5,
      period: '1 год',
      fallbackPrice: '\$79.99',
    ),
  };

  static bool get isStoreAvailable => Platform.isIOS || Platform.isAndroid;
}

class ProductMeta {
  const ProductMeta({
    required this.plan,
    required this.name,
    required this.devices,
    required this.period,
    required this.fallbackPrice,
  });

  final String plan;
  final String name;
  final int devices;
  final String period;
  final String fallbackPrice;
}
