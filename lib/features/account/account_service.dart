import 'dart:convert';
import 'dart:io';

const _apiBase = 'https://api.relokant.net';

class ServerInfo {
  final String name;
  final String region;
  ServerInfo({required this.name, required this.region});
}

class UpgradePlan {
  final String key;
  final int price;
  UpgradePlan({required this.key, required this.price});
}

class UpgradeOption {
  final String tier;
  final String name;
  final int devices;
  final List<String> regions;
  final UpgradePlan monthly;
  final UpgradePlan quarterly;
  final UpgradePlan yearly;
  UpgradeOption({
    required this.tier,
    required this.name,
    required this.devices,
    required this.regions,
    required this.monthly,
    required this.quarterly,
    required this.yearly,
  });
}

class AccountInfo {
  final String activationCode;
  final String? plan;
  final String planName;
  final int devices;
  final String status;
  final String? expiresAt;
  final bool hasStripe;
  final List<ServerInfo> servers;
  final String referralLink;
  final int referralCount;
  final int referralBonusDays;
  final List<UpgradeOption> upgrades;

  AccountInfo({
    required this.activationCode,
    this.plan,
    required this.planName,
    required this.devices,
    required this.status,
    this.expiresAt,
    required this.hasStripe,
    required this.servers,
    required this.referralLink,
    required this.referralCount,
    required this.referralBonusDays,
    required this.upgrades,
  });

  bool get isActive => status == 'active' || status == 'paid';

  DateTime? get expiresDate {
    if (expiresAt == null) return null;
    return DateTime.tryParse(expiresAt!);
  }

  int get daysRemaining {
    final d = expiresDate;
    if (d == null) return 0;
    return d.difference(DateTime.now()).inDays.clamp(0, 9999);
  }
}

Future<AccountInfo?> fetchAccountInfo(String code) async {
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    final request = await client.getUrl(
      Uri.parse('$_apiBase/api/account-info/$code'),
    );
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    client.close();

    if (response.statusCode != 200) return null;

    final data = jsonDecode(body) as Map<String, dynamic>;
    if (data.containsKey('error')) return null;

    final acc = data['account'] as Map<String, dynamic>;
    final upgradesList = data['upgrades'] as List<dynamic>? ?? [];

    final servers = (acc['servers'] as List<dynamic>? ?? [])
        .map((s) => ServerInfo(
              name: s['name'] as String? ?? '',
              region: s['region'] as String? ?? '',
            ))
        .toList();

    final upgrades = upgradesList.map((u) {
      final plans = u['plans'] as Map<String, dynamic>;
      return UpgradeOption(
        tier: u['tier'] as String,
        name: u['name'] as String,
        devices: u['devices'] as int,
        regions: (u['regions'] as List<dynamic>).cast<String>(),
        monthly: UpgradePlan(
          key: plans['monthly']['key'] as String,
          price: plans['monthly']['price'] as int,
        ),
        quarterly: UpgradePlan(
          key: plans['quarterly']['key'] as String,
          price: plans['quarterly']['price'] as int,
        ),
        yearly: UpgradePlan(
          key: plans['yearly']['key'] as String,
          price: plans['yearly']['price'] as int,
        ),
      );
    }).toList();

    return AccountInfo(
      activationCode: acc['activation_code'] as String,
      plan: acc['plan'] as String?,
      planName: acc['plan_name'] as String? ?? 'Unknown',
      devices: acc['devices'] as int? ?? 2,
      status: acc['status'] as String? ?? 'unknown',
      expiresAt: acc['expires_at'] as String?,
      hasStripe: acc['has_stripe'] as bool? ?? false,
      servers: servers,
      referralLink: acc['referral_link'] as String? ?? '',
      referralCount: acc['referral_count'] as int? ?? 0,
      referralBonusDays: acc['referral_bonus_days'] as int? ?? 0,
      upgrades: upgrades,
    );
  } catch (_) {
    return null;
  }
}

Future<String?> createCheckoutByCode(String code, String planKey) async {
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    final request = await client.postUrl(
      Uri.parse('$_apiBase/api/checkout-by-code'),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'code': code, 'plan': planKey}));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    client.close();

    if (response.statusCode != 200) return null;
    final data = jsonDecode(body) as Map<String, dynamic>;
    return data['url'] as String?;
  } catch (_) {
    return null;
  }
}

Future<String?> getPortalUrl(String code) async {
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    final request = await client.postUrl(
      Uri.parse('$_apiBase/api/customer-portal'),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'code': code}));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    client.close();

    if (response.statusCode != 200) return null;
    final data = jsonDecode(body) as Map<String, dynamic>;
    return data['url'] as String?;
  } catch (_) {
    return null;
  }
}
