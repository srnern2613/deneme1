// ============================================================================
// DOSYA ADI: lib/core/coach/ignis_moments_engine.dart
// AÇIKLAMA: AŞAMA 2 — Ignis Anları'nın yerel istatistik + tetikleyici motoru.
//
// AI YOK, SUNUCU YOK, HESAP YOK — tamamen database_helper.dart'taki
// daily_stats / flashcards verisinden ve StreakFreezeService'ten besleniyor.
//
// SIKLIK KURALI (kullanıcı kararı: "ölçülü"): günde en fazla 1 "önemli an"
// (seri kilometre taşı, kişisel rekor vb.) + her seans sonu basit bir özet.
// Egzersizin ortasında ASLA çağrılmaz — sadece seans/oturum bittiğinde.
// ============================================================================

import 'package:shared_preferences/shared_preferences.dart';

import '../../database_helper.dart';
import '../../streak_freeze_service.dart';

enum IgnisMomentType {
  streakMilestone,
  paceInsight,
  dailySummary,
  streakLost,
  dailyGoalCompleted,
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

  static const _prefsLastImportantDateKey = 'ignis_last_important_moment_date';
  // Faz F: seri-kaybı anı ayrı bir tetikleyici noktada (uygulama açılışı)
  // gösteriliyor — seans-sonu "önemli an" sıklık kuralıyla PAYLAŞMIYOR,
  // kendi günlük kilidini kullanıyor.
  static const _prefsLastStreakLossDateKey = 'ignis_last_streak_loss_moment_date';
  // Faz F2: günlük hedef tamamlanınca gösterilen "loving" anı — kendi
  // günlük kilidini kullanır, seri kaybı/önemli an sıklık kurallarıyla
  // PAYLAŞMAZ (aynı desen: bkz. _prefsLastStreakLossDateKey).
  static const _prefsLastDailyGoalDateKey = 'ignis_last_daily_goal_moment_date';
  static const List<int> _streakMilestones = [7, 30, 100];

  String _todayKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<bool> _importantMomentAlreadyShownToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsLastImportantDateKey) == _todayKey();
  }

  Future<void> _markImportantMomentShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLastImportantDateKey, _todayKey());
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
    final alreadyShown = await _importantMomentAlreadyShownToday();

    if (!alreadyShown) {
      // Öncelik 1: seri kilometre taşı (7/30/100 gün) — en güçlü an.
      final streakResult = await StreakFreezeService.instance.checkAndUpdateStreak();
      final streakDays = streakResult['streakDays'] as int? ?? 0;
      if (_streakMilestones.contains(streakDays)) {
        await _markImportantMomentShown();
        return IgnisMoment(
          type: IgnisMomentType.streakMilestone,
          pose: 'celebrating',
          title: '$streakDays Günlük Seri!',
          message: '$streakDays gündür kesintisiz pratik yapıyorsun. Bu disiplin kalıcı hafızanın temeli.',
        );
      }

      // Öncelik 2: hız/projeksiyon içgörüsü (kullanıcının asıl istediği
      // özellik: "bu gidişle 1 haftada şu kadar öğrenirsin").
      final range = await db.getDailyStatsRange(7);
      final totalNewLast7Days = range.fold<int>(
        0,
        (sum, row) => sum + ((row['new_words_count'] as int?) ?? 0),
      );
      final avgPerDay = totalNewLast7Days / 7.0;
      final weeklyProjection = (avgPerDay * 7).round();

      await _markImportantMomentShown();

      if (weeklyProjection > 0) {
        return IgnisMoment(
          type: IgnisMomentType.paceInsight,
          pose: 'teacher',
          title: 'Bugün $newWords Kelime Öğrendin!',
          message: 'Bu hızla bir haftada yaklaşık $weeklyProjection kelime öğrenmiş olacaksın. '
              'Yarın $dueTomorrow kelimenin tekrar vakti geliyor.',
        );
      }
    }

    // Bugün zaten bir "önemli an" gösterildi ya da hiçbiri tetiklenmedi —
    // sade günlük özet (her seans sonunda gösterilebilir, ölçülü kuralı
    // dışında çünkü bu bir kutlama değil, bilgi satırı).
    return IgnisMoment(
      type: IgnisMomentType.dailySummary,
      pose: 'teacher',
      title: 'Bugünkü İlerlemen',
      message: 'Bugün $newWords yeni kelime, $reviews tekrar yaptın. '
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
