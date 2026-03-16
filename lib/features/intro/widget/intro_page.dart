import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/model/profile_failure.dart';
import 'package:hiddify/features/trial/trial_service.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class IntroPage extends HookConsumerWidget with PresLogger {
  const IntroPage({super.key});

  static const _serverBase = 'https://api.relokant.net';

  static const _green = Color(0xFF00E5A0);
  static const _dark = Color(0xFF0a0a0a);
  static const _surface = Color(0xFF141414);
  static const _border = Color(0xFF222222);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTrialLoading = useState(false);
    final errorText = useState<String?>(null);

    Future<void> activateWithCode(String code) async {
      try {
        final subUrl = '$_serverBase/activate/$code';
        final profileRepo = ref.read(profileRepositoryProvider).requireValue;
        final result = await profileRepo
            .upsertRemote(subUrl, userOverride: UserOverride(name: 'Relokant'))
            .run();

        result.match(
          (failure) {
            isTrialLoading.value = false;
            if (failure is ProfileInvalidUrlFailure) {
              errorText.value = 'Неверный код активации';
            } else {
              errorText.value = 'Ошибка подключения. Попробуйте ещё раз.';
            }
            loggy.warning('Activation failed: $failure');
          },
          (_) async {
            loggy.info('Activation successful');
            await ref.read(Preferences.introCompleted.notifier).update(true);
          },
        );
      } catch (e) {
        isTrialLoading.value = false;
        errorText.value = 'Ошибка подключения. Попробуйте ещё раз.';
        loggy.error('Activation error', e);
      }
    }

    Future<void> startTrial() async {
      isTrialLoading.value = true;
      errorText.value = null;

      final trial = ref.read(trialProvider.notifier);
      final code = await trial.createTrial();

      if (code == null) {
        isTrialLoading.value = false;
        errorText.value =
            ref.read(trialProvider).error ?? 'Не удалось создать пробный доступ';
        return;
      }

      isTrialLoading.value = false;
      await activateWithCode(code);
    }

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
                  colorFilter:
                      const ColorFilter.mode(_green, BlendMode.srcIn),
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

                // ─── Subtitle ───
                Text(
                  'Безопасный доступ к российским\nсервисам из-за рубежа',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.4),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Gap(40),

                // ─── Error ───
                if (errorText.value != null) ...[
                  Text(
                    errorText.value!,
                    style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(16),
                ],

                // ─── PRIMARY: Connect (trial) ───
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton(
                    onPressed: isTrialLoading.value ? null : startTrial,
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: _dark,
                      disabledBackgroundColor: _green.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: isTrialLoading.value
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: _dark,
                            ),
                          )
                        : const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Попробовать бесплатно',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '3 дня · 1 ГБ/день · все серверы',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const Gap(32),

                // ─── TERTIARY: Buy + Enter code ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse('https://relokant.net/#pricing'),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.4),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      child: const Text('Купить подписку'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '·',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CodeEntryPage(),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.4),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      child: const Text('Ввести код'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Code Entry Page — standalone page for activation code + email
// ═══════════════════════════════════════════════════════════════

class CodeEntryPage extends HookConsumerWidget with PresLogger {
  const CodeEntryPage({super.key, this.initialCode});

  final String? initialCode;

  static const _serverBase = 'https://api.relokant.net';

  static const _green = Color(0xFF00E5A0);
  static const _dark = Color(0xFF0a0a0a);
  static const _surface = Color(0xFF141414);
  static const _border = Color(0xFF222222);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeController = useTextEditingController(text: initialCode ?? '');
    final emailController = useTextEditingController();
    final isLoading = useState(false);
    final errorText = useState<String?>(null);
    final showEmailForm = useState(false);
    final emailSent = useState(false);

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
              errorText.value = 'Ошибка подключения. Попробуйте ещё раз.';
            }
            loggy.warning('Activation failed: $failure');
          },
          (_) async {
            loggy.info('Activation successful');
            ref.read(trialProvider.notifier).clearTrial();
            await ref.read(Preferences.introCompleted.notifier).update(true);
            if (context.mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        );
      } catch (e) {
        isLoading.value = false;
        errorText.value = 'Ошибка подключения. Попробуйте ещё раз.';
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

    Future<void> sendRecoveryEmail() async {
      final email = emailController.text.trim().toLowerCase();
      if (email.isEmpty || !email.contains('@')) {
        errorText.value = 'Введите корректный email';
        return;
      }

      isLoading.value = true;
      errorText.value = null;

      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 10);
        final request = await client.postUrl(
          Uri.parse('$_serverBase/api/recover'),
        );
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'email': email}));
        final response = await request.close();
        await response.transform(utf8.decoder).join();
        client.close();

        isLoading.value = false;

        if (response.statusCode == 200) {
          emailSent.value = true;
        } else {
          errorText.value = 'Ошибка. Попробуйте позже.';
        }
      } catch (e) {
        isLoading.value = false;
        errorText.value = 'Ошибка сети: $e';
      }
    }

    return Scaffold(
      backgroundColor: _dark,
      appBar: AppBar(
        backgroundColor: _dark,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: emailSent.value
                  ? _buildEmailSentView(context, showEmailForm, emailSent)
                  : showEmailForm.value
                      ? _buildEmailForm(
                          emailController,
                          isLoading,
                          errorText,
                          showEmailForm,
                          sendRecoveryEmail,
                        )
                      : _buildCodeForm(
                          codeController,
                          isLoading,
                          errorText,
                          showEmailForm,
                          activate,
                        ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeForm(
    TextEditingController codeController,
    ValueNotifier<bool> isLoading,
    ValueNotifier<String?> errorText,
    ValueNotifier<bool> showEmailForm,
    VoidCallback onActivate,
  ) {
    return Column(
      key: const ValueKey('code'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🔑', style: TextStyle(fontSize: 36)),
        const Gap(16),
        const Text(
          'Ввод кода',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const Gap(8),
        Text(
          'Введите 8-значный код из email\nили Telegram-бота',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.4),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(32),

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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            errorText: errorText.value,
            errorStyle: const TextStyle(color: Color(0xFFFF6B6B)),
          ),
          cursorColor: _green,
          onSubmitted: (_) => onActivate(),
        ),
        const Gap(20),

        // ─── Activate button ───
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: isLoading.value ? null : onActivate,
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: _dark,
              disabledBackgroundColor: _green.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: isLoading.value
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _dark,
                    ),
                  )
                : const Text(
                    'Активировать',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                'забыли код?',
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

        // ─── Email recovery link ───
        TextButton.icon(
          onPressed: () => showEmailForm.value = true,
          style: TextButton.styleFrom(foregroundColor: _green),
          icon: const Icon(Icons.email_outlined, size: 18),
          label: const Text(
            'Отправить код на email',
            style: TextStyle(fontSize: 15),
          ),
        ),
        const Gap(4),
        Text(
          'Если покупали — код придёт на почту',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm(
    TextEditingController emailController,
    ValueNotifier<bool> isLoading,
    ValueNotifier<String?> errorText,
    ValueNotifier<bool> showEmailForm,
    VoidCallback onSend,
  ) {
    return Column(
      key: const ValueKey('email'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('📧', style: TextStyle(fontSize: 36)),
        const Gap(16),
        const Text(
          'Получить код',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const Gap(8),
        Text(
          'Введите email, на который\nоформляли подписку',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.4),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(32),

        // ─── Email input ───
        TextField(
          controller: emailController,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: 'your@email.com',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.15),
            ),
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _green, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            errorText: errorText.value,
            errorStyle: const TextStyle(color: Color(0xFFFF6B6B)),
          ),
          cursorColor: _green,
          onSubmitted: (_) => onSend(),
        ),
        const Gap(16),

        // ─── Send button ───
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: isLoading.value ? null : onSend,
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: _dark,
              disabledBackgroundColor: _green.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isLoading.value
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _dark,
                    ),
                  )
                : const Text(
                    'Отправить',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const Gap(16),

        Text(
          'Код будет отправлен на указанный email.\nПроверьте папку «Спам».',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.25),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(24),

        // ─── Back to code entry ───
        TextButton(
          onPressed: () {
            showEmailForm.value = false;
            errorText.value = null;
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.4),
          ),
          child: const Text('← Ввести код вручную'),
        ),
      ],
    );
  }

  Widget _buildEmailSentView(
    BuildContext context,
    ValueNotifier<bool> showEmailForm,
    ValueNotifier<bool> emailSent,
  ) {
    return Column(
      key: const ValueKey('sent'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _green,
          ),
          child: const Icon(Icons.check, size: 32, color: _dark),
        ),
        const Gap(16),
        const Text(
          'Код отправлен!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const Gap(8),
        Text(
          'Проверьте почту и введите\nкод на предыдущем экране',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.4),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () {
              emailSent.value = false;
              showEmailForm.value = false;
            },
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: _dark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Ввести код',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
