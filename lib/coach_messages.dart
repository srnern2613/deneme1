// ============================================================================
// DOSYA ADI: lib/coach_messages.dart
// AÇIKLAMA: Yüksek Frekanslı, Dinamik ve Özgün Canlı Koçluk Metin Havuzu
// ============================================================================

import 'dart:math';

class CoachMessages {
  static final Random _rand = Random();

  // --- 1. ANA EKRAN BAĞLAMSAL KARŞILAMA MESAJLARI (5'er Adet) ---
  static String getHomeGreeting({
    required int todayPages,
    required int targetPages,
    required bool hasShield,
  }) {
    // Hedef Tamamlandıysa (%100)
    if (todayPages >= targetPages && todayPages > 0) {
      final completed = [
        'Bugünkü görev tamam! Günün kahramanı ilan edildin 🚀',
        'Hedef %100! Günlük elmas sandığını hak ettin 🎉',
        'Görev bitti, serin parlıyor! Kendine bir tebriği çok görme 🏆',
        'Disiplinin bugün de kazandı. Yarın aynı saatte buradayız! ✨',
        'Günün kotası doldu, zihnin devasa bir adım daha attı 🧠',
      ];
      return completed[_rand.nextInt(completed.length)];
    }

    final hour = DateTime.now().hour;

    // Gece Kuşu (23:00 - 04:00)
    if (hour >= 23 || hour < 4) {
      final night = [
        'Gece sessizliği, yüksek odaklanma. Batman bile bu saatte okumuyor 🦉',
        'Gece kuşu modu aktif! Bu saatte çalışanlar fark yaratır 🌙',
        'Yıldızlar altında gece okuması... Seriyi kurtarmak için harika an! 🌌',
        'Herkes uyurken sen kelimelerle dans ediyorsun. Saygılar şefim! ⚔️',
        'Gece mesaisi başladı! Zihnin en berrak olduğu saatler 🕯️',
      ];
      return night[_rand.nextInt(night.length)];
    }

    // Sabah (05:00 - 10:00)
    if (hour >= 4 && hour < 11) {
      final morning = [
        'Güneş doğarken zihnini besleyenler kazanır. Güne 1-0 önde başladın ☕',
        'Güne zinde bir başlangıç! Erken kalkan yol alır, İngilizce öğrenir 🌅',
        'Sabah kahvesi hazırsa ilk sayfaları açalım mı? ☕',
        'Günün ilk zaferini kazanmak için harika bir sabah! ☀️',
        'Zihnin sabah tazeliğinde! Birkaç sayfa okuyup güne damga vur 🚀',
      ];
      return morning[_rand.nextInt(morning.length)];
    }

    // Öğle / Öğleden Sonra (11:00 - 17:00)
    if (hour >= 11 && hour < 18) {
      final afternoon = [
        'Kısa bir molayı İngilizceyle taçlandırmak mı? Mükemmel seçim 🥪',
        'Günün temposunda zihnine güzel bir okuma molası ver 📖',
        'Öğleden sonra hedeflerini tamamlamak için en verimli saatler! ☀️',
        'Öğle kahvesi eşliğinde 2 sayfa? Hedefe adım adım yaklaşıyoruz 🎯',
        'Günün yarısı bitti bile; hedefi erken tamamlayıp rahatla! ⏳',
      ];
      return afternoon[_rand.nextInt(afternoon.length)];
    }

    // Akşam (18:00 - 22:00)
    final evening = [
      'Günün yorgunluğunu birkaç sayfa okuyarak dağıtma zamanı 🌆',
      'Akşam seansıyla serini güvenceye alalım mı? 🔥',
      'Günü güzel bir okuma rekoruyla kapatmaya ne dersin? ✨',
      'Akşam kahveni al, sayfaların arasında kaybolma vakti 🛋️',
      'Geceye girmeden bugünün hedefini bitirip kalkanı dinlendir 🛡️',
    ];
    return evening[_rand.nextInt(evening.length)];
  }

  // --- 2. FLASHCARD EGZERSİZİ SERİ TOASTLARI (5'er Adet) ---
  static String? getFlashcardCheer(int streak) {
    if (streak == 3) {
      final s3 = [
        '🔥 3\'te 3! Nöronlar ısınmaya başladı, ritmi yakaladın.',
        '🔥 Üçte üç! Odaklanman tam yerinde, aynen böyle devam!',
        '🔥 Harika ritim! Kelimeler tıkır tıkır oturuyor.',
        '🔥 3 kelime peş peşe! Zihnin hızlandı.',
        '🔥 Üçleme tamam! Akış modundasın.',
      ];
      return s3[_rand.nextInt(s3.length)];
    } else if (streak == 5) {
      final s5 = [
        '⚡ 5 seri! Kelimeler zihninde kalıcı hafızaya taşınıyor.',
        '⚡ 5 peş peşe! Hafıza kasların resmen şov yapıyor!',
        '⚡ Beşte beş! Zihnin kelimeleri sünger gibi çekiyor.',
        '⚡ Muhteşem ivme! Kelimeler senden kaçamaz.',
        '⚡ 5 doğru birden! Tempoyu hiç düşürmüyorsun.',
      ];
      return s5[_rand.nextInt(s5.length)];
    } else if (streak == 8) {
      final s8 = [
        '🎯 8\'de 8! Zihnin kelimeleri fotoğraflıyor gibi, harikasın.',
        '🎯 Sekiz kelime sıfır hata! Bugün odaklanma zirvede.',
        '🎯 Muazzam seri! Beynindeki sinapslar parti veriyor.',
        '🎯 8 doğru! Sözlükle aranda telepatik bir bağ var sanki.',
        '🎯 Keskin nişancı gibisin! 8 hedef tam isabet.',
      ];
      return s8[_rand.nextInt(s8.length)];
    } else if (streak == 10) {
      final s10 = [
        '👑 10 kelime hatasız! Bugün senin günün, durdurulamazsın.',
        '👑 Çift haneli seri! Resmen hafıza sarayı inşa ediyorsun.',
        '👑 On numara performans! Bu hızla koca sözlüğü yutarız.',
        '👑 10\'da 10! Zihinsel kondisyonun muhteşem seviyede.',
        '👑 Efsane seri! Kelimeler adeta havada uçuşuyor.',
      ];
      return s10[_rand.nextInt(s10.length)];
    }
    return null;
  }

  // --- 3. YANLIŞ YAPILDIĞINDA MORAL DESTEĞİ (5 Adet) ---
  static String getWrongAnswerEncouragement() {
    final list = [
      '💪 Hiç sorun değil; beyin unutarak öğrenir. Bir sonrakini kapıyoruz!',
      '🌱 Yanılmak öğrenmenin en hızlı yoludur. Yola devam!',
      '🔄 Sorun yok! Bu kelimeyi bir dahaki turda affetmeyeceğiz.',
      '🧠 Hafıza kası böyle gelişir; bir sonraki turda bu kelime senin!',
      '🎯 Hata yapmak ilerlemenin kanıtıdır. Ritmi bozma!',
    ];
    return list[_rand.nextInt(list.length)];
  }

  // --- 4. OKUMA SEANSI İÇİ TOASTLAR (4'er Adet) ---
  static String getReadingPageCheer() {
    final list = [
      '📖 Harika bir akış yakaladın, sayfalar su gibi akıyor.',
      '📖 Sayfaları peş peşe deviriyorsun; hikayenin içine girdin!',
      '📖 Ritim muazzam! Zihnin İngilizceye tamamen adapte oldu.',
      '📖 Birkaç sayfa daha devrildi! Kitap kurdu modu aktif 🚀',
    ];
    return list[_rand.nextInt(list.length)];
  }

  static String getReadingTimeCheer15Min() {
    final list = [
      '⏱️ 15 dakika derin odaklanma! Beynin şu an yeni kalıplar örüyor.',
      '⏱️ Çeyrek saat geride kaldı! Zihinsel kondisyonun muazzam.',
      '⏱️ 15 dakikalık akış modu (flow)! Dikkatin kusursuz seviyede.',
      '⏱️ 15 dakika devrildi! Bugün İngilizce hanene büyük bir artı yazdın.',
    ];
    return list[_rand.nextInt(list.length)];
  }

  static String getReadingTimeCheer30Min() {
    final list = [
      '🧠 Yarım saatlik maraton! Gerçek bir kitap kurdu performansı.',
      '🧠 30 dakikadır aralıksız zihin antrenmanı! Saygılar şefim.',
      '🧠 Yarım saat devrildi! Bu odaklanma seviyesi seni zirveye taşır.',
      '🧠 30 dakika derin okuma! Beyin hücreleri resmen bayram ediyor.',
    ];
    return list[_rand.nextInt(list.length)];
  }
}