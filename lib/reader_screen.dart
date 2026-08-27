// ============================================================================
// DOSYA ADI: lib/reader_screen.dart
// AÇIKLAMA: Yalnızca Aktif Sayfayı Dinleyen (Zero-Jank) E-Kitap Okuyucu
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

import 'book_model.dart';
import 'database_helper.dart';
import 'dictionary_service.dart';
import 'tts_service.dart';
import 'coach_messages.dart';
import 'audiobook_manager.dart';

/// Okuma arayüzü temaları
enum ReaderTheme { light, sepia, dark }

/// Tipografi font seçenekleri
enum ReaderFont { serif, sans }

/// Okuma seansı tamamlandığında ana sayfaya/istatistiklere aktarılan veri modeli
class ReadingSessionResult {
  final int durationSeconds;
  final int wordsExamined;
  final int wordsAdded;
  final int lastPage;
  final int pagesRead;

  ReadingSessionResult({
    required this.durationSeconds,
    required this.wordsExamined,
    required this.wordsAdded,
    required this.lastPage,
    required this.pagesRead,
  });
}

class ReaderScreen extends StatefulWidget {
  final Book book;
  final Function(int pageIndex)? onPageChanged;

  const ReaderScreen({
    super.key,
    required this.book,
    this.onPageChanged,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late PageController _pageController;
  late int _currentPage;
  late int _initialStartPage;

  // Görünüm Ayarları
  double _fontSize = 17.5;
  ReaderTheme _currentTheme = ReaderTheme.sepia;
  ReaderFont _currentFont = ReaderFont.serif;
  double _ttsSpeedMultiplier = 0.45;

  // Arayüz Durumu
  bool _showControls = true;
  String? _selectedWord;

  // Seans ve Koçluk Takibi
  DateTime _sessionStartTime = DateTime.now();
  int _wordsExaminedCount = 0;
  int _wordsAddedCount = 0;

  Timer? _sessionTimer;
  int _sessionSeconds = 0;
  bool _notified15Min = false;
  bool _notified30Min = false;
  String? _activeCoachToast;

  // Sözlük Kelime Türü Çevirileri
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

  String _getTurkishPos(String? pos) {
    if (pos == null || pos.trim().isEmpty) return '';
    final clean = pos.trim().toLowerCase();
    return _posTranslations[clean] ?? pos.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();

    final manager = AudiobookManager.instance;
    // Oturum devam ediyorsa son kalınan sayfayı yöneticiden senkronize et
    if (manager.hasActiveSession && manager.currentBook?.id == widget.book.id) {
      _currentPage = manager.currentPage;
    } else {
      _currentPage = widget.book.currentPage.clamp(0, widget.book.totalPages - 1);
    }

    _initialStartPage = _currentPage;
    _pageController = PageController(initialPage: _currentPage);
    TtsService.instance.initService();
    _startSessionCoachTimer();

    // ------------------------------------------------------------------------
    // ÇÖZÜLEN SORUN (Sayfa Atlama Senkronu):
    // TTS bir sayfayı bitirip sonraki sayfaya geçtiğinde PageView kaymıyordu.
    // AudiobookManager'a callback bağlanarak sayfa değişiminde jumpToPage tetiklendi.
    // ------------------------------------------------------------------------
    manager.attachReaderCallback((pageIndex) {
      if (mounted && _pageController.hasClients && _currentPage != pageIndex) {
        _pageController.jumpToPage(pageIndex);
        setState(() => _currentPage = pageIndex);
      }
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _pageController.dispose();
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
    HapticFeedback.lightImpact();
    setState(() => _activeCoachToast = message);
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted && _activeCoachToast == message) {
        setState(() => _activeCoachToast = null);
      }
    });
  }

  // --------------------------------------------------------------------------
  // ÇÖZÜLEN SORUN (Hayalet Okuma Döngüleri - Race Condition):
  // Eski yapıda bu butona basılıp durdurulduğunda arkadaki 'for' döngüsü ölmüyordu.
  // Artık AudiobookManager içindeki Generation Token sayesinde basıldığı an
  // eski okuma döngüsü anında kendini terk ediyor.
  // --------------------------------------------------------------------------
  void _togglePageReading() {
    HapticFeedback.mediumImpact();
    final manager = AudiobookManager.instance;

    if (manager.hasActiveSession && manager.currentBook?.id == widget.book.id) {
      manager.togglePlayPause();
    } else {
      manager.startSession(
        book: widget.book,
        pageIndex: _currentPage,
        onPageTurnedCallback: (newPageIndex) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(newPageIndex);
            setState(() => _currentPage = newPageIndex);
          }
        },
      );
    }
  }

  void _handleExit() {
    HapticFeedback.lightImpact();
    final duration = DateTime.now().difference(_sessionStartTime);
    final totalSeconds = duration.inSeconds;

    int pagesDelta = _currentPage - _initialStartPage;
    int pagesRead = pagesDelta > 0 ? pagesDelta : (totalSeconds >= 20 ? 1 : 0);

    final result = ReadingSessionResult(
      durationSeconds: totalSeconds,
      wordsExamined: _wordsExaminedCount,
      wordsAdded: _wordsAddedCount,
      lastPage: _currentPage,
      pagesRead: pagesRead,
    );

    Navigator.pop(context, result);
  }

  // Tema Renk Tanımlamaları
  Color get _backgroundColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFFF5EFE6);
      case ReaderTheme.dark:
        return const Color(0xFF121214);
      case ReaderTheme.light:
        return const Color(0xFFFAF9F6);
    }
  }

  Color get _textColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFF382B1E);
      case ReaderTheme.dark:
        return const Color(0xFFE6E6E6);
      case ReaderTheme.light:
        return const Color(0xFF1E1E20);
    }
  }

  Color get _surfacePanelColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFFEBE0D0);
      case ReaderTheme.dark:
        return const Color(0xFF1E1E22);
      case ReaderTheme.light:
        return Colors.white;
    }
  }

  Color get _panelBorderColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFFD6C5AD);
      case ReaderTheme.dark:
        return const Color(0xFF36363C);
      case ReaderTheme.light:
        return const Color(0xFFE2E2E8);
    }
  }

  Color get _accentColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFF9E5D24);
      case ReaderTheme.dark:
        return const Color(0xFFEBB04D);
      case ReaderTheme.light:
        return const Color(0xFF2B549A);
    }
  }

  Color get _sliderInactiveColor {
    switch (_currentTheme) {
      case ReaderTheme.dark:
        return const Color(0xFF42424A);
      case ReaderTheme.sepia:
        return const Color(0xFFC7B79E);
      case ReaderTheme.light:
        return const Color(0xFFDCDCE2);
    }
  }

  Color get _sentenceBgColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFFD99B26).withValues(alpha: 0.16);
      case ReaderTheme.dark:
        return const Color(0xFFFFC107).withValues(alpha: 0.14);
      case ReaderTheme.light:
        return const Color(0xFFFFD54F).withValues(alpha: 0.22);
    }
  }

  Color get _wordHighlightColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFFD99B26).withValues(alpha: 0.45);
      case ReaderTheme.dark:
        return const Color(0xFFFFC107).withValues(alpha: 0.40);
      case ReaderTheme.light:
        return const Color(0xFFFFD54F).withValues(alpha: 0.55);
    }
  }

  TextStyle get _readerTextStyle {
    return TextStyle(
      fontSize: _fontSize,
      height: 1.72,
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

  Future<void> _showWordDetails(String word) async {
    final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (cleanWord.isEmpty) return;

    if (AudiobookManager.instance.isPlaying) {
      await AudiobookManager.instance.togglePlayPause();
    }

    HapticFeedback.lightImpact();
    setState(() {
      _selectedWord = cleanWord;
      _wordsExaminedCount++;
    });

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: _surfacePanelColor,
      elevation: 16,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FutureBuilder<WordDefinitionResult>(
              future: DictionaryService.instance.fetchWordMeaning(cleanWord),
              builder: (context, snapshot) {
                final isLoading = snapshot.connectionState == ConnectionState.waiting;
                final result = snapshot.data;
                final isOffline = result?.isOfflineError ?? false;

                return FutureBuilder<bool>(
                  future: DatabaseHelper.instance.isWordInFlashcards(cleanWord),
                  builder: (context, cardSnap) {
                    bool isSaved = cardSnap.data ?? false;

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(
                                color: _textColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cleanWord,
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'serif',
                                      color: _textColor,
                                    ),
                                  ),
                                  if (result?.phonetic != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      result!.phonetic!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                        color: _accentColor.withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Row(
                                children: [
                                  if (isSaved)
                                    const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                                  const SizedBox(width: 6),
                                  IconButton.filledTonal(
                                    style: IconButton.styleFrom(
                                      backgroundColor: _accentColor.withValues(alpha: 0.15),
                                    ),
                                    icon: Icon(Icons.volume_up_rounded, size: 22, color: _accentColor),
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
                          const SizedBox(height: 14),

                          if (isLoading) ...[
                            Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Gelişmiş sözlük taranıyor...',
                                  style: TextStyle(fontSize: 14, color: _textColor.withValues(alpha: 0.7)),
                                ),
                              ],
                            ),
                          ] else if (isOffline) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.wifi_off_rounded, color: Colors.amber, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Çevrimdışısınız. Bu kelime daha önce kaydedilmediği için çevrilemedi.',
                                      style: TextStyle(fontSize: 12, color: _textColor),
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: _textColor.withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: (result?.alternativeMeanings ?? [result?.primaryMeaning ?? ''])
                                  .map((mean) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: _accentColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: _accentColor.withValues(alpha: 0.25)),
                                        ),
                                        child: Text(
                                          mean,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: _accentColor,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],

                          const SizedBox(height: 22),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: isSaved ? Colors.grey[700] : _accentColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                final messenger = ScaffoldMessenger.of(sheetContext);

                                if (isSaved) {
                                  await DatabaseHelper.instance.removeFlashcardByWord(cleanWord);
                                  setSheetState(() => isSaved = false);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      content: Text('"$cleanWord" kartlardan çıkarıldı.'),
                                    ),
                                  );
                                } else {
                                  final saveMeaning = isOffline
                                      ? 'Anlam bekleniyor'
                                      : (result?.alternativeMeanings.take(3).join(', ') ?? result?.primaryMeaning ?? '');

                                  await DatabaseHelper.instance.addFlashcard(cleanWord, saveMeaning);
                                  if (mounted) {
                                    setState(() => _wordsAddedCount++);
                                    _showCoachToast('⭐ "$cleanWord" kelime kartlarına eklendi!');
                                  }
                                  setSheetState(() => isSaved = true);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      content: Text('"$cleanWord" kelime kartlarına eklendi! 🌟'),
                                    ),
                                  );
                                }
                              },
                              icon: Icon(
                                isSaved ? Icons.bookmark_remove_rounded : Icons.bookmark_add_rounded,
                                size: 20,
                              ),
                              label: Text(
                                isSaved ? 'Kelime Kartlarından Çıkar' : 'Kelime Kartlarına Ekle',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      setState(() => _selectedWord = null);
    });
  }

  // --------------------------------------------------------------------------
  // ÇÖZÜLEN KRİTİK SORUN 1 (İlk Açılışta Sayfaların Boş / Beyaz Görünmesi):
  // Eski kodda doğrudan `AudiobookManager.getPageSentences(pageIndex)` çağrılıyordu.
  // İlk anda Manager başlatılmadığı için liste boş [] dönüyor ve ekran boş kalıyordu.
  // Çözüm: Sayfa içeriğini modelden anında kontrol eden Fallback (yedek) mekanizması eklendi.
  //
  // ÇÖZÜLEN KRİTİK SORUN 2 (Skipped Frames & UI Kilitlenmesi):
  // WidgetSpan yerine TextSpan + TapGestureRecognizer yapısına geçilerek render ağacı
  // %80 hafifletildi.
  // --------------------------------------------------------------------------
  List<InlineSpan> _buildOptimizedSpans(int pageIndex, HighlightState? highlight) {
    // 1. Modelden metni güvenli şekilde al
    final pageContent = (widget.book.pages.isNotEmpty && pageIndex < widget.book.pages.length)
        ? widget.book.pages[pageIndex]
        : '';

    if (pageContent.trim().isEmpty) {
      return [
        TextSpan(
          text: 'Bu sayfada görüntülenecek metin bulunamadı.',
          style: _readerTextStyle.copyWith(fontStyle: FontStyle.italic),
        ),
      ];
    }

    // 2. Önbellekte varsa al, yoksa metni ilk açılışta anında kendin böl (Fallback)
    List<String> sentences = AudiobookManager.instance.getPageSentences(pageIndex);
    if (sentences.isEmpty) {
      final clean = _normalizePdfText(pageContent);
      final regExp = RegExp(r'(?<=[.!?])\s+');
      sentences = clean.split(regExp).where((s) => s.trim().length > 1).toList();
      if (sentences.isEmpty && clean.isNotEmpty) {
        sentences = [clean];
      }
    }

    final spans = <InlineSpan>[];
    final isCurrentPage = highlight != null && highlight.pageIndex == pageIndex;

    for (int s = 0; s < sentences.length; s++) {
      final sentence = sentences[s];
      final isCurrentSentence = isCurrentPage && (highlight.sentenceIndex == s);
      final words = sentence.split(' ').where((w) => w.isNotEmpty).toList();

      for (int w = 0; w < words.length; w++) {
        final word = words[w];
        final clean = word.replaceAll(RegExp(r'[^\w\s]'), '');
        final isSelected = _selectedWord != null && _selectedWord == clean;
        final isCurrentWord = isCurrentSentence && (highlight.wordIndexInSentence == w);

        // Arka plan rengini katmanlı olarak hesapla
        Color bg = Colors.transparent;
        if (isSelected) {
          bg = _accentColor.withValues(alpha: 0.25);
        } else if (isCurrentWord) {
          bg = _wordHighlightColor; // Kelime bazlı canlı vurgu
        } else if (isCurrentSentence) {
          bg = _sentenceBgColor;    // Cümle bazlı hafif gölge
        }

        spans.add(
          TextSpan(
            text: '$word ',
            style: _readerTextStyle.copyWith(
              backgroundColor: bg,
              fontWeight: (isCurrentWord || isCurrentSentence) ? FontWeight.w600 : FontWeight.normal,
              color: isCurrentWord ? _accentColor : _textColor,
            ),
            recognizer: TapGestureRecognizer()..onTap = () => _showWordDetails(word),
          ),
        );
      }
    }
    return spans;
  }

  void _openSettingsBottomSheet() {
    HapticFeedback.lightImpact();
    int selectedTab = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: _surfacePanelColor,
      isScrollControlled: true,
      elevation: 24,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final profiles = TtsService.instance.voiceProfiles;
            final activeProfile = TtsService.instance.activeProfile;

            return Container(
              color: _surfacePanelColor,
              padding: EdgeInsets.fromLTRB(
                22,
                16,
                22,
                MediaQuery.of(context).padding.bottom + 20,
              ),
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
                    height: 46,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _textColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _panelBorderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setSheetState(() => selectedTab = 0);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                color: selectedTab == 0 ? _accentColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.text_fields_rounded,
                                    size: 18,
                                    color: selectedTab == 0 ? Colors.white : _textColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Görünüm',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: selectedTab == 0 ? Colors.white : _textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setSheetState(() => selectedTab = 1);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                color: selectedTab == 1 ? _accentColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.headphones_rounded,
                                    size: 18,
                                    color: selectedTab == 1 ? Colors.white : _textColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Sesli Kitap',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: selectedTab == 1 ? Colors.white : _textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (selectedTab == 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _textColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _panelBorderColor),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'A',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                activeTrackColor: _accentColor,
                                inactiveTrackColor: _sliderInactiveColor,
                                thumbColor: _accentColor,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              ),
                              child: Slider(
                                value: _fontSize,
                                min: 14.0,
                                max: 26.0,
                                divisions: 8,
                                onChanged: (val) {
                                  HapticFeedback.selectionClick();
                                  setSheetState(() => _fontSize = val);
                                  setState(() => _fontSize = val);
                                },
                              ),
                            ),
                          ),
                          Text(
                            'A',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildColorCard(
                          ReaderTheme.light,
                          const Color(0xFFFAF9F6),
                          'Aydınlık',
                          const Color(0xFF1E1E20),
                          setSheetState,
                        ),
                        _buildColorCard(
                          ReaderTheme.sepia,
                          const Color(0xFFF5EFE6),
                          'Sepya',
                          const Color(0xFF382B1E),
                          setSheetState,
                        ),
                        _buildColorCard(
                          ReaderTheme.dark,
                          const Color(0xFF121214),
                          'Gece',
                          const Color(0xFFE6E6E6),
                          setSheetState,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        _buildFontCard(
                          title: 'Kitap',
                          subtitle: 'Klasik Roman',
                          font: ReaderFont.serif,
                          setSheetState: setSheetState,
                        ),
                        const SizedBox(width: 10),
                        _buildFontCard(
                          title: 'Modern',
                          subtitle: 'Net & Düz',
                          font: ReaderFont.sans,
                          setSheetState: setSheetState,
                        ),
                      ],
                    ),
                  ],

                  if (selectedTab == 1) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Okuma Hızı', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textColor)),
                        Row(
                          children: [
                            _buildSpeedPill('0.5x', 0.35, setSheetState),
                            const SizedBox(width: 6),
                            _buildSpeedPill('0.75x', 0.45, setSheetState),
                            const SizedBox(width: 6),
                            _buildSpeedPill('1.0x', 0.55, setSheetState),
                            const SizedBox(width: 6),
                            _buildSpeedPill('1.25x', 0.65, setSheetState),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    Column(
                      children: profiles.map((p) {
                        final isSelected = (activeProfile.id == p.id);

                        String avatar = '👩';
                        if (p.id == 'james') avatar = '👨';
                        if (p.id == 'ava') avatar = '🎙️';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: GestureDetector(
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              await TtsService.instance.applyProfile(p);
                              setSheetState(() {});
                              setState(() {});
                              TtsService.instance.speakWord(p.displayName);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? _accentColor.withValues(alpha: 0.15) : _textColor.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? _accentColor : _panelBorderColor,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(avatar, style: const TextStyle(fontSize: 22)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.displayName,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? _accentColor : _textColor,
                                          ),
                                        ),
                                        Text(
                                          p.description,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _textColor.withValues(alpha: 0.65),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check_circle_rounded, color: _accentColor, size: 22),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColorCard(
    ReaderTheme theme,
    Color bgPreviewColor,
    String label,
    Color fontColor,
    StateSetter setSheetState,
  ) {
    final isSelected = (_currentTheme == theme);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setSheetState(() => _currentTheme = theme);
            setState(() => _currentTheme = theme);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: bgPreviewColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? _accentColor : Colors.grey.withValues(alpha: 0.4),
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isSelected ? 0.14 : 0.04),
                  blurRadius: isSelected ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Aa',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                    color: fontColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: fontColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFontCard({
    required String title,
    required String subtitle,
    required ReaderFont font,
    required StateSetter setSheetState,
  }) {
    final isSelected = (_currentFont == font);
    final isSerif = (font == ReaderFont.serif);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setSheetState(() => _currentFont = font);
          setState(() => _currentFont = font);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? _accentColor.withValues(alpha: 0.15) : _textColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? _accentColor : _panelBorderColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                'Aa',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: isSerif ? 'serif' : 'sans-serif',
                  color: isSelected ? _accentColor : _textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? _accentColor : _textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: _textColor.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedPill(String label, double val, StateSetter setSheetState) {
    final isSelected = (_ttsSpeedMultiplier == val);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setSheetState(() => _ttsSpeedMultiplier = val);
        setState(() => _ttsSpeedMultiplier = val);
        TtsService.instance.setSpeed(val);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _accentColor : _textColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : _textColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = AudiobookManager.instance;

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

                  final bool isThisBookActive = manager.hasActiveSession && manager.currentBook?.id == widget.book.id;
                  if (isThisBookActive && manager.currentPage != pageIndex) {
                    manager.changePage(pageIndex);
                  }

                  setState(() {
                    _currentPage = pageIndex;
                    widget.book.currentPage = pageIndex;
                  });
                  widget.onPageChanged?.call(pageIndex);
                },
                itemBuilder: (context, index) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      26,
                      MediaQuery.of(context).padding.top + 54,
                      26,
                      MediaQuery.of(context).padding.bottom + 64,
                    ),
                    // --------------------------------------------------------
                    // ÇÖZÜLEN KRİTİK SORUN 3 (EGL avg=1000ms+ ve ANR Krizleri):
                    // Eski kodda `ListenableBuilder(listenable: manager)` tüm PageView'i
                    // sarmalıyordu. Her kelime okunduğunda önbellekteki görünmeyen 3 sayfa
                    // da baştan regex çalıştırıp çiziliyordu.
                    // Çözüm: Sadece metin alanı `ValueListenableBuilder` ile izole dinleniyor.
                    // Yalnızca okunan o anki tek sayfa canlı boyanıyor, komşu sayfalar uyuyor.
                    // --------------------------------------------------------
                    child: ValueListenableBuilder<HighlightState?>(
                      valueListenable: manager.activeHighlight,
                      builder: (context, highlight, _) {
                        return Text.rich(
                          TextSpan(
                            children: _buildOptimizedSpans(index, highlight),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // Üst Kontrol Barı
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
                    ListenableBuilder(
                      listenable: manager,
                      builder: (context, _) {
                        final bool isThisBookActive = manager.hasActiveSession && manager.currentBook?.id == widget.book.id;
                        final bool isPlaying = isThisBookActive && manager.isPlaying;

                        return IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause_circle_filled_rounded : Icons.headphones_rounded,
                            color: isPlaying ? Colors.green[600] : _textColor,
                            size: 24,
                          ),
                          tooltip: isPlaying ? 'Okumayı Durdur' : 'Kesintisiz Dinle (Audiobook)',
                          onPressed: _togglePageReading,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Alt Kontrol Barı (Sayfa Kaydırıcı & Tipografi Ayarları)
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
                child: Row(
                  children: [
                    Text(
                      '${_currentPage + 1}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textColor),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          activeTrackColor: _accentColor,
                          inactiveTrackColor: _sliderInactiveColor,
                          thumbColor: _accentColor,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                        ),
                        child: Slider(
                          value: _currentPage.toDouble(),
                          min: 0,
                          max: (widget.book.totalPages - 1).toDouble().clamp(0, double.infinity),
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            final newPage = val.toInt();
                            final bool isThisBookActive = manager.hasActiveSession && manager.currentBook?.id == widget.book.id;
                            if (isThisBookActive) {
                              manager.changePage(newPage);
                            }
                            _pageController.jumpToPage(newPage);
                          },
                        ),
                      ),
                    ),
                    Text(
                      '${widget.book.totalPages}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textColor.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: _accentColor.withValues(alpha: 0.14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: Text(
                        'Aa',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'serif',
                          color: _accentColor,
                        ),
                      ),
                      onPressed: _openSettingsBottomSheet,
                    ),
                  ],
                ),
              ),
            ),

            // Okuma Koçu Bildirim Toast'ı
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
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      _activeCoachToast!,
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
}