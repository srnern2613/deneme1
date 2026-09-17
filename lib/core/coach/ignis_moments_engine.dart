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

  IgnisDailyStatus({
    required this.newWordsToday,
    required this.reviewsToday,
    required this.dueTomorrow,
    required this.weeklyProjection,
  });

  bool get hasActivityToday => newWordsToday > 0 || reviewsToday > 0;
}

class IgnisMomentsEngine {
  IgnisMomentsEngine._();
  static final IgnisMomentsEngine instance = IgnisMomentsEngine._();

  static const _prefsLastImportantDateKey = 'ignis_last_important_moment_date';
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

    return IgnisDailyStatus(
      newWordsToday: newWords,
      reviewsToday: reviews,
      dueTomorrow: dueTomorrow,
      weeklyProjection: weeklyProjection,
    );
  }
}
