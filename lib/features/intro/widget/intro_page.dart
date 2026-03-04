import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/model/profile_failure.dart';
import 'package:hiddify/features/trial/trial_service.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class IntroPage extends HookConsumerWidget with PresLogger {
  const IntroPage({super.key});

  static const _serverBase = 'https://api.relokant.net';

  static const _green = Color(0xFF00E5A0);
  static const _dark = Color(0xFF0a0a0a);
  static const _surface = Color(0xFF141414);
  static const _border = Color(0xFF222222);
  static const _muted = Color(0xFF888888);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeController = useTextEditingController();
    final isLoading = useState(false);
    final isTrialLoading = useState(false);
    final errorText = useState<String?>(null);

    Future<void> activateWithCode(String code) async {
      isLoading.value = true;
      errorText.value = null;

      try {
        final subUrl = '$_serverBase/activate/$code';
        final profileRepo = ref.read(profileRepositoryProvider).requireValue;
        final result = await profileRepo
            .upsertRemote(subUrl, userOverride: UserOverride(name: 'Relokant'))
            .run();

        result.match(
          (failure) {
            isLoading.value = false;
            if (failure is ProfileInvalidUrlFailure) {
              errorText.value = 'Неверный код активации';
            } else {
              errorText.value = 'Ошибка подключения. Попробуйте позже.';
            }
            loggy.warning('Activation failed: $failure');
          },
          (_) async {
            loggy.info('Activation successful');
            await ref.read(Preferences.introCompleted.notifier).update(true);
          },
        );
      } catch (e) {
        isLoading.value = false;
        errorText.value = 'Ошибка: $e';
        loggy.error('Activation error', e);
      }
    }

    Future<void> activate() async {
      final code = codeController.text.trim().toUpperCase();
      if (code.isEmpty) {
        errorText.value = 'Введите код активации';
        return;
      }
      await activateWithCode(code);
    }

    Future<void> startTrial() async {
      isTrialLoading.value = true;
      errorText.value = null;

      final trial = ref.read(trialProvider.notifier);
      final code = await trial.createTrial();

      if (code == null) {
        isTrialLoading.value = false;
        errorText.value = ref.read(trialProvider).error ?? 'Не удалось создать пробный доступ';
        return;
      }

      isTrialLoading.value = false;
      await activateWithCode(code);
    }

    final anyLoading = isLoading.value || isTrialLoading.value;

    return Scaffold(
      backgroundColor: _dark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── Logo ───
                Assets.images.logo.svg(
                  width: 72,
                  height: 72,
                  colorFilter: const ColorFilter.mode(_green, BlendMode.srcIn),
                ),
                const Gap(20),

                // ─── Relokant VPN ───
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      'Relokant',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'VPN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _green,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const Gap(6),
                Text(
                  'Российский IP за 2 минуты',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                const Gap(40),

                // ─── Code label ───
                Text(
                  'Введите код активации из Telegram-бота:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
                const Gap(14),

                // ─── Code input ───
                TextField(
                  controller: codeController,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontSize: 22,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: InputDecoration(
                    hintText: 'AB3K9F2X',
                    hintStyle: TextStyle(
                      letterSpacing: 8,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    filled: true,
                    fillColor: _surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _green, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    errorText: errorText.value,
                    errorStyle: const TextStyle(color: Color(0xFFFF6B6B)),
                  ),
                  cursorColor: _green,
                  onSubmitted: (_) => activate(),
                ),
                const Gap(20),

                // ─── Activate button (black) ───
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: anyLoading ? null : activate,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _dark,
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isLoading.value
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _dark,
                            ),
                          )
                        : const Text(
                            'Активировать',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const Gap(20),

                // ─── Divider ───
                Row(
                  children: [
                    Expanded(child: Divider(color: _border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'или',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: _border)),
                  ],
                ),
                const Gap(20),

                // ─── Trial button ───
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: anyLoading ? null : startTrial,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: BorderSide(color: _green.withValues(alpha: 0.3), width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isTrialLoading.value
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _green),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Попробовать бесплатно',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '10 минут в день — без регистрации',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: _green.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const Gap(32),

                // ─── No code? ───
                Text(
                  'Нет кода?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                const Gap(2),
                TextButton.icon(
                  onPressed: () {
                    UriUtils.tryLaunch(Uri.parse(Constants.telegramChannelUrl));
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _green,
                  ),
                  icon: const Icon(Icons.telegram, size: 20),
                  label: const Text(
                    'Получить в @relokant_net_bot',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
