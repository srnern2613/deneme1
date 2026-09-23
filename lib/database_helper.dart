// ============================================================================
// DOSYA ADI: lib/database_helper.dart
// AÇIKLAMA: SQLite Veritabanı Yöneticisi (Mükerrer Kayıt Korumalı Flashcards v17)
// AŞAMA 0: flashcards.uuid/updated_at + daily_stats tablosu (Ignis Anları'nın
// yakıtı). Hesap sistemi ertelendi ama uuid/updated_at kapıyı açık tutuyor.
// ============================================================================

import 'dart:math';
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
      version: 17,
      onCreate: _createDB,
      onUpgrade: _onUpgradeDB,
    );
  }

  /// RFC 4122 benzeri v4 UUID üretir. Harici paket eklemeden (uuid
  /// bağımlılığı yerine dart:math ile) — cihazdan bağımsız kalıcı kimlik.
  String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int start, int end) =>
        bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  /// AŞAMA 0 / AŞAMA 2: günlük istatistik satırını artımlı olarak günceller
  /// (yoksa oluşturur). Ignis Anları ve "bugün X kelime öğrendin" gibi
  /// projeksiyonların tek veri kaynağı burasıdır.
  Future<void> _touchDailyStat({
    required String mode,
    int newWords = 0,
    int reviews = 0,
    int correct = 0,
    int wrong = 0,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final existing = await db.query(
      'daily_stats',
      where: 'stat_date = ? AND mode = ?',
      whereArgs: [dateStr, mode],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert('daily_stats', {
        'stat_date': dateStr,
        'mode': mode,
        'new_words_count': newWords,
        'review_count': reviews,
        'correct_count': correct,
        'wrong_count': wrong,
      });
    } else {
      final row = existing.first;
      await db.update(
        'daily_stats',
        {
          'new_words_count': (row['new_words_count'] as int? ?? 0) + newWords,
          'review_count': (row['review_count'] as int? ?? 0) + reviews,
          'correct_count': (row['correct_count'] as int? ?? 0) + correct,
          'wrong_count': (row['wrong_count'] as int? ?? 0) + wrong,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future _createDB(Database db, int version) async {
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
        chapter_info TEXT,
        fsrs_stability REAL,
        fsrs_difficulty REAL,
        fsrs_due_at TEXT,
        fsrs_state INTEGER DEFAULT 0,
        fsrs_reps INTEGER DEFAULT 0,
        fsrs_lapses INTEGER DEFAULT 0,
        fsrs_last_reviewed_at TEXT,
        uuid TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('CREATE UNIQUE INDEX idx_flashcards_unique_word ON flashcards(word COLLATE NOCASE)');
    await db.execute('CREATE INDEX idx_flashcards_mastered ON flashcards(is_mastered)');
    await db.execute('CREATE INDEX idx_flashcards_state ON flashcards(learning_state)');
    await db.execute('CREATE INDEX idx_flashcards_boss ON flashcards(boss_level)');
    await db.execute('CREATE INDEX idx_flashcards_book ON flashcards(book_title COLLATE NOCASE)');
    await db.execute('CREATE INDEX idx_flashcards_repetitions ON flashcards(repetitions)');

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

    await db.execute('''
      CREATE TABLE book_progress (
        book_id TEXT PRIMARY KEY,
        book_title TEXT NOT NULL COLLATE NOCASE,
        current_page INTEGER DEFAULT 0,
        total_pages INTEGER DEFAULT 1,
        last_chapter TEXT,
        total_read_seconds INTEGER DEFAULT 0,
        last_read_at TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_book_progress_title ON book_progress(book_title COLLATE NOCASE)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cacheObject (
        key TEXT PRIMARY KEY,
        value TEXT,
        expiry_date TEXT
      )
    ''');

    // AŞAMA 0: günlük istatistik — Ignis Anları'nın yakıtı. Kelime verisi
    // eskiden yalnızca kümülatifti; bu tablo tarihe göre kırılım sağlıyor.
    await db.execute('''
      CREATE TABLE daily_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stat_date TEXT NOT NULL,
        mode TEXT NOT NULL,
        new_words_count INTEGER DEFAULT 0,
        review_count INTEGER DEFAULT 0,
        correct_count INTEGER DEFAULT 0,
        wrong_count INTEGER DEFAULT 0,
        UNIQUE(stat_date, mode)
      )
    ''');

    await db.execute('CREATE INDEX idx_daily_stats_date ON daily_stats(stat_date)');

    await _insertInitialWords(db);
  }

  Future _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 15) {
      try {
        await db.execute('''
          DELETE FROM flashcards
          WHERE id NOT IN (
            SELECT MAX(id)
            FROM flashcards
            GROUP BY word COLLATE NOCASE
          )
        ''');
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_flashcards_unique_word ON flashcards(word COLLATE NOCASE)');
      } catch (_) {}
    }
    if (oldVersion < 16) {
      // EJDERHA ROTASI V2 — FAZ 3: FSRS kolonları eklendi. Mevcut kartlar
      // için bu alanlar NULL/0 kalır — FsrsRepository bunu "hiç
      // incelenmemiş, hemen vadesi gelmiş" (cold start) olarak okur, hata
      // fırlatmaz. Eski sabit-aralıklı sistemin kolonlarına dokunulmadı.
      for (final stmt in [
        "ALTER TABLE flashcards ADD COLUMN fsrs_stability REAL",
        "ALTER TABLE flashcards ADD COLUMN fsrs_difficulty REAL",
        "ALTER TABLE flashcards ADD COLUMN fsrs_due_at TEXT",
        "ALTER TABLE flashcards ADD COLUMN fsrs_state INTEGER DEFAULT 0",
        "ALTER TABLE flashcards ADD COLUMN fsrs_reps INTEGER DEFAULT 0",
        "ALTER TABLE flashcards ADD COLUMN fsrs_lapses INTEGER DEFAULT 0",
        "ALTER TABLE flashcards ADD COLUMN fsrs_last_reviewed_at TEXT",
      ]) {
        try {
          await db.execute(stmt);
        } catch (_) {
          // Kolon zaten varsa (ör. tekrar eden upgrade denemesi) sessizce geç.
        }
      }
    }
    if (oldVersion < 17) {
      // AŞAMA 0 — Veri modeli temeli (tek migrasyon, bkz.
      // docs/yayin_oncesi_kontrol_listesi.md). uuid/updated_at ileride hesap
      // sistemi gelirse zorunlu; daily_stats Ignis Anları'nın veri kaynağı.
      for (final stmt in [
        "ALTER TABLE flashcards ADD COLUMN uuid TEXT",
        "ALTER TABLE flashcards ADD COLUMN updated_at TEXT",
      ]) {
        try {
          await db.execute(stmt);
        } catch (_) {
          // Kolon zaten varsa sessizce geç.
        }
      }

      // Mevcut kartlara geriye dönük uuid/updated_at ata. Tek seferlik
      // maliyet — kullanıcı tabanı küçük, kart sayısı da öyle.
      try {
        final existingRows = await db.query('flashcards', columns: ['id']);
        final nowIso = DateTime.now().toIso8601String();
        for (final row in existingRows) {
          final id = row['id'] as int;
          await db.update(
            'flashcards',
            {'uuid': _generateUuidV4(), 'updated_at': nowIso},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      } catch (_) {
        // Geriye dönük doldurma başarısız olsa bile uygulama çalışmaya devam
        // etmeli; uuid null kalan satırlar bir sonraki yazmada doldurulur.
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS daily_stats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stat_date TEXT NOT NULL,
            mode TEXT NOT NULL,
            new_words_count INTEGER DEFAULT 0,
            review_count INTEGER DEFAULT 0,
            correct_count INTEGER DEFAULT 0,
            wrong_count INTEGER DEFAULT 0,
            UNIQUE(stat_date, mode)
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_daily_stats_date ON daily_stats(stat_date)');
      } catch (_) {
        // Tablo zaten varsa (ör. tekrar eden upgrade denemesi) sessizce geç.
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

  Future<List<String>> getDistractorMeanings({
    required String correctWord,
    required String correctMeaning,
    int count = 3,
  }) async {
    final db = await database;
    
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

    final fallbackList = ['Sonuç, netice', 'Geliştirmek', 'Keşfetmek', 'Hatırlamak', 'Önemli, mühim'];
    for (var fb in fallbackList) {
      if (distractors.length >= count) break;
      if (fb != correctMeaning.trim()) {
        distractors.add(fb);
      }
    }

    return distractors.take(count).toList();
  }

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

  Future<bool> isWordInFlashcards(String word) async {
    final db = await database;
    final clean = word.trim();
    final result = await db.query(
      'flashcards', 
      where: "word = ? COLLATE NOCASE AND learning_state != 'DISCOVERED'", 
      whereArgs: [clean], 
      limit: 1,
    );
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
    final clean = word.trim();
    bool insertedNewActiveWord = false;

    final resultId = await db.transaction((txn) async {
      final existing = await txn.query(
        'flashcards',
        where: 'word = ? COLLATE NOCASE',
        whereArgs: [clean],
      );

      final nowIso = DateTime.now().toIso8601String();

      if (existing.isNotEmpty) {
        final firstId = existing.first['id'] as int;

        if (existing.length > 1) {
          for (int i = 1; i < existing.length; i++) {
            await txn.delete('flashcards', where: 'id = ?', whereArgs: [existing[i]['id']]);
          }
        }

        await txn.update(
          'flashcards',
          {
            if (meaning.trim().isNotEmpty && meaning.trim() != 'kelime anlamı') 'meaning': meaning.trim(),
            'learning_state': learningState,
            'is_mastered': learningState == 'MASTERED' ? 1 : 0,
            if (contextSentence != null && contextSentence.trim().isNotEmpty) 'context_sentence': contextSentence.trim(),
            if (bookTitle != null && bookTitle.trim().isNotEmpty) 'book_title': bookTitle.trim(),
            if (chapterInfo != null && chapterInfo.trim().isNotEmpty) 'chapter_info': chapterInfo.trim(),
            'updated_at': nowIso,
          },
          where: 'id = ?',
          whereArgs: [firstId],
        );
        return firstId;
      }

      final newId = await txn.insert(
        'flashcards',
        {
          'word': clean,
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
          'uuid': _generateUuidV4(),
          'updated_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // AŞAMA 0/2: yeni bir kart pratik havuzuna gerçekten girdiğinde
      // (DISCOVERED değil) günlük istatistiğe "yeni kelime" olarak işlensin.
      // NOT: _touchDailyStat burada DEĞİL, transaction bittikten SONRA
      // çağrılır — aynı bağlantı üzerinden txn içindeyken txn dışı bir
      // db.query/update çağırmak sqflite'ı kilitler (deadlock riski).
      if (learningState != 'DISCOVERED') {
        insertedNewActiveWord = true;
      }

      return newId;
    });

    if (insertedNewActiveWord) {
      await _touchDailyStat(mode: 'new_word', newWords: 1);
    }

    return resultId;
  }

  Future<int> discoverWord({
    required String word,
    required String meaning,
    String? contextSentence,
    String? bookTitle,
  }) async {
    final db = await database;
    final clean = word.trim();
    
    return await db.transaction((txn) async {
      final existing = await txn.query(
        'flashcards',
        where: 'word = ? COLLATE NOCASE',
        whereArgs: [clean],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        return existing.first['id'] as int;
      }

      return await txn.insert(
        'flashcards',
        {
          'word': clean,
          'meaning': meaning.trim(),
          'interval': 1,
          'repetitions': 0,
          'is_mastered': 0,
          'learning_state': 'DISCOVERED',
          'success_streak': 0,
          'wrong_count': 0,
          'boss_level': 0,
          'modes_passed': '',
          'distinct_days_count': 0,
          'context_sentence': contextSentence?.trim(),
          'book_title': bookTitle?.trim(),
          'uuid': _generateUuidV4(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    });
  }

  Future<void> promoteToLearning(String word) async {
    final db = await database;
    final rowsAffected = await db.update(
      'flashcards',
      {'learning_state': 'LEARNING', 'updated_at': DateTime.now().toIso8601String()},
      where: "word = ? COLLATE NOCASE AND learning_state = 'DISCOVERED'",
      whereArgs: [word.trim()],
    );
    // AŞAMA 0/2: DISCOVERED → LEARNING geçişi gerçek anlamda "kelime
    // öğrenmeye başladı" anı — günlük istatistiğe yeni kelime olarak yazılır.
    if (rowsAffected > 0) {
      await _touchDailyStat(mode: 'new_word', newWords: 1);
    }
  }

  Future<int> demoteToDiscovered(String word) async {
    final db = await database;
    return await db.update(
      'flashcards',
      {
        'learning_state': 'DISCOVERED',
        'is_mastered': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'word = ? COLLATE NOCASE',
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

  Future<void> updateBookReadingProgress({
    required String bookId,
    required String bookTitle,
    required int currentPage,
    required int totalPages,
    String? chapterInfo,
    int additionalSeconds = 0,
  }) async {
    final db = await database;
    final safeTotalPages = totalPages <= 0 ? 1 : totalPages;
    final safeCurrentPage = currentPage.clamp(0, safeTotalPages);
    final nowIso = DateTime.now().toIso8601String();

    final existing = await db.query(
      'book_progress',
      columns: ['total_read_seconds'],
      where: 'book_id = ?',
      whereArgs: [bookId],
      limit: 1,
    );

    int currentSeconds = 0;
    if (existing.isNotEmpty) {
      currentSeconds = existing.first['total_read_seconds'] as int? ?? 0;
    }

    final newTotalSeconds = currentSeconds + (additionalSeconds > 0 ? additionalSeconds : 0);

    await db.insert(
      'book_progress',
      {
        'book_id': bookId,
        'book_title': bookTitle.trim(),
        'current_page': safeCurrentPage,
        'total_pages': safeTotalPages,
        'last_chapter': chapterInfo?.trim(),
        'total_read_seconds': newTotalSeconds,
        'last_read_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteBookProgress(String bookId) async {
    final db = await database;
    await db.delete('book_progress', where: 'book_id = ?', whereArgs: [bookId]);
  }

  /// Ayarlar → Veri Yönetimi → "İlerlemeyi Sıfırla". Kullanıcının ÖĞRENME
  /// İLERLEMESİNİ siler: öğrenilen kelimeler (flashcards), vurgulamalar,
  /// kitap okuma ilerlemesi, günlük istatistikler. BİLEREK silmediklerimiz:
  /// `dictionary` (statik kelime tanımları — kullanıcı verisi değil, referans
  /// veri) ve `cacheObject` (ilgisiz bir önbellek tablosu). Bu, "mevcut
  /// sistemleri bozma" kuralı gereği yalnızca gerçekten "ilerleme" sayılan
  /// tabloları hedefliyor.
  Future<void> resetAllProgress() async {
    final db = await database;
    await db.delete('flashcards');
    await db.delete('highlights');
    await db.delete('book_progress');
    await db.delete('daily_stats');
  }

  Future<Map<String, dynamic>> getBookJourneyData({
    required String bookTitle,
    String? bookId,
  }) async {
    final db = await database;
    final cleanTitle = bookTitle.trim();

    Map<String, dynamic>? progressRow;
    if (bookId != null && bookId.isNotEmpty) {
      final res = await db.query('book_progress', where: 'book_id = ?', whereArgs: [bookId], limit: 1);
      if (res.isNotEmpty) progressRow = res.first;
    }
    if (progressRow == null) {
      final res = await db.query('book_progress', where: 'book_title = ? COLLATE NOCASE', whereArgs: [cleanTitle], limit: 1);
      if (res.isNotEmpty) progressRow = res.first;
    }

    final int currentPage = progressRow?['current_page'] as int? ?? 0;
    final int totalPages = progressRow?['total_pages'] as int? ?? 1;
    final String lastChapter = progressRow?['last_chapter'] as String? ?? 'Bölüm 1';
    final int totalReadSec = progressRow?['total_read_seconds'] as int? ?? 0;
    final double readingRatio = totalPages > 0 ? (currentPage / totalPages).clamp(0.0, 1.0) : 0.0;

    final wordRows = await db.query(
      'flashcards',
      where: 'book_title = ? COLLATE NOCASE',
      whereArgs: [cleanTitle],
      orderBy: 'id DESC',
    );

    int discoveredCount = 0;
    int learningCount = 0;
    int reviewingCount = 0;
    int familiarCount = 0;
    int masteredCount = 0;
    int bossCount = 0;

    final List<Map<String, dynamic>> sampleWords = [];

    for (var card in wordRows) {
      final state = card['learning_state'] as String? ?? 'LEARNING';
      final bossLvl = card['boss_level'] as int? ?? 0;

      if (bossLvl > 0) bossCount++;

      switch (state) {
        case 'DISCOVERED':
          discoveredCount++;
          break;
        case 'LEARNING':
          learningCount++;
          break;
        case 'REVIEWING':
          reviewingCount++;
          break;
        case 'FAMILIAR':
          familiarCount++;
          break;
        case 'MASTERED':
          masteredCount++;
          break;
      }

      if (sampleWords.length < 8) {
        sampleWords.add(card);
      }
    }

    final int totalDiscovered = wordRows.length;

    return {
      'book_id': bookId ?? progressRow?['book_id'] ?? cleanTitle,
      'book_title': cleanTitle,
      'current_page': currentPage,
      'total_pages': totalPages,
      'reading_ratio': readingRatio,
      'reading_percentage': (readingRatio * 100).toInt(),
      'last_chapter': lastChapter,
      'total_read_seconds': totalReadSec,
      'total_words': totalDiscovered,
      'discovered_count': discoveredCount,
      'learning_count': learningCount,
      'reviewing_count': reviewingCount,
      'familiar_count': familiarCount,
      'mastered_count': masteredCount,
      'boss_count': bossCount,
      'sample_words': sampleWords,
    };
  }

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

      final modeSet = modesPassed.split(',').where((m) => m.isNotEmpty).toSet();
      modeSet.add(mode);
      modesPassed = modeSet.join(',');

      if (lastReviewStr == null || !lastReviewStr.startsWith(todayStr)) {
        distinctDays += 1;
      }

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
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [cardId],
      );
      await _touchDailyStat(mode: mode, reviews: 1, correct: 1);
    } else {
      wrongCount += 1;
      currentStreak = 0;
      currentInterval = 1;
      reps += 1;

      if (wrongCount >= 8) {
        bossLevel = 4;
      } else if (wrongCount >= 5 && mode != 'srs') {
        bossLevel = 3;
      } else if (wrongCount >= 5) {
        bossLevel = 2;
      } else if (wrongCount >= 3) {
        bossLevel = 1;
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
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [cardId],
      );
      await _touchDailyStat(mode: mode, reviews: 1, wrong: 1);
    }
  }

  Future<void> recordBossFailureCooldown(int cardId) async {
    final db = await database;
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
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [cardId],
    );
  }

  // ========================================================================
  // AŞAMA 2 — IGNIS ANLARI: yerel istatistik motorunun okuyacağı sorgular
  // ========================================================================

  /// Son [days] günün (bugün dahil) daily_stats toplamlarını tarihe göre
  /// gruplu döner. Boş günler listede yer almaz — çağıran taraf 0 varsayar.
  Future<List<Map<String, dynamic>>> getDailyStatsRange(int days) async {
    final db = await database;
    final since = DateTime.now().subtract(Duration(days: days - 1));
    final sinceStr =
        "${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}";

    return await db.rawQuery('''
      SELECT
        stat_date,
        SUM(new_words_count) AS new_words_count,
        SUM(review_count) AS review_count,
        SUM(correct_count) AS correct_count,
        SUM(wrong_count) AS wrong_count
      FROM daily_stats
      WHERE stat_date >= ?
      GROUP BY stat_date
      ORDER BY stat_date ASC
    ''', [sinceStr]);
  }

  /// Bugünün toplamı — tek satırda özet (Ana Sayfa "Günlük Durum" kartı ve
  /// seans-sonu Ignis Anı için).
  Future<Map<String, int>> getTodayStatsSummary() async {
    final db = await database;
    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(new_words_count), 0) AS new_words_count,
        COALESCE(SUM(review_count), 0) AS review_count,
        COALESCE(SUM(correct_count), 0) AS correct_count,
        COALESCE(SUM(wrong_count), 0) AS wrong_count
      FROM daily_stats
      WHERE stat_date = ?
    ''', [todayStr]);

    final row = result.isNotEmpty ? result.first : <String, Object?>{};
    return {
      'new_words_count': row['new_words_count'] as int? ?? 0,
      'review_count': row['review_count'] as int? ?? 0,
      'correct_count': row['correct_count'] as int? ?? 0,
      'wrong_count': row['wrong_count'] as int? ?? 0,
    };
  }

  /// Yarın FSRS'e göre tekrar vakti gelecek kart sayısı — bedava veri,
  /// Ignis Anları'nın "yarın seni bekleyen X kelime var" mesajı için.
  Future<int> getDueTomorrowCount() async {
    final db = await database;
    final now = DateTime.now();
    final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
    final startOfDayAfter = DateTime(now.year, now.month, now.day + 2);
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM flashcards
      WHERE fsrs_due_at IS NOT NULL AND fsrs_due_at >= ? AND fsrs_due_at < ?
    ''', [startOfTomorrow.toIso8601String(), startOfDayAfter.toIso8601String()]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Bugün tekrar vakti gelmiş (gecikmişler dahil) kart sayısı — Ana Sayfa
  /// "Tekrar Zamanı" kartı için. FSRS'in hesapladığı fsrs_due_at bugünün
  /// sonundan önce olan kartları sayar; hiç tekrar görmemiş yeni kartlar
  /// (fsrs_due_at NULL) ve henüz öğrenmeye alınmamış keşif kartları dahil değil.
  Future<int> getDueTodayCount() async {
    final db = await database;
    final now = DateTime.now();
    final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM flashcards
      WHERE fsrs_due_at IS NOT NULL
        AND fsrs_due_at < ?
        AND learning_state != 'DISCOVERED'
    ''', [startOfTomorrow.toIso8601String()]);
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
