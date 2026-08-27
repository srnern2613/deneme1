// ============================================================================
// DOSYA ADI: lib/celebration_dialog.dart
// AÇIKLAMA: Çok Katmanlı Işık Huzmesi, Canlı XP/Elmas Sayacı ve Konfetili Modal
// ============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CelebrationDialog extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final int earnedXp;
  final int earnedGems;
  final String? actionLabel;
  final VoidCallback? onAction;

  const CelebrationDialog({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.earnedXp = 0,
    this.earnedGems = 0,
    this.actionLabel,
    this.onAction,
  });

  // --------------------------------------------------------------------------
  // ÇÖZÜLEN SORUN (Dialog Kapanırken Yaşanan UI Donması):
  // Standart showDialog arka planı senkronize kapatırken animasyon düşmesi yapıyordu.
  // Çözüm: Custom Elastic Transition ve showGeneralDialog mimarisine geçildi.
  // --------------------------------------------------------------------------
  static Future<void> show(
    BuildContext context, {
    required String emoji,
    required String title,
    required String subtitle,
    int earnedXp = 0,
    int earnedGems = 0,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    HapticFeedback.heavyImpact();
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Celebration',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (ctx, anim1, anim2) => CelebrationDialog(
        emoji: emoji,
        title: title,
        subtitle: subtitle,
        earnedXp: earnedXp,
        earnedGems: earnedGems,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
      transitionBuilder: (ctx, anim, _, child) {
        return Transform.scale(
          scale: Curves.elasticOut.transform(anim.value),
          child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<CelebrationDialog>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _rotationController;
  late Animation<double> _scaleAnimation;
  late Animation<int> _xpCounter;
  late Animation<int> _gemsCounter;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    // Canlı artan sayaç animasyonları (0 -> Hedef Puan)
    _xpCounter = IntTween(begin: 0, end: widget.earnedXp).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _gemsCounter = IntTween(begin: 0, end: widget.earnedGems).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    for (int i = 0; i < 36; i++) {
      _particles.add(_Particle(_random));
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Canlı Konfeti Parçacıkları (CustomPainter ile GPU hızlandırmalı)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(360, 440),
                  painter: _ConfettiPainter(_particles, _controller.value),
                );
              },
            ),

            // Ana Modal Kartı
            Container(
              width: 326,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E3D5B) : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                    blurRadius: 36,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dönen Işık Halkası & Büyüyen Rozet
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        RotationTransition(
                          turns: _rotationController,
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [
                                  Colors.amber.withValues(alpha: 0.0),
                                  Colors.amber.withValues(alpha: 0.45),
                                  Colors.orange.withValues(alpha: 0.65),
                                  Colors.amber.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            width: 82,
                            height: 82,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFFFFBEB),
                              border: Border.all(
                                color: const Color(0xFFFBBF24).withValues(alpha: 0.5),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFBBF24).withValues(alpha: 0.35),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: Text(widget.emoji, style: const TextStyle(fontSize: 44)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),

                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),

                  // Sayaçlı XP & Elmas Alanı
                  if (widget.earnedXp > 0 || widget.earnedGems > 0) ...[
                    const SizedBox(height: 18),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.earnedXp > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Text('⚡', style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '+${_xpCounter.value} XP',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14.5,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (widget.earnedGems > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: Colors.cyan.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Text('💎', style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '+${_gemsCounter.value} Elmas',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14.5,
                                        color: Colors.cyan[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 3,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop();
                        widget.onAction?.call();
                      },
                      child: Text(
                        widget.actionLabel ?? 'Harika, Devam Et!',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Particle {
  late double x;
  late double y;
  late double vx;
  late double vy;
  late Color color;
  late double size;

  _Particle(Random rand) {
    x = 163;
    y = 200;
    final angle = rand.nextDouble() * 2 * pi;
    final speed = rand.nextDouble() * 200 + 90;
    vx = cos(angle) * speed;
    vy = sin(angle) * speed;
    size = rand.nextDouble() * 6 + 4;
    color = [
      Colors.amber,
      Colors.cyan,
      Colors.purpleAccent,
      Colors.orange,
      Colors.greenAccent,
      Colors.pinkAccent,
    ][rand.nextInt(6)];
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;
    for (var p in particles) {
      final currentX = p.x + p.vx * progress * 0.8;
      final currentY = p.y + p.vy * progress * 0.8 + (160 * progress * progress);
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(currentX, currentY), p.size * (1.0 - progress * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}