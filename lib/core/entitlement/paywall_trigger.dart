// ============================================================================
// DOSYA ADI: lib/core/entitlement/paywall_trigger.dart
// AÇIKLAMA: Ejderha Rotası V2 — Faz 2. Uygulamadaki HER kilitli özelliğin
// kullanacağı TEK paywall bileşeni.
//
// Kullanım: kilitli olabilecek herhangi bir widget'ı PaywallTrigger ile
// sarın. Kullanıcı premium'sa (veya Geliştirici Test Modu açıksa — bkz.
// EntitlementRepository.devTestOverrideNotifier) child aynen (hiçbir
// sarmalama olmadan) gösterilir. Premium değilse: child'a dokunma etkisiz
// hale gelir (AbsorbPointer) ve dokunuş önce Ignis karakterinin bilgilendirme
// kartını açar (satın alma akışı RevenueCat'te henüz yapılandırılmamış veya
// paywall gösterilemese bile kullanıcı HER ZAMAN bir geri bildirim görür —
// "tıkladığımda hiçbir şey olmuyor" sorununun kökü). Kullanıcı "Premium'a
// Geç" derse RevenueCat'in hazır paywall ekranı açılır. Satın alma başarılı
// olursa isPremiumNotifier otomatik güncellenir ve widget bir sonraki
// build'de child'ı doğrudan gösterir; ayrıca ekrana özel bir yenileme
// gerekiyorsa (örn. bir liste yeniden yüklenecekse) onUnlocked callback'i
// çağrılır.
//
// Yeni kod BUNUN DIŞINDA bir "kilit/tıklama -> mağaza" mantığı yazmamalı.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'entitlement_repository.dart';
import '../branding/app_branding.dart';

class PaywallTrigger extends StatelessWidget {
  final Widget child;

  /// Satın alma/restore başarılı olduktan sonra çağrılır (ör. ekranın
  /// kendi state'ini yeniden yüklemesi için). Opsiyoneldir — çoğu widget
  /// zaten isPremiumNotifier'ı dinlediği için buna ihtiyaç duymaz.
  final VoidCallback? onUnlocked;

  /// Bilgilendirme kartında "X, Premium'a özel" satırında gösterilecek özel
  /// ad. Boş bırakılırsa genel bir mesaj kullanılır.
  final String? featureName;

  const PaywallTrigger({super.key, required this.child, this.onUnlocked, this.featureName});

  Future<void> _handleTap(BuildContext context) async {
    HapticFeedback.lightImpact();
    final wantsUpgrade = await _showIgnisPremiumSheet(context);
    if (wantsUpgrade != true) return;
    final unlocked = await EntitlementRepository.instance.presentPaywall();
    if (unlocked) onUnlocked?.call();
  }

  Future<bool?> _showIgnisPremiumSheet(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(sheetContext).padding.bottom + 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  AppBranding.poseAsset('greeting'),
                  width: 64,
                  height: 64,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: AppBranding.accentColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(Icons.auto_awesome, color: AppBranding.accentColor, size: 30),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${AppBranding.characterName} bunu Premium\'a sakladı 🔒',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
              ),
              const SizedBox(height: 8),
              Text(
                featureName != null
                    ? '"$featureName" Premium üyelere özel. Yükseltirsen bu ve diğer tüm ileri pratik modlarının kilidi hemen açılır.'
                    : 'Bu özellik Premium üyelere özel. Yükseltirsen tüm ileri pratik modlarının kilidi hemen açılır.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppBranding.accentColor,
                    foregroundColor: const Color(0xFF070B14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: Text('Premium\'a Geç ⚡', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: Text('Şimdi Değil', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        EntitlementRepository.instance.isPremiumNotifier,
        EntitlementRepository.instance.devTestOverrideNotifier,
      ]),
      builder: (context, _) {
        if (EntitlementRepository.instance.isPremium) return child;
        return GestureDetector(
          onTap: () => _handleTap(context),
          child: AbsorbPointer(child: child),
        );
      },
    );
  }
}
