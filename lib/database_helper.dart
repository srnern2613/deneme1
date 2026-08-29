// ============================================================================
// DOSYA ADI: lib/database_helper.dart
// AÇIKLAMA: SQLite Veritabanı Yöneticisi
//           - Çevrimdışı 20.000 Kelimelik Sözlük Destekli (POS & Phonetic)
//           - Flashcard, Highlight ve SRS Şemaları
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
      version: 9,
      onCreate: _createDB,
      onUpgrade: _onUpgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. GENİŞLETİLMİŞ SÖZLÜK TABLOSU
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

    // 2. GELİŞMİŞ FLASHCARD TABLOSU (Bağlam & Kitap Destekli)
    await db.execute('''
      CREATE TABLE flashcards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL COLLATE NOCASE,
        meaning TEXT NOT NULL,
        interval INTEGER DEFAULT 1,
        repetitions INTEGER DEFAULT 0,
        context_sentence TEXT,
        book_title TEXT,
        chapter_info TEXT
      )
    ''');

    // 3. FOSFORLU KALEM (HIGHLIGHTS) TABLOSU
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

    // 4. ÖNBELLEK TABLOSU
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS highlights (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT NOT NULL,
        page_index INTEGER NOT NULL,
        start_word_index INTEGER NOT NULL,
        end_word_index INTEGER NOT NULL,
        color_tag TEXT DEFAULT 'yellow'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cacheObject (
        key TEXT PRIMARY KEY,
        value TEXT,
        expiry_date TEXT
      )
    ''');

    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE flashcards ADD COLUMN context_sentence TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE flashcards ADD COLUMN book_title TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE flashcards ADD COLUMN chapter_info TEXT');
      } catch (_) {}
    }

    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE dictionary ADD COLUMN pos TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE dictionary ADD COLUMN phonetic TEXT');
      } catch (_) {}
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

  // --- SÖZLÜK METOTLARI ---

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

  // --- HIGHLIGHT METOTLARI ---

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

  // --- FLASHCARD METOTLARI ---

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
  }) async {
    final db = await database;
    return await db.insert(
      'flashcards',
      {
        'word': word.trim(),
        'meaning': meaning.trim(),
        'interval': 1,
        'repetitions': 0,
        'context_sentence': contextSentence?.trim(),
        'book_title': bookTitle?.trim(),
        'chapter_info': chapterInfo?.trim(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
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

  Future<int> deleteFlashcard(int id) async {
    final db = await database;
    return await db.delete('flashcards', where: 'id = ?', whereArgs: [id]);
  }

  // --- SRS METODU ---

  Future<void> updateFlashcardSrsProgress({
    required int cardId,
    required int repetitions,
    required int interval,
  }) async {
    final db = await database;
    await db.update(
      'flashcards',
      {
        'repetitions': repetitions,
        'interval': interval,
      },
      where: 'id = ?',
      whereArgs: [cardId],
    );
  }
}