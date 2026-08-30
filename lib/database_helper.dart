// ============================================================================
// DOSYA ADI: lib/database_helper.dart
// AÇIKLAMA: SQLite Veritabanı Yöneticisi (Vocabulary Learning States Entegreli)
// GÖREVLER & DÜZELTMELER:
//   1. Versiyon 12: 'learning_state' ve 'success_streak' alanları eklendi.
//   2. 5 Aşamalı Durum Mimarisi: DISCOVERED -> LEARNING -> REVIEWING -> FAMILIAR -> MASTERED.
//   3. Sıfır Veri Kaybı: Eski 'is_mastered' ve 'repetitions' verileriyle tam uyum.
//   4. İndeksleme: 'learning_state' için B-Tree indeksi ile ultra hızlı filtreleme.
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
      version: 12, // Yeni sütunlar ve indeksler için Versiyon 12'ye yükseltildi
      onCreate: _createDB,
      onUpgrade: _onUpgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // ------------------------------------------------------------------------
    // 1. SÖZLÜK TABLOSU (Çevrimdışı Sözlük Havuzu)
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
    // 2. GELİŞMİŞ FLASHCARD & KELİME TAKİP TABLOSU
    // 'learning_state': DISCOVERED, LEARNING, REVIEWING, FAMILIAR, MASTERED
    // 'success_streak': Durum yükseltme/düşürme için ardışık doğru cevap sayısı
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
        context_sentence TEXT,
        book_title TEXT,
        chapter_info TEXT
      )
    ''');

    // Hızlı sorgulama ve filtreleme indeksleri
    await db.execute('CREATE INDEX idx_flashcards_word ON flashcards(word COLLATE NOCASE)');
    await db.execute('CREATE INDEX idx_flashcards_mastered ON flashcards(is_mastered)');
    await db.execute('CREATE INDEX idx_flashcards_state ON flashcards(learning_state)');
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
    // Geriye dönük yükseltmelerde veri kaybını engellemek için try-catch ile korunur
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

    // SÜRÜM 12 GÜNCELLEMESİ: Vocabulary Learning State Entegrasyonu
    if (oldVersion < 12) {
      try {
        // Yeni öğrenme durumu ve ardışık başarı serisi sütunları eklenir
        await db.execute("ALTER TABLE flashcards ADD COLUMN learning_state TEXT DEFAULT 'LEARNING'");
        await db.execute("ALTER TABLE flashcards ADD COLUMN success_streak INTEGER DEFAULT 0");

        // Mevcut ustalara (is_mastered = 1) sahip olanların durumunu otomatik MASTERED yap
        await db.execute("UPDATE flashcards SET learning_state = 'MASTERED' WHERE is_mastered = 1");

        // Yeni durum filtresi için B-Tree indeksi oluştur
        await db.execute('CREATE INDEX IF NOT EXISTS idx_flashcards_state ON flashcards(learning_state)');
      } catch (e) {
        // Olası migration hatalarında loglama
        // ignore: avoid_print
        print('DB Upgrade v12 Error: $e');
      }
    }
  }

  Future<void> _insertInitialWords(Database db) async {
    final sampleWords = [
      {'word': 'Habit', 'meaning': 'Alışkanlık', 'pos': 'noun', 'phonetic': '/ˈhæb.ɪt/', 'example': 'Good habits make time your ally.'},
      {'word': 'Improve', 'meaning': 'Geliştirmek, iyileştirmek', 'pos': 'verb', 'phonetic': '/ɪmˈpruːv/', 'example': 'Read every day to improve yourself.'},
    ];

    for (var item in sampleWords) {
      await db.insert('dictionary', item, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ==========================================================================
  // SÖZLÜK METOTLARI
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
  // FLASHCARD & KELİME DURUM METOTLARI
  // ==========================================================================

  Future<bool> isWordInFlashcards(String word) async {
    final db = await database;
    final clean = word.trim().toLowerCase();
    final result = await db.query('flashcards', where: 'word = ? COLLATE NOCASE', whereArgs: [clean], limit: 1);
    return result.isNotEmpty;
  }

  /// Kelime ilk defa incelendiğinde veya desteye eklendiğinde çağrılır
  Future<int> addFlashcard(
    String word, 
    String meaning, {
    String? contextSentence,
    String? bookTitle,
    String? chapterInfo,
    String learningState = 'LEARNING', // Varsayılan durum
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
        'context_sentence': contextSentence?.trim(),
        'book_title': bookTitle?.trim(),
        'chapter_info': chapterInfo?.trim(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Kitapta bir kelimeye dokunulduğunda 'DISCOVERED' olarak kaydeder
  Future<int> discoverWord({
    required String word,
    required String meaning,
    String? contextSentence,
    String? bookTitle,
  }) async {
    final db = await database;
    final clean = word.trim();
    
    // Zaten ekliyse durumunu bozma
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

  /// Durumu DISCOVERED olan kelimeyi öğrenme havuzuna (LEARNING) geçirir
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

  /// Sadece aktif pratik yapılacak kartları çeker (DISCOVERED olanlar egzersiz havuzuna girmez)
  Future<List<Map<String, dynamic>>> getActivePracticeCards() async {
    final db = await database;
    return await db.query(
      'flashcards',
      where: "learning_state != 'DISCOVERED'",
      orderBy: 'id DESC',
    );
  }

  /// Belirli bir duruma göre filtrelenmiş kartları getirir
  Future<List<Map<String, dynamic>>> getCardsByState(String stateKey) async {
    final db = await database;
    return await db.query(
      'flashcards',
      where: 'learning_state = ?',
      whereArgs: [stateKey],
      orderBy: 'id DESC',
    );
  }

  Future<int> deleteFlashcard(int id) async {
    final db = await database;
    return await db.delete('flashcards', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================================================
  // HIZLI SAYAÇ & İSTATİSTİK METOTLARI (Bellek Dostu COUNT Sorguları)
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
  // GELİŞMİŞ SRS & LEARNING STATE HESAPLAMA VE GÜNCELLEME
  // ==========================================================================

  /// Egzersiz sonucuna göre kartın durumunu (State), serisini (Streak) ve aralığını (Interval) günceller
  Future<void> recordExerciseResult({
    required int cardId,
    required bool isCorrect,
  }) async {
    final db = await database;
    
    // Mevcut kart verisini oku
    final list = await db.query('flashcards', where: 'id = ?', whereArgs: [cardId], limit: 1);
    if (list.isEmpty) return;

    final card = list.first;
    int currentRepetitions = card['repetitions'] as int? ?? 0;
    int currentStreak = card['success_streak'] as int? ?? 0;
    int currentInterval = card['interval'] as int? ?? 1;

    String nextState;
    int newStreak;
    int newRepetitions;
    int newInterval;

    if (isCorrect) {
      newStreak = currentStreak + 1;
      newRepetitions = currentRepetitions + 1;
      newInterval = (currentInterval * 1.8).round().clamp(1, 365);

      // Başarı eşiklerine göre aşamalı yükselme
      if (newStreak >= 6) {
        nextState = 'MASTERED';
      } else if (newStreak >= 4) {
        nextState = 'FAMILIAR';
      } else if (newStreak >= 2) {
        nextState = 'REVIEWING';
      } else {
        nextState = 'LEARNING';
      }
    } else {
      // Hatalı cevapta streak sıfırlanır ve durum bir basamak geriler
      newStreak = 0;
      newRepetitions = currentRepetitions + 1;
      newInterval = 1; // Unutulduğu için aralık başa döner

      if (card['learning_state'] == 'MASTERED' || card['learning_state'] == 'FAMILIAR') {
        nextState = 'REVIEWING'; // Usta veya Aşina ise Tekrara düşer
      } else {
        nextState = 'LEARNING'; // Diğer durumlarda Öğreniliyor'a döner
      }
    }

    final bool isMasteredFlag = nextState == 'MASTERED';

    await db.update(
      'flashcards',
      {
        'repetitions': newRepetitions,
        'success_streak': newStreak,
        'interval': newInterval,
        'learning_state': nextState,
        'is_mastered': isMasteredFlag ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [cardId],
    );
  }

  /// Klasik SRS metodunu geriye dönük uyumluluk için korur
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