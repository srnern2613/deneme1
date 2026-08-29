// ============================================================================
// DOSYA ADI: lib/celebration_dialog.dart
// AÇIKLAMA: Dinamik Renkli Işık Halkası, Canlı Sayaçlar, Konfeti,
//           Mastery (Ustalaşılan Kelime) Destekli Büyüme Modalı
// ============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CelebrationDialog extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color themeColor;
  final int earnedXp;
  final int earnedGems;
  final int? totalWordsReviewed;
  final int? strengthenedWords;
  final int? needsReviewWords;
  final int masteredWordsCount; // Bu oturumda ustalaşılan yeni kelime sayısı
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  const CelebrationDialog({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.themeColor = const Color(0xFFF59E0B),
    this.earnedXp = 0,
    this.earnedGems = 0,
    this.totalWordsReviewed,
    this.strengthenedWords,
    this.needsReviewWords,
    this.masteredWordsCount = 0,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  static Future<void> show(
    BuildContext context, {
    required String emoji,
    required String title,
    required String subtitle,
    Color themeColor = const Color(0xFFF59E0B),
    int earnedXp = 0,
    int earnedGems = 0,
    int? totalWordsReviewed,
    int? strengthenedWords,
    int? needsReviewWords,
    int masteredWordsCount = 0,
    String? actionLabel,
    VoidCallback? onAction,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
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
        themeColor: themeColor,
        earnedXp: earnedXp,
        earnedGems: earnedGems,
        totalWordsReviewed: totalWordsReviewed,
        strengthenedWords: strengthenedWords,
        needsReviewWords: needsReviewWords,
        masteredWordsCount: masteredWordsCount,
        actionLabel: actionLabel,
        onAction: onAction,
        secondaryActionLabel: secondaryActionLabel,
        onSecondaryAction: onSecondaryAction,
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

class _CelebrationDialogState extends State<CelebrationDialog> with TickerProviderStateMixin {
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
      _particles.add(_Particle(_random, widget.themeColor));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColor = widget.themeColor;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(360, 440),
                  painter: _ConfettiPainter(_particles, _controller.value),
                );
              },
            ),

            Container(
              width: 334,
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: themeColor.withValues(alpha: isDark ? 0.35 : 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withValues(alpha: isDark ? 0.22 : 0.12),
                    blurRadius: 36,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Hızlı Kapatma
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop();
                        widget.onAction?.call();
                      },
                    ),
                  ),

                  // Dönen Işık ve Rozet
                  SizedBox(
                    width: 92,
                    height: 92,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        RotationTransition(
                          turns: _rotationController,
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [
                                  themeColor.withValues(alpha: 0.0),
                                  themeColor.withValues(alpha: 0.45),
                                  themeColor.withValues(alpha: 0.75),
                                  themeColor.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            width: 72,
                            height: 72,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              border: Border.all(
                                color: themeColor.withValues(alpha: 0.6),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: themeColor.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: Text(widget.emoji, style: const TextStyle(fontSize: 36)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),

                  // BÜYÜME VE MASTERY İSTATİSTİK PANELİ
                  if (widget.totalWordsReviewed != null && widget.totalWordsReviewed! > 0) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('Tekrar Edildi', '${widget.totalWordsReviewed}', Colors.blueAccent),
                              _buildStatItem('Güçlendi', '${widget.strengthenedWords ?? 0}', const Color(0xFF10B981)),
                              if (widget.masteredWordsCount > 0)
                                _buildStatItem('Ustalaşıldı', '🏆 ${widget.masteredWordsCount}', Colors.amber)
                              else
                                _buildStatItem('Pekiştirilecek', '${widget.needsReviewWords ?? 0}', Colors.orangeAccent),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.masteredWordsCount > 0 
                                ? '🏆 ${widget.masteredWordsCount} kelime kalıcı hafızana geçti!' 
                                : '🗓️ Yarın yeni tekrarlar seni bekliyor!',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: widget.masteredWordsCount > 0 ? Colors.amber : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Sayaçlı XP ve Elmas Rozeti
                  if (widget.earnedXp > 0 || widget.earnedGems > 0) ...[
                    const SizedBox(height: 12),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.earnedXp > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Text('⚡', style: TextStyle(fontSize: 13)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+${_xpCounter.value} XP',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (widget.earnedGems > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: Colors.cyan.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Text('💎', style: TextStyle(fontSize: 13)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+${_gemsCounter.value} Elmas',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
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

                  const SizedBox(height: 18),

                  // BİRİNCİL ANA BUTON
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                        shadowColor: themeColor.withValues(alpha: 0.4),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop();
                        widget.onAction?.call();
                      },
                      child: Text(
                        widget.actionLabel ?? 'Kitaba Dön 📖',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                      ),
                    ),
                  ),

                  // İKİNCİL BUTON (Zorlandıklarımı Gör)
                  if (widget.secondaryActionLabel != null && widget.onSecondaryAction != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop();
                          widget.onSecondaryAction?.call();
                        },
                        child: Text(
                          widget.secondaryActionLabel!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
      ],
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

  _Particle(Random rand, Color primaryColor) {
    x = 167;
    y = 175;
    final angle = rand.nextDouble() * 2 * pi;
    final speed = rand.nextDouble() * 200 + 90;
    vx = cos(angle) * speed;
    vy = sin(angle) * speed;
    size = rand.nextDouble() * 6 + 4;
    color = [
      primaryColor,
      Colors.amber,
      Colors.cyan,
      Colors.purpleAccent,
      Colors.orange,
      Colors.greenAccent,
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