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

  /// Poz görsellerinin bulunduğu klasör ön eki. NOT: bu sabit fiilen
  /// KULLANILMIYOR — _poseFallback haritasındaki her satır kendi tam yolunu
  /// taşıyor (aşağıda mascot_emotions/ klasörüne güncellendi). Bu alan
  /// sadece dokümantasyon amaçlı bırakıldı.
  static const String poseAssetPrefix = 'assets/images/mascot_emotions/';

  /// Faz F: gerçek duygu-ifade görselleri eklendi (assets/images/mascot_emotions/*.webp)
  /// — artık tüm pozlar rozet görseline değil, kendi duygusuna uygun gerçek
  /// bir yüz ifadesine düşüyor. Yeni bir poz eklemek istersen sadece bu
  /// haritaya bir satır eklemek yeterli, çağıran kod değişmez.
  static const Map<String, String> _poseFallback = {
    // Temel duygular
    'happy': 'assets/images/mascot_emotions/happy.webp',
    'excited': 'assets/images/mascot_emotions/excited.webp',
    'loving': 'assets/images/mascot_emotions/loving.webp',
    'thinking': 'assets/images/mascot_emotions/thinking.webp',
    'suspicious': 'assets/images/mascot_emotions/suspicious.webp',
    'sad': 'assets/images/mascot_emotions/sad.webp',
    'angry': 'assets/images/mascot_emotions/angry.webp',
    // Eylül 2026: eskiden başka pozlara düşen anahtarlar artık kendi
    // çizimlerine sahip.
    'celebrating': 'assets/images/mascot_emotions/celebrating.webp',
    'teacher': 'assets/images/mascot_emotions/teacher.webp',
    'greeting': 'assets/images/mascot_emotions/greeting_ignis_bust.webp',
    'worried': 'assets/images/mascot_emotions/worried_ignis_bust.webp',
    // Yeni durum pozları (Ana Sayfa öneri kartları vb.)
    'reading': 'assets/images/mascot_emotions/reading_ignis_bust.webp',
    'warrior': 'assets/images/mascot_emotions/warrior_ignis_bust.webp',
    'sleepy': 'assets/images/mascot_emotions/sleepy_ignis.webp',
    'proud': 'assets/images/mascot_emotions/proud_ignis_bust.webp',
    'explorer': 'assets/images/mascot_emotions/explorer_ignis_bust.webp',
    'confused': 'assets/images/mascot_emotions/confused_ignis_bust.webp',
    'listening': 'assets/images/mascot_emotions/listening_ignis_bust.webp',
  };
  /// Bir poz anahtarı için görsel yolunu döner (tanımsız bir anahtar gelirse
  /// kutlama pozuna düşer — hiçbir zaman boş/kırık görsel göstermez).
  static String poseAsset(String poseKey) {
    return _poseFallback[poseKey] ?? _poseFallback['celebrating']!;
  }

  /// Karakterin vurgu rengi — Ignis Anları kartlarında/rozetlerinde kullanılır.
  static const Color accentColor = Color(0xFFF59E0B);
}
