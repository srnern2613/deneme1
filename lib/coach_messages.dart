// ============================================================================
// DOSYA ADI: lib/coach_messages.dart
// AÇIKLAMA: Dinamik, Özgün, Zenginleştirilmiş Canlı Koçluk Metin Havuzu
// ============================================================================

import 'dart:math';

class CoachMessages {
  static final Random _rand = Random();

  // --- 1. ANA EKRAN BAĞLAMSAL KARŞILAMA MESAJLARI ---
  static String getHomeGreeting({
    required int todayPages,
    required int targetPages,
    required bool hasShield,
  }) {
    if (todayPages >= targetPages && todayPages > 0) {
      final completed = [
        'Bugünkü görev tamam! Günün kahramanısın 🚀',
        'Hedef %100! Günlük elmas sandığını hak ettin 🎉',
        'Görev bitti, serin parlıyor! Tebrikler 🏆',
        'Disiplinin kazandı. Yarın buradayız! ✨',
        'Günün kotası doldu, zihnin dev adım attı 🧠',
      ];
      return completed[_rand.nextInt(completed.length)];
    }

    final hour = DateTime.now().hour;

    // Gece Kuşu (23:00 - 04:00)
    if (hour >= 23 || hour < 4) {
      final night = [
        'Gece sessizliği, yüksek odaklanma 🦉',
        'Gece kuşu modu aktif! Fark yaratıyorsun 🌙',
        'Yıldızlar altında okuma... Harika an! 🌌',
        'Herkes uyurken sen öğreniyorsun ⚔️',
        'Zihnin en berrak olduğu saatler 🕯️',
      ];
      return night[_rand.nextInt(night.length)];
    }

    // Sabah (05:00 - 10:00)
    if (hour >= 4 && hour < 11) {
      final morning = [
        'Güne zinde bir başlangıç! 🌅',
        'Sabah kahvesi hazırsa sayfaları açalım ☕',
        'Günün ilk zaferi için harika bir sabah! ☀️',
        'Erken kalkan yol alır, İngilizce öğrenir 🚀',
        'Zihnin sabah tazeliğinde! ☀️',
      ];
      return morning[_rand.nextInt(morning.length)];
    }

    // Öğle / Öğleden Sonra (11:00 - 17:00)
    if (hour >= 11 && hour < 18) {
      final afternoon = [
        'Kısa bir okuma molası harika gider 🥪',
        'Günün temposunda zihnine mola ver 📖',
        'Hedefleri tamamlamak için en verimli an! ☀️',
        'Kahve eşliğinde 2 sayfa okuyalım mı? 🎯',
        'Hedefe adım adım yaklaşıyoruz ⏳',
      ];
      return afternoon[_rand.nextInt(afternoon.length)];
    }

    // Akşam (18:00 - 22:00)
    final evening = [
      'Günün yorgunluğunu sayfalarla dağıt 🌆',
      'Akşam seansıyla serini güvenceye al 🔥',
      'Günü güzel bir okumayla kapatalım ✨',
      'Sayfaların arasında kaybolma vakti 🛋️',
      'Bugünün hedefini bitirip kalkanı dinlendir 🛡️',
    ];
    return evening[_rand.nextInt(evening.length)];
  }

  // --- 2. SERİ TOASTLARI ---
  static String? getFlashcardCheer(int streak) {
    if (streak == 3) {
      final s3 = [
        '🔥 3\'te 3! Ritim yakalandı, aynen böyle!',
        '🔥 Harika odaklanma, devam et!',
        '🔥 3 kelime peş peşe! Akıştasın.',
      ];
      return s3[_rand.nextInt(s3.length)];
    } else if (streak == 5) {
      final s5 = [
        '⚡ 5 seri! Kelimeler hafızana kazınıyor.',
        '⚡ Beşte beş! Zihnin sünger gibi çekiyor.',
        '⚡ Muhteşem ivme! Tempoyu düşürme.',
      ];
      return s5[_rand.nextInt(s5.length)];
    } else if (streak == 8) {
      final s8 = [
        '🎯 8\'de 8! Sıfır hata ile gidiyorsun.',
        '🎯 Muazzam seri! Odaklanman zirvede.',
        '🎯 Tam isabet! Harika bir hafıza performansı.',
      ];
      return s8[_rand.nextInt(s8.length)];
    } else if (streak == 10) {
      final s10 = [
        '👑 10 kelime hatasız! Durdurulamazsın.',
        '👑 Efsane seri! Hafıza sarayı inşa ediyorsun.',
        '👑 10\'da 10! Zihinsel kondisyon muazzam.',
      ];
      return s10[_rand.nextInt(s10.length)];
    }
    return null;
  }

  // --- 3. ZENGİNLEŞTİRİLMİŞ YANLIŞ / HATA MORAL DESTEĞİ HAVUZU ---
  static String getWrongAnswerEncouragement() {
    final list = [
      '🧠 Zihin hata yaparak öğrenir, hiç sorun değil!',
      '🌱 Yanılmak öğrenmenin en hızlı yoludur. Devam!',
      '💡 Bu kelime artık aklında yer etmeye başladı!',
      '💪 Ufak bir kaza; odaklan ve bir sonrakini yakala!',
      '🎯 Hata yapmak ilerlemenin kanıtıdır. Ritmi bozma!',
      '🔄 Bir sonraki turda bu kelime senin!',
      '⚡ Nöronlar yeni bir bağlantı kurdu, yola devam!',
      '🚀 Mükemmel olmak zorunda değilsin, pratik yaptıkça oturacak!',
    ];
    return list[_rand.nextInt(list.length)];
  }

  // --- 4. OKUMA SEANSI TOASTLARI ---
  static String getReadingPageCheer() {
    final list = [
      '📖 Harika bir akış, sayfalar su gibi akıyor.',
      '📖 Ritim muazzam! Zihnin tamamen adapte oldu.',
      '📖 Kitap kurdu modu aktif! Birkaç sayfa daha devrildi 🚀',
    ];
    return list[_rand.nextInt(list.length)];
  }

  static String getReadingTimeCheer15Min() {
    final list = [
      '⏱️ 15 dakika derin odaklanma! Beynin yeni kalıplar örüyor.',
      '⏱️ Çeyrek saat geride kaldı! Zihinsel kondisyonun harika.',
    ];
    return list[_rand.nextInt(list.length)];
  }

  static String getReadingTimeCheer30Min() {
    final list = [
      '🧠 30 dakikalık maraton! Gerçek bir kitap kurdu performansı.',
      '🧠 Yarım saat derin okuma devrildi! Tebrikler şefim.',
    ];
    return list[_rand.nextInt(list.length)];
  }
}