// ============================================================================
// DOSYA ADI: lib/database_helper.dart
// AÇIKLAMA: SQLite Veritabanı Yöneticisi (Word Boss & Çok Boyutlu Mastery Destekli)
// GÖREVLER & DÜZELTMELER:
//   1. Versiyon 13: 'wrong_count', 'boss_level', 'modes_passed', 'distinct_days_count',
//      'last_reviewed_at', 'cooldown_until' alanları eklendi.
//   2. Çok Boyutlu Mastered Kriteri: Zaman (3+ gün), Aralık (>=21), Modalite (>=2 mod) ve Seri (>=6).
//   3. Boss Tetikleme & Seviye Belirleme Algoritması (Troublemaker -> Legendary Boss).
//   4. Boss Zaferinde Exploit Koruması (Mastered otomatik yapılmaz, +1 streak & cooldown verilir).
//   5. Fallback Distractor: Yetersiz kelime durumunda sözlükten çeldirici üretme koruması.
// ============================================================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 13, // Word Boss ve Çok Boyutlu Mastery için Versiyon 13'e yükseltildi
      onCreate: _createDB,
      onUpgrade: _onUpgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // ------------------------------------------------------------------------
    // 1. SÖZLÜK TABLOSU (Çevrimdışı Sözlük Havuzu & Çeldirici Kaynağı)
    // ------------------------------------------------------------------------
    await db.execute('''
      CREATE TABLE dictionary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL COLLATE NOCASE,
        meaning TEXT NOT NULL,
        pos TEXT,
        phonetic TEXT,
        example TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_dictionary_word ON dictionary(word COLLATE NOCASE)
    ''');

    // ------------------------------------------------------------------------
    // 2. GELİŞMİŞ FLASHCARD, KELİME TAKİP & WORD BOSS TABLOSU
    // ------------------------------------------------------------------------
    await db.execute('''
      CREATE TABLE flashcards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL COLLATE NOCASE,
        meaning TEXT NOT NULL,
        interval INTEGER DEFAULT 1,
        repetitions INTEGER DEFAULT 0,
        is_mastered INTEGER DEFAULT 0,
        learning_state TEXT DEFAULT 'LEARNING',
        success_streak INTEGER DEFAULT 0,
        wrong_count INTEGER DEFAULT 0,
        boss_level INTEGER DEFAULT 0,
        modes_passed TEXT DEFAULT '',
        distinct_days_count INTEGER DEFAULT 0,
        last_reviewed_at TEXT,
        cooldown_until TEXT,
        context_sentence TEXT,
        book_title TEXT,
        chapter_info TEXT
      )
    ''');

    // Hızlı sorgulama ve Boss indeksleri
    await db.execute('CREATE INDEX idx_flashcards_word ON flashcards(word COLLATE NOCASE)');
    await db.execute('CREATE INDEX idx_flashcards_mastered ON flashcards(is_mastered)');
    await db.execute('CREATE INDEX idx_flashcards_state ON flashcards(learning_state)');
    await db.execute('CREATE INDEX idx_flashcards_boss ON flashcards(boss_level)');
    await db.execute('CREATE INDEX idx_flashcards_repetitions ON flashcards(repetitions)');

    // ------------------------------------------------------------------------
    // 3. FOSFORLU KALEM (HIGHLIGHTS) TABLOSU
    // ------------------------------------------------------------------------
    await db.execute('''
      CREATE TABLE highlights (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT NOT NULL,
        page_index INTEGER NOT NULL,
        start_word_index INTEGER NOT NULL,
        end_word_index INTEGER NOT NULL,
        color_tag TEXT DEFAULT 'yellow'
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_highlights_lookup ON highlights(book_id, page_index)
    ''');

    // ------------------------------------------------------------------------
    // 4. ÖNBELLEK TABLOSU
    // ------------------------------------------------------------------------
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cacheObject (
        key TEXT PRIMARY KEY,
        value TEXT,
        expiry_date TEXT
      )
    ''');

    await _insertInitialWords(db);
  }

  Future _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE flashcards ADD COLUMN context_sentence TEXT');
        await db.execute('ALTER TABLE flashcards ADD COLUMN book_title TEXT');
        await db.execute('ALTER TABLE flashcards ADD COLUMN chapter_info TEXT');
      } catch (_) {}
    }

    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE dictionary ADD COLUMN pos TEXT');
        await db.execute('ALTER TABLE dictionary ADD COLUMN phonetic TEXT');
      } catch (_) {}
    }

    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE flashcards ADD COLUMN is_mastered INTEGER DEFAULT 0');
      } catch (_) {}
    }

    if (oldVersion < 11) {
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_flashcards_word ON flashcards(word COLLATE NOCASE)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_flashcards_mastered ON flashcards(is_mastered)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_flashcards_repetitions ON flashcards(repetitions)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_highlights_lookup ON highlights(book_id, page_index)');
      } catch (_) {}
    }

    if (oldVersion < 12) {
      try {
        await db.execute("ALTER TABLE flashcards ADD COLUMN learning_state TEXT DEFAULT 'LEARNING'");
        await db.execute("ALTER TABLE flashcards ADD COLUMN success_streak INTEGER DEFAULT 0");
        await db.execute("UPDATE flashcards SET learning_state = 'MASTERED' WHERE is_mastered = 1");
        await db.execute('CREATE INDEX IF NOT EXISTS idx_flashcards_state ON flashcards(learning_state)');
      } catch (_) {}
    }

    // SÜRÜM 13 GÜNCELLEMESİ: Word Boss & Çok Boyutlu Mastery Alanları
    if (oldVersion < 13) {
      try {
        await db.execute("ALTER TABLE flashcards ADD COLUMN wrong_count INTEGER DEFAULT 0");
        await db.execute("ALTER TABLE flashcards ADD COLUMN boss_level INTEGER DEFAULT 0");
        await db.execute("ALTER TABLE flashcards ADD COLUMN modes_passed TEXT DEFAULT ''");
        await db.execute("ALTER TABLE flashcards ADD COLUMN distinct_days_count INTEGER DEFAULT 0");
        await db.execute("ALTER TABLE flashcards ADD COLUMN last_reviewed_at TEXT");
        await db.execute("ALTER TABLE flashcards ADD COLUMN cooldown_until TEXT");
        await db.execute('CREATE INDEX IF NOT EXISTS idx_flashcards_boss ON flashcards(boss_level)');
      } catch (e) {
        // ignore: avoid_print
        print('DB Upgrade v13 Error: $e');
      }
    }
  }

  Future<void> _insertInitialWords(Database db) async {
    final sampleWords = [
      {'word': 'Habit', 'meaning': 'Alışkanlık', 'pos': 'noun', 'phonetic': '/ˈhæb.ɪt/', 'example': 'Good habits make time your ally.'},
      {'word': 'Improve', 'meaning': 'Geliştirmek, iyileştirmek', 'pos': 'verb', 'phonetic': '/ɪmˈpruːv/', 'example': 'Read every day to improve yourself.'},
      {'word': 'Challenge', 'meaning': 'Meydan okuma, zorluk', 'pos': 'noun', 'phonetic': '/ˈtʃæl.ɪndʒ/', 'example': 'Every challenge is an opportunity.'},
      {'word': 'Persistent', 'meaning': 'İnatçı, ısrarcı, sürekli', 'pos': 'adjective', 'phonetic': '/pəˈsɪs.tənt/', 'example': 'Be persistent in your daily practice.'},
    ];

    for (var item in sampleWords) {
      await db.insert('dictionary', item, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ==========================================================================
  // SÖZLÜK METOTLARI & ÇELDİRİCİ (DISTRACTOR) ÜRETECİ
  // ==========================================================================

  Future<Map<String, dynamic>?> getWordDefinition(String word) async {
    final db = await database;
    final clean = word.trim().toLowerCase();
    final result = await db.query(
      'dictionary',
      where: 'word = ? COLLATE NOCASE',
      whereArgs: [clean],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> saveWordDefinition({
    required String word,
    required String meaning,
    String? pos,
    String? phonetic,
    String? example,
  }) async {
    final db = await database;
    await db.insert(
      'dictionary',
      {
        'word': word.trim().toLowerCase(),
        'meaning': meaning.trim(),
        'pos': pos?.trim(),
        'phonetic': phonetic?.trim(),
        'example': example?.trim(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> searchWord(String query) async {
    final db = await database;
    return await db.query(
      'dictionary',
      where: 'word LIKE ? OR meaning LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      limit: 20,
    );
  }

  /// RangeError Önleyici: Testler ve Boss için çeldirici anlam listesi üretir
  Future<List<String>> getDistractorMeanings({
    required String correctWord,
    required String correctMeaning,
    int count = 3,
  }) async {
    final db = await database;
    
    // 1. Önce kullanıcının kendi flashcards havuzundan çeldirici dene
    final rawFlashcards = await db.query(
      'flashcards',
      columns: ['meaning'],
      where: 'word != ? COLLATE NOCASE AND meaning != ?',
      whereArgs: [correctWord.trim(), correctMeaning.trim()],
      orderBy: 'RANDOM()',
      limit: count,
    );

    final Set<String> distractors = rawFlashcards
        .map((e) => (e['meaning'] as String? ?? '').trim())
        .where((m) => m.isNotEmpty && m != correctMeaning.trim())
        .toSet();

    // 2. Yeterli çeldirici yoksa çevrimdışı sözlük havuzundan tamamla (RangeError Koruması)
    if (distractors.length < count) {
      final needed = count - distractors.length;
      final rawDictionary = await db.query(
        'dictionary',
        columns: ['meaning'],
        where: 'word != ? COLLATE NOCASE AND meaning != ?',
        whereArgs: [correctWord.trim(), correctMeaning.trim()],
        orderBy: 'RANDOM()',
        limit: needed * 2,
      );

      for (var row in rawDictionary) {
        final m = (row['meaning'] as String? ?? '').trim();
        if (m.isNotEmpty && m != correctMeaning.trim()) {
          distractors.add(m);
        }
        if (distractors.length >= count) break;
      }
    }

    // 3. Çok uç durumda hala eksikse varsayılan fallback anlamlar ekle
    final fallbackList = ['Sonuç, netice', 'Geliştirmek', 'Keşfetmek', 'Hatırlamak', 'Önemli, mühim'];
    for (var fb in fallbackList) {
      if (distractors.length >= count) break;
      if (fb != correctMeaning.trim()) {
        distractors.add(fb);
      }
    }

    return distractors.take(count).toList();
  }

  // ==========================================================================
  // HIGHLIGHT METOTLARI
  // ==========================================================================

  Future<void> addHighlightRange({
    required String bookId,
    required int pageIndex,
    required int startIndex,
    required int endIndex,
    String colorTag = 'yellow',
  }) async {
    final db = await database;
    await db.insert(
      'highlights',
      {
        'book_id': bookId,
        'page_index': pageIndex,
        'start_word_index': startIndex,
        'end_word_index': endIndex,
        'color_tag': colorTag,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeHighlightRange({
    required String bookId,
    required int pageIndex,
    required int startIndex,
    required int endIndex,
  }) async {
    final db = await database;
    await db.delete(
      'highlights',
      where: 'book_id = ? AND page_index = ? AND start_word_index = ? AND end_word_index = ?',
      whereArgs: [bookId, pageIndex, startIndex, endIndex],
    );
  }

  Future<List<Map<String, dynamic>>> getHighlightsForPage(String bookId, int pageIndex) async {
    final db = await database;
    return await db.query(
      'highlights',
      where: 'book_id = ? AND page_index = ?',
      whereArgs: [bookId, pageIndex],
    );
  }

  Future<void> deleteHighlightsForBook(String bookId) async {
    final db = await database;
    await db.delete('highlights', where: 'book_id = ?', whereArgs: [bookId]);
  }

  // ==========================================================================
  // FLASHCARD, VOCABULARY STATES & WORD BOSS METOTLARI
  // ==========================================================================

  Future<bool> isWordInFlashcards(String word) async {
    final db = await database;
    final clean = word.trim().toLowerCase();
    final result = await db.query('flashcards', where: 'word = ? COLLATE NOCASE', whereArgs: [clean], limit: 1);
    return result.isNotEmpty;
  }

  Future<int> addFlashcard(
    String word, 
    String meaning, {
    String? contextSentence,
    String? bookTitle,
    String? chapterInfo,
    String learningState = 'LEARNING',
  }) async {
    final db = await database;
    return await db.insert(
      'flashcards',
      {
        'word': word.trim(),
        'meaning': meaning.trim(),
        'interval': 1,
        'repetitions': 0,
        'is_mastered': learningState == 'MASTERED' ? 1 : 0,
        'learning_state': learningState,
        'success_streak': 0,
        'wrong_count': 0,
        'boss_level': 0,
        'modes_passed': '',
        'distinct_days_count': 0,
        'context_sentence': contextSentence?.trim(),
        'book_title': bookTitle?.trim(),
        'chapter_info': chapterInfo?.trim(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> discoverWord({
    required String word,
    required String meaning,
    String? contextSentence,
    String? bookTitle,
  }) async {
    final db = await database;
    final clean = word.trim();
    
    final existing = await db.query(
      'flashcards',
      where: 'word = ? COLLATE NOCASE',
      whereArgs: [clean],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    }

    return await addFlashcard(
      clean,
      meaning,
      contextSentence: contextSentence,
      bookTitle: bookTitle,
      learningState: 'DISCOVERED',
    );
  }

  Future<void> promoteToLearning(String word) async {
    final db = await database;
    await db.update(
      'flashcards',
      {'learning_state': 'LEARNING'},
      where: "word = ? COLLATE NOCASE AND learning_state = 'DISCOVERED'",
      whereArgs: [word.trim()],
    );
  }

  Future<int> removeFlashcardByWord(String word) async {
    final db = await database;
    return await db.delete('flashcards', where: 'word = ? COLLATE NOCASE', whereArgs: [word.trim()]);
  }

  Future<List<Map<String, dynamic>>> getFlashcards() async {
    final db = await database;
    return await db.query('flashcards', orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> getActivePracticeCards() async {
    final db = await database;
    return await db.query(
      'flashcards',
      where: "learning_state != 'DISCOVERED'",
      orderBy: 'id DESC',
    );
  }

  /// Aktif Word Boss kelimelerini getirir (Maksimum ilk 3 boss; Fatigue Önleme)
  Future<List<Map<String, dynamic>>> getActiveBossCards({int limit = 3}) async {
    final db = await database;
    final nowIso = DateTime.now().toIso8601String();
    return await db.query(
      'flashcards',
      where: "boss_level > 0 AND (cooldown_until IS NULL OR cooldown_until <= ?)",
      whereArgs: [nowIso],
      orderBy: 'boss_level DESC, wrong_count DESC',
      limit: limit,
    );
  }

  Future<int> getActiveBossCount() async {
    final db = await database;
    final nowIso = DateTime.now().toIso8601String();
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM flashcards 
      WHERE boss_level > 0 AND (cooldown_until IS NULL OR cooldown_until <= ?)
    ''', [nowIso]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> deleteFlashcard(int id) async {
    final db = await database;
    return await db.delete('flashcards', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================================================
  // HIZLI SAYAÇ & İSTATİSTİK METOTLARI
  // ==========================================================================

  Future<int> getMasteredCount() async {
    final db = await database;
    final result = await db.rawQuery("SELECT COUNT(*) as cnt FROM flashcards WHERE learning_state = 'MASTERED' OR is_mastered = 1");
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getDueReviewCount() async {
    final db = await database;
    final result = await db.rawQuery("SELECT COUNT(*) as cnt FROM flashcards WHERE learning_state IN ('LEARNING', 'REVIEWING')");
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, int>> getLearningStateCounts() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT learning_state, COUNT(*) as cnt 
      FROM flashcards 
      GROUP BY learning_state
    ''');

    final Map<String, int> counts = {
      'DISCOVERED': 0,
      'LEARNING': 0,
      'REVIEWING': 0,
      'FAMILIAR': 0,
      'MASTERED': 0,
    };

    for (var row in result) {
      final state = row['learning_state'] as String?;
      final cnt = row['cnt'] as int? ?? 0;
      if (state != null && counts.containsKey(state)) {
        counts[state] = cnt;
      }
    }
    return counts;
  }

  // ==========================================================================
  // ÇOK BOYUTLU SRS, MODALİTE & WORD BOSS ALGORİTMASI
  // ==========================================================================

  /// Çok modlu egzersiz sonucunu kaydeder ('srs', 'quiz', 'spelling', 'match', 'boss')
  Future<void> recordMultiModalResult({
    required int cardId,
    required bool isCorrect,
    required String mode,
  }) async {
    final db = await database;
    
    final list = await db.query('flashcards', where: 'id = ?', whereArgs: [cardId], limit: 1);
    if (list.isEmpty) return;

    final card = list.first;
    int reps = card['repetitions'] as int? ?? 0;
    int currentStreak = card['success_streak'] as int? ?? 0;
    int currentInterval = card['interval'] as int? ?? 1;
    int wrongCount = card['wrong_count'] as int? ?? 0;
    int bossLevel = card['boss_level'] as int? ?? 0;
    String modesPassed = card['modes_passed'] as String? ?? '';
    int distinctDays = card['distinct_days_count'] as int? ?? 0;
    String? lastReviewStr = card['last_reviewed_at'] as String?;

    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (isCorrect) {
      currentStreak += 1;
      reps += 1;
      currentInterval = (currentInterval * 1.8).round().clamp(1, 365);

      // Başarılı olunan modaliteyi kaydet
      final modeSet = modesPassed.split(',').where((m) => m.isNotEmpty).toSet();
      modeSet.add(mode);
      modesPassed = modeSet.join(',');

      // Farklı gün kontrolü (Aynı gün içindeki tekrarlar distinct day sayılmaz)
      if (lastReviewStr == null || !lastReviewStr.startsWith(todayStr)) {
        distinctDays += 1;
      }

      // 🎯 ÇOK BOYUTLU MASTERED DEĞERLENDİRMESİ:
      // Mastered için: 6+ doğru seri, en az 3 farklı gün, en az 21 gün aralık ve en az 2 farklı mod başarısı
      bool meetsMasteryCriteria = currentStreak >= 6 &&
          distinctDays >= 3 &&
          currentInterval >= 21 &&
          modeSet.length >= 2;

      String nextState;
      if (meetsMasteryCriteria) {
        nextState = 'MASTERED';
      } else if (currentStreak >= 4) {
        nextState = 'FAMILIAR';
      } else if (currentStreak >= 2) {
        nextState = 'REVIEWING';
      } else {
        nextState = 'LEARNING';
      }

      // Eğer kelime Boss idi ve kazanıldıysa Boss seviyesini sıfırla (Exploit engeli)
      if (mode == 'boss') {
        bossLevel = 0;
        wrongCount = 0;
      }

      await db.update(
        'flashcards',
        {
          'repetitions': reps,
          'success_streak': currentStreak,
          'interval': currentInterval,
          'learning_state': nextState,
          'is_mastered': nextState == 'MASTERED' ? 1 : 0,
          'wrong_count': wrongCount,
          'boss_level': bossLevel,
          'modes_passed': modesPassed,
          'distinct_days_count': distinctDays,
          'last_reviewed_at': now.toIso8601String(),
          'cooldown_until': null,
        },
        where: 'id = ?',
        whereArgs: [cardId],
      );
    } else {
      // 🔴 HATALI CEVAP: Streak kırılır, hata sayısı artar ve Boss seviyesi hesaplanır
      wrongCount += 1;
      currentStreak = 0;
      currentInterval = 1;
      reps += 1;

      // 👹 ADAPTİF WORD BOSS SEVİYESİ HESAPLAMA (Level 1 - 4)
      if (wrongCount >= 8) {
        bossLevel = 4; // Level 4: Legendary Boss (Kronik unutma)
      } else if (wrongCount >= 5 && mode != 'srs') {
        bossLevel = 3; // Level 3: Elite Boss (Farklı modlarda başarısızlık)
      } else if (wrongCount >= 5) {
        bossLevel = 2; // Level 2: Rival (Tekrar tekrar unutuluyor)
      } else if (wrongCount >= 3) {
        bossLevel = 1; // Level 1: Troublemaker (Direniyor)
      }

      String nextState;
      if (card['learning_state'] == 'MASTERED' || card['learning_state'] == 'FAMILIAR') {
        nextState = 'REVIEWING';
      } else {
        nextState = 'LEARNING';
      }

      await db.update(
        'flashcards',
        {
          'repetitions': reps,
          'success_streak': 0,
          'interval': 1,
          'wrong_count': wrongCount,
          'boss_level': bossLevel,
          'learning_state': nextState,
          'is_mastered': 0,
          'last_reviewed_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [cardId],
      );
    }
  }

  /// Boss savaşı kaybedildiğinde soğuma süresi (Cooldown) uygular
  Future<void> recordBossFailureCooldown(int cardId) async {
    final db = await database;
    // Kullanıcıyı hemen boğmamak için 2 saat soğuma verilir
    final cooldownTime = DateTime.now().add(const Duration(hours: 2)).toIso8601String();
    await db.update(
      'flashcards',
      {
        'cooldown_until': cooldownTime,
        'last_reviewed_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [cardId],
    );
  }

  /// Geriye dönük uyumluluk için standart SRS metodu
  Future<void> recordExerciseResult({
    required int cardId,
    required bool isCorrect,
  }) async {
    await recordMultiModalResult(cardId: cardId, isCorrect: isCorrect, mode: 'srs');
  }

  Future<void> updateFlashcardSrsProgress({
    required int cardId,
    required int repetitions,
    required int interval,
    bool isMastered = false,
  }) async {
    final db = await database;
    final String state = isMastered ? 'MASTERED' : (repetitions >= 3 ? 'REVIEWING' : 'LEARNING');
    await db.update(
      'flashcards',
      {
        'repetitions': repetitions,
        'interval': interval,
        'is_mastered': isMastered ? 1 : 0,
        'learning_state': state,
      },
      where: 'id = ?',
      whereArgs: [cardId],
    );
  }
}