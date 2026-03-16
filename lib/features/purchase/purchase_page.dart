import 'package:flutter/material.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/utils/utils.dart';

/// Stub purchase page that redirects to the web pricing page.
/// On mobile platforms this is pushed as a route; on desktop the caller
/// opens the URL directly via [Constants.pricingUrl].
class PurchasePage extends StatefulWidget {
  const PurchasePage({super.key});

  @override
  State<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> {
  @override
  void initState() {
    super.initState();
    // Immediately open the pricing URL and pop back.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UriUtils.tryLaunch(Uri.parse(Constants.pricingUrl));
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
