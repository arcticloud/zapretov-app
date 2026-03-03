import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/gen/assets.gen.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  static const _brandGreen = Color(0xFF00E5A0);
  static const _bgColor = Color(0xFF0a0a0a);

  late final AnimationController _glowCtrl;
  late final AnimationController _entryCtrl;
  late final AnimationController _ringCtrl;
  late final AnimationController _fadeOutCtrl;

  // Entry animations
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _vpnSlide;
  late final Animation<double> _vpnOpacity;
  late final Animation<double> _cornerOpacity;

  // Fade out
  late final Animation<double> _fadeOut;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Ambient glow pulse — loops forever
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    // Entry animations — plays once
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Ring expansion — loops
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

    // Fade out
    _fadeOutCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Logo: scale 0.6→1, opacity 0→1, starts immediately
    _logoScale = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.0, 0.40, curve: Curves.easeOutCubic)),
    );
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.0, 0.25, curve: Curves.easeOut)),
    );

    // Title "Relokant": slide up 24px, fade in, starts at 0.20
    _titleSlide = Tween(begin: const Offset(0, 24), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.20, 0.50, curve: Curves.easeOutCubic)),
    );
    _titleOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.20, 0.45, curve: Curves.easeOut)),
    );

    // "VPN": slide up, fade in, starts at 0.32
    _vpnSlide = Tween(begin: const Offset(0, 24), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.32, 0.60, curve: Curves.easeOutCubic)),
    );
    _vpnOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.32, 0.55, curve: Curves.easeOut)),
    );

    // Corners: fade in at 0.55
    _cornerOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.55, 0.75, curve: Curves.easeOut)),
    );

    // Fade out
    _fadeOut = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutCtrl, curve: Curves.easeIn),
    );

    // Start entry animation
    _entryCtrl.forward();

    // Navigate after splash completes
    Future.delayed(const Duration(milliseconds: 2200), _navigateAway);
  }

  void _navigateAway() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _fadeOutCtrl.forward().then((_) {
      if (mounted) context.goNamed('home');
    });
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _entryCtrl.dispose();
    _ringCtrl.dispose();
    _fadeOutCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeOut,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: Stack(
          children: [
            // Radial gradient background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.1),
                    radius: 0.8,
                    colors: [Color(0xFF0d1f16), _bgColor],
                    stops: [0.0, 0.7],
                  ),
                ),
              ),
            ),

            // Ambient glow
            _buildAmbientGlow(),

            // Expanding rings
            _buildRing(0.0),
            _buildRing(0.34),
            _buildRing(0.68),

            // Floating particles
            ..._buildParticles(),

            // Main content (logo + text)
            Center(
              child: AnimatedBuilder(
                animation: _entryCtrl,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // R Logo
                    Transform.scale(
                      scale: _logoScale.value,
                      child: Opacity(
                        opacity: _logoOpacity.value,
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: _brandGreen.withValues(alpha: 0.25),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                              BoxShadow(
                                color: _brandGreen.withValues(alpha: 0.1),
                                blurRadius: 60,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Assets.images.logo.svg(
                            width: 120,
                            height: 120,
                            colorFilter: const ColorFilter.mode(_brandGreen, BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // "Relokant"
                    Transform.translate(
                      offset: _titleSlide.value,
                      child: Opacity(
                        opacity: _titleOpacity.value,
                        child: const Text(
                          'Relokant',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // "VPN"
                    Transform.translate(
                      offset: _vpnSlide.value,
                      child: Opacity(
                        opacity: _vpnOpacity.value,
                        child: const Text(
                          'VPN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _brandGreen,
                            letterSpacing: 12,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Corner accents
            AnimatedBuilder(
              animation: _entryCtrl,
              builder: (context, _) => Opacity(
                opacity: _cornerOpacity.value,
                child: Stack(
                  children: [
                    _CornerAccent(top: 40, left: 24),
                    _CornerAccent(top: 40, right: 24),
                    _CornerAccent(bottom: 40, left: 24),
                    _CornerAccent(bottom: 40, right: 24),
                  ],
                ),
              ),
            ),

            // Bottom line accent
            AnimatedBuilder(
              animation: _entryCtrl,
              builder: (context, _) => Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Opacity(
                    opacity: _cornerOpacity.value,
                    child: Container(
                      width: 40 * _cornerOpacity.value,
                      height: 3,
                      decoration: BoxDecoration(
                        color: _brandGreen.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientGlow() {
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (context, _) {
        final t = _glowCtrl.value;
        final opacity = 0.6 + 0.4 * t;
        final scale = 1.0 + 0.15 * t;
        return Positioned.fill(
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, -40),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 340,
                    height: 340,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _brandGreen.withValues(alpha: 0.12),
                          _brandGreen.withValues(alpha: 0.03),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 0.7],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRing(double delayFraction) {
    return AnimatedBuilder(
      animation: _ringCtrl,
      builder: (context, _) {
        var t = (_ringCtrl.value + delayFraction) % 1.0;
        final size = 160 + 340 * t;
        final opacity = (1.0 - t).clamp(0.0, 0.5);
        final scale = 0.8 + 0.2 * t;
        return Positioned.fill(
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, -40),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _brandGreen.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildParticles() {
    final rng = Random(42);
    return List.generate(15, (i) {
      return _Particle(
        key: ValueKey('particle_$i'),
        left: rng.nextDouble(),
        duration: Duration(milliseconds: 4000 + rng.nextInt(6000)),
        delay: Duration(milliseconds: rng.nextInt(8000)),
        size: 2 + rng.nextDouble() * 2,
        particleOpacity: 0.2 + rng.nextDouble() * 0.4,
      );
    });
  }
}

// ── Particle ────────────────────────────────────────────

class _Particle extends StatefulWidget {
  const _Particle({
    super.key,
    required this.left,
    required this.duration,
    required this.delay,
    required this.size,
    required this.particleOpacity,
  });

  final double left;
  final Duration duration;
  final Duration delay;
  final double size;
  final double particleOpacity;

  @override
  State<_Particle> createState() => _ParticleState();
}

class _ParticleState extends State<_Particle> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        double opacity;
        if (t < 0.1) {
          opacity = t / 0.1 * widget.particleOpacity;
        } else if (t > 0.9) {
          opacity = (1.0 - t) / 0.1 * widget.particleOpacity;
        } else {
          opacity = widget.particleOpacity;
        }
        return Positioned(
          left: widget.left * screenW,
          bottom: -10 + (screenH + 20) * t,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E5A0).withValues(alpha: 0.4),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Corner accent ───────────────────────────────────────

class _CornerAccent extends StatelessWidget {
  const _CornerAccent({this.top, this.bottom, this.left, this.right});

  final double? top;
  final double? bottom;
  final double? left;
  final double? right;

  @override
  Widget build(BuildContext context) {
    final bool isTop = top != null;
    final bool isLeft = left != null;

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: SizedBox(
        width: 30,
        height: 30,
        child: CustomPaint(
          painter: _CornerPainter(
            isTop: isTop,
            isLeft: isLeft,
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({required this.isTop, required this.isLeft});

  final bool isTop;
  final bool isLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5A0).withValues(alpha: 0.15)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double x = isLeft ? 0 : size.width;
    final double y = isTop ? 0 : size.height;
    final double dx = isLeft ? 20 : -20;
    final double dy = isTop ? 20 : -20;

    // Horizontal line
    canvas.drawLine(Offset(x, y), Offset(x + dx, y), paint);
    // Vertical line
    canvas.drawLine(Offset(x, y), Offset(x, y + dy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
