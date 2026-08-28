// ============================================================================
// DOSYA ADI: lib/reader_screen.dart
// AÇIKLAMA: Highlight Silme (Toggle) Özelliği Eklenmiş Okuyucu Ekranı
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

enum ReaderTheme { light, sepia, dark }
enum ReaderFont { serif, sans }

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

  double _fontSize = 17.5;
  ReaderTheme _currentTheme = ReaderTheme.sepia;
  final ReaderFont _currentFont = ReaderFont.serif;

  bool _showControls = true;
  String? _selectedWord;

  final List<Map<String, dynamic>> _pageHighlightData = [];

  DateTime _sessionStartTime = DateTime.now();
  int _wordsExaminedCount = 0;
  int _wordsAddedCount = 0;

  Timer? _sessionTimer;
  int _sessionSeconds = 0;
  bool _notified15Min = false;
  bool _notified30Min = false;
  String? _activeCoachToast;

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
    _currentPage = widget.book.currentPage.clamp(0, widget.book.totalPages - 1);
    _initialStartPage = _currentPage;
    _pageController = PageController(initialPage: _currentPage);
    
    TtsService.instance.initService();
    _startSessionCoachTimer();
    _loadHighlightsForCurrentPage(_currentPage);
  }

  Future<void> _loadHighlightsForCurrentPage(int pageIndex) async {
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
      });
    }
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

  Color get _backgroundColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFFF4ECD8);
      case ReaderTheme.dark:
        return const Color(0xFF121214);
      case ReaderTheme.light:
        return const Color(0xFFFAF9F6);
    }
  }

  Color get _textColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFF2C241D);
      case ReaderTheme.dark:
        return const Color(0xFFE2E8F0);
      case ReaderTheme.light:
        return const Color(0xFF1E293B);
    }
  }

  Color get _surfacePanelColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFFE5DAC0);
      case ReaderTheme.dark:
        return const Color(0xFF1A1A1E);
      case ReaderTheme.light:
        return const Color(0xFFF1F5F9);
    }
  }

  Color get _panelBorderColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFFD3C3A3);
      case ReaderTheme.dark:
        return const Color(0xFF27272C);
      case ReaderTheme.light:
        return const Color(0xFFE2E8F0);
    }
  }

  Color get _accentColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFFB45309);
      case ReaderTheme.dark:
        return const Color(0xFFF59E0B);
      case ReaderTheme.light:
        return const Color(0xFF2563EB);
    }
  }

  Color get _sliderInactiveColor {
    switch (_currentTheme) {
      case ReaderTheme.dark:
        return const Color(0xFF2D2D36);
      case ReaderTheme.sepia:
        return const Color(0xFFD3C3A3);
      case ReaderTheme.light:
        return const Color(0xFFCBD5E1);
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

  /// Highlight ekleme veya silme mantığı
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

  /// Belirli bir aralıktaki highlight'ı tamamen siler
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

  Future<void> _showWordDetails(String word, int pageIndex, int globalWordIndex, int? sentenceStart, int? sentenceEnd) async {
    final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (cleanWord.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() {
      _selectedWord = cleanWord;
      _wordsExaminedCount++;
    });

    if (!mounted) return;

    final safeStart = sentenceStart ?? globalWordIndex;
    final safeEnd = sentenceEnd ?? globalWordIndex;

    // Bu kelimenin veya cümlenin halihazırda bir highlight'ı var mı kontrol et
    bool isWordHighlighted = _pageHighlightData.any((h) => h['start'] == globalWordIndex && h['end'] == globalWordIndex);
    bool isSentenceHighlighted = _pageHighlightData.any((h) => h['start'] == safeStart && h['end'] == safeEnd);

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
                                        color: _accentColor,
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

                          const SizedBox(height: 18),

                          // --- KELİME FOSFORLAMA & SİLME ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'FOSFORLU KALEM (KELİME)',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: _textColor.withValues(alpha: 0.6)),
                              ),
                              if (isWordHighlighted)
                                GestureDetector(
                                  onTap: () async {
                                    await _removeHighlight(pageIndex, globalWordIndex, globalWordIndex);
                                    if (!sheetContext.mounted) return;
                                    Navigator.pop(sheetContext);
                                  },
                                  child: Text('İşareti Kaldır', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red[400])),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
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
                          const SizedBox(height: 12),

                          // --- CÜMLE FOSFORLAMA & SİLME ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'FOSFORLU KALEM (TÜM CÜMLE)',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: _textColor.withValues(alpha: 0.6)),
                              ),
                              if (isSentenceHighlighted)
                                GestureDetector(
                                  onTap: () async {
                                    await _removeHighlight(pageIndex, safeStart, safeEnd);
                                    if (!sheetContext.mounted) return;
                                    Navigator.pop(sheetContext);
                                  },
                                  child: Text('Cümle İşaretini Kaldır', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red[400])),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
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
                          const SizedBox(height: 14),

                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: isSaved ? Colors.grey[700] : _accentColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                if (isSaved) {
                                  await DatabaseHelper.instance.removeFlashcardByWord(cleanWord);
                                  setSheetState(() => isSaved = false);
                                  if (mounted) setState(() {});
                                  if (!sheetContext.mounted) return;
                                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                                    SnackBar(behavior: SnackBarBehavior.floating, content: Text('"$cleanWord" kartlardan çıkarıldı.')),
                                  );
                                } else {
                                  final saveMeaning = isOffline
                                      ? 'Anlam bekleniyor'
                                      : (result?.alternativeMeanings.take(3).join(', ') ?? result?.primaryMeaning ?? '');

                                  await DatabaseHelper.instance.addFlashcard(cleanWord, saveMeaning);
                                  setSheetState(() => isSaved = true);
                                  if (mounted) {
                                    setState(() => _wordsAddedCount++);
                                    _showCoachToast('⭐ "$cleanWord" kelime kartlarına eklendi!');
                                  }
                                }
                              },
                              icon: Icon(isSaved ? Icons.bookmark_remove_rounded : Icons.bookmark_add_rounded, size: 20),
                              label: Text(
                                isSaved ? 'Kelime Kartlarından Çıkar' : 'Kelime Kartlarına Ekle',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

  Widget _buildColorButton(BuildContext sheetContext, int pageIndex, int start, int end, String colorTag, String label, Color dotColor) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textColor),
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _buildOptimizedSpans(int pageIndex) {
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

    final clean = _normalizePdfText(pageContent);
    final regExp = RegExp(r'(?<=[.!?])\s+');
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
        final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '');
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
            ),
          ),
        );
      }
    }
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
                            setState(() => _fontSize = val);
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
                  _buildColorCard(ReaderTheme.dark, const Color(0xFF121214), 'Gece', const Color(0xFFE2E8F0)),
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
            setState(() => _currentTheme = theme);
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
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),

            // Alt Kontrol Barı
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

            // Toast Bildirimi
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