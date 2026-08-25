// ============================================================================
// DOSYA ADI: lib/database_helper.dart
// AÇIKLAMA: SQLite Veritabanı Yöneticisi ve Yüksek Performanslı Sözlük Motoru
//
// MİMARİ VE PERFORMANS DETAYLARI:
// 1. Singleton Deseni: Uygulama boyunca tek bir SQLite bağlantı havuzu kullanılır[cite: 2].
// 2. B-Tree İndeksleme (INDEX): `idx_dictionary_word` indeksi sayesinde on binlerce
//    kelime arasından tam eşleşen kelime O(1)/O(log N) hızında bulunur[cite: 2].
// 3. İki Yönlü Eşzamanlama: Okuyucudan doğrudan hem sözlük sorgulanır hem de
//    flashcards tablosuna tek tıkla ekleme/silme yapılır[cite: 2, 9].
// ============================================================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // Uygulama genelinde tek bir veritabanı örneği tutan Singleton yapısı[cite: 2]
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Veritabanı nesnesine güvenli erişim noktası[cite: 2]
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app_database.db');
    return _database!;
  }

  // Cihazın yerel depolama dizininde veritabanı dosyasını oluşturur/açar[cite: 2]
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // Yeni indeks yapısı için versiyon 2
      onCreate: _createDB,
      onUpgrade: _onUpgradeDB,
    );
  }

  // Veritabanı ilk kez oluşturulduğunda çalışan şema kurucu[cite: 2]
  Future _createDB(Database db, int version) async {
    // 1. Çevrimdışı Sözlük Tablosu[cite: 2]
    await db.execute('''
      CREATE TABLE dictionary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL COLLATE NOCASE,
        meaning TEXT NOT NULL,
        example TEXT
      )
    ''');

    // 2. Arama Performansı için B-Tree İndeksi (Kritik Optimizasyon)[cite: 2]
    await db.execute('''
      CREATE INDEX idx_dictionary_word ON dictionary(word COLLATE NOCASE)
    ''');

    // 3. Kullanıcının Kelime Kartları (Flashcards) Tablosu[cite: 2]
    await db.execute('''
      CREATE TABLE flashcards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL COLLATE NOCASE,
        meaning TEXT NOT NULL,
        interval INTEGER DEFAULT 1,
        repetitions INTEGER DEFAULT 0
      )
    ''');

    // Başlangıç seviyesi örnek sözlük kelimeleri[cite: 2]
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
      {'word': 'Tired', 'meaning': 'Yorgun / Bıkkın', 'example': 'Alice was beginning to get very tired.'},
      {'word': 'Consider', 'meaning': 'Düşünmek / Değerlendirmek', 'example': 'She was considering in her own mind.'},
      {'word': 'Suddenly', 'meaning': 'Aniden / Birdenbire', 'example': 'Suddenly a white rabbit ran close by her.'},
      {'word': 'Trouble', 'meaning': 'Zahmet / Dert / Sorun', 'example': 'It is not worth the trouble.'},
      {'word': 'Eclipses', 'meaning': 'Gölgede bırakmak / Tutulmak', 'example': 'In his eyes she eclipses all others.'},
    ];

    for (var item in sampleWords) {
      await db.insert('dictionary', item);
    }
  }

  // Veritabanı sürümü yükseltildiğinde çalışan geçiş (Migration) metodu
  Future _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_dictionary_word ON dictionary(word COLLATE NOCASE)
      ''');
    }
  }

  // --------------------------------------------------------------------------
  // SÖZLÜK FONKSİYONLARI (OKUYUCU VE ARAMA ENTEGRASYONU)
  // --------------------------------------------------------------------------

  // Kitapta bir kelimeye dokunulduğunda tam kelimeyi getiren sorgu[cite: 2]
  Future<Map<String, dynamic>?> getWordDefinition(String word) async {
    final db = await instance.database;
    final clean = word.trim().toLowerCase();

    final result = await db.query(
      'dictionary',
      where: 'word = ? COLLATE NOCASE',
      whereArgs: [clean],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  // Çevrimdışı Sözlük ekranındaki dinamik arama çubuğu sorgusu[cite: 2]
  Future<List<Map<String, dynamic>>> searchWord(String query) async {
    final db = await instance.database;
    return await db.query(
      'dictionary',
      where: 'word LIKE ? OR meaning LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      limit: 20,
    );
  }

  // --------------------------------------------------------------------------
  // FLASHCARD (SRS KELİME KARTLARI) FONKSİYONLARI
  // --------------------------------------------------------------------------

  // Kelimenin daha önce kaydedilip kaydedilmediğini kontrol eder[cite: 2]
  Future<bool> isWordInFlashcards(String word) async {
    final db = await instance.database;
    final clean = word.trim().toLowerCase();

    final result = await db.query(
      'flashcards',
      where: 'word = ? COLLATE NOCASE',
      whereArgs: [clean],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  // Yeni bir kelimeyi flashcards tablosuna ekler[cite: 2]
  Future<int> addFlashcard(String word, String meaning) async {
    final db = await instance.database;
    return await db.insert('flashcards', {
      'word': word.trim(),
      'meaning': meaning.trim(),
      'interval': 1,
      'repetitions': 0,
    });
  }

  // Kelimeyi kartlardan siler (Toggle desteği için)[cite: 2]
  Future<int> removeFlashcardByWord(String word) async {
    final db = await instance.database;
    return await db.delete(
      'flashcards',
      where: 'word = ? COLLATE NOCASE',
      whereArgs: [word.trim()],
    );
  }

  // Kayıtlı tüm kelime kartlarını çeker[cite: 2]
  Future<List<Map<String, dynamic>>> getFlashcards() async {
    final db = await instance.database;
    return await db.query('flashcards', orderBy: 'id DESC');
  }

  // ID üzerinden kart siler[cite: 2]
  Future<int> deleteFlashcard(int id) async {
    final db = await instance.database;
    return await db.delete('flashcards', where: 'id = ?', whereArgs: [id]);
  }
}