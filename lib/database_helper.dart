// ==============================================================
// database_helper.dart
// --------------------------------------------------------------
// SQLite VERİTABANI YÖNETİCİSİ (SINGLETON PATTERN)
// Bu dosya hem dahili sözlük tablosunu hem de kullanıcının kişisel
// kelime kartlarını (Flashcards) telefonun hafızasında saklar.
// ==============================================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // Singleton yapısı: Uygulama boyunca tek bir veritabanı nesnesi kullanılır.
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Veritabanına erişim noktası
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app_database.db');
    return _database!;
  }

  // Veritabanı dosyasını cihazda oluşturma
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  // İlk açılışta tabloları oluşturma ve başlangıç kelimelerini yükleme
  Future _createDB(Database db, int version) async {
    // 1. Sözlük Tablosu
    await db.execute('''
      CREATE TABLE dictionary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        meaning TEXT NOT NULL,
        example TEXT
      )
    ''');

    // 2. Flashcard (Kullanıcının Kelime Kartları) Tablosu
    await db.execute('''
      CREATE TABLE flashcards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        meaning TEXT NOT NULL,
        interval INTEGER DEFAULT 1,
        repetitions INTEGER DEFAULT 0
      )
    ''');

    // Başlangıç için örnek 10 sözlük kelimesi ekleyelim
    final sampleWords = [
      {'word': 'Habit', 'meaning': 'Alışkanlık', 'example': 'Good habits make time your ally.'},
      {'word': 'Improve', 'meaning': 'Geliştirmek', 'example': 'Read every day to improve yourself.'},
      {'word': 'Discipline', 'meaning': 'Disiplin', 'example': 'Discipline equals freedom.'},
      {'word': 'Growth', 'meaning': 'Büyüme / Gelişim', 'example': 'Personal growth takes patience.'},
      {'word': 'Achieve', 'meaning': 'Başarmak / Elde etmek', 'example': 'Set goals to achieve your dreams.'},
      {'word': 'Knowledge', 'meaning': 'Bilgi', 'example': 'Knowledge is power.'},
      {'word': 'Focus', 'meaning': 'Odaklanmak', 'example': 'Stay focused on your daily goals.'},
      {'word': 'Progress', 'meaning': 'İlerleme', 'example': 'Focus on progress, not perfection.'},
      {'word': 'Challenge', 'meaning': 'Meydan okuma / Zorluk', 'example': 'Embrace every challenge.'},
      {'word': 'Consistency', 'meaning': 'Tutarlılık / Devamlılık', 'example': 'Consistency is key to success.'},
    ];

    for (var item in sampleWords) {
      await db.insert('dictionary', item);
    }
  }

  // --- SÖZLÜK FONKSİYONLARI ---
  Future<List<Map<String, dynamic>>> searchWord(String query) async {
    final db = await instance.database;
    return await db.query(
      'dictionary',
      where: 'word LIKE ? OR meaning LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      limit: 20,
    );
  }

  // --- FLASHCARD FONKSİYONLARI ---
  Future<int> addFlashcard(String word, String meaning) async {
    final db = await instance.database;
    return await db.insert('flashcards', {
      'word': word,
      'meaning': meaning,
      'interval': 1,
      'repetitions': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getFlashcards() async {
    final db = await instance.database;
    return await db.query('flashcards', orderBy: 'id DESC');
  }

  Future<int> deleteFlashcard(int id) async {
    final db = await instance.database;
    return await db.delete('flashcards', where: 'id = ?', whereArgs: [id]);
  }
}