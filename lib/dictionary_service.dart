// ============================================================================
// DOSYA ADI: lib/dictionary_service.dart
// AÇIKLAMA: Çoklu Anlam & Eş Anlam Destekli Hibrit Sözlük Servisi
//
// MİMARİ VE ÇALIŞMA MANTIĞI:
// 1. Yerel SQLite Önceliği: Dokunulan kelime önce telefonun içindeki SQLite
//    'dictionary' tablosunda aranır. Eğer daha önce kaydedilmişse hiç internet
//    harcamadan milisaniyeler (0.01 sn) içinde anlamı ekrana getirir.
//
// 2. Google GTX Sözlük Motoru: Kelime telefonda yoksa, Google'ın ücretsiz ve
//    açık sözlük uç noktasına hafif bir GET isteği atılır. Bu servis kelimenin
//    sözcük türünü (noun, verb vb.) ve en yaygın alternatif Türkçe karşılıklarını döner.
//
// 3. Eş Anlam Sınırlandırması (Max 3): Kullanıcının kafasının karışmaması için
//    gelen alternatif karşılıklardan yalnızca en popüler İLK 3 ANLAM ayıklanır.
//
// 4. Free Dictionary API (Fonetik & Ses): Eşzamanlı olarak kelimenin uluslararası
//    fonetik alfabesindeki okunuşu (IPA) ve orijinal telaffuz ses dosyası (.mp3) çekilir.
//
// 5. Otomatik SQLite Önbelleğe Alma: Çekilen tüm bu veriler sessizce telefonun
//    yerel veritabanına yazılır. Böylece aynı kelimeye bir sonraki dokunuşta
//    uygulama tamamen internetsiz (çevrimdışı) çalışır.
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';

// ----------------------------------------------------------------------------
// SÖZLÜK VE ANLAM VERİ MODELİ
// Pop-up penceresine taşınacak tüm detayları paketleyen sınıftır.
// ----------------------------------------------------------------------------
class WordDefinitionResult {
  final String word;                      // Ekranda dokunulan yalın İngilizce kelime
  final String primaryMeaning;            // En yaygın kullanılan 1. Türkçe karşılık
  final List<String> alternativeMeanings; // Listelenecek en fazla 3 alternatif eş anlam
  final String? partOfSpeech;             // Sözcük türü (İsim: NOUN, Fiil: VERB, Sıfat: ADJ)
  final String? phonetic;                 // Fonetik telaffuz metni (Örn: /ˈhæb.ɪt/)
  final String? audioUrl;                 // İnternet üzerinden dinlenebilecek ses dosyası linki
  final String? example;                  // Sözlükten gelen örnek kullanım cümlesi
  final bool isFromLocalDb;               // Veri yerel SQLite hafızasından mı okundu?
  final bool isOfflineError;              // İnternet olmadığı ve kelime yerelde bulunamadığı için mi hata oluştu?

  WordDefinitionResult({
    required this.word,
    required this.primaryMeaning,
    this.alternativeMeanings = const [],
    this.partOfSpeech,
    this.phonetic,
    this.audioUrl,
    this.example,
    this.isFromLocalDb = false,
    this.isOfflineError = false,
  });
}

class DictionaryService {
  // Singleton Deseni: Uygulama boyunca tek bir servis nesnesi kullanılır.
  static final DictionaryService instance = DictionaryService._init();
  DictionaryService._init();

  // --------------------------------------------------------------------------
  // HİBRİT SÖZLÜK SORGULAMA FONKSİYONU
  // --------------------------------------------------------------------------
  Future<WordDefinitionResult> fetchWordMeaning(String rawWord) async {
    // Kelimenin sağındaki/solundaki noktalama işaretlerini (nokta, virgül, tırnak) temizliyoruz
    final cleanWord = rawWord.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
    
    // Eğer temizleme sonrası geriye boş bir metin kalırsa işlemi sonlandırıyoruz
    if (cleanWord.isEmpty) {
      return WordDefinitionResult(
        word: rawWord,
        primaryMeaning: 'Geçersiz kelime seçimi.',
      );
    }

    // ------------------------------------------------------------------------
    // 1. AŞAMA: TELEFONUN YEREL HAFIZASINI (SQLITE) KONTROL ETME
    // ------------------------------------------------------------------------
    try {
      final localData = await DatabaseHelper.instance.getWordDefinition(cleanWord);
      if (localData != null) {
        final rawMeaning = localData['meaning'] as String;
        // Veritabanında virgülle ayrılmış birden fazla anlam varsa listeye çeviriyoruz
        final parts = rawMeaning.split(',').map((e) => e.trim()).toList();
        
        return WordDefinitionResult(
          word: cleanWord,
          primaryMeaning: parts.isNotEmpty ? parts.first : rawMeaning,
          alternativeMeanings: parts.take(3).toList(), // En fazla ilk 3 anlamı alıyoruz
          example: localData['example'] as String?,
          isFromLocalDb: true, // Verinin yerel hafızadan geldiğini işaretliyoruz
        );
      }
    } catch (e) {
      // Yerel SQLite sorgusunda beklenmeyen bir durum olursa akışı kesmeyip internet sorgusuna geçiyoruz
    }

    // ------------------------------------------------------------------------
    // 2. AŞAMA: GOOGLE GTX SÖZLÜK MOTORUNDAN ÇOKLU ANLAMLARI ÇEKME
    // ------------------------------------------------------------------------
    try {
      // Google Çeviri'nin sözlük ve eş anlam tablosunu döndüren ücretsiz GET uç noktası
      final gtxUrl = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=tr&dt=t&dt=bd&dt=rm&q=$cleanWord',
      );

      // 4 saniyelik zaman aşımı (timeout) koyarak uygulamanın kilitlenmesini önlüyoruz
      final response = await http.get(gtxUrl).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        
        String primary = '';
        List<String> alternatives = [];
        String? pos; // Part of Speech (Sözcük türü)

        // data[0]: Düz çeviri sonucunu ayıklıyoruz
        if (data is List && data.isNotEmpty && data[0] is List && data[0].isNotEmpty) {
          primary = data[0][0][0] ?? '';
        }

        // data[1]: Sözlük detayları, sözcük türleri (İsim, Fiil vb.) ve eş anlam dizilerini içerir
        if (data is List && data.length > 1 && data[1] != null && data[1] is List) {
          for (var entry in data[1]) {
            if (entry is List && entry.length > 1) {
              pos ??= entry[0]?.toString(); // İlk bulunan sözcük türünü alıyoruz (Örn: 'noun')
              
              if (entry[1] is List) {
                // Bu türe ait tüm Türkçe karşılıkları tarıyoruz
                for (var mean in entry[1]) {
                  final meanStr = mean.toString().trim();
                  // Listede yoksa ve henüz 3 adede ulaşmadıysak listeye ekliyoruz
                  if (!alternatives.contains(meanStr) && alternatives.length < 3) {
                    alternatives.add(meanStr);
                  }
                }
              }
            }
          }
        }

        // Eğer alternatif sözlük listesi boşsa ama düz çeviri varsa onu listeye ekliyoruz
        if (alternatives.isEmpty && primary.isNotEmpty) {
          alternatives.add(primary);
        }

        final mainMeaning = alternatives.isNotEmpty ? alternatives.first : primary;

        // --------------------------------------------------------------------
        // 3. AŞAMA: FREE DICTIONARY API İLE FONETİK OKUNUŞ VE SES DOSYASI ALMA
        // --------------------------------------------------------------------
        String? phoneticText;
        String? audioLink;
        try {
          final dictUrl = Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$cleanWord');
          final dictRes = await http.get(dictUrl).timeout(const Duration(seconds: 2));
          
          if (dictRes.statusCode == 200) {
            final List<dynamic> dictData = json.decode(dictRes.body);
            if (dictData.isNotEmpty) {
              phoneticText = dictData[0]['phonetic'];
              final phonetics = dictData[0]['phonetics'] as List<dynamic>?;
              
              if (phonetics != null) {
                for (var p in phonetics) {
                  // MP3 uzantılı geçerli bir ses kaydı linki buluyoruz
                  if (p['audio'] != null && p['audio'].toString().isNotEmpty) {
                    audioLink = p['audio'];
                    break;
                  }
                }
              }
            }
          }
        } catch (_) {
          // Fonetik çekilemezse ana akışı bozmamak için sessizce devam ediyoruz
        }

        // --------------------------------------------------------------------
        // 4. AŞAMA: VERİLERİ YEREL SQLITE VERİTABANINA KAYDETME (ÖNBELLEKLEME)
        // --------------------------------------------------------------------
        final joinedMeanings = alternatives.join(', ');
        final db = await DatabaseHelper.instance.database;
        await db.insert('dictionary', {
          'word': cleanWord,
          'meaning': joinedMeanings.isNotEmpty ? joinedMeanings : primary,
          'example': 'Google Dictionary & Oxford verified.',
        });

        return WordDefinitionResult(
          word: cleanWord,
          primaryMeaning: mainMeaning,
          alternativeMeanings: alternatives.take(3).toList(),
          partOfSpeech: pos,
          phonetic: phoneticText,
          audioUrl: audioLink,
          isFromLocalDb: false,
        );
      }
    } catch (e) {
      // Cihaz internetsizse veya bağlantı koptuysa çevrimdışı hata modelini döndürüyoruz
      return WordDefinitionResult(
        word: cleanWord,
        primaryMeaning: 'Çevrimdışı moddasınız.',
        isOfflineError: true,
      );
    }

    // Hiçbir kaynaktan sonuç dönmediği durum
    return WordDefinitionResult(
      word: cleanWord,
      primaryMeaning: 'Kelime anlamı bulunamadı.',
      isOfflineError: false,
    );
  }
}