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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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

      // Activate with the trial code
      isTrialLoading.value = false;
      await activateWithCode(code);
    }

    final anyLoading = isLoading.value || isTrialLoading.value;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Assets.images.logo.svg(width: 80, height: 80),
                const Gap(24),
                Text(
                  Constants.appName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B8F5A),
                  ),
                ),
                const Gap(8),
                Text(
                  'Российский IP за 2 минуты',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Gap(40),
                Text(
                  'Введите код активации из Telegram-бота:',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const Gap(16),
                TextField(
                  controller: codeController,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: InputDecoration(
                    hintText: 'AB3K9F2X',
                    hintStyle: TextStyle(
                      letterSpacing: 8,
                      color: theme.colorScheme.onSurface.withAlpha(77),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    errorText: errorText.value,
                  ),
                  onSubmitted: (_) => activate(),
                ),
                const Gap(24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: anyLoading ? null : activate,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1B8F5A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isLoading.value
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Активировать',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ),
                const Gap(16),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'или',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const Gap(16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: anyLoading ? null : startTrial,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1B8F5A),
                      side: const BorderSide(color: Color(0xFF1B8F5A), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isTrialLoading.value
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Попробовать бесплатно',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '10 минут в день — без регистрации',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
                              ),
                            ],
                          ),
                  ),
                ),
                const Gap(24),
                Text(
                  'Нет кода?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Gap(4),
                TextButton.icon(
                  onPressed: () {
                    UriUtils.tryLaunch(Uri.parse(Constants.telegramChannelUrl));
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1B8F5A),
                  ),
                  icon: const Icon(Icons.telegram),
                  label: const Text('Получить в @relokant_net_bot'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
