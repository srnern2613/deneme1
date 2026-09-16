// ============================================================================
// DOSYA ADI: lib/core/entitlement/paywall_trigger.dart
// AÇIKLAMA: Ejderha Rotası V2 — Faz 2. Uygulamadaki HER kilitli özelliğin
// kullanacağı TEK paywall bileşeni.
//
// Kullanım: kilitli olabilecek herhangi bir widget'ı PaywallTrigger ile
// sarın. Kullanıcı premium'sa child aynen (hiçbir sarmalama olmadan)
// gösterilir. Premium değilse: child'a dokunma etkisiz hale gelir
// (AbsorbPointer) ve dokunuş RevenueCat'in paywall ekranını açar. Satın
// alma başarılı olursa isPremiumNotifier otomatik güncellenir ve widget
// bir sonraki build'de child'ı doğrudan gösterir; ayrıca ekrana özel bir
// yenileme gerekiyorsa (örn. bir liste yeniden yüklenecekse) onUnlocked
// callback'i çağrılır.
//
// Yeni kod BUNUN DIŞINDA bir "kilit/tıklama -> mağaza" mantığı yazmamalı.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'entitlement_repository.dart';

class PaywallTrigger extends StatelessWidget {
  final Widget child;

  /// Satın alma/restore başarılı olduktan sonra çağrılır (ör. ekranın
  /// kendi state'ini yeniden yüklemesi için). Opsiyoneldir — çoğu widget
  /// zaten isPremiumNotifier'ı dinlediği için buna ihtiyaç duymaz.
  final VoidCallback? onUnlocked;

  const PaywallTrigger({super.key, required this.child, this.onUnlocked});

  Future<void> _handleTap() async {
    HapticFeedback.lightImpact();
    final unlocked = await EntitlementRepository.instance.presentPaywall();
    if (unlocked) onUnlocked?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: EntitlementRepository.instance.isPremiumNotifier,
      builder: (context, isPremium, _) {
        if (isPremium) return child;
        return GestureDetector(
          onTap: _handleTap,
          child: AbsorbPointer(child: child),
        );
      },
    );
  }
}
