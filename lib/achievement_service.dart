// ============================================================================
// DOSYA ADI: lib/achievement_service.dart
// AÇIKLAMA: Eksiksiz Başarım Kontrolü ve Özgün Başarım Metinleri Motoru
// ============================================================================

import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class UnlockedBadgeInfo {
  final String id;
  final String title;
  final String emoji;
  final String celebrationText;

  UnlockedBadgeInfo({
    required this.id,
    required this.title,
    required this.emoji,
    required this.celebrationText,
  });
}

class AchievementService {
  static final AchievementService instance = AchievementService._init();
  AchievementService._init();

  final Random _rand = Random();

  final Map<String, List<String>> _badgeMessages = {
    // 🌱 Yeni Başlayanlar
    'first_step': [
      'Yumurtayı kırdın! İngilizce serüvenin resmen başladı, geri dönüş yok.',
      'İlk adımı attın! Bin millik yolculuklar tam olarak böyle başlar.',
      'Ve start verildi! Bu serüvende seninle çok yol kat edeceğiz.',
    ],
    'librarian': [
      'İlk kitabını rafa koydun. İskenderiye Kütüphanesi de böyle tek bir parşömenle başlamıştı.',
      'Kütüphanenin ilk taşı kondu! Artık resmi olarak bir okuma kulübüyüz.',
      'İlk kitap raflarda! Sayfaların kokusu buralara kadar geldi.',
    ],
    'first_curiosity': [
      'Bilinmeyen bir kelimeye ilk darbe indirildi! Merakın seni zirveye taşıyacak.',
      'İlk kelimeyi sorguladın. Öğrenmek tam olarak bu cesaretle başlar!',
      'Sözlüğün kapağı aralandı! Bilinmeyen kelimeler artık senden korksun.',
    ],
    'first_spark': [
      'İlk kelime kartın cebinde. Hafıza sarayının ilk tuğlası döşendi.',
      'Kıvılcım çaktı! Bu kartlar yakında koca bir kelime hazinesine dönüşecek.',
      'İlk kelimeyi hafıza kasına emanet ettin. Devamı çorap söküğü gibi gelecek!',
    ],
    'apprentice_reader': [
      'İlk okuma seansı tamam! Kronometre işledi, beyin hücreleri selam durdu.',
      'Kronometre ilk kez durdu! Odaklanma kasların ilk antrenmanını tamamladı.',
      'İlk seans bitti bile. Başlamak işin yarısıydı, diğer yarısını da halledeceğiz!',
    ],

    // 🌅 Zaman & Alışkanlık
    'night_owl': [
      'Herkes uyurken sen kelimelerle dans ediyorsun. Batman bile bu saatte kitap okumuyor!',
      'Gecenin sessizliği, senin kelime sahnen. Bu saatte okuyanlar dünyayı yönetir!',
      'Ayakta mısın? Yıldızlar ve İngilizce cümleler bu gece sadece sana çalışıyor.',
    ],
    'early_bird': [
      'Güneşten önce uyanıp İngilizce kasmak mı? Saygılar şefim, günün ilk kahvesi senden.',
      'Horozlar bile ötmeden kelimeler ezberlendi. Günün en verimli insanı sensin!',
      'Güne 1-0 önde başladın. Sabah serinliği zihnine çok iyi gelmiş!',
    ],
    'shield_master': [
      'Kalkanı kaptın! Hayat araya girse bile serin çelik gibi güvende.',
      'Serin artık sigortalı! Beklenmedik planlar serini bozamayacak.',
      'Savunma hattı kuruldu! Bir gün kaçırsan bile serin dimdik ayakta.',
    ],
    'weekend_warrior': [
      'Millet gezip tozarken sen 20 sayfa devirdin. Disiplinin göz yaşartıyor.',
      'Hafta sonu tatilini zihinsel maratona çevirdin. Gerçek azim işte budur!',
      'Pazar rehaveti sana sökmez! Hafta sonunu rekorla kapattın.',
    ],
    'time_bender': [
      'Kesintisiz 45 dakika okuma! Zaman nasıl geçti anlamadık, Matrix\'e bağladın.',
      '45 dakika kesintisiz akış hali! Odaklanma seviyen uzayda.',
      'Zamanı büktün resmen. 45 dakika boyunca sayfalar arasında kayboldun!',
    ],

    // 📚 Okuma Miktarları
    'page_monster': [
      '100 sayfa bitti gitti! Sayfalar senin elinde resmen eriyor.',
      'Dalya dedin! 100 sayfalık bir İngilizce kütüphanesini geride bıraktın.',
      '100 sayfa devrildi! Hızına yetişmek için yeni kitaplar basmamız gerekecek.',
    ],
    'bound_scholar': [
      '500 sayfa devrildi. Yakında İngilizce konferans verirsen şaşırmayız.',
      '500 sayfa mı?! Resmen devasa bir ansiklopediyi yuttun, tebrikler üstat!',
      '500 sayfalık bilgelik kilidi açıldı. Artık İngilizce metinler senden çekinsin.',
    ],
    'marathoner': [
      'Bir günde 40+ sayfa! Gözlerine bir bardak su ver, bugün tarih yazdın.',
      'Günün maraton şampiyonu! Sayfaları resmen koşarak geçtin.',
      'Tek günde 40 sayfa! Bu hızla gidersen birkaç haftaya roman yazarsın.',
    ],
    'text_detective': [
      '100+ kelime didik didik edildi. Sherlock Holmes bile bu kadar titiz incelemedi.',
      'Metinlerin altını üstüne getirdin. Kaçan hiçbir gizemli kelime kalmadı!',
      'Kelime dedektifi iş başında! 100 kelimenin röntgenini çektin.',
    ],

    // 📇 Hafıza & SRS
    'synapse_master': [
      'Kelime havuzun taştı taşıyor! Beyindeki sinapslar parti veriyor.',
      'Nöronlar ışık hızında! Zihninde devasa bir kelime ağı örüldü.',
      'Kelime dağarcığın level atladı. Artık akıcı konuşmaya çok yakınsın!',
    ],
    'diamond_memory': [
      'SRS kartlarında sıfır hata! Zihninde fotoğrafik bir kamera mı var?',
      'Elmas gibi berrak bir hafıza! Hiçbir kelimeyi ıskalamadın.',
      'Kusursuz hafıza performansı! Kartlar senden korksun.',
    ],
    'voice_guide': [
      'Metin seslendirildi, kulaklar bayram etti. Aksan yükleniyor...',
      'Dinleme kasların çalışıyor! Kulak aşinalığı seviyen tavan yaptı.',
      'Telaffuz ustası olma yolundasın. Sesli öğrenme en kalıcı yoldur!',
    ],
    'curious_mind': [
      'Sözlüğü onlarca kez açtın. Sözlük yazarları bile senin kadar bakmıyor.',
      'Merakın sınır tanımıyor! Her bilinmeyen kelimeye meydan okuyorsun.',
      'Öğrenme açlığı işte böyle bir şey! Zihnini durdurmak imkansız.',
    ],
    'word_collector': [
      '50 favori kelime kütüphanende. Resmen kelime borsası kurdun!',
      'Koleksiyonun parlıyor! Bu kelimeler gelecekteki cümlelerinin temeli.',
      'Büyük bir kelime hazinesi birikti. Koleksiyoncu rozetini sonuna kadar hak ettin!',
    ],

    // 🕵️ Gizli & Prestij
    'speed_of_light': [
      'Günde 5 kez uygulamayı açtın. Bildirime gerek yok, sen zaten buradasın!',
      'Işık hızıyla giriş! Disiplinin rekor kırıyor.',
      'Gözün hep burada! Bu odaklanma seni çok hızlı geliştirecek.',
    ],
    'ghost_reader': [
      'Sessizce geldin, sayfaları devirip çıktın. Tam bir gölge savaşçısı.',
      'Gölge okur devrede! Sessiz ve derinden sayfaları eritiyorsun.',
      'Fark ettirmeden sayfaları bitirdin. Hayalet modun harika işliyor.',
    ],
    'legendary_scholar': [
      'Bütün rozetleri topladın! Uygulamanın son boss\'unu yendin, taht senin 👑',
      'Efsanevi Alim unvanı açıldı! Bu azimle dünyayı fethedebilirsin.',
      'Zirvedesin! İngilizce öğrenme serüveninin yaşayan efsanesi sensin.',
    ],
  };

  String _getRandomMessage(String badgeId, String defaultTitle) {
    final list = _badgeMessages[badgeId];
    if (list != null && list.isNotEmpty) {
      return list[_rand.nextInt(list.length)];
    }
    return '$defaultTitle başarımının kilidi açıldı!';
  }

  Future<List<UnlockedBadgeInfo>> checkAndUnlockAchievements({
    required int totalPagesRead,
    required int totalFlashcards,
    required int totalReadMinutes,
    int wordsExamined = 0,
    int dailyPages = 0,
    bool hasShield = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final List<UnlockedBadgeInfo> newlyUnlocked = [];

    Future<void> check(String id, String title, String emoji, bool condition) async {
      final key = 'badge_unlocked_$id';
      final isUnlocked = prefs.getBool(key) ?? false;
      if (!isUnlocked && condition) {
        await prefs.setBool(key, true);
        newlyUnlocked.add(
          UnlockedBadgeInfo(
            id: id,
            title: title,
            emoji: emoji,
            celebrationText: _getRandomMessage(id, title),
          ),
        );
      }
    }

    final now = DateTime.now();
    final currentHour = now.hour;
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

    // 1. 🌱 Yeni Başlayanlar
    await check('first_step', 'İlk Adım', '🐣', true);
    await check('librarian', 'Kütüphaneci Adayı', '📕', true);
    await check('first_curiosity', 'İlk Merak', '🔍', wordsExamined > 0);
    await check('first_spark', 'İlk Kıvılcım', '⭐', totalFlashcards > 0);
    await check('apprentice_reader', 'Çırak Okur', '⏱️', totalReadMinutes > 0);

    // 2. 🌅 Zaman & Alışkanlık
    await check('night_owl', 'Gece Baykuşu', '🦉', (currentHour >= 0 && currentHour < 4) && totalReadMinutes > 0);
    await check('early_bird', 'Sabah Memuru', '☕', (currentHour >= 5 && currentHour < 8) && totalReadMinutes > 0);
    await check('shield_master', 'Seri Kalkanı', '🛡️', hasShield);
    await check('weekend_warrior', 'Hafta Sonu', '📅', isWeekend && dailyPages >= 20);
    await check('time_bender', 'Zaman Bükücü', '⏳', totalReadMinutes >= 45);

    // 3. 📚 Okuma Miktarları
    await check('page_monster', 'Sayfa Canavarı', '📖', totalPagesRead >= 100);
    await check('bound_scholar', 'Ciltli Alim', '📜', totalPagesRead >= 500);
    await check('marathoner', 'Maratoncu', '🏃', dailyPages >= 40);
    await check('text_detective', 'Metin Dedektifi', '🕵️', wordsExamined >= 100);

    // 4. 📇 Hafıza & SRS
    await check('synapse_master', 'Sinaps Ustası', '🧠', totalFlashcards >= 25);
    await check('diamond_memory', 'Elmas Hafıza', '💎', totalFlashcards >= 50);
    await check('voice_guide', 'Sesli Rehber', '🗣️', totalReadMinutes >= 10);
    await check('curious_mind', 'Meraklı Zihin', '🔍', wordsExamined >= 50);
    await check('word_collector', 'Koleksiyoncu', '🌟', totalFlashcards >= 30);

    // 5. 🕵️ Gizli & Prestij
    await check('speed_of_light', 'Işık Hızı', '⚡', totalReadMinutes >= 20);
    await check('ghost_reader', 'Hayalet Okur', '🥷', totalPagesRead >= 30);
    await check('legendary_scholar', 'Efsanevi Alim', '👑', totalPagesRead >= 300 && totalFlashcards >= 50);

    return newlyUnlocked;
  }

  Future<bool> isBadgeUnlocked(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('badge_unlocked_$id') ?? false;
  }
}