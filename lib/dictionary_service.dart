// ============================================================================
// DOSYA ADI: lib/dictionary_service.dart
// AÇIKLAMA: Çok Katmanlı Hibrit Sözlük Motoru (RAM -> SQLite -> Core Map -> API)
//           0 ms Çevrimdışı Yanıt ve Otomatik Arka Plan Senkronizasyonu
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';

class WordDefinitionResult {
  final String word;
  final String primaryMeaning;
  final List<String> alternativeMeanings;
  final String? partOfSpeech;
  final String? phonetic;
  final String? audioUrl;
  final String? example;
  final bool isFromLocalDb;
  final bool isOfflineError;

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
  static final DictionaryService instance = DictionaryService._init();
  DictionaryService._init();

  // 1. KATMAN: RAM ÖNBELLEĞİ (0 ms)
  final Map<String, WordDefinitionResult> _memoryCache = {};
  static const int _maxMemoryCacheSize = 250;

  void _addToMemoryCache(String key, WordDefinitionResult result) {
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[key] = result;
  }

  // 2. KATMAN: SIFIR GECİKMELİ DAHİLİ TEMEL HAVUZ (Garantili Çevrimdışı Temel)
  static const Map<String, Map<String, dynamic>> _coreDictionary = {
    'in': {'meaning': 'içinde, -de, -da', 'pos': 'preposition', 'phonetic': '/ɪn/'},
    'into': {'meaning': 'içine, içeriye, doğru', 'pos': 'preposition', 'phonetic': '/ˈɪn.tuː/'},
    'on': {'meaning': 'üzerinde, üstünde', 'pos': 'preposition', 'phonetic': '/ɒn/'},
    'at': {'meaning': '-de, -da, yanında', 'pos': 'preposition', 'phonetic': '/æt/'},
    'to': {'meaning': '-e, -a doğru, için', 'pos': 'preposition', 'phonetic': '/tuː/'},
    'for': {'meaning': 'için, çünkü, boyunca', 'pos': 'preposition', 'phonetic': '/fɔːr/'},
    'with': {'meaning': 'ile, birlikte, yanında', 'pos': 'preposition', 'phonetic': '/wɪð/'},
    'about': {'meaning': 'hakkında, yaklaşık olarak', 'pos': 'preposition', 'phonetic': '/əˈbaʊt/'},
    'against': {'meaning': 'karşı, aleyhinde', 'pos': 'preposition', 'phonetic': '/əˈɡenst/'},
    'between': {'meaning': 'arasında, iki şeyin arasında', 'pos': 'preposition', 'phonetic': '/bɪˈtwiːn/'},
    'through': {'meaning': 'boyunca, içinden, vasıtasıyla', 'pos': 'preposition', 'phonetic': '/θruː/'},
    'during': {'meaning': 'esnasında, sırasında, boyunca', 'pos': 'preposition', 'phonetic': '/ˈdjʊə.rɪŋ/'},
    'before': {'meaning': 'önce, önünde', 'pos': 'preposition', 'phonetic': '/bɪˈfɔːr/'},
    'after': {'meaning': 'sonra, ardından', 'pos': 'preposition', 'phonetic': '/ˈɑːf.tər/'},
    'above': {'meaning': 'üzerinde, yukarıda', 'pos': 'preposition', 'phonetic': '/əˈbʌv/'},
    'below': {'meaning': 'altında, aşağısında', 'pos': 'preposition', 'phonetic': '/bɪˈləʊ/'},
    'from': {'meaning': '-den, -dan, itibaren', 'pos': 'preposition', 'phonetic': '/frɒm/'},
    'up': {'meaning': 'yukarı, yukarıya', 'pos': 'preposition', 'phonetic': '/ʌp/'},
    'down': {'meaning': 'aşağı, aşağıya', 'pos': 'preposition', 'phonetic': '/daʊn/'},
    'out': {'meaning': 'dışarı, dışarıda', 'pos': 'preposition', 'phonetic': '/aʊt/'},
    'off': {'meaning': 'uzakta, kapalı, dışına', 'pos': 'preposition', 'phonetic': '/ɒf/'},
    'over': {'meaning': 'üzerinde, bitmiş, aşkın', 'pos': 'preposition', 'phonetic': '/ˈəʊ.vər/'},
    'under': {'meaning': 'altında, emrinde', 'pos': 'preposition', 'phonetic': '/ˈʌn.dər/'},
    'again': {'meaning': 'tekrar, yeniden', 'pos': 'adverb', 'phonetic': '/əˈɡen/'},
    'further': {'meaning': 'daha ileri, ayrıca, ek olarak', 'pos': 'adverb', 'phonetic': '/ˈfɜː.ðər/'},
    'then': {'meaning': 'o zaman, ondan sonra, öyleyse', 'pos': 'adverb', 'phonetic': '/ðen/'},
    'once': {'meaning': 'bir kez, bir zamanlar', 'pos': 'adverb', 'phonetic': '/wʌns/'},
    'here': {'meaning': 'burada, buraya', 'pos': 'adverb', 'phonetic': '/hɪər/'},
    'there': {'meaning': 'orada, oraya', 'pos': 'adverb', 'phonetic': '/ðeər/'},
    'when': {'meaning': 'ne zaman, -dığı zaman', 'pos': 'conjunction', 'phonetic': '/wen/'},
    'where': {'meaning': 'nerede, nereye, -dığı yer', 'pos': 'conjunction', 'phonetic': '/weər/'},
    'why': {'meaning': 'neden, niçin', 'pos': 'adverb', 'phonetic': '/waɪ/'},
    'how': {'meaning': 'nasıl, ne şekilde', 'pos': 'adverb', 'phonetic': '/haʊ/'},
    'all': {'meaning': 'tüm, bütün, hepsi', 'pos': 'pronoun', 'phonetic': '/ɔːl/'},
    'any': {'meaning': 'herhangi bir, hiç', 'pos': 'determiner', 'phonetic': '/ˈen.i/'},
    'both': {'meaning': 'her ikisi, her iki', 'pos': 'determiner', 'phonetic': '/bəʊθ/'},
    'each': {'meaning': 'her biri, her', 'pos': 'determiner', 'phonetic': '/iːtʃ/'},
    'few': {'meaning': 'az, birkaç', 'pos': 'determiner', 'phonetic': '/fjuː/'},
    'more': {'meaning': 'daha fazla, daha çok', 'pos': 'determiner', 'phonetic': '/mɔːr/'},
    'most': {'meaning': 'en çok, çoğu', 'pos': 'determiner', 'phonetic': '/məʊst/'},
    'other': {'meaning': 'diğer, başka', 'pos': 'determiner', 'phonetic': '/ˈʌð.ər/'},
    'some': {'meaning': 'bazı, biraz', 'pos': 'determiner', 'phonetic': '/sʌm/'},
    'such': {'meaning': 'böyle, bu tür', 'pos': 'determiner', 'phonetic': '/sʌtʃ/'},
    'no': {'meaning': 'hayır, hiç, yok', 'pos': 'determiner', 'phonetic': '/nəʊ/'},
    'nor': {'meaning': 'ne de', 'pos': 'conjunction', 'phonetic': '/nɔːr/'},
    'not': {'meaning': 'değil, yok', 'pos': 'adverb', 'phonetic': '/nɒt/'},
    'only': {'meaning': 'sadece, yalnızca', 'pos': 'adverb', 'phonetic': '/ˈəʊn.li/'},
    'own': {'meaning': 'kendi, sahip olmak', 'pos': 'adjective', 'phonetic': '/əʊn/'},
    'same': {'meaning': 'aynı, farksız', 'pos': 'adjective', 'phonetic': '/seɪm/'},
    'so': {'meaning': 'öyleyse, bu yüzden, çok', 'pos': 'adverb', 'phonetic': '/səʊ/'},
    'than': {'meaning': '-den daha, kıyasla', 'pos': 'conjunction', 'phonetic': '/ðæn/'},
    'too': {'meaning': 'çok, aşırı, de/da', 'pos': 'adverb', 'phonetic': '/tuː/'},
    'very': {'meaning': 'çok, tam', 'pos': 'adverb', 'phonetic': '/ˈver.i/'},
    'can': {'meaning': '-ebilmek, yapabilmek', 'pos': 'verb', 'phonetic': '/kæn/'},
    'will': {'meaning': '-ecek/-acak, istemek, irade', 'pos': 'verb', 'phonetic': '/wɪl/'},
    'just': {'meaning': 'sadece, az önce, adil', 'pos': 'adverb', 'phonetic': '/dʒʌst/'},
    'should': {'meaning': '-meli/-malı, gerekir', 'pos': 'verb', 'phonetic': '/ʃʊd/'},
    'now': {'meaning': 'şimdi, şu anda', 'pos': 'adverb', 'phonetic': '/naʊ/'},
    'is': {'meaning': 'dır/dir, öyledir', 'pos': 'verb', 'phonetic': '/ɪz/'},
    'are': {'meaning': 'dırlar/dirler', 'pos': 'verb', 'phonetic': '/ɑːr/'},
    'was': {'meaning': 'idi, öyleydi, -di', 'pos': 'verb', 'phonetic': '/wɒz/'},
    'were': {'meaning': 'idiler, öyleydiler', 'pos': 'verb', 'phonetic': '/wɜːr/'},
    'be': {'meaning': 'olmak, bulunmak', 'pos': 'verb', 'phonetic': '/biː/'},
    'been': {'meaning': 'olmuş, bulunmuş', 'pos': 'verb', 'phonetic': '/biːn/'},
    'being': {'meaning': 'varlık, olma durumu', 'pos': 'noun', 'phonetic': '/ˈbiː.ɪŋ/'},
    'have': {'meaning': 'sahip olmak, var olmak', 'pos': 'verb', 'phonetic': '/hæv/'},
    'has': {'meaning': 'sahip (o)', 'pos': 'verb', 'phonetic': '/hæz/'},
    'had': {'meaning': 'sahipti, vardı', 'pos': 'verb', 'phonetic': '/hæd/'},
    'do': {'meaning': 'yapmak, etmek', 'pos': 'verb', 'phonetic': '/duː/'},
    'does': {'meaning': 'yapar, eder', 'pos': 'verb', 'phonetic': '/dʌz/'},
    'did': {'meaning': 'yaptı, etti', 'pos': 'verb', 'phonetic': '/dɪd/'},
    'say': {'meaning': 'söylemek, demek', 'pos': 'verb', 'phonetic': '/seɪ/'},
    'said': {'meaning': 'dedi, söyledi', 'pos': 'verb', 'phonetic': '/sed/'},
    'go': {'meaning': 'gitmek, sürmek', 'pos': 'verb', 'phonetic': '/ɡəʊ/'},
    'went': {'meaning': 'gitti', 'pos': 'verb', 'phonetic': '/went/'},
    'gone': {'meaning': 'gitmiş, kayıp', 'pos': 'adjective', 'phonetic': '/ɡɒn/'},
    'get': {'meaning': 'almak, elde etmek, olmak', 'pos': 'verb', 'phonetic': '/ɡet/'},
    'got': {'meaning': 'aldı, sahip oldu', 'pos': 'verb', 'phonetic': '/ɡɒt/'},
    'make': {'meaning': 'yapmak, oluşturmak', 'pos': 'verb', 'phonetic': '/meɪk/'},
    'made': {'meaning': 'yapılmış, yaptı', 'pos': 'adjective', 'phonetic': '/meɪd/'},
    'know': {'meaning': 'bilmek, tanımak', 'pos': 'verb', 'phonetic': '/nəʊ/'},
    'knew': {'meaning': 'biliyordu, bildi', 'pos': 'verb', 'phonetic': '/njuː/'},
    'known': {'meaning': 'bilinen, tanınmış', 'pos': 'adjective', 'phonetic': '/nəʊn/'},
    'think': {'meaning': 'düşünmek, sanmak', 'pos': 'verb', 'phonetic': '/θɪŋk/'},
    'thought': {'meaning': 'düşünce, düşündü', 'pos': 'noun', 'phonetic': '/θɔːt/'},
    'take': {'meaning': 'almak, götürmek', 'pos': 'verb', 'phonetic': '/teɪk/'},
    'took': {'meaning': 'aldı, götürdü', 'pos': 'verb', 'phonetic': '/tʊk/'},
    'taken': {'meaning': 'alınmış, tutulmuş', 'pos': 'adjective', 'phonetic': '/ˈteɪ.kən/'},
    'see': {'meaning': 'görmek, anlamak', 'pos': 'verb', 'phonetic': '/siː/'},
    'saw': {'meaning': 'gördü, testere', 'pos': 'verb', 'phonetic': '/sɔː/'},
    'seen': {'meaning': 'görülmüş', 'pos': 'adjective', 'phonetic': '/siːn/'},
    'come': {'meaning': 'gelmek, ulaşmak', 'pos': 'verb', 'phonetic': '/kʌm/'},
    'came': {'meaning': 'geldi', 'pos': 'verb', 'phonetic': '/keɪm/'},
    'look': {'meaning': 'bakmak, görünmek', 'pos': 'verb', 'phonetic': '/lʊk/'},
    'use': {'meaning': 'kullanmak, yararlanmak', 'pos': 'verb', 'phonetic': '/juːz/'},
    'find': {'meaning': 'bulmak, keşfetmek', 'pos': 'verb', 'phonetic': '/faɪnd/'},
    'give': {'meaning': 'vermek, sunmak', 'pos': 'verb', 'phonetic': '/ɡɪv/'},
    'tell': {'meaning': 'anlatmak, söylemek', 'pos': 'verb', 'phonetic': '/tel/'},
    'work': {'meaning': 'çalışmak, iş', 'pos': 'noun', 'phonetic': '/wɜːk/'},
    'call': {'meaning': 'aramak, çağırmak, isim vermek', 'pos': 'verb', 'phonetic': '/kɔːl/'},
    'try': {'meaning': 'denemek, çabalamak', 'pos': 'verb', 'phonetic': '/traɪ/'},
    'ask': {'meaning': 'sormak, istemek', 'pos': 'verb', 'phonetic': '/ɑːsk/'},
    'need': {'meaning': 'ihtiyaç duymak, gerekmek', 'pos': 'noun', 'phonetic': '/niːd/'},
    'feel': {'meaning': 'hissetmek, sezmek', 'pos': 'verb', 'phonetic': '/fiːl/'},
    'become': {'meaning': 'haline gelmek, olmak', 'pos': 'verb', 'phonetic': '/bɪˈkʌm/'},
    'leave': {'meaning': 'ayrılmak, bırakmak, izin', 'pos': 'verb', 'phonetic': '/liːv/'},
    'put': {'meaning': 'koymak, yerleştirmek', 'pos': 'verb', 'phonetic': '/pʊt/'},
    'mean': {'meaning': 'anlamına gelmek, kaba, cimri', 'pos': 'verb', 'phonetic': '/miːn/'},
    'keep': {'meaning': 'tutmak, korumak, sürdürmek', 'pos': 'verb', 'phonetic': '/kiːp/'},
    'let': {'meaning': 'izin vermek, bırakmak', 'pos': 'verb', 'phonetic': '/let/'},
    'begin': {'meaning': 'başlamak, başlatmak', 'pos': 'verb', 'phonetic': '/bɪˈɡɪn/'},
    'beginning': {'meaning': 'başlangıç, ilk, baş', 'pos': 'noun', 'phonetic': '/bɪˈɡɪn.ɪŋ/'},
    'seem': {'meaning': 'görünmek, gibi gelmek', 'pos': 'verb', 'phonetic': '/siːm/'},
    'help': {'meaning': 'yardım etmek, fayda sağlamak', 'pos': 'noun', 'phonetic': '/help/'},
    'talk': {'meaning': 'konuşmak, sohbet etmek', 'pos': 'verb', 'phonetic': '/tɔːk/'},
    'turn': {'meaning': 'dönmek, dönüştürmek, sıra', 'pos': 'noun', 'phonetic': '/tɜːn/'},
    'start': {'meaning': 'başlamak, çalıştırmak', 'pos': 'noun', 'phonetic': '/stɑːt/'},
    'show': {'meaning': 'göstermek, gösteri', 'pos': 'noun', 'phonetic': '/ʃəʊ/'},
    'hear': {'meaning': 'duymak, işitmek', 'pos': 'verb', 'phonetic': '/hɪər/'},
    'play': {'meaning': 'oynamak, çalmak, tiyatro oyunu', 'pos': 'noun', 'phonetic': '/pleɪ/'},
    'run': {'meaning': 'koşmak, işletmek, çalıştırmak', 'pos': 'verb', 'phonetic': '/rʌn/'},
    'move': {'meaning': 'hareket etmek, taşınmak', 'pos': 'verb', 'phonetic': '/muːv/'},
    'like': {'meaning': 'beğenmek, hoşlanmak, gibi', 'pos': 'verb', 'phonetic': '/laɪk/'},
    'live': {'meaning': 'yaşamak, canlı', 'pos': 'verb', 'phonetic': '/lɪv/'},
    'believe': {'meaning': 'inanmak, güvenmek', 'pos': 'verb', 'phonetic': '/bɪˈliːv/'},
    'hold': {'meaning': 'tutmak, kavramak, beklemek', 'pos': 'verb', 'phonetic': '/həʊld/'},
    'bring': {'meaning': 'getirmek, neden olmak', 'pos': 'verb', 'phonetic': '/brɪŋ/'},
    'happen': {'meaning': 'olmak, meydana gelmek', 'pos': 'verb', 'phonetic': '/ˈhæp.ən/'},
    'write': {'meaning': 'yazmak, bestelemek', 'pos': 'verb', 'phonetic': '/raɪt/'},
    'provide': {'meaning': 'sağlamak, temin etmek', 'pos': 'verb', 'phonetic': '/prəˈvaɪd/'},
    'sit': {'meaning': 'oturmak', 'pos': 'verb', 'phonetic': '/sɪt/'},
    'stand': {'meaning': 'ayakta durmak, katlanmak', 'pos': 'verb', 'phonetic': '/stænd/'},
    'lose': {'meaning': 'kaybetmek, yitirmek', 'pos': 'verb', 'phonetic': '/luːz/'},
    'pay': {'meaning': 'ödemek, maaş', 'pos': 'verb', 'phonetic': '/peɪ/'},
    'meet': {'meaning': 'buluşmak, tanışmak, karşılamak', 'pos': 'verb', 'phonetic': '/miːt/'},
    'include': {'meaning': 'içermek, kapsamak', 'pos': 'verb', 'phonetic': '/ɪnˈkluːd/'},
    'continue': {'meaning': 'devam etmek, sürdürmek', 'pos': 'verb', 'phonetic': '/kənˈtɪn.juː/'},
    'set': {'meaning': 'kurmak, ayarlamak, küme', 'pos': 'verb', 'phonetic': '/set/'},
    'learn': {'meaning': 'öğrenmek, bilgi edinmek', 'pos': 'verb', 'phonetic': '/lɜːn/'},
    'change': {'meaning': 'değiştirmek, değişim, bozuk para', 'pos': 'noun', 'phonetic': '/tʃeɪndʒ/'},
    'lead': {'meaning': 'yol göstermek, öncülük etmek', 'pos': 'verb', 'phonetic': '/liːd/'},
    'understand': {'meaning': 'anlamak, kavramak', 'pos': 'verb', 'phonetic': '/ˌʌn.dəˈstænd/'},
    'watch': {'meaning': 'izlemek, seyretmek, kol saati', 'pos': 'noun', 'phonetic': '/wɒtʃ/'},
    'follow': {'meaning': 'takip etmek, izlemek', 'pos': 'verb', 'phonetic': '/ˈfɒl.əʊ/'},
    'stop': {'meaning': 'durmak, durdurmak, durak', 'pos': 'noun', 'phonetic': '/stɒp/'},
    'create': {'meaning': 'yaratmak, oluşturmak', 'pos': 'verb', 'phonetic': '/kriˈeɪt/'},
    'speak': {'meaning': 'konuşmak, hitap etmek', 'pos': 'verb', 'phonetic': '/spiːk/'},
    'read': {'meaning': 'okumak, anlam çıkarmak', 'pos': 'verb', 'phonetic': '/riːd/'},
    'allow': {'meaning': 'izin vermek, olanak sağlamak', 'pos': 'verb', 'phonetic': '/əˈlaʊ/'},
    'add': {'meaning': 'eklemek, ilave etmek', 'pos': 'verb', 'phonetic': '/æd/'},
    'spend': {'meaning': 'harcamak, geçirmek (zaman)', 'pos': 'verb', 'phonetic': '/spend/'},
    'grow': {'meaning': 'büyümek, yetiştirmek', 'pos': 'verb', 'phonetic': '/ɡrəʊ/'},
    'open': {'meaning': 'açmak, açık', 'pos': 'adjective', 'phonetic': '/ˈəʊ.pən/'},
    'walk': {'meaning': 'yürümek, yürüyüş', 'pos': 'noun', 'phonetic': '/wɔːk/'},
    'win': {'meaning': 'kazanmak, galip gelmek', 'pos': 'verb', 'phonetic': '/wɪn/'},
    'offer': {'meaning': 'teklif etmek, sunmak', 'pos': 'noun', 'phonetic': '/ˈɒf.ər/'},
    'remember': {'meaning': 'hatırlamak, anımsamak', 'pos': 'verb', 'phonetic': '/rɪˈmem.bər/'},
    'love': {'meaning': 'sevmek, aşk, sevgi', 'pos': 'noun', 'phonetic': '/lʌv/'},
    'consider': {'meaning': 'dikkate almak, düşünmek', 'pos': 'verb', 'phonetic': '/kənˈsɪd.ər/'},
    'appear': {'meaning': 'belirmek, görünmek', 'pos': 'verb', 'phonetic': '/əˈpɪər/'},
    'buy': {'meaning': 'satın almak', 'pos': 'verb', 'phonetic': '/baɪ/'},
    'wait': {'meaning': 'beklemek, garsonluk yapmak', 'pos': 'verb', 'phonetic': '/weɪt/'},
    'serve': {'meaning': 'hizmet etmek, servis yapmak', 'pos': 'verb', 'phonetic': '/sɜːv/'},
    'die': {'meaning': 'ölmek, vefat etmek', 'pos': 'verb', 'phonetic': '/daɪ/'},
    'send': {'meaning': 'göndermek, yollamak', 'pos': 'verb', 'phonetic': '/send/'},
    'expect': {'meaning': 'ummak, beklemek', 'pos': 'verb', 'phonetic': '/ɪkˈspekt/'},
    'build': {'meaning': 'inşa etmek, kurmak', 'pos': 'verb', 'phonetic': '/bɪld/'},
    'stay': {'meaning': 'kalmak, konaklamak', 'pos': 'verb', 'phonetic': '/steɪ/'},
    'fall': {'meaning': 'düşmek, sonbahar', 'pos': 'noun', 'phonetic': '/fɔːl/'},
    'cut': {'meaning': 'kesmek, kesik', 'pos': 'noun', 'phonetic': '/kʌt/'},
    'reach': {'meaning': 'ulaşmak, erişmek', 'pos': 'verb', 'phonetic': '/riːtʃ/'},
    'kill': {'meaning': 'öldürmek, yok etmek', 'pos': 'verb', 'phonetic': '/kɪl/'},
    'remain': {'meaning': 'kalmak, sürdürmek', 'pos': 'verb', 'phonetic': '/rɪˈmeɪn/'},
    'habit': {'meaning': 'alışkanlık, huy', 'pos': 'noun', 'phonetic': '/ˈhæb.ɪt/'},
    'improve': {'meaning': 'geliştirmek, iyileştirmek', 'pos': 'verb', 'phonetic': '/ɪmˈpruːv/'},
    'conversation': {'meaning': 'konuşma, sohbet, görüşme', 'pos': 'noun', 'phonetic': '/ˌkɒn.vəˈseɪ.ʃən/'},
    'conversations': {'meaning': 'konuşmalar, sohbetler', 'pos': 'noun', 'phonetic': '/ˌkɒn.vəˈseɪ.ʃənz/'},
  };

  // --------------------------------------------------------------------------
  // ÇOK KATMANLI SÖZLÜK SORGULAMA MOTORU
  // --------------------------------------------------------------------------
  Future<WordDefinitionResult> fetchWordMeaning(String rawWord) async {
    final cleanWord = rawWord.replaceAll(RegExp(r'''^[\s"“”'‘’\(\)\[\]\{\}\.,;:!?\-—_]+|[\s"“”'‘’\(\)\[\]\{\}\.,;:!?\-—_]+$'''), '').trim().toLowerCase();
    
    if (cleanWord.isEmpty || !RegExp(r'[a-zA-Z]').hasMatch(cleanWord)) {
      return WordDefinitionResult(
        word: rawWord,
        primaryMeaning: 'Geçersiz kelime seçimi.',
      );
    }

    // 1. KATMAN: RAM Önbelleği (0 ms)
    if (_memoryCache.containsKey(cleanWord)) {
      return _memoryCache[cleanWord]!;
    }

    // 2. KATMAN: SQLite Veritabanı (<5 ms)
    try {
      final localData = await DatabaseHelper.instance.getWordDefinition(cleanWord);
      if (localData != null) {
        final rawMeaning = (localData['meaning'] as String? ?? '').trim();
        final parts = rawMeaning.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        
        final result = WordDefinitionResult(
          word: cleanWord,
          primaryMeaning: parts.isNotEmpty ? parts.first : rawMeaning,
          alternativeMeanings: parts.take(3).toList(),
          partOfSpeech: localData['pos'] as String?,
          phonetic: localData['phonetic'] as String?,
          example: localData['example'] as String?,
          isFromLocalDb: true,
        );
        
        _addToMemoryCache(cleanWord, result);
        return result;
      }
    } catch (_) {}

    // 3. KATMAN: Dahili Temel Sözlük Havuzu (0 ms)
    if (_coreDictionary.containsKey(cleanWord)) {
      final entry = _coreDictionary[cleanWord]!;
      final rawMeaning = entry['meaning'] as String;
      final parts = rawMeaning.split(',').map((e) => e.trim()).toList();
      
      final result = WordDefinitionResult(
        word: cleanWord,
        primaryMeaning: parts.isNotEmpty ? parts.first : rawMeaning,
        alternativeMeanings: parts.take(3).toList(),
        partOfSpeech: entry['pos'],
        phonetic: entry['phonetic'],
        isFromLocalDb: true,
      );

      _addToMemoryCache(cleanWord, result);
      return result;
    }

    // 4. KATMAN: Canlı API Yedeklemesi (İnternet Açıksa)
    try {
      final gtxUri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=tr&dt=t&dt=bd&dt=rm&q=$cleanWord',
      );
      final dictUri = Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$cleanWord');

      final gtxFuture = http.get(gtxUri).timeout(const Duration(seconds: 3));
      final dictFuture = http.get(dictUri).timeout(const Duration(milliseconds: 1800)).catchError((_) => http.Response('', 404));

      final results = await Future.wait([gtxFuture, dictFuture]);
      final gtxResponse = results[0];
      final dictResponse = results[1];

      if (gtxResponse.statusCode == 200) {
        final dynamic data = json.decode(gtxResponse.body);
        
        String primary = '';
        List<String> alternatives = [];
        String? pos;

        if (data is List && data.isNotEmpty && data[0] is List && data[0].isNotEmpty) {
          primary = data[0][0][0] ?? '';
        }

        if (data is List && data.length > 1 && data[1] != null && data[1] is List) {
          for (var entry in data[1]) {
            if (entry is List && entry.length > 1) {
              pos ??= entry[0]?.toString();
              
              if (entry[1] is List) {
                for (var mean in entry[1]) {
                  final meanStr = mean.toString().trim();
                  if (!alternatives.contains(meanStr) && alternatives.length < 3) {
                    alternatives.add(meanStr);
                  }
                }
              }
            }
          }
        }

        if (alternatives.isEmpty && primary.isNotEmpty) {
          alternatives.add(primary);
        }

        final mainMeaning = alternatives.isNotEmpty ? alternatives.first : primary;

        String? phoneticText;
        String? audioLink;
        if (dictResponse.statusCode == 200 && dictResponse.body.isNotEmpty) {
          try {
            final List<dynamic> dictData = json.decode(dictResponse.body);
            if (dictData.isNotEmpty) {
              phoneticText = dictData[0]['phonetic'];
              final phonetics = dictData[0]['phonetics'] as List<dynamic>?;
              if (phonetics != null) {
                for (var p in phonetics) {
                  if (p['audio'] != null && p['audio'].toString().isNotEmpty) {
                    audioLink = p['audio'];
                    break;
                  }
                }
              }
            }
          } catch (_) {}
        }

        final finalResult = WordDefinitionResult(
          word: cleanWord,
          primaryMeaning: mainMeaning,
          alternativeMeanings: alternatives.take(3).toList(),
          partOfSpeech: pos,
          phonetic: phoneticText,
          audioUrl: audioLink,
          isFromLocalDb: false,
        );

        _addToMemoryCache(cleanWord, finalResult);

        // Gelecekte çevrimdışı kullanım için SQLite'a kaydet
        DatabaseHelper.instance.saveWordDefinition(
          word: cleanWord,
          meaning: alternatives.isNotEmpty ? alternatives.join(', ') : primary,
          pos: pos,
          phonetic: phoneticText,
        ).catchError((_) {});

        return finalResult;
      }
    } catch (_) {
      return WordDefinitionResult(
        word: cleanWord,
        primaryMeaning: 'Çevrimdışı moddasınız.',
        isOfflineError: true,
      );
    }

    return WordDefinitionResult(
      word: cleanWord,
      primaryMeaning: 'Kelime anlamı bulunamadı.',
      isOfflineError: false,
    );
  }
}