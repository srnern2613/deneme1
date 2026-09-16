// ============================================================================
// DOSYA ADI: lib/core/fsrs/fsrs_models.dart
// AÇIKLAMA: Ejderha Rotası V2 — Faz 3. FSRS algoritmasının veri modelleri.
// ============================================================================

/// Klasik FSRS 4 dereceli puanlama: Again(1) / Hard(2) / Good(3) / Easy(4).
///
/// Mevcut egzersiz ekranları (flashcards/quiz/match/spelling) şimdilik
/// yalnızca doğru/yanlış (binary) sonuç üretiyor — 4 seçenekli bir "ne kadar
/// kolaydı" arayüzü henüz yok. Bu yüzden [FsrsRating.fromCorrectness] ile
/// doğru cevabı Good'a, yanlışı Again'e eşliyoruz. İleride ekranlara
/// "Zor/Kolay" gibi bir geri bildirim eklenirse Hard/Easy de kullanılabilir
/// hale gelir — algoritma zaten hazır.
enum FsrsRating {
  again,
  hard,
  good,
  easy;

  /// 1..4 aralığında klasik FSRS derecesi.
  int get grade => index + 1;

  static FsrsRating fromCorrectness(bool isCorrect) => isCorrect ? FsrsRating.good : FsrsRating.again;
}

/// FSRS kart durumu — New(0) hiç incelenmemiş, Learning(1) yeni öğreniliyor,
/// Review(2) normal tekrar döngüsünde, Relearning(3) bir "Again" sonrası
/// yeniden öğreniliyor.
enum FsrsState { newCard, learning, review, relearning }

/// Bir kartın, review'dan ÖNCEKİ FSRS durumu — [SqliteFsrsRepository]
/// veritabanından okuyup [FsrsEngine.review]'a verir.
class FsrsCardState {
  final double stability;
  final double difficulty;
  final DateTime? lastReviewAt;
  final int reps;
  final int lapses;

  const FsrsCardState({
    required this.stability,
    required this.difficulty,
    required this.lastReviewAt,
    required this.reps,
    required this.lapses,
  });
}

/// Bir review'dan SONRAKİ FSRS durumu — repository bunu doğrudan DB
/// satırına yazar.
class FsrsReviewResult {
  final double stability;
  final double difficulty;
  final DateTime dueAt;
  final int reps;
  final int lapses;
  final FsrsState state;

  const FsrsReviewResult({
    required this.stability,
    required this.difficulty,
    required this.dueAt,
    required this.reps,
    required this.lapses,
    required this.state,
  });
}
