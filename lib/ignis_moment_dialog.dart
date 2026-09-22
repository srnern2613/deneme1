// ============================================================================
// DOSYA ADI: lib/ignis_moment_dialog.dart
// AÇIKLAMA: Faz F — Duolingo tarzı Ignis karakter pop-up'ı. CelebrationDialog
//           (confetti + XP/elmas sayaçlı büyüme modalı) ile KARIŞTIRILMAMALI:
//           bu, konfeti/sayaç OLMADAN sade bir "karakter + mesaj + CTA" anı —
//           özellikle konfetinin uygunsuz kaçacağı durumlar için (seri kaybı
//           gibi), ama kısa kutlama anları için de kullanılabilir.
//           iOS HIG tarzı: blur backdrop (cihaz gücüne göre), 24pt köşe
//           yarıçapı, alttan açılan thumb-zone birincil/ikincil CTA butonları.
// ============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/branding/app_branding.dart';
import 'core/theme/draconic_theme.dart';

class IgnisMomentDialog extends StatelessWidget {
  final String pose; // AppBranding.poseAsset() anahtarı
  final String title;
  final String message;
  final Color? accentColor;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  // Rozet Kazanma pop-up'ı: doluysa, Ignis karakter görselinin yerine
  // kazanılan rozetin kendi simgesi (emoji) gösterilir — kullanıcı geri
  // bildirimi: "rozet kazanma pop-upındaki ignis resmi yerine kazanılan
  // rozetin simgesini ekle". null bırakılırsa eski davranış (Ignis pozu)
  // aynen korunur.
  final String? badgeEmoji;

  const IgnisMomentDialog({
    super.key,
    required this.pose,
    required this.title,
    required this.message,
    this.accentColor,
    this.primaryLabel = 'Devam Et',
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.badgeEmoji,
  });

  static Future<void> show(
    BuildContext context, {
    required String pose,
    required String title,
    required String message,
    Color? accentColor,
    String primaryLabel = 'Devam Et',
    VoidCallback? onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    String? badgeEmoji,
  }) {
    HapticFeedback.mediumImpact();
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: AppBranding.characterName,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, anim1, anim2) => IgnisMomentDialog(
        pose: pose,
        title: title,
        message: message,
        accentColor: accentColor,
        primaryLabel: primaryLabel,
        onPrimary: onPrimary,
        secondaryLabel: secondaryLabel,
        onSecondary: onSecondary,
        badgeEmoji: badgeEmoji,
      ),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    final color = accentColor ?? theme.primaryAmber;

    final card = SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                color: theme.surfaceDark,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.borderSubtle, width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (badgeEmoji != null && badgeEmoji!.isNotEmpty)
                    Container(
                      width: 96,
                      height: 96,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
                        boxShadow: [
                          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 20, spreadRadius: 1),
                        ],
                      ),
                      child: Text(badgeEmoji!, style: const TextStyle(fontSize: 44)),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        AppBranding.poseAsset(pose),
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: Icon(Icons.auto_awesome, color: color, size: 40),
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.w900, color: theme.textPrimary, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13.5, height: 1.45, color: theme.textSecondary),
                  ),
                  const SizedBox(height: 22),
                  // Thumb-zone CTA: her zaman tam genişlikte, kartın en
                  // altında — kullanıcının başparmağının doğal olarak
                  // ulaştığı bölge.
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: theme.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop();
                        onPrimary?.call();
                      },
                      child: Text(primaryLabel, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15)),
                    ),
                  ),
                  if (secondaryLabel != null) ...[
                    const SizedBox(height: 2),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop();
                        onSecondary?.call();
                      },
                      child: Text(
                        secondaryLabel!,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13, color: theme.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Performans katmanına duyarlı: GlassPanel'deki AYNI kural — düşük
    // katmanda (glassBlurSigma == 0) ağır BackdropFilter yerine sade koyu
    // perde kullanılır.
    if (theme.glassBlurSigma <= 0) return card;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: card,
    );
  }
}
