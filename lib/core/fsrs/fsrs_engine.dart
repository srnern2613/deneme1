// ============================================================================
// DOSYA ADI: lib/core/fsrs/fsrs_engine.dart
// AÇIKLAMA: Ejderha Rotası V2 — Faz 3. FSRS-4.5 (Free Spaced Repetition
// Scheduler) algoritmasının saf Dart implementasyonu. Dış bağımlılık yok —
// tamamen yerel, senkron ve test edilebilir.
//
// Kaynak: FSRS-4.5 açık kaynak referans formülleri (ts-fsrs / py-fsrs ile
// aynı varsayılan ağırlıklar ve "power forgetting curve").
//
// Bu motor V1'deki sabit-aralıklı sistemin (database_helper.dart'taki
// recordMultiModalResult — interval * 1.8) YERİNE geçmiyor, YANINDA
// çalışıyor: flashcards tablosuna eklenen ayrı fsrs_* kolonlarını
// güncelliyor. İki sistem de aynı anda yazılıyor; hangisinin kart sırasını
// belirleyeceği ekran tarafında seçiliyor (bkz. flashcards_screen.dart).
// ============================================================================

import 'dart:math' as math;

import 'fsrs_models.dart';

class FsrsEngine {
  /// FSRS-4.5 "power forgetting curve" sabitleri.
  static const double decay = -0.5;
  static final double factor = math.pow(0.9, 1 / decay) - 1;

  /// FSRS-4.5 referans implementasyonlarıyla aynı 19 varsayılan ağırlık.
  static const List<double> defaultWeights = [
    0.4072, 1.1829, 3.1262, 15.4722, 7.2102, 0.5316, 1.0651, 0.0234, 1.616,
    0.1544, 1.0824, 1.9813, 0.0953, 0.2975, 2.2042, 0.2407, 2.9466, 0.5034, 0.6567,
  ];

  final List<double> w;

  /// Hedeflenen hatırlama olasılığı — 0.9 = "bu kartı %90 ihtimalle
  /// hatırlayacağın günde tekrar göster". Endüstri standardı varsayılan.
  final double desiredRetention;

  FsrsEngine({List<double>? weights, this.desiredRetention = 0.9}) : w = weights ?? defaultWeights;

  double _clampDifficulty(double d) => d.clamp(1.0, 10.0);

  double _initialStability(FsrsRating rating) => math.max(w[rating.grade - 1], 0.1);

  double _initialDifficulty(FsrsRating rating) {
    final d = w[4] - (rating.grade - 3) * w[5];
    return _clampDifficulty(d);
  }

  double _nextDifficulty(double difficulty, FsrsRating rating) {
    final dPrime = difficulty - w[6] * (rating.grade - 3);
    final meanReverted = w[7] * _initialDifficulty(FsrsRating.easy) + (1 - w[7]) * dPrime;
    return _clampDifficulty(meanReverted);
  }

  /// t gün önce incelenmiş, kararlılığı (stability) S olan bir kartın ŞU AN
  /// hatırlanma olasılığı (retrievability), 0..1 arası.
  double retrievability(double elapsedDays, double stability) {
    if (stability <= 0) return 0;
    return math.pow(1 + factor * elapsedDays / stability, decay).toDouble();
  }

  double _nextStability({
    required double difficulty,
    required double stability,
    required double r,
    required FsrsRating rating,
  }) {
    if (rating == FsrsRating.again) {
      // Unutma (lapse) formülü: kararlılık düşer.
      return w[11] *
          math.pow(difficulty, -w[12]) *
          (math.pow(stability + 1, w[13]) - 1) *
          math.exp((1 - r) * w[14]);
    }
    // Hatırlama formülü: kararlılık büyür; Hard cezalı, Easy bonuslu.
    final hardPenalty = rating == FsrsRating.hard ? w[15] : 1.0;
    final easyBonus = rating == FsrsRating.easy ? w[16] : 1.0;
    final growth = math.exp(w[8]) *
        (11 - difficulty) *
        math.pow(stability, -w[9]) *
        (math.exp((1 - r) * w[10]) - 1) *
        hardPenalty *
        easyBonus;
    return stability * (1 + growth);
  }

  int _nextIntervalDays(double stability) {
    final interval = (stability / factor) * (math.pow(desiredRetention, 1 / decay) - 1);
    return interval.round().clamp(1, 36500);
  }

  /// Bir kartın review anındaki FSRS hesabını yapar. [current] null ise
  /// kart hiç incelenmemiş demektir (cold start / yeni kelime).
  FsrsReviewResult review({
    required FsrsCardState? current,
    required FsrsRating rating,
    required DateTime now,
  }) {
    late final double stability;
    late final double difficulty;
    late final int reps;
    late int lapses;

    if (current == null || current.reps == 0) {
      difficulty = _initialDifficulty(rating);
      stability = _initialStability(rating);
      reps = 1;
      lapses = rating == FsrsRating.again ? 1 : 0;
    } else {
      final elapsedDays = current.lastReviewAt == null
          ? 0.0
          : now.difference(current.lastReviewAt!).inHours / 24.0;
      final r = retrievability(elapsedDays.clamp(0, double.infinity), current.stability);
      difficulty = _nextDifficulty(current.difficulty, rating);
      stability = _nextStability(
        difficulty: current.difficulty,
        stability: current.stability,
        r: r,
        rating: rating,
      );
      reps = current.reps + 1;
      lapses = current.lapses + (rating == FsrsRating.again ? 1 : 0);
    }

    final FsrsState state;
    if (rating == FsrsRating.again) {
      state = (current == null || current.reps == 0) ? FsrsState.learning : FsrsState.relearning;
    } else {
      state = FsrsState.review;
    }

    // P0 (Faz 1, #9): "Again" (yanlış cevap) için gün-bazlı _nextIntervalDays
    // formülü minimum 1 gün clamp'i içeriyor — bu, yanlış cevaplanan bir
    // kelimeyi YANLIŞLIKLA yarına erteliyordu (FSRS'in standart davranışı
    // "relearning" adımını kısa sürede, aynı gün içinde tekrar sormaktır).
    // Doğru cevaplarda (Hard/Good/Easy) gün-bazlı aralık aynen korunuyor.
    final DateTime dueAt;
    if (rating == FsrsRating.again) {
      dueAt = now.add(const Duration(minutes: 10));
    } else {
      final intervalDays = _nextIntervalDays(stability);
      dueAt = DateTime(now.year, now.month, now.day).add(Duration(days: intervalDays));
    }

    return FsrsReviewResult(
      stability: stability,
      difficulty: difficulty,
      dueAt: dueAt,
      reps: reps,
      lapses: lapses,
      state: state,
    );
  }
}
