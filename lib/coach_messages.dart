// ============================================================================
// DOSYA ADI: lib/coach_messages.dart
// AÇIKLAMA: Çoklu Varyasyonlu, Büyüme Odaklı ve Başarı Seviyesine Göre 
//           Dinamik Renk/Tema Destekli Koçluk Mesaj Motoru
// ============================================================================

import 'dart:math';
import 'package:flutter/material.dart';

class CoachFeedback {
  final String emoji;
  final String title;
  final String subtitle;
  final String actionLabel;
  final Color themeColor; // Dinamik başarı teması rengi
  final bool shouldOfferRetry;

  CoachFeedback({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.themeColor,
    this.shouldOfferRetry = false,
  });
}

class CoachMessages {
  static final Random _rand = Random();

  // 1. KADEME: %90 ve Üzeri (Kusursuz / Yüksek Başarı) -> Canlı Altın Sarısı
  static final List<Map<String, String>> _tierHighSuccess = [
    {
      'emoji': '🎉',
      'title': 'Mükemmel İlerleme!',
      'subtitle': 'Kelimeler hafızana sağlam şekilde yerleşiyor. Kitapta karşılaştığında çok daha rahat anlayacaksın.',
    },
    {
      'emoji': '🏆',
      'title': 'Zihnin Zirvede!',
      'subtitle': 'Neredeyse hiç takılmadan tamamladın. Kelime dağarcığın adım adım genişliyor.',
    },
    {
      'emoji': '✨',
      'title': 'Harika Bir Odaklanma!',
      'subtitle': 'Kelimeleri çok hızlı ve net hatırladın. Bugünkü tekrar görevini başarıyla tamamladın.',
    },
    {
      'emoji': '🚀',
      'title': 'Kalıcı Hafıza Devrede!',
      'subtitle': 'Bu kelimeler artık uzun süreli hafızana taşınıyor. Okuma akıcılığın belirgin şekilde artacak.',
    },
  ];

  // 2. KADEME: %70 - %89 (Güçlü / İyi İlerleme) -> Zümrüt Yeşili
  static final List<Map<String, String>> _tierGoodSuccess = [
    {
      'emoji': '💪',
      'title': 'Harika Gidiyorsun!',
      'subtitle': 'Bugünkü kelimelerin büyük kısmı zihninde pekişti. Hafızan adım adım güçleniyor.',
    },
    {
      'emoji': '⚡',
      'title': 'Güçlü Bir Seans!',
      'subtitle': 'Kelimelerin çoğunu rahatça hatırladın. Kalanlar da bir sonraki tekrarda oturacaktır.',
    },
    {
      'emoji': '🎯',
      'title': 'Hedefe Çok Yakınsın!',
      'subtitle': 'Zihnin kelimeleri kavramaya başladı. Düzenli pratikle hepsi kalıcı hale gelecek.',
    },
    {
      'emoji': '🌟',
      'title': 'Gözle Görülür İlerleme!',
      'subtitle': 'Zorlandığın birkaç kelime oldu ama genel akışın harikaydı. Öğrenme döngün tıkır tıkır işliyor.',
    },
  ];

  // 3. KADEME: %50 - %69 (Orta / Gelişen Seviye) -> Elektrik Mavisi
  static final List<Map<String, String>> _tierModerateSuccess = [
    {
      'emoji': '🧠',
      'title': 'İyi Bir Pratik Oldu!',
      'subtitle': 'Kelimeler zihninde tazelendi. Algoritma bunları kalıcı yapmak için doğru zamanda tekrar getirecek.',
    },
    {
      'emoji': '📚',
      'title': 'Hafıza Çalışıyor!',
      'subtitle': 'Beyin yeni kelimeleri bağlarken efor sarf eder. Tam olarak bu çaba kalıcılığı sağlar.',
    },
    {
      'emoji': '🧩',
      'title': 'Taşlar Yerine Oturuyor!',
      'subtitle': 'Bazı kelimeler netleşti, bazıları biraz daha tekrar istiyor. Süreç gayet doğal ilerliyor.',
    },
    {
      'emoji': '⏳',
      'title': 'Adım Adım Gelişim!',
      'subtitle': 'Bugün bu kelimelerle temas ettin. Bir dahaki sefere hatırlamak çok daha kolay olacak.',
    },
  ];

  // 4. KADEME: %50 Altı (Zorlanılan Seans) -> Sıcak Mor / Indigo
  static final List<Map<String, String>> _tierNeedPractice = [
    {
      'emoji': '🌱',
      'title': 'Pratikle Güçlenecek!',
      'subtitle': 'Yeni kelimeleri kalıcı hafızaya almak zaman ister. Beyin tam da zorlandığı bu anlarda öğrenir.',
    },
    {
      'emoji': '💡',
      'title': 'Öğrenme Tam Olarak Bu!',
      'subtitle': 'Takılmak sürecin en doğal parçası. Bu kelimeler yarınki tekrarlarda zihninde çok daha rahat oturacak.',
    },
    {
      'emoji': '🛡️',
      'title': 'Algoritma Devrede!',
      'subtitle': 'Zorlandığın kelimeleri not aldık. Seni yormadan, tam unutma eşiğinde tekrar karşına çıkaracağız.',
    },
    {
      'emoji': '📖',
      'title': 'Temas Kurmak En Önemlisiydi!',
      'subtitle': 'Bugün kelimeleri zihninde uyandırdın. Kitabına dönüp onları bağlam içinde gördüğünde anlam pekişecek.',
    },
  ];

  /// Başarı oranına göre varyasyonlu ve dinamik renk temalı koçluk sonucu üretir
  static CoachFeedback getFeedback({
    required String exerciseType,
    required int score,
    required int total,
  }) {
    final double ratio = total > 0 ? (score / total) : 1.0;
    Map<String, String> selected;
    Color themeColor;

    if (ratio >= 0.90) {
      selected = _tierHighSuccess[_rand.nextInt(_tierHighSuccess.length)];
      themeColor = const Color(0xFFF59E0B); // Canlı Amber Altın
    } else if (ratio >= 0.70) {
      selected = _tierGoodSuccess[_rand.nextInt(_tierGoodSuccess.length)];
      themeColor = const Color(0xFF10B981); // Zümrüt Yeşili
    } else if (ratio >= 0.50) {
      selected = _tierModerateSuccess[_rand.nextInt(_tierModerateSuccess.length)];
      themeColor = const Color(0xFF06B6D4); // Camgöbeği / Elektrik Mavisi
    } else {
      selected = _tierNeedPractice[_rand.nextInt(_tierNeedPractice.length)];
      themeColor = const Color(0xFF8B5CF6); // Sıcak Lavanta / Mor
    }

    return CoachFeedback(
      emoji: selected['emoji'] ?? '🎉',
      title: selected['title'] ?? 'Pratik Tamamlandı!',
      subtitle: selected['subtitle'] ?? 'Tebrikler, bugünkü tekrarını tamamladın.',
      actionLabel: 'Kitaba Dön 📖',
      themeColor: themeColor,
      shouldOfferRetry: false,
    );
  }

  // --- FLASHCARD İÇİ TOASTLAR ---
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

  static String getWrongAnswerEncouragement() {
    final list = [
      '🌱 Sorun yok! Beyin hatırlamaya çalışırken öğrenir.',
      '💡 Algoritma bunu senin için not aldı.',
      '📚 Bir sonraki tekrarda çok daha kolay olacak.',
      '⚡ Nöronlar yeni bir bağlantı kurdu, yola devam!',
      '🔄 Zihin pratikle güçlenir, ritmi bozma!',
    ];
    return list[_rand.nextInt(list.length)];
  }

  // --- ANA EKRAN VE OKUYUCU MESAJLARI ---
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
    if (hour >= 23 || hour < 4) {
      final night = [
        'Gece sessizliği, yüksek odaklanma 🦉',
        'Gece kuşu modu aktif! Fark yaratıyorsun 🌙',
        'Yıldızlar altında okuma... Harika an! 🌌',
        'Herkes uyurken sen öğreniyorsun ⚔️',
      ];
      return night[_rand.nextInt(night.length)];
    }

    if (hour >= 4 && hour < 11) {
      final morning = [
        'Güne zinde bir başlangıç! 🌅',
        'Sabah kahvesi hazırsa sayfaları açalım ☕',
        'Günün ilk zaferi için harika bir sabah! ☀️',
      ];
      return morning[_rand.nextInt(morning.length)];
    }

    if (hour >= 11 && hour < 18) {
      final afternoon = [
        'Kısa bir okuma molası harika gider 🥪',
        'Günün temposunda zihnine mola ver 📖',
        'Hedefleri tamamlamak için en verimli an! ☀️',
      ];
      return afternoon[_rand.nextInt(afternoon.length)];
    }

    final evening = [
      'Günün yorgunluğunu sayfalarla dağıt 🌆',
      'Akşam seansıyla serini güvenceye al 🔥',
      'Günü güzel bir okumayla kapatalım ✨',
    ];
    return evening[_rand.nextInt(evening.length)];
  }

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
      '🧠 Yarım saat derin okuma devrildi! Tebrikler.',
    ];
    return list[_rand.nextInt(list.length)];
  }
}