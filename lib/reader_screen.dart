// ============================================================================
// DOSYA ADI: lib/reader_screen.dart
// AÇIKLAMA: Akıllı Cümle Kırpmalı (Windowing), Gelişmiş Noktalama Bölücülü,
//            Fosforlu Kalem Destekli ve Stop-Word Korumalı SRS Reader Arayüzü
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

// Modeller, veritabanı yardımcıları ve harici servisler
import 'book_model.dart';
import 'database_helper.dart';
import 'dictionary_service.dart';
import 'tts_service.dart';
import 'coach_messages.dart';
import 'xp_shop_service.dart';
import 'celebration_dialog.dart';
import 'default_books.dart';

// Okuma ekranının tema paletleri (Sepya, Koyu, Açık)
enum ReaderTheme { light, sepia, dark }

// Font ailesi tercihi (Tırnaklı klasik kitap fontu / Tırnaksız modern font)
enum ReaderFont { serif, sans }

/// Okuma oturumu bittiğinde ana ekrana ve istatistiklere döndürülen sonuç modeli.
class ReadingSessionResult {
  final int durationSeconds; // Okuma yapılan toplam süre (saniye)
  final int wordsExamined;   // Üzerine tıklanıp sözlükte incelenen kelime sayısı
  final int wordsAdded;      // 'Kelimeyi Avla' denilerek koleksiyona eklenen yeni kelimeler
  final int lastPage;        // Kullanıcının kitabı bıraktığı son sayfa indeksi
  final int pagesRead;       // Bu oturumda çevrilen / okunan net sayfa sayısı
  final int earnedXp;        // Oturum sonunda kazanılan toplam deneyim puanı (XP)

  ReadingSessionResult({
    required this.durationSeconds,
    required this.wordsExamined,
    required this.wordsAdded,
    required this.lastPage,
    required this.pagesRead,
    required this.earnedXp,
  });
}

class ReaderScreen extends StatefulWidget {
  final Book book;                                   // Okunacak kitap verisi (içerik, sayfalar vb.)
  final Function(int pageIndex)? onPageChanged;      // Sayfa her değiştiğinde dışarıya haber veren callback

  const ReaderScreen({
    super.key,
    required this.book,
    this.onPageChanged,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  // Sayfa kaydırma kontrolcüsü (PageView)
  late PageController _pageController;

  // Mevcut aktif sayfa ve oturumun başladığı ilk sayfa (okunan net sayfa farkını bulmak için)
  late int _currentPage;
  late int _initialStartPage;

  // Okuma tipografisi ve tema ayarları
  double _fontSize = 17.5;                           // Varsayılan metin boyutu (pt)
  ReaderTheme _currentTheme = ReaderTheme.sepia;      // Varsayılan tema (Göz yormayan sepya)
  final ReaderFont _currentFont = ReaderFont.serif;  // Tipografi türü

  // Arayüz durum değişkenleri
  bool _showControls = true;                          // Üst ve alt menü çubuklarının görünürlüğü
  String? _selectedWord;                             // O an modalda incelenen kelimenin saf hali
  bool _isExiting = false;                            // Çıkış işleminin birden fazla kez tetiklenmesini önleyen bayrak

  // Fosforlu kalem işaretlemeleri ve performans önbellekleri
  final List<Map<String, dynamic>> _pageHighlightData = []; // Bu sayfadaki boyanmış kelime aralıkları
  final Map<int, List<InlineSpan>> _spansCache = {};        // Sayfaların TextSpan ağacını tutan önbellek

  // Oturum ve İlerleme Takip Değişkenleri
  DateTime _sessionStartTime = DateTime.now();       // Kronometrenin başladığı an
  int _wordsExaminedCount = 0;                       // Oturumda dokunulan kelime sayısı
  int _wordsAddedCount = 0;                          // Oturumda avlanan kelime sayısı

  // Koçluk ve Süre Bildirimleri
  Timer? _sessionTimer;                              // Arka planda her saniye işleyen oturum sayacı
  int _sessionSeconds = 0;                           // Geçen toplam saniye
  bool _notified15Min = false;                       // 15. dakika tebrik mesajının gösterilip gösterilmediği
  bool _notified30Min = false;                       // 30. dakika tebrik mesajının gösterilip gösterilmediği
  String? _activeCoachToast;                         // Ekranda yüzen koçluk mesajı kutusu

  // İngilizce dilbilgisi kısaltmalarını Türkçe etiketlere çeviren sözlük
  static const Map<String, String> _posTranslations = {
    'noun': 'İsim',
    'verb': 'Fiil',
    'adjective': 'Sıfat',
    'adverb': 'Zarf',
    'pronoun': 'Zamir',
    'preposition': 'Edat',
    'conjunction': 'Bağlaç',
    'interjection': 'Ünlem',
    'article': 'Belirteç',
    'phrase': 'Deyim / İfade',
  };

  /// İngilizce kelime türünü (POS) Türkçeleştirir.
  String _getTurkishPos(String? pos) {
    if (pos == null || pos.trim().isEmpty) return '';
    final clean = pos.trim().toLowerCase();
    return _posTranslations[clean] ?? pos.toUpperCase();
  }

  /// Kelimenin başındaki ve sonundaki tırnak, parantez, noktalama gibi yabancı karakterleri temizler.
  /// TIKLAMA ÖZGÜRLÜĞÜ: Stop-word kısıtlaması buradan kaldırıldı. 'see', 'of', 'that' gibi
  /// tüm kelimelerin sözlük modalının açılmasına izin verilir.
  String _cleanWordText(String raw) {
    return raw.replaceAll(
      RegExp(r'''^[\s"“”'‘’\(\)\[\]\{\}\.,;:!?\-—_]+|[\s"“”'‘’\(\)\[\]\{\}\.,;:!?\-—_]+$'''), 
      '',
    ).trim();
  }

  /// Kelimenin stop-word veya temel gramer kelimesi olup olmadığını doğrular.
  /// Büyük/küçük harf duyarsızlığı ve kesme işaretli ekleri (örn: "that's" -> "that") normalize eder.
  bool _isLearnableTargetWord(String word) {
    var normalized = word.toLowerCase().trim();
    if (normalized.contains("'")) {
      normalized = normalized.split("'")[0];
    }
    if (normalized.contains("’")) {
      normalized = normalized.split("’")[0];
    }
    return DefaultBooksManager.isValidWordToSave(normalized);
  }

  /// Sözlük API'sinde arama yaparken kesme işaretli ekleri temizleyip yalın kökü hazırlar.
  String _getLookupWord(String word) {
    var lookup = word.trim();
    if (lookup.contains("'")) {
      lookup = lookup.split("'")[0];
    }
    if (lookup.contains("’")) {
      lookup = lookup.split("’")[0];
    }
    return lookup.trim();
  }

  /// [WINDOWING MEKANİZMASI]
  /// Cümle aşırı uzun olduğunda (16 kelimeden fazla), hedef kelimenin 6 kelime öncesi
  /// ve 6 kelime sonrasını alıp araya '...' koyarak temiz, odaklı bir bağlam cümlesi üretir.
  String _formatContextSentence(String fullSentence, int wordIndexInSentence) {
    final words = fullSentence.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length <= 16) {
      return fullSentence.trim();
    }

    final safeIdx = wordIndexInSentence.clamp(0, words.length - 1);
    final start = (safeIdx - 6).clamp(0, words.length);
    final end = (safeIdx + 7).clamp(0, words.length);

    final subList = words.sublist(start, end);
    var snippet = subList.join(' ');

    if (start > 0) snippet = '...$snippet';
    if (end < words.length) snippet = '$snippet...';

    return snippet.trim();
  }

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _currentPage = widget.book.currentPage.clamp(0, widget.book.totalPages - 1);
    _initialStartPage = _currentPage;
    _pageController = PageController(initialPage: _currentPage);
    
    TtsService.instance.initService();
    _startSessionCoachTimer();
    _loadHighlightsForCurrentPage(_currentPage);
  }

  Future<void> _loadHighlightsForCurrentPage(int pageIndex) async {
    try {
      final rawHighlights = await DatabaseHelper.instance.getHighlightsForPage(widget.book.id, pageIndex);
      final data = rawHighlights.map((h) => {
        'start': h['start_word_index'] as int? ?? 0,
        'end': h['end_word_index'] as int? ?? 0,
        'color': h['color_tag'] as String? ?? 'yellow',
      }).toList();

      if (mounted) {
        setState(() {
          _pageHighlightData.clear();
          _pageHighlightData.addAll(data);
          _spansCache.remove(pageIndex);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    TtsService.instance.stop();
    _pageController.dispose();
    _spansCache.clear();
    super.dispose();
  }

  void _startSessionCoachTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _sessionSeconds++;

      if (_sessionSeconds == 900 && !_notified15Min) {
        _notified15Min = true;
        _showCoachToast(CoachMessages.getReadingTimeCheer15Min());
      } else if (_sessionSeconds == 1800 && !_notified30Min) {
        _notified30Min = true;
        _showCoachToast(CoachMessages.getReadingTimeCheer30Min());
      }
    });
  }

  void _showCoachToast(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _activeCoachToast = message);
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted && _activeCoachToast == message) {
        setState(() => _activeCoachToast = null);
      }
    });
  }

  Future<void> _handleExit() async {
    if (_isExiting) return;
    _isExiting = true;

    HapticFeedback.lightImpact();
    TtsService.instance.stop();

    final duration = DateTime.now().difference(_sessionStartTime);
    final totalSeconds = duration.inSeconds;

    int pagesDelta = _currentPage - _initialStartPage;
    int pagesRead = pagesDelta > 0 ? pagesDelta : (totalSeconds >= 20 ? 1 : 0);

    final calculatedXp = (pagesRead * 10) + (_wordsAddedCount * 15);
    if (calculatedXp > 0) {
      XpShopService.instance.addXp(calculatedXp).catchError((_) => 0);
    }

    final safeTotalPages = widget.book.totalPages <= 0 ? 1 : widget.book.totalPages;
    await DatabaseHelper.instance.updateBookReadingProgress(
      bookId: widget.book.id,
      bookTitle: widget.book.title,
      currentPage: _currentPage,
      totalPages: safeTotalPages,
      chapterInfo: 'Sayfa ${_currentPage + 1}',
      additionalSeconds: totalSeconds,
    ).catchError((_) {});

    final result = ReadingSessionResult(
      durationSeconds: totalSeconds,
      wordsExamined: _wordsExaminedCount,
      wordsAdded: _wordsAddedCount,
      lastPage: _currentPage,
      pagesRead: pagesRead,
      earnedXp: calculatedXp,
    );

    if (!mounted) return;

    if (pagesRead > 0 || _wordsAddedCount > 0) {
      final int minutes = (totalSeconds / 60).ceil();
      CelebrationDialog.show(
        context,
        emoji: _wordsAddedCount >= 3 ? '🏹' : '📖',
        title: _wordsAddedCount >= 3 ? 'Usta Kelime Avcısı!' : 'Okuma Oturumu Tamamlandı!',
        subtitle: '$minutes dakikada $pagesRead sayfa okudun ve $_wordsAddedCount yeni kelimeyi koleksiyonuna kattın.',
        themeColor: const Color(0xFF10B981),
        earnedXp: calculatedXp,
        totalWordsReviewed: _wordsExaminedCount,
        strengthenedWords: _wordsAddedCount,
        actionLabel: 'Lobiye Dön',
        onAction: () {
          Navigator.pop(context, result);
        },
      );
    } else {
      Navigator.pop(context, result);
    }
  }

  // --- TEMA VE RENK PALETİ GETTER'LARI ---

  Color get _backgroundColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia: return const Color(0xFFF4ECD8);
      case ReaderTheme.dark:  return const Color(0xFF070B14);
      case ReaderTheme.light: return const Color(0xFFFAF9F6);
    }
  }

  Color get _textColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia: return const Color(0xFF2C241D);
      case ReaderTheme.dark:  return const Color(0xFFE2E8F0);
      case ReaderTheme.light: return const Color(0xFF1E293B);
    }
  }

  Color get _surfacePanelColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia: return const Color(0xFFE5DAC0);
      case ReaderTheme.dark:  return const Color(0xFF111827);
      case ReaderTheme.light: return const Color(0xFFF1F5F9);
    }
  }

  Color get _panelBorderColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia: return const Color(0xFFD3C3A3);
      case ReaderTheme.dark:  return const Color(0xFF1F2937);
      case ReaderTheme.light: return const Color(0xFFE2E8F0);
    }
  }

  Color get _accentColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia: return const Color(0xFFB45309);
      case ReaderTheme.dark:  return const Color(0xFFF59E0B);
      case ReaderTheme.light: return const Color(0xFF2563EB);
    }
  }

  Color get _sliderInactiveColor {
    switch (_currentTheme) {
      case ReaderTheme.dark:  return const Color(0xFF1F2937);
      case ReaderTheme.sepia: return const Color(0xFFD3C3A3);
      case ReaderTheme.light: return const Color(0xFFCBD5E1);
    }
  }

  Color _getHighlightColorBg(String colorTag) {
    switch (colorTag) {
      case 'green':
        return _currentTheme == ReaderTheme.dark
            ? const Color(0xFF059669).withValues(alpha: 0.40)
            : const Color(0xFFA7F3D0).withValues(alpha: 0.70);
      case 'blue':
        return _currentTheme == ReaderTheme.dark
            ? const Color(0xFF2563EB).withValues(alpha: 0.40)
            : const Color(0xFFBFDBFE).withValues(alpha: 0.70);
      case 'yellow':
      default:
        return _currentTheme == ReaderTheme.dark
            ? const Color(0xFFFBBF24).withValues(alpha: 0.35)
            : (_currentTheme == ReaderTheme.sepia ? const Color(0xFFFCD34D).withValues(alpha: 0.65) : const Color(0xFFFEF08A));
    }
  }

  TextStyle get _readerTextStyle {
    return TextStyle(
      fontSize: _fontSize,
      height: 1.8,
      letterSpacing: 0.25,
      fontFamily: _currentFont == ReaderFont.serif ? 'serif' : 'sans-serif',
      color: _textColor,
    );
  }

  String _normalizePdfText(String rawText) {
    String text = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text.replaceAll(RegExp(r'\n\s*\n+'), ' ');
    text = text.replaceAll('\n', ' ');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    return text.trim();
  }

  Future<void> _applyHighlight(int pageIndex, int startIndex, int endIndex, String colorTag) async {
    HapticFeedback.mediumImpact();
    
    final existingIndex = _pageHighlightData.indexWhere(
      (r) => r['start'] == startIndex && r['end'] == endIndex,
    );

    if (existingIndex >= 0 && _pageHighlightData[existingIndex]['color'] == colorTag) {
      await DatabaseHelper.instance.removeHighlightRange(
        bookId: widget.book.id,
        pageIndex: pageIndex,
        startIndex: startIndex,
        endIndex: endIndex,
      );
      setState(() {
        _pageHighlightData.removeAt(existingIndex);
        _spansCache.remove(pageIndex);
      });
    } else {
      if (existingIndex >= 0) {
        await DatabaseHelper.instance.removeHighlightRange(
          bookId: widget.book.id,
          pageIndex: pageIndex,
          startIndex: startIndex,
          endIndex: endIndex,
        );
      }
      await DatabaseHelper.instance.addHighlightRange(
        bookId: widget.book.id,
        pageIndex: pageIndex,
        startIndex: startIndex,
        endIndex: endIndex,
        colorTag: colorTag,
      );
      await _loadHighlightsForCurrentPage(pageIndex);
    }
  }

  Future<void> _removeHighlight(int pageIndex, int startIndex, int endIndex) async {
    HapticFeedback.mediumImpact();
    await DatabaseHelper.instance.removeHighlightRange(
      bookId: widget.book.id,
      pageIndex: pageIndex,
      startIndex: startIndex,
      endIndex: endIndex,
    );
    await _loadHighlightsForCurrentPage(pageIndex);
  }

  Widget _buildStateBadge(String state) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (state) {
      case 'MASTERED':
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF34D399);
        label = 'Usta (Mastered)';
        icon = Icons.check_circle_rounded;
        break;
      case 'FAMILIAR':
        bg = const Color(0xFFFBBF24).withValues(alpha: 0.15);
        fg = const Color(0xFFFDE68A);
        label = 'Aşina';
        icon = Icons.verified_outlined;
        break;
      case 'REVIEWING':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        fg = const Color(0xFFF59E0B);
        label = 'Tekrarda';
        icon = Icons.loop_rounded;
        break;
      case 'LEARNING':
        bg = const Color(0xFF818CF8).withValues(alpha: 0.15);
        fg = const Color(0xFF818CF8);
        label = 'Öğreniliyor';
        icon = Icons.auto_stories_rounded;
        break;
      case 'DISCOVERED':
      default:
        bg = const Color(0xFF38BDF8).withValues(alpha: 0.15);
        fg = const Color(0xFF38BDF8);
        label = 'Keşfedildi';
        icon = Icons.search_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.outfit(color: fg, fontSize: 10, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  /// Kelimeye tıklandığında alttan açılan sözlük ve kelime inceleme penceresi.
  Future<void> _showWordDetails(
    String word, 
    int pageIndex, 
    int globalWordIndex, 
    int? sentenceStart, 
    int? sentenceEnd,
    String contextSentence,
  ) async {
    final cleanWord = _cleanWordText(word);
    if (cleanWord.isEmpty) return;

    final isLearnable = _isLearnableTargetWord(cleanWord);
    final lookupWord = _getLookupWord(cleanWord);

    HapticFeedback.lightImpact();
    setState(() {
      _selectedWord = cleanWord;
      _wordsExaminedCount++;
      _spansCache.remove(pageIndex);
    });

    if (!mounted) return;

    final safeStart = sentenceStart ?? globalWordIndex;
    final safeEnd = sentenceEnd ?? globalWordIndex;

    bool isWordHighlighted = _pageHighlightData.any((h) => h['start'] == globalWordIndex && h['end'] == globalWordIndex);
    bool isSentenceHighlighted = _pageHighlightData.any((h) => h['start'] == safeStart && h['end'] == safeEnd);

    // Modal açılmadan önce veritabanındaki kayıt durumunu sorgula
    final initialCardQuery = await DatabaseHelper.instance.database.then((db) => db.query(
      'flashcards',
      where: 'word = ? COLLATE NOCASE',
      whereArgs: [cleanWord],
      limit: 1,
    ));

    bool isAddedToStudyPool = false;
    String currentLearningState = 'DISCOVERED';
    if (initialCardQuery.isNotEmpty) {
      currentLearningState = initialCardQuery.first['learning_state'] as String? ?? 'LEARNING';
      isAddedToStudyPool = currentLearningState != 'DISCOVERED';
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: _surfacePanelColor,
      isScrollControlled: true,
      elevation: 16,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FutureBuilder<WordDefinitionResult>(
              // Kesme işaretli ekleri temizlenmiş kök ile sözlük araması yapılır
              future: DictionaryService.instance.fetchWordMeaning(lookupWord),
              builder: (context, snapshot) {
                final isLoading = snapshot.connectionState == ConnectionState.waiting;
                final result = snapshot.data;
                final isOffline = result?.isOfflineError ?? false;

                final rawMeaning = result?.alternativeMeanings.take(3).join(', ') ?? result?.primaryMeaning ?? '';
                final hasValidMeaning = rawMeaning.trim().isNotEmpty && rawMeaning.trim() != 'Tanım yok';

                // VERİTABANI KORUMASI: Sadece öğrenilebilir gerçek kelimeler 'DISCOVERED' olarak kaydedilir.
                // Stop-word veya temel gramer kelimeleri ('see', 'of', 'that') veritabanına sessizce yazılmaz!
                if (!isLoading && hasValidMeaning && !isAddedToStudyPool && isLearnable) {
                  DatabaseHelper.instance.discoverWord(
                    word: cleanWord,
                    meaning: rawMeaning,
                    contextSentence: contextSentence.trim(),
                    bookTitle: widget.book.title,
                  );
                }

                return Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
                  ),
                  child: SafeArea(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        22, 
                        12, 
                        22, 
                        MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: _textColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 1. ÜST BAŞLIK: Kelime, Fonetik, Rozet ve Telaffuz Butonu
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            cleanWord,
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'serif',
                                              color: _textColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // ROZET KORUMASI: Stop-word kelimelerde veya henüz havuza eklenmemiş temel kelimelerde rozet gizlenir
                                        if (isAddedToStudyPool || isLearnable)
                                          _buildStateBadge(isAddedToStudyPool ? currentLearningState : 'DISCOVERED'),
                                      ],
                                    ),
                                    if (result?.phonetic != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        result!.phonetic!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: _accentColor,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isAddedToStudyPool)
                                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 24),
                                  const SizedBox(width: 6),
                                  IconButton.filledTonal(
                                    style: IconButton.styleFrom(
                                      backgroundColor: _accentColor.withValues(alpha: 0.15),
                                    ),
                                    icon: Icon(Icons.volume_up_rounded, size: 20, color: _accentColor),
                                    tooltip: 'Telaffuzu Dinle',
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      TtsService.instance.speakWord(cleanWord);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 2. SÖZLÜK ANLAMLARI VE ÇEVRİMDIŞI DURUMU
                          if (isLoading) ...[
                            Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Gelişmiş sözlük taranıyor...',
                                  style: TextStyle(fontSize: 13, color: _textColor.withValues(alpha: 0.7)),
                                ),
                              ],
                            ),
                          ] else if (isOffline && !hasValidMeaning) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.wifi_off_rounded, color: Color(0xFFF59E0B), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Çevrimdışısınız. İnternet bağlandığında otomatik güncellenecektir.',
                                      style: TextStyle(fontSize: 11.5, color: _textColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            if (result?.partOfSpeech != null && result!.partOfSpeech!.isNotEmpty) ...[
                              Text(
                                _getTurkishPos(result.partOfSpeech).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: _textColor.withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: (result?.alternativeMeanings ?? [result?.primaryMeaning ?? ''])
                                  .where((m) => m.trim().isNotEmpty)
                                  .map((mean) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _accentColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: _accentColor.withValues(alpha: 0.25)),
                                        ),
                                        child: Text(
                                          mean,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: _accentColor,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],

                          const SizedBox(height: 10),

                          // 3. BAĞLAM CÜMLESİ (Kırpılmış & Odaklanmış)
                          if (contextSentence.trim().isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _textColor.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _panelBorderColor.withValues(alpha: 0.6)),
                              ),
                              child: Text(
                                '“$contextSentence”',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontStyle: FontStyle.italic,
                                  color: _textColor.withValues(alpha: 0.8),
                                ),
                              ),
                            ),

                          const SizedBox(height: 10),

                          // 4. FOSFORLU KALEM BUTONLARI (Tek Kelime)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'FOSFORLU KALEM (KELİME)',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: _textColor.withValues(alpha: 0.6)),
                              ),
                              if (isWordHighlighted)
                                GestureDetector(
                                  onTap: () async {
                                    await _removeHighlight(pageIndex, globalWordIndex, globalWordIndex);
                                    if (!sheetContext.mounted) return;
                                    Navigator.pop(sheetContext);
                                  },
                                  child: Text('İşareti Kaldır', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red[400])),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: _buildColorButton(sheetContext, pageIndex, globalWordIndex, globalWordIndex, 'yellow', 'Sarı', Colors.amber.shade700),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildColorButton(sheetContext, pageIndex, globalWordIndex, globalWordIndex, 'green', 'Yeşil', Colors.green.shade700),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildColorButton(sheetContext, pageIndex, globalWordIndex, globalWordIndex, 'blue', 'Mavi', Colors.blue.shade700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 5. FOSFORLU KALEM BUTONLARI (Tüm Cümle)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'FOSFORLU KALEM (TÜM CÜMLE)',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: _textColor.withValues(alpha: 0.6)),
                              ),
                              if (isSentenceHighlighted)
                                GestureDetector(
                                  onTap: () async {
                                    await _removeHighlight(pageIndex, safeStart, safeEnd);
                                    if (!sheetContext.mounted) return;
                                    Navigator.pop(sheetContext);
                                  },
                                  child: Text('Cümle İşaretini Kaldır', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red[400])),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: _buildColorButton(sheetContext, pageIndex, safeStart, safeEnd, 'yellow', 'Sarı (Cümle)', Colors.amber.shade700),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildColorButton(sheetContext, pageIndex, safeStart, safeEnd, 'green', 'Yeşil (Cümle)', Colors.green.shade700),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildColorButton(sheetContext, pageIndex, safeStart, safeEnd, 'blue', 'Mavi (Cümle)', Colors.blue.shade700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 6. ANA AKSİYON BUTONU
                          // LEGACY & STOP-WORD KORUMASI:
                          // - Eğer eski sürümlerde havuza eklenmişse: Kullanıcıya silme imkanı tanınır (Koleksiyondan Kaldır - Kırmızı).
                          // - Yeni bir stop-word ise: Buton soluk gri (disabled) kalarak kullanıcıyı bilgilendirir.
                          // - Normal kelime ise: Standart yeşil "Kelimeyi Avla & Öğren" butonu çalışır.
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: isAddedToStudyPool
                                ? FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                      foregroundColor: const Color(0xFFEF4444),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                                      ),
                                    ),
                                    onPressed: () async {
                                      HapticFeedback.heavyImpact();
                                      setSheetState(() {
                                        isAddedToStudyPool = false;
                                        currentLearningState = 'DISCOVERED';
                                      });
                                      if (mounted) setState(() {});

                                      await DatabaseHelper.instance.demoteToDiscovered(cleanWord);

                                      if (!sheetContext.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          behavior: SnackBarBehavior.floating,
                                          content: Text('"$cleanWord" koleksiyondan çıkarıldı.'),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    icon: const Icon(PhosphorIcons.trashBold, size: 18, color: Color(0xFFEF4444)),
                                    label: Text(
                                      'KOLEKSİYONDAN KALDIR',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w900, 
                                        fontSize: 13, 
                                        letterSpacing: 0.3,
                                        color: const Color(0xFFEF4444),
                                      ),
                                    ),
                                  )
                                : (!isLearnable)
                                    ? FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: _textColor.withValues(alpha: 0.08),
                                          foregroundColor: _textColor.withValues(alpha: 0.45),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            side: BorderSide(color: _panelBorderColor.withValues(alpha: 0.5)),
                                          ),
                                        ),
                                        onPressed: null, // Buton pasif (disabled)
                                        icon: Icon(
                                          PhosphorIcons.infoBold, 
                                          size: 18, 
                                          color: _textColor.withValues(alpha: 0.45),
                                        ),
                                        label: Text(
                                          'TEMEL KELİME (HAVUZA EKLENEMEZ)',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w800, 
                                            fontSize: 12, 
                                            letterSpacing: 0.3,
                                            color: _textColor.withValues(alpha: 0.45),
                                          ),
                                        ),
                                      )
                                    : FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: isLoading 
                                              ? const Color(0xFF10B981).withValues(alpha: 0.5) 
                                              : const Color(0xFF10B981),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                        onPressed: () async {
                                          HapticFeedback.heavyImpact();

                                          if (isLoading) {
                                            if (!sheetContext.mounted) return;
                                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                                              const SnackBar(
                                                behavior: SnackBarBehavior.floating,
                                                content: Text('Kelime anlamı yüklenirken lütfen bekleyin...'),
                                                duration: Duration(seconds: 1),
                                              ),
                                            );
                                            return;
                                          }

                                          setSheetState(() {
                                            isAddedToStudyPool = true;
                                            currentLearningState = 'LEARNING';
                                          });
                                          if (mounted) {
                                            setState(() {
                                              _wordsAddedCount++;
                                            });
                                          }

                                          final saveMeaning = hasValidMeaning 
                                              ? rawMeaning 
                                              : 'kelime anlamı';

                                          await DatabaseHelper.instance.addFlashcard(
                                            cleanWord, 
                                            saveMeaning,
                                            contextSentence: contextSentence.trim(),
                                            bookTitle: widget.book.title,
                                            chapterInfo: 'Sayfa ${pageIndex + 1}',
                                            learningState: 'LEARNING',
                                          );

                                          _showCoachToast('🏹 +1 Kelime Avlandı! ("$cleanWord" • Öğrenme Havuzunda)');
                                        },
                                        icon: const Icon(PhosphorIcons.crosshairBold, size: 18, color: Colors.white),
                                        label: Text(
                                          isLoading ? 'Anlam Yükleniyor...' : '🎯 KELİMEYİ AVLA & ÖĞREN',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w900, 
                                            fontSize: 13, 
                                            letterSpacing: 0.3,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _selectedWord = null;
          _spansCache.remove(pageIndex);
        });
      }
    });
  }

  Widget _buildColorButton(BuildContext sheetContext, int pageIndex, int start, int end, String colorTag, String label, Color dotColor) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        side: BorderSide(color: _panelBorderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: _backgroundColor.withValues(alpha: 0.4),
      ),
      onPressed: () async {
        await _applyHighlight(pageIndex, start, end, colorTag);
        if (!sheetContext.mounted) return;
        Navigator.pop(sheetContext);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _textColor),
            ),
          ),
        ],
      ),
    );
  }

  /// [METİN AYRIŞTIRICI & SPAN ÜRETİCİ]
  /// Sayfa metnini ayrıştırır; noktalı virgül, iki nokta ve diyalog tırnaklarına göre
  /// edebi cümle bloklarına böler. Her kelimeye global index verip tıklanabilirlik kazandırır.
  List<InlineSpan> _buildOptimizedSpans(int pageIndex) {
    if (_spansCache.containsKey(pageIndex)) {
      return _spansCache[pageIndex]!;
    }

    final pageContent = (widget.book.pages.isNotEmpty && pageIndex < widget.book.pages.length)
        ? widget.book.pages[pageIndex]
        : '';

    if (pageContent.trim().isEmpty) {
      final fallback = [
        TextSpan(
          text: 'Bu sayfada görüntülenecek metin bulunamadı.',
          style: _readerTextStyle.copyWith(fontStyle: FontStyle.italic),
        ),
      ];
      _spansCache[pageIndex] = fallback;
      return fallback;
    }

    final clean = _normalizePdfText(pageContent);
    // Gelişmiş Noktalama Bölücüsü: Noktalı virgül, iki nokta ve tırnak boşluklarını da yakalar
    final regExp = RegExp(r'(?<=[.!?;:])\s+|(?<=[”"])\s+');
    var sentences = clean.split(regExp).where((s) => s.trim().length > 1).toList();
    if (sentences.isEmpty && clean.isNotEmpty) {
      sentences = [clean];
    }

    final spans = <InlineSpan>[];
    int globalWordCounter = 0;

    for (int s = 0; s < sentences.length; s++) {
      final sentence = sentences[s];
      final words = sentence.split(' ').where((w) => w.isNotEmpty).toList();

      if (words.isEmpty) continue;

      final sentenceStartIndex = globalWordCounter;
      final sentenceEndIndex = globalWordCounter + words.length - 1;

      for (int w = 0; w < words.length; w++) {
        final word = words[w];
        final currentWordIndex = globalWordCounter++;
        final cleanWord = _cleanWordText(word);
        final isSelected = _selectedWord != null && _selectedWord == cleanWord;

        String? matchedColorTag;
        for (var h in _pageHighlightData) {
          final start = h['start'] as int? ?? 0;
          final end = h['end'] as int? ?? 0;
          if ((start == end && start == currentWordIndex) || (currentWordIndex >= start && currentWordIndex <= end)) {
            matchedColorTag = h['color'] as String?;
            break;
          }
        }

        Color bg = Colors.transparent;
        if (isSelected) {
          bg = _accentColor.withValues(alpha: 0.35);
        } else if (matchedColorTag != null) {
          bg = _getHighlightColorBg(matchedColorTag);
        }

        final windowedContext = _formatContextSentence(sentence, w);

        spans.add(
          TextSpan(
            text: '$word ',
            style: _readerTextStyle.copyWith(
              backgroundColor: bg,
              fontWeight: matchedColorTag != null ? FontWeight.w600 : FontWeight.normal,
              color: _textColor,
            ),
            recognizer: TapGestureRecognizer()..onTap = () => _showWordDetails(
              word, 
              pageIndex, 
              currentWordIndex, 
              sentenceStartIndex, 
              sentenceEndIndex,
              windowedContext,
            ),
          ),
        );
      }
    }

    _spansCache[pageIndex] = spans;
    return spans;
  }

  void _openSettingsBottomSheet() {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: _surfacePanelColor,
      isScrollControlled: true,
      elevation: 24,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return Container(
          color: _surfacePanelColor,
          padding: EdgeInsets.fromLTRB(22, 16, 22, MediaQuery.of(context).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _textColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _panelBorderColor),
                ),
                child: Row(
                  children: [
                    Text('A', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textColor)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: _accentColor,
                          inactiveTrackColor: _sliderInactiveColor,
                          thumbColor: _accentColor,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        ),
                        child: Slider(
                          value: _fontSize,
                          min: 14.0,
                          max: 26.0,
                          divisions: 8,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _fontSize = val;
                              _spansCache.clear();
                            });
                          },
                        ),
                      ),
                    ),
                    Text('A', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textColor)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildColorCard(ReaderTheme.dark, const Color(0xFF070B14), 'Gece', const Color(0xFFE2E8F0)),
                  _buildColorCard(ReaderTheme.sepia, const Color(0xFFF4ECD8), 'Sepya', const Color(0xFF2C241D)),
                  _buildColorCard(ReaderTheme.light, const Color(0xFFFAF9F6), 'Klasik', const Color(0xFF1E293B)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColorCard(ReaderTheme theme, Color bgPreviewColor, String label, Color fontColor) {
    final isSelected = (_currentTheme == theme);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _currentTheme = theme;
              _spansCache.clear();
            });
            Navigator.pop(context);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: bgPreviewColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? _accentColor : _panelBorderColor, width: isSelected ? 2.5 : 1),
            ),
            child: Column(
              children: [
                Text('Aa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'serif', color: fontColor)),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: fontColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleExit();
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: Stack(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _showControls = !_showControls);
              },
              behavior: HitTestBehavior.opaque,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.book.totalPages,
                onPageChanged: (pageIndex) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _currentPage = pageIndex;
                    widget.book.currentPage = pageIndex;
                  });
                  widget.onPageChanged?.call(pageIndex);
                  _loadHighlightsForCurrentPage(pageIndex);

                  final safeTotal = widget.book.totalPages <= 0 ? 1 : widget.book.totalPages;
                  DatabaseHelper.instance.updateBookReadingProgress(
                    bookId: widget.book.id,
                    bookTitle: widget.book.title,
                    currentPage: pageIndex,
                    totalPages: safeTotal,
                    chapterInfo: 'Sayfa ${pageIndex + 1}',
                  ).catchError((_) {});
                },
                itemBuilder: (context, index) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(26, MediaQuery.of(context).padding.top + 54, 26, MediaQuery.of(context).padding.bottom + 64),
                    child: Text.rich(TextSpan(children: _buildOptimizedSpans(index))),
                  );
                },
              ),
            ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              top: _showControls ? 0 : -150,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: _surfacePanelColor,
                  border: Border(bottom: BorderSide(color: _panelBorderColor)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _textColor),
                      onPressed: _handleExit,
                    ),
                    Expanded(
                      child: Text(
                        widget.book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textColor),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(PhosphorIcons.crosshairBold, size: 13, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text(
                            '$_wordsAddedCount Av',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              bottom: _showControls ? 0 : -90,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: _surfacePanelColor,
                  border: Border(top: BorderSide(color: _panelBorderColor)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))],
                ),
                padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
                child: Row(
                  children: [
                    Text('${_currentPage + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textColor)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          activeTrackColor: _accentColor,
                          inactiveTrackColor: _sliderInactiveColor,
                          thumbColor: _accentColor,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        ),
                        child: Slider(
                          value: _currentPage.toDouble(),
                          min: 0,
                          max: (widget.book.totalPages - 1).toDouble().clamp(0, double.infinity),
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            final newPage = val.toInt();
                            _pageController.jumpToPage(newPage);
                            _loadHighlightsForCurrentPage(newPage);
                          },
                        ),
                      ),
                    ),
                    Text('${widget.book.totalPages}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textColor.withValues(alpha: 0.6))),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: _accentColor.withValues(alpha: 0.14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: Text('Aa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'serif', color: _accentColor)),
                      onPressed: _openSettingsBottomSheet,
                    ),
                  ],
                ),
              ),
            ),

            if (_activeCoachToast != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 20,
                right: 20,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 280),
                  offset: _activeCoachToast != null ? Offset.zero : const Offset(0, -1.5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Text(_activeCoachToast!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}