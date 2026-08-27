// ============================================================================
// DOSYA ADI: lib/coach_messages.dart
// AÇIKLAMA: Canlı Koçluk, Okuma Teşvikleri & Psikolojik Başarı Geri Bildirim Motoru
// ============================================================================

import 'dart:math';

class ExerciseResultFeedback {
  final String emoji;
  final String title;
  final String subtitle;
  final String actionLabel;
  final bool shouldOfferRetry;

  ExerciseResultFeedback({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.shouldOfferRetry = false,
  });
}

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

  // --- 3. YANLIŞ / HATA MORAL DESTEĞİ HAVUZU ---
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

  // --- 4. OKUMA SEANSI İÇİ TEŞVİKLER (ReaderScreen Uyumluluğu) ---
  static String getReadingPageCheer() {
    final list = [
      '📖 Harika bir akış, sayfalar su gibi akıyor.',
      '📖 Ritim muazzam! Zihnin tamamen adapte oldu.',
      '📖 Kitap kurdu modu aktif! Birkaç sayfa daha devrildi 🚀',
      '📖 Sayfalar peş peşe akıyor, odaklanman çok iyi!',
    ];
    return list[_rand.nextInt(list.length)];
  }

  static String getReadingTimeCheer15Min() {
    final list = [
      '⏱️ 15 dakika derin odaklanma! Beynin yeni kalıplar örüyor.',
      '⏱️ Çeyrek saat geride kaldı! Zihinsel kondisyonun harika.',
      '⏱️ 15 dakikalık akış modu! Dikkatin kusursuz seviyede.',
    ];
    return list[_rand.nextInt(list.length)];
  }

  static String getReadingTimeCheer30Min() {
    final list = [
      '🧠 30 dakikalık maraton! Gerçek bir kitap kurdu performansı.',
      '🧠 Yarım saat derin okuma devrildi! Tebrikler şefim.',
      '🧠 30 dakikadır aralıksız zihin antrenmanı! Muazzam odak.',
    ];
    return list[_rand.nextInt(list.length)];
  }

  // --- 5. 3 KADEMELİ DİNAMİK BAŞARI & POP-UP MOTORU ---
  static ExerciseResultFeedback getFeedback({
    required String exerciseType,
    required int score,
    required int total,
  }) {
    final double ratio = total > 0 ? (score / total) : 0.0;
    final randIdx = _rand.nextInt(3);

    // 1. Kademe: Zirve / Mükemmel (%80 - %100)
    if (ratio >= 0.8) {
      final emojis = ['🎯', '👑', '⚡'];
      final titles = ['Harika Performans!', 'Kusursuz Hakimiyet!', 'Zirve Performans!'];
      final subtitles = [
        '$total üzerinden $score doğru! Reflekslerin zirvede, kelimeler kalıcı hafızana geçti.',
        '$score/$total doğru! Bugün zihinsel kondisyonun muazzam seviyede, durdurulamazsın.',
        'Neredeyse sıfır hata ($score/$total)! Bu hızla kelime haznen hızla büyüyecek.',
      ];
      return ExerciseResultFeedback(
        emoji: emojis[randIdx],
        title: titles[randIdx],
        subtitle: subtitles[randIdx],
        actionLabel: 'Süper, Devam Et!',
        shouldOfferRetry: false,
      );
    }

    // 2. Kademe: Gelişme / İyi (%50 - %79)
    if (ratio >= 0.5) {
      final emojis = ['🧠', '📈', '💡'];
      final titles = ['İyi İlerleme!', 'Güzel Mücadele!', 'Adım Adım Zirveye!'];
      final subtitles = [
        '$total sorudan $score tanesini doğru bildin. İyi bir ritim yakaladın, pratikle tam oturacak.',
        '$score/$total doğru. Zihnin kelimeleri kavramaya başladı, tempoyu koru!',
        'Fena bir tur değil ($score/$total doğru). Birkaç tekrarla bu kelimeleri tamamen ezberleyebilirsin.',
      ];
      return ExerciseResultFeedback(
        emoji: emojis[randIdx],
        title: titles[randIdx],
        subtitle: subtitles[randIdx],
        actionLabel: 'Devam Et',
        shouldOfferRetry: false,
      );
    }

    // 3. Kademe: Kurtarma / Düşük Skor (%0 - %49)
    final emojis = ['🩹', '⏳', '🔄'];
    final titles = ['Pratikle Güçleneceksin!', 'Zihin Hata Yaparak Öğrenir!', 'Tekrarla ve Zirveye Çık!'];
    final subtitles = [
      '$total üzerinden $score doğru. Bu tur biraz zorladı ama sorun yok; beyin yanılarak öğrenir!',
      '$score/$total doğru. Kelimeler henüz zihninde taze; hemen bir tekrar yapıp puanını katlayalım mı?',
      'Birkaç fire verdik ($score/$total) ama pes etmek yok! Hemen bir tur daha deneyip skorunu yükselt.',
    ];
    return ExerciseResultFeedback(
      emoji: emojis[randIdx],
      title: titles[randIdx],
      subtitle: subtitles[randIdx],
      actionLabel: 'Tekrar Dene 🚀',
      shouldOfferRetry: true,
    );
  }
}