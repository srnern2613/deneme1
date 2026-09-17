// ============================================================================
// DOSYA ADI: lib/core/branding/app_branding.dart
// AÇIKLAMA: AŞAMA 2 — Marka/karakter bilgisi TEK yerden yönetilir.
//
// NEDEN: Gelecekte aynı motoru kullanan 2. bir dil-çifti uygulaması (ör.
// İspanyolca↔İngilizce) çıkarsa, karakterin adı ve poz görsellerinin yolu
// koda dağılmış olursa her yeri tek tek değiştirmek gerekir. Bunun yerine
// maskot sistemi (Ignis Anları) ve mesaj şablonları HER ZAMAN buradaki
// AppBranding üzerinden karakter adını/görsel yolunu okur.
//
// Bugünkü maliyeti ≈ sıfır; sonradan eklemenin maliyeti yüksek.
// ============================================================================

import 'package:flutter/material.dart';

class AppBranding {
  AppBranding._();

  /// Karakterin adı. Mesaj şablonlarında düz metin ("Ignis") yazmak yerine
  /// buradan okunmalı — ikinci bir karakterli uygulama tek satır değişikliğiyle
  /// kurulabilsin diye.
  static const String characterName = 'Ignis';

  /// Poz görsellerinin bulunduğu klasör ön eki (assets/images/ altında).
  /// Örn: '${AppBranding.poseAssetPrefix}celebrating.webp'
  static const String poseAssetPrefix = 'assets/images/ignis_poses/';

  /// Şu an üretilmiş poz görselleri yok (bkz. Aşama 2 "Poz seti" maddesi) —
  /// bu yüzden geçici olarak mevcut rozet görseline düşülüyor. Yeni pozlar
  /// eklendiğinde bu haritayı güncellemek yeterli, çağıran kod değişmez.
  static const Map<String, String> _poseFallback = {
    'celebrating': 'assets/images/ignis_avatar_badge.png',
    'teacher': 'assets/images/ignis_avatar_badge.png',
    'worried': 'assets/images/ignis_avatar_badge.png',
    'sad': 'assets/images/ignis_avatar_badge.png',
    'greeting': 'assets/images/ignis_avatar_badge.png',
    'thinking': 'assets/images/ignis_avatar_badge.png',
  };

  /// Bir poz anahtarı için görsel yolunu döner (poz üretilene kadar rozet
  /// görseline düşer). Poz üretildiğinde sadece _poseFallback güncellenir.
  static String poseAsset(String poseKey) {
    return _poseFallback[poseKey] ?? _poseFallback['celebrating']!;
  }

  /// Karakterin vurgu rengi — Ignis Anları kartlarında/rozetlerinde kullanılır.
  static const Color accentColor = Color(0xFFF59E0B);
}
