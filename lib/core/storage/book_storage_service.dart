// ============================================================================
// DOSYA ADI: lib/core/storage/book_storage_service.dart
// AÇIKLAMA: AŞAMA 1 — Android Auto Backup 25 MB kotası koruması.
//
// SORUN: Book.toJson() 'pages' alanını (kitabın TÜM sayfa metnini) içeriyor
// ve bu, doğrudan SharedPreferences'a ('saved_books' anahtarı) yazılıyordu.
// Birkaç kitap kolayca 25 MB'lık Android Auto Backup kotasını aşar; kota
// aşılınca sistem KISMİ yedek almaz, o anda kelime/XP/seri yedeklemesi de
// sessizce durur (onQuotaExceeded).
//
// ÇÖZÜM: Sayfa metnini ayrı bir SQLite dosyasında (book_content.db) tut.
// Bu dosya AndroidManifest'teki dataExtractionRules ile yedekten HARİÇ
// tutulacak (bkz. android/app/src/main/res/xml/data_extraction_rules.xml).
// Kitap künyesi (başlık, yazar, seviye, ikon, ilerleme) küçük kaldığından
// SharedPreferences'ta kalır ve normal şekilde yedeklenir.
//
// KABUL EDİLEN SINIR: Yedekten geri yüklemede kitabın METNİ gelmez (kullanıcı
// kitabı yeniden açar/indirir); ama kelime ilerlemesi (flashcards, XP, seri)
// kaybolmaz. Bu, hedeflenen korumanın tam kapsamı.
//
// GERİYE DÖNÜK TAŞIMA: loadBooks() eski sürümden kalan (hâlâ 'pages' içeren)
// kayıtları otomatik tespit edip book_content.db'ye taşır ve SharedPreferences
// kaydını hafif haliyle geri yazar — ayrı bir migration adımı gerekmez.
// ============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../../book_model.dart';

class BookStorageService {
  static const String _prefsKey = 'saved_books';
  static Database? _contentDb;

  static Future<Database> get _db async {
    if (_contentDb != null) return _contentDb!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'book_content.db');
    _contentDb = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE book_pages (
            book_id TEXT PRIMARY KEY,
            pages_json TEXT NOT NULL
          )
        ''');
      },
    );
    return _contentDb!;
  }

  static Future<void> _savePages(String bookId, List<String> pages) async {
    final db = await _db;
    await db.insert(
      'book_pages',
      {'book_id': bookId, 'pages_json': json.encode(pages)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<String>> _loadPages(String bookId) async {
    final db = await _db;
    final rows = await db.query(
      'book_pages',
      columns: ['pages_json'],
      where: 'book_id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (rows.isEmpty) return [];
    final raw = rows.first['pages_json'] as String? ?? '[]';
    try {
      return (json.decode(raw) as List<dynamic>).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Bir kitap kalıcı olarak silinirken (kütüphaneden kaldırma) çağrılmalı,
  /// aksi halde book_content.db'de yetim satır birikir.
  static Future<void> deletePages(String bookId) async {
    final db = await _db;
    await db.delete('book_pages', where: 'book_id = ?', whereArgs: [bookId]);
  }

  /// Tüm kitapları yükler: künye SharedPreferences'tan, sayfa metni
  /// book_content.db'den geliyor — dönen Book nesnesi eskisi gibi tam dolu,
  /// çağıran taraf (library_screen.dart, main.dart) hiçbir şey fark etmez.
  static Future<List<Book>> loadBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_prefsKey) ?? [];
    final List<Book> books = [];
    bool needsRewrite = false;

    for (final raw in rawList) {
      try {
        final map = json.decode(raw) as Map<String, dynamic>;
        // Eski sürümden kalan kayıtlarda 'pages' hâlâ dolu olabilir —
        // varsa bunu tek seferlik geriye dönük taşıma için kullan.
        final legacyPages = (map['pages'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];

        final meta = Book.fromMap(map);
        List<String> pages = await _loadPages(meta.id);

        if (pages.isEmpty && legacyPages.isNotEmpty) {
          await _savePages(meta.id, legacyPages);
          pages = legacyPages;
          needsRewrite = true;
        }

        books.add(Book(
          id: meta.id,
          title: meta.title,
          author: meta.author,
          level: meta.level,
          icon: meta.icon,
          pages: pages,
          currentPage: meta.currentPage,
          lastReadDate: meta.lastReadDate,
          totalReadSeconds: meta.totalReadSeconds,
        ));
      } catch (_) {
        // Bozuk tek bir kayıt yüzünden tüm kitaplığı kaybetme.
      }
    }

    if (needsRewrite) {
      // Sayfalar zaten book_content.db'ye yazıldı; SharedPreferences
      // kaydını hafif haliyle geri yaz (bir daha taşımaya gerek kalmasın).
      await saveBooks(books);
    }

    return books;
  }

  /// Tüm kitap listesini kaydeder: sayfa metinleri book_content.db'ye,
  /// hafif künye SharedPreferences'a ('pages' alanı boş liste olarak gider).
  static Future<void> saveBooks(List<Book> books) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> lightList = [];

    for (final book in books) {
      await _savePages(book.id, book.pages);

      final lightMap = book.toMap();
      lightMap['pages'] = const <String>[];
      lightList.add(json.encode(lightMap));
    }

    await prefs.setStringList(_prefsKey, lightList);
  }
}
