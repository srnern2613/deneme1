// ============================================================================
// DOSYA ADI: lib/database_helper.dart
// AÇIKLAMA: Eksik Tablo (cacheObject, highlights) Güvenceli SQLite Yöneticisi
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
      version: 7, // Tüm eksik tabloların oluşturulması için sürüm 7'ye yükseltildi
      onCreate: _createDB,
      onUpgrade: _onUpgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE dictionary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL COLLATE NOCASE,
        meaning TEXT NOT NULL,
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
        repetitions INTEGER DEFAULT 0
      )
    ''');

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

    // Hata Logundaki 'no such table: cacheObject' sorununu çözen eksik tablo
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cacheObject (
        key TEXT PRIMARY KEY,
        value TEXT,
        expiry_date TEXT
      )
    ''');

    final sampleWords = [
      {'word': 'Habit', 'meaning': 'Alışkanlık', 'example': 'Good habits make time your ally.'},
      {'word': 'Improve', 'meaning': 'Geliştirmek', 'example': 'Read every day to improve yourself.'},
    ];

    for (var item in sampleWords) {
      await db.insert('dictionary', item);
    }
  }

  Future _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    // Sürüm ne olursa olsun eksik tabloları güvenle oluşturur (Crash önleyici)
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
  }

  // --- HIGHLIGHT İŞLEMLERİ ---

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

  // Standart Sözlük ve Flashcard Metotları
  Future<Map<String, dynamic>?> getWordDefinition(String word) async {
    final db = await database;
    final clean = word.trim().toLowerCase();
    final result = await db.query('dictionary', where: 'word = ? COLLATE NOCASE', whereArgs: [clean], limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> searchWord(String query) async {
    final db = await database;
    return await db.query('dictionary', where: 'word LIKE ? OR meaning LIKE ?', whereArgs: ['%$query%', '%$query%'], limit: 20);
  }

  Future<bool> isWordInFlashcards(String word) async {
    final db = await database;
    final clean = word.trim().toLowerCase();
    final result = await db.query('flashcards', where: 'word = ? COLLATE NOCASE', whereArgs: [clean], limit: 1);
    return result.isNotEmpty;
  }

  Future<int> addFlashcard(String word, String meaning) async {
    final db = await database;
    return await db.insert('flashcards', {'word': word.trim(), 'meaning': meaning.trim(), 'interval': 1, 'repetitions': 0});
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
}