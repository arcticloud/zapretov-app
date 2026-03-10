import 'dart:io';
import 'dart:ui';

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
    with TickerProviderStateMixin {
  late final AnimationController _morphController;
  late final AnimationController _rotateController;
  late final AnimationController _pulseController;
  late final Animation<BorderRadius?> _morphAnimation;
  late final Animation<double> _pulseAnimation;

  // Blob shape A (idle start)
  static const _shapeA = BorderRadius.only(
    topLeft: Radius.elliptical(96, 96),
    topRight: Radius.elliptical(64, 48),
    bottomRight: Radius.elliptical(48, 112),
    bottomLeft: Radius.elliptical(112, 64),
  );

  // Blob shape B (idle end)
  static const _shapeB = BorderRadius.only(
    topLeft: Radius.elliptical(48, 80),
    topRight: Radius.elliptical(96, 96),
    bottomRight: Radius.elliptical(112, 48),
    bottomLeft: Radius.elliptical(64, 96),
  );

  @override
  void initState() {
    super.initState();

    // Morph: 6s loop A ↔ B
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _morphAnimation = BorderRadiusTween(begin: _shapeA, end: _shapeB)
        .animate(CurvedAnimation(parent: _morphController, curve: Curves.easeInOut));

    // Rotate: spins while connecting
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isSwitching) _rotateController.repeat();

    // Pulse: expands ring when connected
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    if (widget.isConnected) _pulseController.repeat();
  }

  @override
  void didUpdateWidget(_RelokantConnectionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSwitching && !_rotateController.isAnimating) {
      _rotateController.repeat();
    } else if (!widget.isSwitching && _rotateController.isAnimating) {
      _rotateController
        ..stop()
        ..reset();
    }
    if (widget.isConnected && !_pulseController.isAnimating) {
      _pulseController.repeat();
    } else if (!widget.isConnected && _pulseController.isAnimating) {
      _pulseController
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _morphController.dispose();
    _rotateController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConnected = widget.isConnected;
    final isSwitching = widget.isSwitching;
    final isBlocked = widget.isTrialBlocked;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: 200,
            height: 200,
            child: AnimatedBuilder(
              animation: Listenable.merge([_morphController, _pulseController]),
              builder: (context, _) {
                final borderRadius = _morphAnimation.value ?? _shapeA;
                final pulseValue = _pulseAnimation.value;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulse ring — blob-shaped, expands outward
                    if (isConnected)
                      Positioned.fill(
                        child: Opacity(
                          opacity: (1.0 - pulseValue).clamp(0.0, 1.0),
                          child: Container(
                            margin: EdgeInsets.all(18.0 + 18.0 * pulseValue),
                            decoration: BoxDecoration(
                              borderRadius: borderRadius,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF00E5A0)
                                    : const Color(0xFF00875A),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Outer ring — morphs with blob
                    Container(
                      width: 184,
                      height: 184,
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        border: Border.all(
                          color: isBlocked
                              ? (isDark
                                  ? const Color.fromRGBO(255, 255, 255, 0.04)
                                  : const Color.fromRGBO(0, 0, 0, 0.04))
                              : isConnected
                                  ? (isDark
                                      ? const Color.fromRGBO(0, 229, 160, 0.15)
                                      : const Color.fromRGBO(0, 135, 90, 0.12))
                                  : (isDark
                                      ? const Color.fromRGBO(255, 59, 48, 0.12)
                                      : const Color.fromRGBO(255, 59, 48, 0.10)),
                          width: 1.5,
                        ),
                      ),
                    ),

                    // Main blob button — rotates while connecting
                    RotationTransition(
                      turns: _rotateController,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          color: _buttonColor(isDark, isConnected, isBlocked, isSwitching),
                          border: Border.all(
                            color: _borderColor(isDark, isConnected, isBlocked, isSwitching),
                            width: 1.5,
                          ),
                          boxShadow: _boxShadow(isDark, isConnected, isBlocked),
                        ),
                        // Glassmorphism
                        child: ClipRRect(
                          borderRadius: borderRadius,
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Icon(
                                  _iconData(isConnected, isSwitching),
                                  key: ValueKey('${isConnected}_$isSwitching'),
                                  size: 52,
                                  color: _iconColor(isDark, isConnected, isBlocked, isSwitching),
                                ),
                              ),
                            ),
                          ),
                        ),
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
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
            color: _statusTextColor(isDark, isConnected, isSwitching),
          ),
          child: Text(widget.label.toUpperCase()),
        ),
      ],
    );
  }

  Color _buttonColor(bool isDark, bool isConnected, bool isBlocked, bool isSwitching) {
    if (isBlocked) {
      return isDark
          ? const Color.fromRGBO(255, 255, 255, 0.04)
          : const Color.fromRGBO(0, 0, 0, 0.06);
    }
    if (isConnected) {
      return isDark
          ? const Color.fromRGBO(0, 229, 160, 0.12)
          : const Color.fromRGBO(0, 229, 160, 0.15);
    }
    if (isSwitching) {
      return isDark
          ? const Color.fromRGBO(0, 229, 160, 0.08)
          : const Color.fromRGBO(0, 229, 160, 0.10);
    }
    // Disconnected → red
    return isDark
        ? const Color.fromRGBO(255, 59, 48, 0.08)
        : const Color.fromRGBO(255, 59, 48, 0.06);
  }

  Color _borderColor(bool isDark, bool isConnected, bool isBlocked, bool isSwitching) {
    if (isBlocked) {
      return isDark
          ? const Color.fromRGBO(255, 255, 255, 0.08)
          : const Color.fromRGBO(0, 0, 0, 0.08);
    }
    if (isConnected) {
      return isDark
          ? const Color.fromRGBO(0, 229, 160, 0.50)
          : const Color.fromRGBO(0, 229, 160, 0.60);
    }
    if (isSwitching) {
      return isDark
          ? const Color.fromRGBO(0, 229, 160, 0.30)
          : const Color.fromRGBO(0, 229, 160, 0.40);
    }
    // Disconnected → red
    return isDark
        ? const Color.fromRGBO(255, 59, 48, 0.25)
        : const Color.fromRGBO(255, 59, 48, 0.30);
  }

  Color _iconColor(bool isDark, bool isConnected, bool isBlocked, bool isSwitching) {
    if (isBlocked) {
      return isDark
          ? const Color.fromRGBO(255, 255, 255, 0.15)
          : const Color.fromRGBO(0, 0, 0, 0.15);
    }
    if (isConnected) return const Color(0xFF00E5A0);
    if (isSwitching) {
      return isDark
          ? const Color.fromRGBO(0, 229, 160, 0.60)
          : const Color.fromRGBO(0, 229, 160, 0.70);
    }
    // Disconnected → red at 50%
    return isDark
        ? const Color.fromRGBO(255, 59, 48, 0.50)
        : const Color.fromRGBO(255, 59, 48, 0.60);
  }

  List<BoxShadow> _boxShadow(bool isDark, bool isConnected, bool isBlocked) {
    if (isBlocked || !isConnected) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];
    }
    return [
      BoxShadow(
        color: isDark
            ? const Color.fromRGBO(0, 229, 160, 0.12)
            : const Color.fromRGBO(0, 60, 35, 0.25),
        blurRadius: isDark ? 60 : 40,
      ),
      BoxShadow(
        color: isDark
            ? const Color.fromRGBO(0, 229, 160, 0.04)
            : const Color.fromRGBO(0, 60, 35, 0.10),
        blurRadius: isDark ? 120 : 80,
      ),
    ];
  }

  IconData _iconData(bool isConnected, bool isSwitching) {
    if (isSwitching) return Icons.refresh_rounded;
    if (isConnected) return Icons.check_rounded;
    return Icons.power_settings_new_rounded;
  }

  Color _statusTextColor(bool isDark, bool isConnected, bool isSwitching) {
    if (isConnected) {
      return isDark
          ? const Color(0xFF00E5A0)
          : const Color.fromRGBO(0, 80, 45, 0.9);
    }
    if (isSwitching) {
      return isDark
          ? const Color.fromRGBO(0, 229, 160, 0.7)
          : const Color.fromRGBO(0, 120, 70, 0.7);
    }
    // Disconnected → red tint
    return isDark
        ? const Color.fromRGBO(255, 80, 80, 0.6)
        : const Color.fromRGBO(220, 38, 38, 0.6);
  }
}
