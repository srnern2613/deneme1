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

  /// Faz F: gerçek duygu-ifade görselleri eklendi (assets/images/*.webp) —
  /// artık tüm pozlar rozet görseline değil, kendi duygusuna uygun gerçek
  /// bir yüz ifadesine düşüyor. Yeni bir poz eklemek istersen sadece bu
  /// haritaya bir satır eklemek yeterli, çağıran kod değişmez.
  static const Map<String, String> _poseFallback = {
    'celebrating': 'assets/images/excited.webp',
    'loving': 'assets/images/loving.webp',
    'teacher': 'assets/images/thinking.webp',
    'worried': 'assets/images/suspicious.webp',
    'sad': 'assets/images/sad.webp',
    'angry': 'assets/images/angry.webp',
    'greeting': 'assets/images/happy.webp',
    'thinking': 'assets/images/thinking.webp',
    'happy': 'assets/images/happy.webp',
  };

  /// Bir poz anahtarı için görsel yolunu döner (tanımsız bir anahtar gelirse
  /// kutlama pozuna düşer — hiçbir zaman boş/kırık görsel göstermez).
  static String poseAsset(String poseKey) {
    return _poseFallback[poseKey] ?? _poseFallback['celebrating']!;
  }

  /// Karakterin vurgu rengi — Ignis Anları kartlarında/rozetlerinde kullanılır.
  static const Color accentColor = Color(0xFFF59E0B);
}
