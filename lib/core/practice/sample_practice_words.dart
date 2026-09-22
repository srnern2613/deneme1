// ============================================================================
// DOSYA ADI: lib/core/practice/sample_practice_words.dart
// AÇIKLAMA: P0-D — Yeni kullanıcı "soğuk başlangıç" düzeltmesi. Kullanıcı
// henüz hiç kelime avlamamışsa (veya bir modun eşiğini karşılayacak kadar
// kelimesi yoksa) pratik modlarını tamamen KİLİTLEMEK yerine, bu ortak
// (tüm modlar için tek/paylaşılan) 20 kelimelik dahili örnek havuzuyla
// deneme amaçlı pratik yaptırıyoruz — araç kullanıcıya "soğuk" gelmesin diye.
//
// KRİTİK TASARIM KARARI (kullanıcı onayı ile): bu kartların `id` alanı
// BİLİNÇLİ olarak NEGATİF (-1..-20). flashcards_screen.dart ve tüm egzersiz
// ekranları (quiz/match/spelling/srs) zaten "cardId > 0" ise DB'ye
// yazıyor/XP veriyor deseniyle çalışıyordu — negatif id vermek, hiçbir
// egzersiz ekranını değiştirmeden bu örnek kelimelerle yapılan pratiğin
// otomatik olarak SRS/istatistik/veritabanına YAZILMAMASINI sağlıyor.
// SADECE XP ödülü verme noktaları (addXp çağrıları) bu id'yi kontrol
// etmiyordu — o noktalara `cardId > 0` koruması EKLENDİ (bkz. ilgili
// egzersiz dosyalarındaki P0-D notları), yani örnek kelimelerle pratik XP
// KAZANDIRMAZ.
//
// Kullanıcı kendi gerçek kelimelerini o modun eşiğine ulaşacak kadar
// eklediğinde bu havuz o mod için ARTIK HİÇ kullanılmaz (karışık
// gösterilmez) — flashcards_screen.dart'taki eşik kontrolü ile ikisi asla
// aynı oturumda birleşmez.
// ============================================================================

/// Tüm temel pratik modlarının (Hızlı Test, SRS Hafıza, Eşleştirme,
/// Dinle & Yaz) paylaştığı, sabit ve dahili örnek kelime havuzu.
/// 20 kelime — en yüksek eşiğe (Dinle & Yaz: 20) tam yetecek kadar.
final List<Map<String, dynamic>> kSamplePracticeWords = List.unmodifiable([
  _sample(-1, 'Habit', 'Alışkanlık'),
  _sample(-2, 'Improve', 'Geliştirmek, iyileştirmek'),
  _sample(-3, 'Challenge', 'Meydan okuma, zorluk'),
  _sample(-4, 'Persistent', 'İnatçı, ısrarcı, sürekli'),
  _sample(-5, 'Courage', 'Cesaret'),
  _sample(-6, 'Journey', 'Yolculuk'),
  _sample(-7, 'Discover', 'Keşfetmek'),
  _sample(-8, 'Ancient', 'Antik, eski'),
  _sample(-9, 'Shadow', 'Gölge'),
  _sample(-10, 'Treasure', 'Hazine'),
  _sample(-11, 'Brave', 'Cesur'),
  _sample(-12, 'Mystery', 'Gizem'),
  _sample(-13, 'Wisdom', 'Bilgelik'),
  _sample(-14, 'Strength', 'Güç, kuvvet'),
  _sample(-15, 'Victory', 'Zafer'),
  _sample(-16, 'Legend', 'Efsane'),
  _sample(-17, 'Curious', 'Meraklı'),
  _sample(-18, 'Wander', 'Amaçsızca dolaşmak'),
  _sample(-19, 'Fierce', 'Vahşi, sert'),
  _sample(-20, 'Guardian', 'Koruyucu'),
]);

Map<String, dynamic> _sample(int id, String word, String meaning) {
  return {
    'id': id,
    'word': word,
    'meaning': meaning,
    'interval': 1,
    'repetitions': 0,
    'is_mastered': 0,
    'learning_state': 'LEARNING',
    'success_streak': 0,
    'wrong_count': 0,
    'boss_level': 0,
    'modes_passed': '',
    'distinct_days_count': 0,
    'last_reviewed_at': null,
    'cooldown_until': null,
    'context_sentence': null,
    'book_title': 'Örnek Kelimeler',
    'chapter_info': null,
    'fsrs_stability': null,
    'fsrs_difficulty': null,
    'fsrs_due_at': null,
    'fsrs_state': 0,
    'fsrs_reps': 0,
    'fsrs_lapses': 0,
    'fsrs_last_reviewed_at': null,
    'uuid': null,
    'updated_at': null,
  };
}
