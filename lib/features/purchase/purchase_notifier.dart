import 'dart:io';

import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/purchase/purchase_constants.dart';
import 'package:hiddify/features/purchase/purchase_service.dart';
import 'package:hiddify/features/trial/trial_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseState {
  const PurchaseState({
    this.isLoading = false,
    this.products = const {},
    this.error,
    this.isPurchasing = false,
    this.purchasedProductId,
  });

  final bool isLoading;
  final Map<String, ProductDetails> products;
  final String? error;
  final bool isPurchasing;
  final String? purchasedProductId;

  PurchaseState copyWith({
    bool? isLoading,
    Map<String, ProductDetails>? products,
    String? error,
    bool? isPurchasing,
    String? purchasedProductId,
  }) {
    return PurchaseState(
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
      error: error,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      purchasedProductId: purchasedProductId ?? this.purchasedProductId,
    );
  }
}

class PurchaseNotifier extends StateNotifier<PurchaseState> {
  PurchaseNotifier(this._ref) : super(const PurchaseState()) {
    _init();
  }

  final Ref _ref;
  final _service = PurchaseService.instance;

  Future<void> _init() async {
    if (!PurchaseConstants.isStoreAvailable) return;

    state = state.copyWith(isLoading: true);
    _service.onPurchaseUpdated = _handlePurchaseUpdates;

    final ok = await _service.init();
    state = state.copyWith(
      isLoading: false,
      products: _service.products,
      error: ok ? null : 'Не удалось загрузить подписки',
    );
  }

  Future<void> buy(String productId) async {
    state = state.copyWith(isPurchasing: true, error: null);
    try {
      final ok = await _service.buy(productId);
      if (!ok) {
        state = state.copyWith(isPurchasing: false, error: 'Не удалось начать покупку');
      }
      // Purchase result will come through _handlePurchaseUpdates
    } catch (e) {
      state = state.copyWith(isPurchasing: false, error: 'Ошибка: $e');
    }
  }

  Future<void> restore() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.restorePurchases();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Ошибка восстановления: $e');
    }
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(isPurchasing: true);

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _verifyAndActivate(purchase);

        case PurchaseStatus.error:
          state = state.copyWith(
            isPurchasing: false,
            error: purchase.error?.message ?? 'Ошибка покупки',
          );
          _service.completePurchase(purchase);

        case PurchaseStatus.canceled:
          state = state.copyWith(isPurchasing: false);
          _service.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyAndActivate(PurchaseDetails purchase) async {
    final store = Platform.isIOS ? 'apple' : 'google';
    final receipt = purchase.verificationData.serverVerificationData;

    final code = await _service.validateReceipt(
      store: store,
      receiptData: receipt,
      productId: purchase.productID,
      transactionId: purchase.purchaseID,
    );

    if (code == null) {
      state = state.copyWith(
        isPurchasing: false,
        error: 'Не удалось подтвердить покупку. Попробуйте позже.',
      );
      await _service.completePurchase(purchase);
      return;
    }

    // Activate VPN profile with the code
    final subUrl = '${PurchaseConstants.apiBase}/activate/$code';
    final profileRepo = _ref.read(profileRepositoryProvider).requireValue;
    final result = await profileRepo
        .upsertRemote(subUrl, userOverride: UserOverride(name: 'Relokant'))
        .run();

    result.match(
      (failure) {
        state = state.copyWith(
          isPurchasing: false,
          error: 'Покупка прошла, но не удалось активировать VPN. Код: $code',
        );
      },
      (_) async {
        // Clear trial if was trial user
        _ref.read(trialProvider.notifier).clearTrial();
        await _ref.read(Preferences.introCompleted.notifier).update(true);
        state = state.copyWith(
          isPurchasing: false,
          purchasedProductId: purchase.productID,
        );
      },
    );

    await _service.completePurchase(purchase);
  }

  @override
  void dispose() {
    _service.onPurchaseUpdated = null;
    super.dispose();
  }
}

final purchaseProvider = StateNotifierProvider<PurchaseNotifier, PurchaseState>((ref) {
  return PurchaseNotifier(ref);
});
