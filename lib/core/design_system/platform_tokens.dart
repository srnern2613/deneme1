// ============================================================================
// DOSYA ADI: lib/core/design_system/platform_tokens.dart
// AÇIKLAMA: UI/UX Düzeltme Listesi — Sıra 2 paylaşılan altyapısı.
// PlatformTokens.scrollBottomPadding: P0-1'in tek çözümü — "Alt bar içeriği
// kesiyor" (Profil, Arena, Lobi). Eskiden her ekran kendi sabit sayısını
// (100, 110...) yazıyordu; artık TEK formülden okunuyor: bar yüksekliği +
// viewPadding.bottom + 16 (kabul kriteri: son kart ile bar arası ≥16).
// ============================================================================

import 'package:flutter/material.dart';

class PlatformTokens {
  PlatformTokens._();

  /// main.dart'taki alt gezinme çubuğunun (BottomNavigationBar, ikon+etiket,
  /// elevation 0) gerçek render yüksekliğine en yakın sabit. Kesin ölçüm
  /// için ileride bir GlobalKey ile RenderBox.size ölçülebilir; bu sabit
  /// bilinçli olarak cömert tutuldu (undershoot > overshoot: içerik
  /// kesilmesin diye biraz fazla boşluk, az değil).
  static const double bottomNavBarHeight = 76.0;

  /// A-3: iOS dokunma hedefi 44, Material 48 — tek sayıda birleş (48 ikisini
  /// de karşılıyor).
  static const double minTapTarget = 48.0;

  /// Alt gezinme çubuğu olan bir sekmenin scroll view'ı için TEK doğru alt
  /// padding — P0-1'in çözdüğü üç ekranda (Lobi/Kitaplık(Arena)/Profil) da
  /// bundan okunmalı, sabit sayı yazılmamalı.
  static double scrollBottomPadding(BuildContext context, {double extra = 16}) {
    return bottomNavBarHeight + MediaQuery.of(context).padding.bottom + extra;
  }
}
