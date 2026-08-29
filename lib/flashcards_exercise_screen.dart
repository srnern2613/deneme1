// ============================================================================
// DOSYA ADI: lib/flashcards_exercise_screen.dart
// AÇIKLAMA: Faz 2 - Gelişmiş SRS Egzersizi & Kalıcı Hafıza (Mastery) Kutlaması
// GÖREVLER & PSİKOLOJİK TETİKLEYİCİLER:
//   1. 5 Aşamalı SRS İlerlemesi (0-4 Öğrenim, 5'te Kalıcı Hafızaya Geçiş)[cite: 2, 3]
//   2. Seviye 4 -> 5 Geçişinde "Kalıcı Hafıza Eşiği" Özel Uyarısı & Kutlaması[cite: 3]
//   3. Orijinal Kitap Cümlesi Bağlamı (Context Hint & Tam Görünüm)[cite: 3]
//   4. Çift Yönlü Kaydırma (%38 Eşikli Swipe: Sağ = Bildim, Sol = Tekrar)[cite: 3]
//   5. XP, Seri ve Seans Sonu Detaylı Başarı / Zorlanılan Kelimeler Geri Bildirimi[cite: 3]
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tts_service.dart';
import 'xp_shop_service.dart';
import 'celebration_dialog.dart';
import 'coach_messages.dart';
import 'database_helper.dart';
import 'dictionary_service.dart';

class FlashcardsExerciseScreen extends StatefulWidget {
  // Egzersizde çalışılacak kelime kartlarının listesi
  final List<Map<String, dynamic>> cards;
  
  // Sadece zorlanılan kelimelerin mini tekrarı olup olmadığını belirten bayrak
  final bool isReviewOnly;

  const FlashcardsExerciseScreen({
    super.key, 
    required this.cards,
    this.isReviewOnly = false,
  });

  @override
  State<FlashcardsExerciseScreen> createState() => _FlashcardsExerciseScreenState();
}

class _FlashcardsExerciseScreenState extends State<FlashcardsExerciseScreen> {
  // Seansta kalan kartlar listesi (Her cevapta ilk eleman listeden çıkarılır)
  late List<Map<String, dynamic>> _remainingCards;
  
  // Kullanıcının "Tekrar" veya "Zor" dediği, seans sonunda tekrar gösterilebilecek kartlar
  final List<Map<String, dynamic>> _struggledCards = [];

  // Seans istatistik sayaçları
  int _knownCount = 0;              // Başarıyla bilinen kart sayısı
  int _hardCount = 0;               // Zorlanarak bilinen kart sayısı
  int _reviewCount = 0;             // Hatırlanamayan kart sayısı
  int _masteredCountInSession = 0;  // Bu seansta 5'te 5 yaparak kalıcı hafızaya geçen kelimeler
  int _initialTotal = 0;            // Seansın başında gelen toplam kart sayısı
  int _consecutiveKnownStreak = 0;  // Art arda doğru bilme serisi (Motive edici koç mesajları için)
  int _totalEarnedXp = 0;           // Seansta kazanılan toplam tecrübe puanı (XP)

  // Arayüz ve etkileşim durum değişkenleri
  String? _cheerMessage;            // Ekranda beliren dinamik tebrik / motivasyon banner metni
  bool _isFlipped = false;          // Kartın arka yüzünün (Türkçe anlam) açık olup olmadığı
  bool _showHint = false;           // Kitap cümle ipucunun görünürlüğü
  bool _celebrationShown = false;   // Bitiş kutlama penceresinin mükerrer açılmasını önleyen bayrak
  bool _isProcessing = false;       // Çift tıklama veya hızlı swipe çakışmalarını önleyen kilit

  // Kelime tanımlarını hafızada tutarak gereksiz ağ isteklerini önleyen önbellek
  final Map<String, WordDefinitionResult?> _definitionCache = {};

  // Kelime türlerinin Türkçe karşılık eşlemesi
  static const Map<String, String> _posTranslations = {
    'noun': 'İSİM',
    'verb': 'FİİL',
    'adjective': 'SIFAT',
    'adverb': 'ZARF',
    'pronoun': 'ZAMİR',
    'preposition': 'EDAT',
    'conjunction': 'BAĞLAÇ',
    'interjection': 'ÜNLEM',
    'determiner': 'BELİRTEÇ',
    'article': 'TANIMLIK',
    'phrase': 'DEYİM / İFADE',
  };

  /// Kelime türünü büyük harfli Türkçe etikete dönüştürür
  String _formatTurkishPos(String? pos) {
    if (pos == null || pos.trim().isEmpty) return '';
    final clean = pos.trim().toLowerCase();
    return _posTranslations[clean] ?? pos.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    // 1. Kartları karıştırarak her seansta rastgele bir sıra oluştur
    _remainingCards = List.from(widget.cards)..shuffle();
    _initialTotal = _remainingCards.length;
    // 2. İlk kelimenin ek sözlük detaylarını arka planda çek
    _prefetchCurrentCardDetails();
  }

  @override
  void dispose() {
    // Ekrandan çıkıldığında sesli telaffuz motorunu durdur
    TtsService.instance.stop();
    super.dispose();
  }

  /// Sıradaki kelimenin tür ve sözlük verilerini gecikmesiz göstermek için önbelleğe alır
  void _prefetchCurrentCardDetails() {
    if (_remainingCards.isEmpty) return;
    final word = _remainingCards.first['word']?.toString().trim().toLowerCase() ?? '';
    if (word.isNotEmpty && !_definitionCache.containsKey(word)) {
      DictionaryService.instance.fetchWordMeaning(word).then((result) {
        if (mounted) {
          setState(() {
            _definitionCache[word] = result;
          });
        }
      }).catchError((_) {});
    }
  }

  /// Kullanıcıya kısa süreli başarı/motivasyon bildirimi fırlatır
  void _triggerCheer(String message) {
    setState(() => _cheerMessage = message);
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted && _cheerMessage == message) {
        setState(() => _cheerMessage = null);
      }
    });
  }

  /// SRS Algoritması: Kullanıcının verdiği cevaba (0: Tekrar, 1: Zor, 2: Bildim) göre ilerlemeyi işler
  void _handleSrsRating(int rating) {
    if (_remainingCards.isEmpty || _isProcessing) return;

    _isProcessing = true;
    TtsService.instance.stop();

    // Dokunma / Haptic geri bildirimi sağla
    if (rating == 2) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }

    final currentCard = _remainingCards.first;
    final int cardId = currentCard['id'] as int? ?? 0;
    int currentReps = currentCard['repetitions'] as int? ?? 0;
    int currentInterval = currentCard['interval'] as int? ?? 1;

    int newReps = currentReps;
    int newInterval = currentInterval;
    bool isNowMastered = false;
    int xpGain = 0;

    // --- 1. CEVAP PUANLAMA & SRS HESAPLAMA MANTIĞI ---
    if (rating == 0) {
      // 🔴 TEKRAR (Unutuldu): Tekrar sayısı sıfırlanır, aralık 1 güne iner, zorlanılanlara eklenir
      newReps = 0;
      newInterval = 1;
      _consecutiveKnownStreak = 0;
      _reviewCount++;
      _struggledCards.add(currentCard);

      if (_reviewCount % 3 == 0) {
        _triggerCheer(CoachMessages.getWrongAnswerEncouragement());
      }
    } else if (rating == 1) {
      // 🟠 ZOR (Hatırlandı ama zorlanıldı): Küçük bir aralık artışı ve hafif XP
      _hardCount++;
      _consecutiveKnownStreak = 0;
      _struggledCards.add(currentCard);
      newReps += 1;
      newInterval = (currentInterval * 1.3).round().clamp(1, 30);
      xpGain = 4;
    } else {
      // 🟢 BİLDİM (Rahat hatırlandı): Aralık katlanarak büyür, XP kazanılır
      _knownCount++;
      _consecutiveKnownStreak++;
      newReps += 1;
      newInterval = (currentInterval * 2.4).round().clamp(3, 120);
      xpGain = 6;

      // 🏆 5'te 5 Kalıcı Hafıza (Mastery) Kontrolü[cite: 3]
      if (newReps >= 5 && newInterval >= 21) {
        isNowMastered = true;
        if (!widget.isReviewOnly) {
          _masteredCountInSession++;
          xpGain += 15; // Mastery Özel Bonus XP'si
          HapticFeedback.heavyImpact();
          _triggerCheer('✨ MASTERED! "${currentCard['word']}" artık kalıcı hafızanda!');
        }
      } else if (newReps == 4) {
        // 4. Seviyeye ulaşan kelimeler için motivasyonel yakınlık mesajı[cite: 3]
        _triggerCheer('🔥 Kalıcı hafızaya son 1 adım kaldı!');
      } else {
        final cheer = CoachMessages.getFlashcardCheer(_consecutiveKnownStreak);
        if (cheer != null) {
          _triggerCheer(cheer);
        }
      }
    }

    // --- 2. VERİTABANI & XP SERVİSİ GÜNCELLEMESİ ---
    if (!widget.isReviewOnly) {
      if (xpGain > 0) {
        _totalEarnedXp += xpGain;
        XpShopService.instance.addXp(xpGain).catchError((_) => 0);
      }

      if (cardId > 0) {
        DatabaseHelper.instance.updateFlashcardSrsProgress(
          cardId: cardId,
          repetitions: newReps,
          interval: newInterval,
          isMastered: isNowMastered,
        ).catchError((_) {});
      }
    }

    // Kartı listeden kaldır ve durumları sıfırla
    setState(() {
      _remainingCards.removeAt(0);
      _isFlipped = false;
      _showHint = false;
      _isProcessing = false;
    });

    // Bir sonraki kartın verilerini hazırla
    _prefetchCurrentCardDetails();

    // Tüm kartlar bittiyse kutlama penceresini tetikle
    if (_remainingCards.isEmpty && !_celebrationShown) {
      _celebrationShown = true;
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        _finishSrs();
      });
    }
  }

  /// Egzersiz bittiğinde sonuç özetini ve kazanılan ödülleri gösteren diyalog[cite: 3]
  void _finishSrs() {
    if (widget.isReviewOnly) {
      Navigator.of(context).pop();
      return;
    }

    final feedback = CoachMessages.getFeedback(
      exerciseType: 'srs',
      score: _knownCount,
      total: _initialTotal,
    );

    final needsReviewCount = _reviewCount + _hardCount;

    CelebrationDialog.show(
      context,
      emoji: _masteredCountInSession > 0 ? '🏆' : feedback.emoji,
      title: _masteredCountInSession > 0 ? 'Kalıcı Hafızaya Yeni Kelime Eklendi!' : feedback.title,
      subtitle: _masteredCountInSession > 0 
          ? '$_masteredCountInSession kelimede 5\'te 5 yaparak ustalığa ulaştın.' 
          : feedback.subtitle,
      themeColor: _masteredCountInSession > 0 ? const Color(0xFFF59E0B) : feedback.themeColor,
      earnedXp: _totalEarnedXp,
      earnedGems: _knownCount == _initialTotal && _initialTotal >= 5 ? 5 : 0,
      totalWordsReviewed: _initialTotal,
      strengthenedWords: _knownCount,
      needsReviewWords: needsReviewCount,
      masteredWordsCount: _masteredCountInSession,
      actionLabel: feedback.actionLabel,
      onAction: () {
        Navigator.of(context).pop();
      },
      secondaryActionLabel: needsReviewCount > 0 
          ? '🧠 Zorlandıklarımı Tekrar Et ($needsReviewCount kelime)' 
          : null,
      onSecondaryAction: needsReviewCount > 0 
          ? () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => FlashcardsExerciseScreen(
                    cards: List.from(_struggledCards),
                    isReviewOnly: true,
                  ),
                ),
              );
            }
          : null,
    );
  }

  /// Seansın tahmini tamamlanma süresini hesaplar (Kart başı ortalama 15 saniye)[cite: 3]
  String _getEstimatedSessionTime() {
    int totalSec = _initialTotal * 15;
    int minutes = (totalSec / 60).ceil();
    return '~$minutes dk';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B14),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          children: [
            Text(
              widget.isReviewOnly ? 'Kelimeleri Gözden Geçir' : 'SRS Hafıza Egzersizi',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
            ),
            Text(
              '$_initialTotal kelime • ${_getEstimatedSessionTime()}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            _remainingCards.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                : _buildExerciseView(colors, textStyles),

            // Üst Motivasyon ve Başarı Banner'ı
            if (_cheerMessage != null)
              Positioned(
                top: 10,
                left: 20,
                right: 20,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 250),
                  offset: _cheerMessage != null ? Offset.zero : const Offset(0, -1.5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _cheerMessage!.contains('✨') || _cheerMessage!.contains('🏆')
                          ? const Color(0xFFF59E0B) 
                          : const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (_cheerMessage!.contains('✨') || _cheerMessage!.contains('🏆')
                              ? const Color(0xFFF59E0B) 
                              : const Color(0xFF10B981)).withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      _cheerMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Ana Egzersiz Görünümü (İlerleme çubuğu, Kaydırılabilir Kart ve Butonlar)[cite: 3]
  Widget _buildExerciseView(ColorScheme colors, TextTheme textStyles) {
    final currentCard = _remainingCards.first;
    final String currentWord = currentCard['word'] ?? '';
    final String? contextSentence = currentCard['context_sentence'] as String?;
    final String bookTitle = (currentCard['book_title'] as String?)?.trim().isNotEmpty == true 
        ? currentCard['book_title'] 
        : 'Kütüphanem';
    final String? chapterInfo = currentCard['chapter_info'] as String?;

    final int repetitions = currentCard['repetitions'] as int? ?? 0;
    final bool isAlreadyMastered = (currentCard['is_mastered'] as int? ?? 0) == 1;

    final int currentIndex = _initialTotal - _remainingCards.length + 1;

    final wordKey = currentWord.trim().toLowerCase();
    final defData = _definitionCache[wordKey];

    String effectiveMeaning = (currentCard['meaning'] as String? ?? '').trim();
    if (effectiveMeaning.isEmpty && defData != null) {
      effectiveMeaning = defData.primaryMeaning;
    }

    final String rawPos = defData?.partOfSpeech ?? '';
    final String formattedPos = _formatTurkishPos(rawPos);

    final bool hasValidContext = contextSentence != null && contextSentence.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        children: [
          // 1. ÜST İLERLEME VE DOĞRU/YANLIŞ SAYACI
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kelime $currentIndex / $_initialTotal',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                  fontSize: 13.5,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 4),
                  Text('$_knownCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  const SizedBox(width: 10),
                  const Icon(Icons.replay_circle_filled_rounded, color: Color(0xFFEF4444), size: 16),
                  const SizedBox(width: 4),
                  Text('$_reviewCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // İlerleme Çubuğu
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (currentIndex - 1) / _initialTotal,
              backgroundColor: const Color(0xFF111827),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 14),

          // 2. KAYDIRILABİLİR (DISMISSIBLE) 3D KART GÖVDESİ[cite: 3]
          Expanded(
            child: Dismissible(
              key: ValueKey('${currentCard['id']}_$currentIndex'),
              direction: _isFlipped && !_isProcessing
                  ? DismissDirection.horizontal 
                  : DismissDirection.none,
              // Yanlışlıkla kaydırmayı önlemek için %38 eşik koruması[cite: 3]
              dismissThresholds: const {
                DismissDirection.startToEnd: 0.38,
                DismissDirection.endToStart: 0.38,
              },
              confirmDismiss: (direction) async {
                if (_isProcessing) return false;
                return true;
              },
              onDismissed: (direction) {
                if (direction == DismissDirection.startToEnd) {
                  _handleSrsRating(2); // Sağa Kaydırma = BİLDİM[cite: 3]
                } else {
                  _handleSrsRating(0); // Sola Kaydırma = TEKRAR[cite: 3]
                }
              },
              // Sağa kaydırma arka planı (Yeşil - Bildim)[cite: 3]
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 30),
                    SizedBox(width: 8),
                    Text('BİLDİM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
              ),
              // Sola kaydırma arka planı (Kırmızı - Tekrar)[cite: 3]
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('TEKRAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    SizedBox(width: 8),
                    Icon(Icons.replay_rounded, color: Colors.white, size: 30),
                  ],
                ),
              ),
              child: GestureDetector(
                onTap: () {
                  if (_isProcessing) return;
                  HapticFeedback.selectionClick();
                  setState(() => _isFlipped = !_isFlipped);
                },
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2E),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isAlreadyMastered 
                          ? Colors.amber.withValues(alpha: 0.5) 
                          : (repetitions == 4 ? const Color(0xFFF59E0B).withValues(alpha: 0.5) : const Color(0xFF1E293B)),
                      width: (isAlreadyMastered || repetitions == 4) ? 2 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isAlreadyMastered 
                            ? Colors.amber.withValues(alpha: 0.2) 
                            : const Color(0xFF4F46E5).withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Kart Üst Başlık (Kitap Adı, Seviye Noktaları ve Ses Butonu)[cite: 3]
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.menu_book_rounded, size: 13, color: Color(0xFF818CF8)),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        '$bookTitle ${chapterInfo != null ? '• $chapterInfo' : ''}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF818CF8),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isAlreadyMastered)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                    ),
                                    child: const Text('🏆 Kalıcı Hafıza', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.amber)),
                                  )
                                else if (repetitions > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Row(
                                      children: List.generate(5, (dotIndex) {
                                        final bool isFilled = dotIndex < repetitions;
                                        return Container(
                                          width: 5.5,
                                          height: 5.5,
                                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isFilled ? const Color(0xFF10B981) : const Color(0xFF334155),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),

                                // Telaffuz Dinleme Butonu[cite: 3]
                                IconButton.filledTonal(
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF818CF8), size: 22),
                                  tooltip: 'Telaffuzu Dinle',
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    TtsService.instance.speakWord(currentWord);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Kelime ve Anlam Bölümü[cite: 3]
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentWord,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 32,
                                color: Colors.white,
                              ),
                            ),
                            if (formattedPos.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                formattedPos,
                                style: const TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF38BDF8),
                                ),
                              ),
                            ],
                            if (_isFlipped) ...[
                              const SizedBox(height: 12),
                              Text(
                                effectiveMeaning.isNotEmpty ? effectiveMeaning : 'anlam yükleniyor...',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF38BDF8),
                                ),
                              ),
                            ],
                          ],
                        ),

                        const Spacer(),

                        // Kitap Bağlam Cümlesi & İpucu[cite: 3]
                        if (hasValidContext) ...[
                          if (!_isFlipped) ...[
                            if (!_showHint)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFFFDE68A)),
                                label: const Text('Kitaptan İpucu Gör', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFDE68A))),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _showHint = true);
                                },
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                child: Text(
                                  '“${contextSentence.replaceAll(RegExp(RegExp.escape(currentWord), caseSensitive: false), '___')}”',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                '“$contextSentence”',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFFCBD5E1),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                        ],

                        // Dokunma İndikatörü[cite: 3]
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.touch_app_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 5),
                            Text(
                              _isFlipped ? 'Gizlemek için dokun' : 'Cevabı görmek için dokun',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. ALT CEVAP VE AKSİYON BUTONLARI[cite: 3]
          if (!_isFlipped)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.flip_rounded, size: 20),
                label: const Text('Cevabı Göster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: () {
                  if (_isProcessing) return;
                  HapticFeedback.selectionClick();
                  setState(() => _isFlipped = true);
                },
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildNaturalSrsButton(
                    title: 'Tekrar',
                    sub: 'Hatırlayamadım',
                    color: const Color(0xFFEF4444),
                    icon: Icons.replay_rounded,
                    onTap: () => _handleSrsRating(0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildNaturalSrsButton(
                    title: 'Zor',
                    sub: 'Zorlandım',
                    color: const Color(0xFFF59E0B),
                    icon: Icons.timelapse_rounded,
                    onTap: () => _handleSrsRating(1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _buildNaturalSrsButton(
                    title: 'Bildim',
                    sub: 'Rahat hatırladım',
                    color: const Color(0xFF10B981),
                    icon: Icons.check_circle_rounded,
                    onTap: () => _handleSrsRating(2),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Doğal SRS derecelendirme butonlarını oluşturan yardımcı widget[cite: 3]
  Widget _buildNaturalSrsButton({
    required String title,
    required String sub,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: color)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.85)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}