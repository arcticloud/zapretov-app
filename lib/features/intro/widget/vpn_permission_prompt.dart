import 'dart:io';

import 'package:flutter/material.dart';

/// Shows a pre-prompt screen before iOS system VPN permission dialog.
/// Guides users to tap "Allow" when the system dialog appears.
class VpnPermissionPrompt extends StatelessWidget {
  const VpnPermissionPrompt({super.key, required this.onContinue});

  final VoidCallback onContinue;

  static const _green = Color(0xFF00E5A0);
  static const _dark = Color(0xFF0a0a0a);

  /// Whether this prompt should be shown (iOS only, first time)
  static bool shouldShow() => Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pointing hand
              const _BouncingHand(),
              const SizedBox(height: 32),

              // Main text
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.3,
                  ),
                  children: [
                    TextSpan(text: 'Нажмите '),
                    TextSpan(
                      text: '«Разрешить»',
                      style: TextStyle(color: _green),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                'в следующем окне',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(height: 48),

              // Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: _dark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Понятно',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BouncingHand extends StatefulWidget {
  const _BouncingHand();

  @override
  State<_BouncingHand> createState() => _BouncingHandState();
}

class _BouncingHandState extends State<_BouncingHand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: const Text(
            '👆',
            style: TextStyle(fontSize: 80),
          ),
        );
      },
    );
  }
}
