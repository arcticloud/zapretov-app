import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/purchase/purchase_page.dart';
import 'package:hiddify/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:hiddify/features/trial/trial_service.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ConnectionButton extends HookConsumerWidget {
  const ConnectionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final activeProxy = ref.watch(activeProxyNotifierProvider);
    final delay = activeProxy.valueOrNull?.urlTestDelay ?? 0;
    final requiresReconnect = ref.watch(configOptionNotifierProvider).valueOrNull;
    final trial = ref.watch(trialProvider);

    final isConnected = connectionStatus.valueOrNull is Connected;
    final isConnecting = connectionStatus.valueOrNull is Connecting;
    final isDisconnecting = connectionStatus.valueOrNull is Disconnecting;
    final isSwitching = isConnecting || isDisconnecting;

    // Block connection if trial expired
    final trialBlocked = trial.isTrial && trial.isExpired;

    final onTap = switch (connectionStatus) {
      AsyncData(value: Connected()) when requiresReconnect == true => () async {
        final activeProfile = await ref.read(activeProfileProvider.future);
        return await ref.read(connectionNotifierProvider.notifier).reconnect(activeProfile);
      },
      AsyncData(value: Disconnected()) || AsyncError() => () async {
        // Prevent reconnection if trial is expired
        if (trialBlocked) {
          _showTrialExpiredDialog(context);
          return;
        }
        if (ref.read(activeProfileProvider).valueOrNull == null) {
          await ref.read(dialogNotifierProvider.notifier).showNoActiveProfile();
          ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile();
        }
        if (await ref.read(dialogNotifierProvider.notifier).showExperimentalFeatureNotice()) {
          return await ref.read(connectionNotifierProvider.notifier).toggleConnection();
        }
      },
      AsyncData(value: Connected()) => () async {
        if (requiresReconnect == true &&
            await ref.read(dialogNotifierProvider.notifier).showExperimentalFeatureNotice()) {
          return await ref
              .read(connectionNotifierProvider.notifier)
              .reconnect(await ref.read(activeProfileProvider.future));
        }
        return await ref.read(connectionNotifierProvider.notifier).toggleConnection();
      },
      _ => () {},
    };

    final label = switch (connectionStatus) {
      AsyncData(value: Connected()) when requiresReconnect == true => t.connection.reconnect,
      AsyncData(value: Connected()) when delay <= 0 || delay >= 65000 => t.connection.connecting,
      AsyncData(value: final status) => status.present(t),
      _ => "",
    };

    final enabled = switch (connectionStatus) {
      AsyncData(value: Connected()) || AsyncData(value: Disconnected()) || AsyncError() => true,
      _ => false,
    };

    return _RelokantConnectionButton(
      onTap: onTap,
      enabled: trialBlocked ? false : enabled,
      label: trialBlocked ? 'Лимит исчерпан' : label,
      isConnected: isConnected && delay > 0 && delay < 65000,
      isSwitching: isSwitching,
      isTrialBlocked: trialBlocked,
    );
  }

  static void _showTrialExpiredDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF4444).withValues(alpha: 0.1),
                ),
                child: const Icon(Icons.timer_off_outlined, size: 32, color: Color(0xFFFF4444)),
              ),
              const SizedBox(height: 20),
              Text('Лимит исчерпан', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(
                'Вы использовали 10 минут сегодня.\nВозвращайтесь завтра или оформите подписку.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity, height: 52,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    if (Platform.isIOS || Platform.isAndroid) {
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PurchasePage()));
                    } else {
                      UriUtils.tryLaunch(Uri.parse(Constants.pricingUrl));
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5A0),
                    foregroundColor: const Color(0xFF0a0a0a),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Оформить подписку', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Вернуться завтра', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelokantConnectionButton extends StatefulWidget {
  const _RelokantConnectionButton({
    required this.onTap,
    required this.enabled,
    required this.label,
    required this.isConnected,
    required this.isSwitching,
    this.isTrialBlocked = false,
  });

  final VoidCallback onTap;
  final bool enabled;
  final String label;
  final bool isConnected;
  final bool isSwitching;
  final bool isTrialBlocked;

  @override
  State<_RelokantConnectionButton> createState() => _RelokantConnectionButtonState();
}

class _RelokantConnectionButtonState extends State<_RelokantConnectionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isConnected) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(_RelokantConnectionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isConnected && !_pulseController.isAnimating) {
      _pulseController.repeat();
    } else if (!widget.isConnected && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConnected = widget.isConnected;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: 200,
            height: 200,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final pulseValue = _pulseAnimation.value;
                // Outer ring expands from 12px to 26px inset
                final ringInset = isConnected ? 12.0 + (14.0 * pulseValue) : 12.0;
                final ringOpacity = isConnected ? 1.0 - (0.85 * pulseValue) : 0.0;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulse ring (only when connected)
                    if (isConnected)
                      Positioned.fill(
                        child: Container(
                          margin: EdgeInsets.all(20 - ringInset + 12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? Color.fromRGBO(0, 229, 160, 0.12 * ringOpacity)
                                  : Color.fromRGBO(0, 40, 25, 0.15 * ringOpacity),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                    // Outer ring (static)
                    Container(
                      width: 184,
                      height: 184,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color.fromRGBO(0, 229, 160, 0.06)
                              : const Color.fromRGBO(0, 40, 25, 0.06),
                          width: 1.5,
                        ),
                      ),
                    ),

                    // Main button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _buttonColor(isDark, isConnected),
                        border: Border.all(
                          color: _borderColor(isDark, isConnected),
                          width: isConnected ? 2.5 : 2.0,
                        ),
                        boxShadow: isConnected
                            ? [
                                BoxShadow(
                                  color: isDark
                                      ? const Color.fromRGBO(0, 229, 160, 0.12)
                                      : const Color.fromRGBO(0, 60, 35, 0.25),
                                  blurRadius: isDark ? 60 : 40,
                                ),
                                BoxShadow(
                                  color: isDark
                                      ? const Color.fromRGBO(0, 229, 160, 0.04)
                                      : const Color.fromRGBO(0, 60, 35, 0.1),
                                  blurRadius: isDark ? 120 : 80,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Icon(
                        isConnected ? Icons.check_rounded : Icons.power_settings_new_rounded,
                        size: 52,
                        color: _iconColor(isDark, isConnected),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontSize: 15,
            fontWeight: isConnected ? FontWeight.w700 : FontWeight.w600,
            color: _statusTextColor(isDark, isConnected),
          ),
          child: Text(widget.label),
        ),
      ],
    );
  }

  Color _buttonColor(bool isDark, bool isConnected) {
    if (widget.isTrialBlocked) {
      return isDark
          ? const Color.fromRGBO(255, 255, 255, 0.04)
          : const Color.fromRGBO(0, 0, 0, 0.06);
    }
    if (isDark) {
      return isConnected
          ? const Color.fromRGBO(0, 229, 160, 0.15)
          : const Color.fromRGBO(0, 229, 160, 0.06);
    } else {
      return isConnected
          ? const Color.fromRGBO(0, 40, 25, 0.22)
          : const Color.fromRGBO(0, 40, 25, 0.10);
    }
  }

  Color _borderColor(bool isDark, bool isConnected) {
    if (isDark) {
      return isConnected
          ? const Color.fromRGBO(0, 229, 160, 0.5)
          : const Color.fromRGBO(0, 229, 160, 0.2);
    } else {
      return isConnected
          ? const Color.fromRGBO(0, 40, 25, 0.3)
          : const Color.fromRGBO(0, 40, 25, 0.08);
    }
  }

  Color _iconColor(bool isDark, bool isConnected) {
    if (widget.isTrialBlocked) {
      return isDark
          ? const Color.fromRGBO(255, 255, 255, 0.15)
          : const Color.fromRGBO(0, 0, 0, 0.15);
    }
    if (isDark) {
      return isConnected
          ? const Color(0xFF00E5A0)
          : const Color.fromRGBO(0, 229, 160, 0.4);
    } else {
      return isConnected
          ? const Color.fromRGBO(0, 30, 18, 0.75)
          : const Color.fromRGBO(0, 40, 25, 0.3);
    }
  }

  Color _statusTextColor(bool isDark, bool isConnected) {
    if (isDark) {
      return isConnected
          ? const Color(0xFF00E5A0)
          : const Color.fromRGBO(255, 255, 255, 0.35);
    } else {
      return isConnected
          ? const Color.fromRGBO(0, 0, 0, 0.7)
          : const Color.fromRGBO(0, 0, 0, 0.35);
    }
  }
}
