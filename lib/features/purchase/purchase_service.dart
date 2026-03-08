import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:hiddify/features/purchase/purchase_constants.dart';

class PurchaseService {
  PurchaseService._();
  static final instance = PurchaseService._();

  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Map<String, ProductDetails> products = {};
  bool _initialized = false;

  /// Callback set by the notifier to handle purchase updates
  void Function(List<PurchaseDetails>)? onPurchaseUpdated;

  Future<bool> init() async {
    if (_initialized) return products.isNotEmpty;

    final available = await _iap.isAvailable();
    if (!available) return false;

    _subscription = _iap.purchaseStream.listen(
      (details) => onPurchaseUpdated?.call(details),
      onError: (_) {},
    );

    final response = await _iap.queryProductDetails(PurchaseConstants.allProductIds);
    for (final p in response.productDetails) {
      products[p.id] = p;
    }

    _initialized = true;
    return products.isNotEmpty;
  }

  Future<bool> buy(String productId) async {
    final product = products[productId];
    if (product == null) return false;

    final param = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  Future<void> completePurchase(PurchaseDetails details) async {
    if (details.pendingCompletePurchase) {
      await _iap.completePurchase(details);
    }
  }

  /// Validate receipt with our server and get activation code
  Future<String?> validateReceipt({
    required String store,
    required String receiptData,
    required String productId,
    String? transactionId,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.postUrl(
        Uri.parse('${PurchaseConstants.apiBase}/api/iap/validate'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'store': store,
        'receipt': receiptData,
        'product_id': productId,
        'transaction_id': transactionId,
      }));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode != 200) return null;

      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['activation_code'] as String?;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
