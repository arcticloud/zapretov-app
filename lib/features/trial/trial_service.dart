import 'dart:convert';
import 'dart:io';

import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _apiBase = 'https://api.relokant.net';

const _keyDeviceId = 'trial_device_id';
const _keyActivationCode = 'trial_activation_code';
const _keyExpiresAt = 'trial_expires_at';
const _keyIsTrial = 'trial_is_trial';

class TrialState {
  const TrialState({
    this.isTrial = false,
    this.activationCode,
    this.expiresAt,
    this.isExpired = false,
    this.isLoading = false,
    this.error,
  });

  final bool isTrial;
  final String? activationCode;
  final DateTime? expiresAt;
  final bool isExpired;
  final bool isLoading;
  final String? error;

  TrialState copyWith({
    bool? isTrial,
    String? activationCode,
    DateTime? expiresAt,
    bool? isExpired,
    bool? isLoading,
    String? error,
  }) {
    return TrialState(
      isTrial: isTrial ?? this.isTrial,
      activationCode: activationCode ?? this.activationCode,
      expiresAt: expiresAt ?? this.expiresAt,
      isExpired: isExpired ?? this.isExpired,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class TrialNotifier extends StateNotifier<TrialState> {
  TrialNotifier(this._prefs) : super(const TrialState()) {
    _loadState();
  }

  final SharedPreferences _prefs;

  void _loadState() {
    final isTrial = _prefs.getBool(_keyIsTrial) ?? false;
    final code = _prefs.getString(_keyActivationCode);

    if (!isTrial || code == null) return;

    final expiresStr = _prefs.getString(_keyExpiresAt);
    DateTime? expiresAt;
    if (expiresStr != null && expiresStr.isNotEmpty) {
      expiresAt = DateTime.tryParse(expiresStr);
    }

    final expired = expiresAt != null && DateTime.now().isAfter(expiresAt);

    state = TrialState(
      isTrial: true,
      activationCode: code,
      expiresAt: expiresAt,
      isExpired: expired,
    );
  }

  String _getDeviceId() {
    var id = _prefs.getString(_keyDeviceId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4().replaceAll('-', '').substring(0, 32);
      _prefs.setString(_keyDeviceId, id);
    }
    return id;
  }

  Future<String?> createTrial() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final deviceId = _getDeviceId();
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.postUrl(Uri.parse('$_apiBase/api/trial'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'device_id': deviceId, 'platform': Platform.operatingSystem}));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode != 200) {
        state = state.copyWith(isLoading: false, error: 'Не удалось создать пробный доступ');
        return null;
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final code = data['activation_code'] as String?;
      final expiresAtStr = data['expires_at'] as String?;

      if (code == null || code.isEmpty) {
        state = state.copyWith(isLoading: false, error: 'Ошибка сервера');
        return null;
      }

      await _prefs.setString(_keyActivationCode, code);
      await _prefs.setBool(_keyIsTrial, true);
      if (expiresAtStr != null) {
        await _prefs.setString(_keyExpiresAt, expiresAtStr);
      }

      final expiresAt = expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;

      state = TrialState(
        isTrial: true,
        activationCode: code,
        expiresAt: expiresAt,
        isExpired: false,
      );

      return code;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Ошибка сети: $e');
      return null;
    }
  }

  /// Re-check if trial has expired (call on foreground resume)
  void checkExpiry() {
    if (!state.isTrial || state.expiresAt == null) return;
    final expired = DateTime.now().isAfter(state.expiresAt!);
    if (expired != state.isExpired) {
      state = state.copyWith(isExpired: expired);
    }
  }

  /// Mark as upgraded (no longer trial)
  void clearTrial() {
    _prefs.setBool(_keyIsTrial, false);
    state = const TrialState();
  }
}

final trialProvider = StateNotifierProvider<TrialNotifier, TrialState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).requireValue;
  return TrialNotifier(prefs);
});
