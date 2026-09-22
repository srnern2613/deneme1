// ============================================================================
// DOSYA ADI: lib/core/coach/ignis_moments_engine.dart
// AÇIKLAMA: AŞAMA 2 — Ignis Anları'nın yerel istatistik + tetikleyici motoru.
//
// AI YOK, SUNUCU YOK, HESAP YOK — tamamen database_helper.dart'taki
// daily_stats / flashcards verisinden ve StreakFreezeService'ten besleniyor.
//
// SIKLIK KURALI (güncellendi — kullanıcı kararı: "biraz daha arttıralım"):
// günde en fazla 2 "önemli an" (seri kilometre taşı, kişisel rekor, dünle
// karşılaştırma vb.) + her seans sonu basit bir özet. Egzersizin ortasında
// ASLA çağrılmaz — sadece seans/oturum bittiğinde.
// ============================================================================

import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../database_helper.dart';
import '../../streak_freeze_service.dart';

enum IgnisMomentType {
  streakMilestone,
  paceInsight,
  dailySummary,
  streakLost,
  dailyGoalCompleted,
  // Dünle karşılaştırma anı — paceInsight'ın bir varyasyonu, aynı öncelik
  // kademesinde, önceden zaten çekilen 7 günlük veriden (ek DB sorgusu yok).
  comparison,
}

class IgnisMoment {
  final IgnisMomentType type;
  final String pose; // AppBranding.poseAsset() ile eşleşen anahtar
  final String title;
  final String message;

  IgnisMoment({
    required this.type,
    required this.pose,
    required this.title,
    required this.message,
  });
}

/// AŞAMA 4 — Ana Sayfa "Günlük Durum" kartı için: Ignis Anları'nın kalıcı,
/// sessiz versiyonu. getSessionEndMoment()'ın aksine hiçbir "günde 1 kez"
/// kısıtı YOK — kart her açıldığında güncel veriyi gösterir, popup değildir.
class IgnisDailyStatus {
  final int newWordsToday;
  final int reviewsToday;
  final int dueTomorrow;
  final int weeklyProjection;
  // P0-D: örnek kelime havuzuyla yapılan pratik daily_stats tablosuna hiç
  // yazmıyor (recordMultiModalResult cardId<=0 için no-op) — bu yüzden
  // newWordsToday/reviewsToday sıfır kalabilir. celebration_dialog.dart
  // her seans sonunda (gerçek VEYA örnek) ayrı, hafif bir "bugün pratik
  // yapıldı" bayrağı işaretliyor; bu alan o bayrağı taşıyor ki kullanıcı
  // örnek kelimelerle pratik yaptığında bile "Bugün henüz pratik
  // yapmadın" mesajında takılı kalınmasın. Sayısal alanlar (newWordsToday
  // vb.) bu bayraktan ETKİLENMEZ — hâlâ sadece gerçek veritabanı verisi.
  final bool practicedToday;

  IgnisDailyStatus({
    required this.newWordsToday,
    required this.reviewsToday,
    required this.dueTomorrow,
    required this.weeklyProjection,
    this.practicedToday = false,
  });

  bool get hasActivityToday =>
      newWordsToday > 0 || reviewsToday > 0 || practicedToday;
}

class IgnisMomentsEngine {
  IgnisMomentsEngine._();
  static final IgnisMomentsEngine instance = IgnisMomentsEngine._();

  // Eskiden tek bir tarih string'i tutuluyordu (günde en fazla 1). Artık
  // "gün + o günkü sayaç" birlikte tutuluyor, böylece günde 2'ye kadar
  // önemli an gösterilebiliyor — gün değişince sayaç doğal olarak sıfırlanır.
  static const _prefsImportantMomentDateKey = 'ignis_last_important_moment_date';
  static const _prefsImportantMomentCountKey = 'ignis_important_moment_count';
  static const int _maxImportantMomentsPerDay = 2;
  // Faz F: seri-kaybı anı ayrı bir tetikleyici noktada (uygulama açılışı)
  // gösteriliyor — seans-sonu "önemli an" sıklık kuralıyla PAYLAŞMIYOR,
  // kendi günlük kilidini kullanıyor.
  static const _prefsLastStreakLossDateKey = 'ignis_last_streak_loss_moment_date';
  // Faz F2: günlük hedef tamamlanınca gösterilen "loving" anı — kendi
  // günlük kilidini kullanır, seri kaybı/önemli an sıklık kurallarıyla
  // PAYLAŞMAZ (aynı desen: bkz. _prefsLastStreakLossDateKey).
  static const _prefsLastDailyGoalDateKey = 'ignis_last_daily_goal_moment_date';
  static const List<int> _streakMilestones = [7, 30, 100];

  final Random _rand = Random();

  String _pickVariant(List<String> variants) => variants[_rand.nextInt(variants.length)];

  // Mesaj varyasyon havuzları — hem seans-sonu popup'ı hem de profildeki
  // salt-okunur önizleme AYNI havuzları kullanır, tek yerden yönetilir.
  List<String> _streakMilestoneMessages(int streakDays) => [
        '$streakDays gündür kesintisiz pratik yapıyorsun. Bu disiplin kalıcı hafızanın temeli.',
        '$streakDays gün! Bu istikrarı sürdürmek gerçek bir güç — devam et.',
        '$streakDays günlük seri... Bu artık bir alışkanlık haline geldi, tebrikler!',
        '$streakDays gün boyunca hiç aksatmadın. Zindanın en disiplinli maceracılarından birisin.',
      ];

  List<String> _comparisonMessages(int yesterdayNewWords, int newWords) => [
        'Dün $yesterdayNewWords yeni kelime öğrenmiştin, bugün $newWords — güzel bir sıçrama!',
        'Bugün dünden $newWords kelime ile daha güçlü bir gün geçirdin (dün: $yesterdayNewWords).',
        'Dünle kıyaslayınca bugün daha iyisin: $yesterdayNewWords → $newWords kelime.',
        'Bu ivmeyi seviyorum — dün $yesterdayNewWords, bugün $newWords kelime!',
      ];

  List<String> _paceInsightMessages(int weeklyProjection, int dueTomorrow) => [
        'Bu hızla bir haftada yaklaşık $weeklyProjection kelime öğrenmiş olacaksın. Yarın $dueTomorrow kelimenin tekrar vakti geliyor.',
        'Böyle devam edersen bir haftada $weeklyProjection kelimeye ulaşırsın. $dueTomorrow kelime yarın seni bekliyor.',
        'Bu tempoyla haftalık projeksiyonun $weeklyProjection kelime. Yarına $dueTomorrow tekrar kaldı.',
        'Gidişat çok iyi: bu hızla haftada $weeklyProjection kelime. Yarın $dueTomorrow kelimeyi tekrar edeceksin.',
      ];

  // Günün saatine göre kısa bir selamlama öneki — aynı "günlük özet"
  // mesajının her zaman aynı hissettirmemesi için. Ek state/DB sorgusu
  // gerektirmiyor, sadece DateTime.now().hour.
  String _timeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Bu saatte bile buradasın, etkileyici!';
    if (hour < 12) return 'Güne güzel başladın.';
    if (hour < 18) return 'Günün ortasında bile pratik yapmayı unutmadın.';
    return 'Günü güzel bir pratikle kapatıyorsun.';
  }

  String _todayKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<int> _importantMomentCountToday() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_prefsImportantMomentDateKey) != _todayKey()) return 0;
    return prefs.getInt(_prefsImportantMomentCountKey) ?? 0;
  }

  Future<void> _markImportantMomentShown() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final currentCount = prefs.getString(_prefsImportantMomentDateKey) == today
        ? (prefs.getInt(_prefsImportantMomentCountKey) ?? 0)
        : 0;
    await prefs.setString(_prefsImportantMomentDateKey, today);
    await prefs.setInt(_prefsImportantMomentCountKey, currentCount + 1);
  }

  /// Seans sonunda (SRS/quiz/spelling/match bitişinde) çağrılır — asla
  /// egzersiz ortasında. Her zaman bir şey döner (o gün hiç pratik yoksa
  /// null): bugün henüz "önemli an" gösterilmediyse seri kilometre taşı ya
  /// da hız projeksiyonundan öncelikli olanı seçer; gösterildiyse sade bir
  /// günlük özete düşer.
  Future<IgnisMoment?> getSessionEndMoment() async {
    final db = DatabaseHelper.instance;
    final today = await db.getTodayStatsSummary();
    final newWords = today['new_words_count'] ?? 0;
    final reviews = today['review_count'] ?? 0;

    if (newWords == 0 && reviews == 0) return null;

    final dueTomorrow = await db.getDueTomorrowCount();
    final shownCount = await _importantMomentCountToday();

    if (shownCount < _maxImportantMomentsPerDay) {
      // Öncelik 1: seri kilometre taşı (7/30/100 gün) — en güçlü an.
      final streakResult = await StreakFreezeService.instance.checkAndUpdateStreak();
      final streakDays = streakResult['streakDays'] as int? ?? 0;
      if (_streakMilestones.contains(streakDays)) {
        await _markImportantMomentShown();
        return IgnisMoment(
          type: IgnisMomentType.streakMilestone,
          pose: 'celebrating',
          title: '$streakDays Günlük Seri!',
          message: _pickVariant(_streakMilestoneMessages(streakDays)),
        );
      }

      // Öncelik 2: hız/projeksiyon içgörüsü (kullanıcının asıl istediği
      // özellik: "bu gidişle 1 haftada şu kadar öğrenirsin"). Aynı sorguyla
      // dünle karşılaştırma da hesaplanabiliyor — ek DB maliyeti yok.
      final range = await db.getDailyStatsRange(7);
      final totalNewLast7Days = range.fold<int>(
        0,
        (sum, row) => sum + ((row['new_words_count'] as int?) ?? 0),
      );
      final avgPerDay = totalNewLast7Days / 7.0;
      final weeklyProjection = (avgPerDay * 7).round();

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayKey =
          "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
      final yesterdayRow = range.where((r) => r['stat_date'] == yesterdayKey).toList();
      // "hasYesterdayData": dün gerçekten bir kayıt var mı, yoksa (yeni
      // kullanıcı / dünkü boşluk) 0'a mı düşüyoruz? İkincisinde karşılaştırma
      // göstermiyoruz — hiç geçmişi olmayan bir kullanıcıya "dünden iyisin"
      // demek olmayan bir momentumu ima eder.
      final hasYesterdayData = yesterdayRow.isNotEmpty;
      final yesterdayNewWords = hasYesterdayData ? ((yesterdayRow.first['new_words_count'] as int?) ?? 0) : 0;

      await _markImportantMomentShown();

      // Dünden belirgin bir sıçrama varsa karşılaştırma anını göster —
      // getProfileInsightPreview() İLE AYNI kuralı (deterministik) kullanır,
      // aksi halde seans sonunda görülen popup ile profildeki kart FARKLI
      // türde bir an gösterebilir (kafa karıştırıcı olur). Çeşitlilik
      // ihtiyacı zaten mesaj havuzlarındaki (_pickVariant) rastgelelikle
      // karşılanıyor — tür seçimi rastgele OLMAMALI.
      if (hasYesterdayData && newWords > yesterdayNewWords) {
        return IgnisMoment(
          type: IgnisMomentType.comparison,
          // "happy" — streak kilometre taşının (celebrating/excited) tuttuğu
          // büyük kutlama ile karıştırılmasın diye daha hafif bir ifade.
          pose: 'happy',
          title: 'Dünden Daha İyisin!',
          message: _pickVariant(_comparisonMessages(yesterdayNewWords, newWords)),
        );
      }

      if (weeklyProjection > 0) {
        return IgnisMoment(
          type: IgnisMomentType.paceInsight,
          pose: 'teacher',
          title: 'Bugün $newWords Kelime Öğrendin!',
          message: _pickVariant(_paceInsightMessages(weeklyProjection, dueTomorrow)),
        );
      }
    }

    // Bugün zaten bir "önemli an" gösterildi ya da hiçbiri tetiklenmedi —
    // sade günlük özet (her seans sonunda gösterilebilir, ölçülü kuralı
    // dışında çünkü bu bir kutlama değil, bilgi satırı). Saate göre kısa
    // bir selamlama öneki ekleniyor ki her zaman aynı hissetmesin.
    return IgnisMoment(
      type: IgnisMomentType.dailySummary,
      pose: 'teacher',
      title: 'Bugünkü İlerlemen',
      message: '${_timeOfDayGreeting()} Bugün $newWords yeni kelime, $reviews tekrar yaptın. '
          'Yarın $dueTomorrow kelimenin tekrar vakti geliyor.',
    );
  }

  /// Profil ekranındaki "Ignis Önerisi" kartı için — SALT OKUNUR, seans-sonu
  /// popup'ının günlük kotasını (en fazla 2) HİÇ TÜKETMEZ ve o kotadan
  /// bağımsızdır. Aynı öncelik sırasını (seri kilometre taşı → dünle
  /// karşılaştırma → hız içgörüsü → günlük özet) kullanarak, profil her
  /// açıldığında en güncel içgörüyü yeniden hesaplayıp döner. Bugün hiç
  /// pratik yoksa kart GİZLENMEZ — bunun yerine kısa bir teşvik mesajı
  /// döner (kullanıcı geri bildirimi: kart bazen hiç görünmüyormuş gibi
  /// hissettiriyordu, bir asistan sessizce kaybolmamalı).
  ///
  /// [precomputedStreakResult]: çağıran taraf (ör. profile_screen.dart)
  /// zaten aynı yükleme turunda StreakFreezeService.checkAndUpdateStreak()
  /// çağırdıysa onu buraya verebilir — bu metod checkAndUpdateStreak()'i
  /// TEKRAR çağırmaz (bkz. getStreakLossMoment'taki aynı uyarı: aynı turda
  /// iki kez çağırmak gereksiz iş + tutarsızlık riski taşır).
  Future<IgnisMoment?> getProfileInsightPreview({Map<String, dynamic>? precomputedStreakResult}) async {
    final db = DatabaseHelper.instance;
    final today = await db.getTodayStatsSummary();
    final newWords = today['new_words_count'] ?? 0;
    final reviews = today['review_count'] ?? 0;

    final streakResult = precomputedStreakResult ?? await StreakFreezeService.instance.checkAndUpdateStreak();
    final streakDays = streakResult['streakDays'] as int? ?? 0;

    if (newWords == 0 && reviews == 0) {
      return IgnisMoment(
        type: IgnisMomentType.dailySummary,
        pose: 'greeting',
        title: 'Henüz Başlamadın',
        message: _pickVariant([
          'Bugün henüz pratik yapmadın. Hazır olduğunda kısa bir tur atalım, ilerlemeni burada takip ederim.',
          'Bu sayfa seni bekliyor — bugünkü ilk pratiğini tamamlayınca burada gerçek bir içgörü göreceksin.',
        ]),
      );
    }

    final dueTomorrow = await db.getDueTomorrowCount();
    if (_streakMilestones.contains(streakDays)) {
      return IgnisMoment(
        type: IgnisMomentType.streakMilestone,
        pose: 'celebrating',
        title: '$streakDays Günlük Seri!',
        message: _pickVariant(_streakMilestoneMessages(streakDays)),
      );
    }

    final range = await db.getDailyStatsRange(7);
    final totalNewLast7Days = range.fold<int>(
      0,
      (sum, row) => sum + ((row['new_words_count'] as int?) ?? 0),
    );
    final weeklyProjection = ((totalNewLast7Days / 7.0) * 7).round();

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayKey =
        "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
    final yesterdayRow = range.where((r) => r['stat_date'] == yesterdayKey).toList();
    final hasYesterdayData = yesterdayRow.isNotEmpty;
    final yesterdayNewWords = hasYesterdayData ? ((yesterdayRow.first['new_words_count'] as int?) ?? 0) : 0;

    if (hasYesterdayData && newWords > yesterdayNewWords) {
      return IgnisMoment(
        type: IgnisMomentType.comparison,
        pose: 'happy',
        title: 'Dünden Daha İyisin!',
        message: _pickVariant(_comparisonMessages(yesterdayNewWords, newWords)),
      );
    }

    if (weeklyProjection > 0) {
      return IgnisMoment(
        type: IgnisMomentType.paceInsight,
        pose: 'teacher',
        title: 'Bugün $newWords Kelime Öğrendin!',
        message: _pickVariant(_paceInsightMessages(weeklyProjection, dueTomorrow)),
      );
    }

    return IgnisMoment(
      type: IgnisMomentType.dailySummary,
      pose: 'teacher',
      title: 'Bugünkü İlerlemen',
      message: '${_timeOfDayGreeting()} Bugün $newWords yeni kelime, $reviews tekrar yaptın. '
          'Yarın $dueTomorrow kelimenin tekrar vakti geliyor.',
    );
  }

  /// Faz F — Uygulama açılışında (Ana Sayfa yüklenirken) çağrılır. Parametre
  /// olarak StreakFreezeService.checkAndUpdateStreak()'in ZATEN hesaplanmış
  /// sonucunu alır — burada tekrar çağırmıyoruz, çünkü o metod state
  /// mutasyonu yapıyor (seri sayacını günceller); iki kez çağırmak yanlış
  /// sonuç üretir. Günde en fazla 1 kez gösterilir (kullanıcı ekranı birden
  /// çok kez açıp kapatsa bile canını sıkıcı şekilde tekrar etmesin diye).
  Future<IgnisMoment?> getStreakLossMoment(Map<String, dynamic> streakResult) async {
    final bool streakLost = streakResult['streakLost'] == true;
    if (!streakLost) return null;

    final prefs = await SharedPreferences.getInstance();
    final alreadyShownToday = prefs.getString(_prefsLastStreakLossDateKey) == _todayKey();
    if (alreadyShownToday) return null;

    await prefs.setString(_prefsLastStreakLossDateKey, _todayKey());
    return IgnisMoment(
      type: IgnisMomentType.streakLost,
      pose: 'sad',
      title: 'Serin Kırıldı...',
      message: 'Sorun değil, herkesin ara verdiği günler olur. Bugün yeniden başlayalım — '
          'bir sonraki serin daha güçlü olacak!',
    );
  }

  /// Faz F2 — Uygulama açılışında (Ana Sayfa yüklenirken) çağrılır. Günlük
  /// kelime hedefine o gün ilk kez erişildiğinde Ignis'in sevgi dolu/gurur
  /// pozuyla (loving.webp) kutlanır — seri kilometre taşından (celebrating)
  /// ve seri kaybından (sad) AYRI bir duygu: burada "bugünü başardın"
  /// mesajı var, seri günü sayısıyla ilgisi yok. Günde en fazla 1 kez
  /// gösterilir.
  Future<IgnisMoment?> getDailyGoalCompletedMoment({
    required int learnedToday,
    required int target,
  }) async {
    if (target <= 0 || learnedToday < target) return null;

    final prefs = await SharedPreferences.getInstance();
    final alreadyShownToday = prefs.getString(_prefsLastDailyGoalDateKey) == _todayKey();
    if (alreadyShownToday) return null;

    await prefs.setString(_prefsLastDailyGoalDateKey, _todayKey());
    return IgnisMoment(
      type: IgnisMomentType.dailyGoalCompleted,
      pose: 'loving',
      title: 'Günlük Hedefin Tamam!',
      message: 'Bugünkü $target kelimelik hedefini tamamladın. Bu istikrar seni çok uzağa taşıyacak — seninle gurur duyuyorum!',
    );
  }

  /// Ana Sayfa'daki "Günlük Durum" kartı için anlık veri — popup/gösterim
  /// sıklığı kısıtına tabi DEĞİL, her çağrıda güncel değerleri döner.
  Future<IgnisDailyStatus> getDailyStatusSnapshot() async {
    final db = DatabaseHelper.instance;
    final today = await db.getTodayStatsSummary();
    final newWords = today['new_words_count'] ?? 0;
    final reviews = today['review_count'] ?? 0;
    final dueTomorrow = await db.getDueTomorrowCount();

    final range = await db.getDailyStatsRange(7);
    final totalNewLast7Days = range.fold<int>(
      0,
      (sum, row) => sum + ((row['new_words_count'] as int?) ?? 0),
    );
    final weeklyProjection = ((totalNewLast7Days / 7.0) * 7).round();

    // P0-D: örnek kelime havuzuyla yapılan pratik yukarıdaki reviews/newWords
    // sayaçlarına hiç dokunmuyor (bkz. IgnisDailyStatus.practicedToday
    // yorumu) — celebration_dialog.dart'ın her seans sonunda işaretlediği
    // tarihe-özel bayrağı burada okuyoruz.
    final prefs = await SharedPreferences.getInstance();
    final practicedToday = prefs.getBool('ignis_practiced_today_${_todayKey()}') ?? false;

    return IgnisDailyStatus(
      newWordsToday: newWords,
      reviewsToday: reviews,
      dueTomorrow: dueTomorrow,
      weeklyProjection: weeklyProjection,
      practicedToday: practicedToday,
    );
  }
}
