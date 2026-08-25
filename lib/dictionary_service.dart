// ============================================================================
// DOSYA ADI: lib/dictionary_service.dart
// AÇIKLAMA: Hibrit Çeviri Motoru (Yerel SQLite Önbellek + Açık Ücretsiz API)
//
// MİMARİ VE ÇALIŞMA MANTIĞI:
// 1. Önce Cihaz İçi Kontrol (SQLite): Dokunulan kelime yerel veritabanında varsa
//    hiç internete gitmeden 0.01 saniyede yerelden döndürülür[cite: 2].
// 2. Çevrimiçi İstek (MyMemory API): Kelime yerelde yoksa ücretsiz çeviri servisine
//    hafif bir JSON isteği atılarak Türkçe anlamı çekilir.
// 3. Otomatik SQLite Önbelleğe Alma: Çekilen yeni kelime anında SQLite `dictionary`
//    tablosuna yazılır[cite: 2]. Böylece aynı kelimeye ikinci kez tıklandığında artık
//    tamamen çevrimdışı (internetsiz) çalışır.
// 4. Çevrimdışı Hata Yönetimi: Kullanıcı internetsiz bir ortamdaysa ve kelime
//    daha önce kaydedilmemişse, UI tarafında gösterilecek `isOfflineError` bayrağı döner.
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';

// ----------------------------------------------------------------------------
// ÇEVİRİ VE SÖZLÜK SONUÇ MODELİ
// ----------------------------------------------------------------------------
class WordDefinitionResult {
  final String word;          // Sorgulanan kök kelime
  final String meaning;       // Türkçe çevirisi veya anlamı
  final String? example;      // Örnek cümle (varsa)
  final bool isFromLocalDb;   // Veri yerel SQLite'tan mı geldi?
  final bool isOfflineError;  // İnternet olmadığı için mi sonuç alınamadı?

  WordDefinitionResult({
    required this.word,
    required this.meaning,
    this.example,
    this.isFromLocalDb = false,
    this.isOfflineError = false,
  });
}

class DictionaryService {
  // Uygulama boyunca tek bir servis nesnesi üzerinden çalışması için Singleton deseni
  static final DictionaryService instance = DictionaryService._init();
  DictionaryService._init();

  // --------------------------------------------------------------------------
  // HİBRİT KELİME ANLAMI GETİRİCİSİ
  // --------------------------------------------------------------------------
  Future<WordDefinitionResult> fetchWordMeaning(String rawWord) async {
    // Kelimenin etrafındaki noktalama işaretlerini ve boşlukları temizliyoruz
    final cleanWord = rawWord.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
    if (cleanWord.isEmpty) {
      return WordDefinitionResult(
        word: rawWord,
        meaning: 'Geçersiz kelime.',
      );
    }

    // 1. AŞAMA: Yerel SQLite Veritabanında Ara (0 MB İnternet / Çevrimdışı)
    try {
      final localData = await DatabaseHelper.instance.getWordDefinition(cleanWord);
      if (localData != null) {
        return WordDefinitionResult(
          word: cleanWord,
          meaning: localData['meaning'] as String,
          example: localData['example'] as String?,
          isFromLocalDb: true,
        );
      }
    } catch (e) {
      // Yerel sorguda hata olursa API aşamasına geç
    }

    // 2. AŞAMA: Çevrimiçi Ücretsiz API'den Çek
    try {
      // MyMemory Ücretsiz Çeviri API'si (İngilizce -> Türkçe)
      final url = Uri.parse(
        'https://api.mymemory.translated.net/get?q=$cleanWord&langpair=en|tr',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String translatedText = data['responseData']?['translatedText'] ?? '';

        if (translatedText.isNotEmpty &&
            !translatedText.toLowerCase().contains('mymemory') &&
            translatedText.toLowerCase() != cleanWord) {
          
          // 3. AŞAMA: Yeni Öğrenilen Kelimeyi SQLite'a Otomatik Kaydet (Önbelleğe Al)
          final db = await DatabaseHelper.instance.database;
          await db.insert('dictionary', {
            'word': cleanWord,
            'meaning': translatedText,
            'example': 'Bağlam içi otomatik çeviri.',
          });

          return WordDefinitionResult(
            word: cleanWord,
            meaning: translatedText,
            example: null,
            isFromLocalDb: false,
          );
        }
      }
    } catch (e) {
      // Bağlantı zaman aşımı veya internet yok durumu
      return WordDefinitionResult(
        word: cleanWord,
        meaning: 'Çevrimdışı moddasınız.',
        isOfflineError: true,
      );
    }

    // Kelime API'de de bulunamadıysa
    return WordDefinitionResult(
      word: cleanWord,
      meaning: 'Kelime anlamı bulunamadı.',
      isOfflineError: false,
    );
  }
}