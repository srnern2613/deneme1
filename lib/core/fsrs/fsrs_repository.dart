// ============================================================================
// DOSYA ADI: lib/core/fsrs/fsrs_repository.dart
// AÇIKLAMA: Ejderha Rotası V2 — Faz 3. FSRS motorunu sqflite'a bağlayan
// repository katmanı. flashcards tablosundaki fsrs_* kolonlarını okuyup
// yazar. V1'in recordMultiModalResult sistemine DOKUNMAZ — paralel çalışır.
//
// İleride bulut senkronuna geçilirse yalnızca bu dosyanın implementasyonu
// değişir; UI katmanı (flashcards_screen.dart, flashcards_exercise_screen.dart)
// hiç değişmeden kalır (repository pattern).
// ============================================================================

import 'package:sqflite/sqflite.dart';

import '../../database_helper.dart';
import 'fsrs_engine.dart';
import 'fsrs_models.dart';

class FsrsRepository {
  FsrsRepository._();
  static final FsrsRepository instance = FsrsRepository._();

  final FsrsEngine _engine = FsrsEngine();

  /// Vadesi gelmiş (veya hiç incelenmemiş) kartları döndürür. NULL
  /// fsrs_due_at (yeni/hiç FSRS ile incelenmemiş kart) her zaman önce gelir,
  /// sonra en eski vadeden yeniye sıralanır.
  Future<List<Map<String, dynamic>>> getDueCards({int limit = 20}) async {
    final db = await DatabaseHelper.instance.database;
    final nowIso = DateTime.now().toIso8601String();
    return db.query(
      'flashcards',
      where: "learning_state != 'DISCOVERED' AND (fsrs_due_at IS NULL OR fsrs_due_at <= ?)",
      whereArgs: [nowIso],
      orderBy: "CASE WHEN fsrs_due_at IS NULL THEN 0 ELSE 1 END, fsrs_due_at ASC",
      limit: limit,
    );
  }

  /// Bir review sonucunu FSRS motoruyla hesaplayıp ilgili kartın fsrs_*
  /// kolonlarına yazar. V1'in kendi alanlarına (interval, repetitions,
  /// learning_state vb.) dokunmaz.
  Future<void> recordReview({
    required int cardId,
    required FsrsRating rating,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('flashcards', where: 'id = ?', whereArgs: [cardId], limit: 1);
    if (rows.isEmpty) return;
    final row = rows.first;

    final reps = (row['fsrs_reps'] as int?) ?? 0;
    FsrsCardState? current;
    if (reps > 0) {
      final lastReviewedStr = row['fsrs_last_reviewed_at'] as String?;
      current = FsrsCardState(
        stability: (row['fsrs_stability'] as num?)?.toDouble() ?? 0.1,
        difficulty: (row['fsrs_difficulty'] as num?)?.toDouble() ?? 5.0,
        lastReviewAt: lastReviewedStr != null ? DateTime.tryParse(lastReviewedStr) : null,
        reps: reps,
        lapses: (row['fsrs_lapses'] as int?) ?? 0,
      );
    }

    final now = DateTime.now();
    final result = _engine.review(current: current, rating: rating, now: now);

    await db.update(
      'flashcards',
      {
        'fsrs_stability': result.stability,
        'fsrs_difficulty': result.difficulty,
        'fsrs_due_at': result.dueAt.toIso8601String(),
        'fsrs_state': result.state.index,
        'fsrs_reps': result.reps,
        'fsrs_lapses': result.lapses,
        'fsrs_last_reviewed_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [cardId],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
