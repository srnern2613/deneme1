// ============================================================================
// DOSYA ADI: lib/core/design_system/ignis_alert.dart
// AÇIKLAMA: Uygulama genelinde dağınık `ScaffoldMessenger.of(context).
// showSnackBar(...)` çağrılarının yerini alan TEK, tema-uyumlu kısa
// bilgilendirme/uyarı pop-up'ı.
//
// NEDEN: SnackBar'lar ekranın altında sönük, uygulamanın karanlık fantezi
// "Zindan/Macera Lobisi" estetiğine uymayan gri bir şerit olarak çıkıyordu
// (ör. "Hesap sistemi henüz yapılandırılmadı." uyarısı). Artık HER kısa
// bilgilendirme/uyarı mesajı bu widget üzerinden, ortalanmış, yuvarlak
// köşeli, DraconicTheme token'larını (ham hex DEĞİL) kullanan bir pop-up
// olarak gösteriliyor — projenin geri kalanıyla aynı görsel dil.
//
// KULLANIM:
//   IgnisAlert.show(context, message: 'Bildirim izni verilmedi.');
//   IgnisAlert.show(context, message: 'İşlem başarısız.', type: IgnisAlertType.error);
//   IgnisAlert.show(context, message: 'Kaydedildi!', type: IgnisAlertType.success);
//
// KURAL: Yeni kod ASLA doğrudan ScaffoldMessenger.showSnackBar çağırmamalı —
// bkz. .cursorrules "0.2. Kullanıcı Uyarı/Bilgilendirme Mesajları".
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../theme/draconic_theme.dart';

enum IgnisAlertType { info, success, error }

class IgnisAlert {
  IgnisAlert._();

  /// [actionLabel]/[onAction]: eskiden bazı SnackBar'ların taşıdığı "Geri Al"
  /// gibi ikinci bir eylem butonu gerekiyorsa (ör. habit_tracker_screen.dart'taki
  /// "anında sil + Geri Al" akışı) bunlar verilir — pop-up'ta "Tamam"ın
  /// solunda ikinci bir buton olarak çıkar. Verilmezse tek "Tamam" butonu
  /// gösterilir.
  static Future<void> show(
    BuildContext context, {
    required String message,
    IgnisAlertType type = IgnisAlertType.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;

    final Color accent;
    final IconData icon;
    switch (type) {
      case IgnisAlertType.success:
        accent = theme.successEmerald;
        icon = PhosphorIcons.checkCircleFill;
        break;
      case IgnisAlertType.error:
        accent = theme.dangerRed;
        icon = PhosphorIcons.warningBold;
        break;
      case IgnisAlertType.info:
        accent = theme.infoTeal;
        icon = PhosphorIcons.infoBold;
        break;
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 36),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: theme.surfaceLight,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.borderSubtle),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 26),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: theme.textPrimary,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 22),
                if (actionLabel != null && onAction != null) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        onAction();
                      },
                      child: Text(
                        actionLabel,
                        style: GoogleFonts.outfit(color: accent, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: theme.isDark ? Colors.white : theme.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      'Tamam',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
