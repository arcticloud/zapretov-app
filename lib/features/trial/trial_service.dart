import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _apiBase = 'https://api.relokant.net';
const _dailyLimitSeconds = 10 * 60; // 10 minutes

const _keyDeviceId = 'trial_device_id';
const _keyActivationCode = 'trial_activation_code';
const _keyUsedSeconds = 'trial_used_seconds';
const _keyLastDate = 'trial_last_date';
const _keyIsTrial = 'trial_is_trial';

class TrialState {
  const TrialState({
    this.isTrial = false,
    this.activationCode,
    this.remainingSeconds = _dailyLimitSeconds,
    this.isExpired = false,
    this.isLoading = false,
    this.error,
  });

  final bool isTrial;
  final String? activationCode;
  final int remainingSeconds;
  final bool isExpired;
  final bool isLoading;
  final String? error;

  TrialState copyWith({
    bool? isTrial,
    String? activationCode,
    int? remainingSeconds,
    bool? isExpired,
    bool? isLoading,
    String? error,
  }) {
    return TrialState(
      isTrial: isTrial ?? this.isTrial,
      activationCode: activationCode ?? this.activationCode,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
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
  Timer? _timer;

  void _loadState() {
    final isTrial = _prefs.getBool(_keyIsTrial) ?? false;
    final code = _prefs.getString(_keyActivationCode);

    if (!isTrial || code == null) return;

    final today = _todayStr();
    final lastDate = _prefs.getString(_keyLastDate) ?? '';
    var usedSeconds = _prefs.getInt(_keyUsedSeconds) ?? 0;

    // Reset daily counter if new day
    if (lastDate != today) {
      usedSeconds = 0;
      _prefs.setInt(_keyUsedSeconds, 0);
      _prefs.setString(_keyLastDate, today);
    }

    final remaining = (_dailyLimitSeconds - usedSeconds).clamp(0, _dailyLimitSeconds);

    state = TrialState(
      isTrial: true,
      activationCode: code,
      remainingSeconds: remaining,
      isExpired: remaining <= 0,
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

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<String?> createTrial() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final deviceId = _getDeviceId();
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.postUrl(Uri.parse('$_apiBase/api/trial'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'device_id': deviceId}));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode != 200) {
        state = state.copyWith(isLoading: false, error: 'Не удалось создать пробный доступ');
        return null;
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final code = data['activation_code'] as String?;

      if (code == null || code.isEmpty) {
        state = state.copyWith(isLoading: false, error: 'Ошибка сервера');
        return null;
      }

      await _prefs.setString(_keyActivationCode, code);
      await _prefs.setBool(_keyIsTrial, true);
      await _prefs.setString(_keyLastDate, _todayStr());
      await _prefs.setInt(_keyUsedSeconds, 0);

      state = TrialState(
        isTrial: true,
        activationCode: code,
        remainingSeconds: _dailyLimitSeconds,
        isExpired: false,
      );

      return code;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Ошибка сети: $e');
      return null;
    }
  }

  /// Call when VPN connects — start counting time
  void startTimer() {
    _timer?.cancel();
    if (!state.isTrial || state.isExpired) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final used = (_prefs.getInt(_keyUsedSeconds) ?? 0) + 1;
      _prefs.setInt(_keyUsedSeconds, used);

      final remaining = (_dailyLimitSeconds - used).clamp(0, _dailyLimitSeconds);
      state = state.copyWith(
        remainingSeconds: remaining,
        isExpired: remaining <= 0,
      );

      if (remaining <= 0) {
        _timer?.cancel();
      }
    });
  }

  /// Call when VPN disconnects — stop counting
  void stopTimer() {
    _timer?.cancel();
  }

  /// Mark as upgraded (no longer trial)
  void clearTrial() {
    _timer?.cancel();
    _prefs.setBool(_keyIsTrial, false);
    state = const TrialState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final trialProvider = StateNotifierProvider<TrialNotifier, TrialState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).requireValue;
  return TrialNotifier(prefs);
});
