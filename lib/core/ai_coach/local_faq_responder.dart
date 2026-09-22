// ============================================================================
// DOSYA ADI: lib/core/ai_coach/local_faq_responder.dart
// AÇIKLAMA: AI Koç ekranı için YEREL (sunucuya gitmeyen, kota harcamayan)
// hızlı cevap katmanı. Kullanıcının mesajı sık sorulan bir kalıba
// uyuyorsa, gerçek AI'a hiç gidilmeden anında (varyasyonlu ve mümkünse
// GERÇEK VERİYE dayalı) bir cevap döner. Eşleşme yoksa null döner ve
// ekran normal AI akışına (AiCoachRepository) düşer.
//
// AI YOK, SUNUCU YOK — sadece basit anahtar-kelime eşleştirme +
// database_helper/streak_freeze_service/xp_shop_service'ten okuma.
// ============================================================================

import 'dart:math';

import '../../database_helper.dart';
import '../../streak_freeze_service.dart';
import '../../xp_shop_service.dart';
import '../coach/ignis_moments_engine.dart';

class LocalFaqResponder {
  LocalFaqResponder._();
  static final LocalFaqResponder instance = LocalFaqResponder._();

  final Random _rand = Random();

  String _pick(List<String> variants) => variants[_rand.nextInt(variants.length)];

  bool _has(String text, List<String> keywords) => keywords.any((k) => text.contains(k));

  /// Eşleşme varsa cevabı, yoksa null döner. Eşleşen kategoriler ASLA
  /// AiCoachRepository'ye gitmez — kota harcanmaz.
  Future<String?> tryAnswer(String rawMessage) async {
    final text = rawMessage.toLowerCase().trim();
    if (text.isEmpty) return null;

    // Sıra önemli: daha spesifik/veri gerektiren kalıplar önce kontrol
    // edilir ki "kelime" gibi genel bir kelime yanlış kategoriye düşmesin.

    if (_has(text, ['bugün kaç kelime', 'bugün ne kadar öğren', 'bugünkü ilerle'])) {
      return _answerTodayProgress();
    }

    if (_has(text, ['seri', 'streak']) && _has(text, ['kaç', 'nasıl', 'koru', 'kaybet', 'kırıl'])) {
      return _answerStreak();
    }

    if (_has(text, ['kaç kelime', 'kelime sayım', 'toplam kelime', 'kelime havuzum'])) {
      return _answerWordCount();
    }

    if (_has(text, ['xp', 'elmas', 'puan']) && _has(text, ['kaç', 'ne kadar', 'nasıl kazan'])) {
      return _answerXpGems();
    }

    if (_has(text, ['rozet', 'başarım', 'achievement', 'madalya'])) {
      return _pick([
        'Rozetler, belirli bir eşiği geçtiğinde otomatik açılır — sayfa okumak, kelime avlamak, seri yapmak gibi. Profil sekmesindeki "Rozetlerim" bölümünden hangi rozete ne kadar kaldığını görebilirsin.',
        'Her rozetin kendine özgü bir koşulu var (sayfa sayısı, kelime sayısı, okuma süresi gibi). Profilindeki rozet odasında kilitli olanlara dokunursan ne yapman gerektiğini gösteriyorum.',
      ]);
    }

    if (_has(text, ['premium', 'abonelik', 'pro üyelik', 'satın al'])) {
      return _pick([
        'Premium ile sınırsız AI sohbeti, reklamsız deneyim ve bazı kozmetik/hızlandırma öğeleri açılıyor. İstersen Ayarlar veya Profil üzerinden detaylara bakabilirsin — burada seni zorlamıyorum, karar tamamen sana ait 🙂',
        'Premium temel olarak günlük mesaj/pratik sınırlarını kaldırıyor. Ücretsiz halde de öğrenmeye devam edebilirsin, merak ettiğin belirli bir özellik varsa sorabilirsin.',
      ]);
    }

    if (_has(text, ['kelime nasıl ekle', 'kelime ekleme', 'nasıl kelime ekler'])) {
      return _pick([
        'Kelime eklemenin iki yolu var: Sözlük ekranında bir kelimeye bakıp "Hafıza Havuzuna Ekle"ye dokunmak, ya da kitap okurken bilmediğin bir kelimeye dokunup oradan eklemek.',
        'Okurken karşına çıkan bilmediğin kelimeye dokun, açılan pencereden anlamını gör ve "Ekle" de — otomatik olarak pratik listene girer.',
      ]);
    }

    if (_has(text, ['selam', 'merhaba', 'naber', 'nasılsın', 'günaydın', 'iyi akşamlar'])) {
      return _pick([
        'Selam maceracı! Bugün hangi kelimelerle uğraşacağız?',
        'Buradayım! Kelime, telaffuz ya da çalışma stratejisi hakkında ne sormak istersin?',
        'Merhaba! Zindanda bugün seni ne bekliyor, birlikte bakalım mı?',
      ]);
    }

    if (_has(text, ['teşekkür', 'sağol', 'sağ ol', 'eyvallah', 'süper', 'harika'])) {
      return _pick([
        'Rica ederim! Başka bir sorun olursa buradayım.',
        'Ne demek, her zaman yardımcı olmaya çalışırım 🔥',
      ]);
    }

    return null; // eşleşme yok — gerçek AI'a düşer.
  }

  Future<String> _answerStreak() async {
    final streakResult = await StreakFreezeService.instance.checkAndUpdateStreak();
    final streakDays = streakResult['streakDays'] as int? ?? 0;
    final hasShield = streakResult['hasFreezeShield'] == true;
    final shieldNote = hasShield
        ? 'Ayrıca aktif bir seri kalkanın var, bir gün atlasan bile serin korunur.'
        : 'Mağazadan bir seri kalkanı alırsan, bir gün pratik yapamazsan bile serin kırılmaz.';
    if (streakDays <= 0) {
      return 'Henüz bir serin yok — bugün bir pratik seansı tamamlarsan seri başlamış olur! $shieldNote';
    }
    return _pick([
      'Şu an $streakDays günlük serin var. Seriyi korumak için günde en az bir pratik seansı (SRS/quiz/eşleştirme fark etmez) yeterli. $shieldNote',
      '$streakDays gündür kesintisiz gidiyorsun! Devam ettirmek için her gün en az bir kısa seans yeter. $shieldNote',
    ]);
  }

  Future<String> _answerWordCount() async {
    final cards = await DatabaseHelper.instance.getFlashcards();
    final mastered = await DatabaseHelper.instance.getMasteredCount();
    final due = await DatabaseHelper.instance.getDueReviewCount();
    return _pick([
      'Hafıza havuzunda toplam ${cards.length} kelime var, bunlardan $mastered tanesinde ustalaştın. Şu an tekrar zamanı gelmiş $due kelime bekliyor.',
      'Şu anki durumun: ${cards.length} kelime, $mastered tanesi kalıcı hafızada, $due tanesi tekrar bekliyor. Güzel gidiyor!',
    ]);
  }

  Future<String> _answerXpGems() async {
    final totalXp = await XpShopService.instance.getTotalXp();
    return _pick([
      'Toplamda $totalXp XP\'ye ulaşmışsın. XP ve elmas, her pratik seansının sonunda doğru cevap/ustalaşma oranına göre kazanılıyor.',
      'Şu an $totalXp XP\'n var. Daha çok kazanmak için zorlandığın kelimeleri tekrar etmek en verimlisi — ustalaşınca bonus XP geliyor.',
    ]);
  }

  Future<String> _answerTodayProgress() async {
    final status = await IgnisMomentsEngine.instance.getDailyStatusSnapshot();
    if (!status.hasActivityToday) {
      return 'Bugün henüz bir pratik seansı görünmüyor. İster misin kısa bir tur atalım, ilerlemeni birlikte takip edelim?';
    }
    return _pick([
      'Bugün ${status.newWordsToday} yeni kelime öğrendin, ${status.reviewsToday} tekrar yaptın. Yarın ${status.dueTomorrow} kelimenin tekrar vakti geliyor.',
      'Harika bir gün: ${status.newWordsToday} yeni kelime + ${status.reviewsToday} tekrar. Bu hızla haftalık projeksiyonun yaklaşık ${status.weeklyProjection} kelime.',
    ]);
  }
}
