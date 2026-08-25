// ============================================================================
// DOSYA ADI: lib/reader_screen.dart
// AÇIKLAMA: Apple Books & Kindle Seviyesi Akıllı E-Kitap Okuma Motoru
//
// MİMARİ VE ÇALIŞMA MANTIĞI:
// 1. Canlı Sözlük Sorgusu: Kelimeye dokunulduğunda `DictionaryService` üzerinden
//    önce yerel SQLite taranır, yoksa ücretsiz API'den çekilip otomatik önbelleğe alınır.
// 2. Çevrimdışı Hata Yönetimi: İnternet yoksa ve kelime kaydedilmemişse kullanıcıya
//    uyarı kartı gösterilir; yine de kelimeyi kartlarına ekleyebilir.
// 3. Sayfalama ve Tipografi: Göz dinlendirici Sepya/Gece modları, serif font ve
//    haptik titreşim desteğiyle akıcı okuma sunar.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'book_model.dart';
import 'database_helper.dart';
import 'dictionary_service.dart';

enum ReaderTheme { light, sepia, dark }
enum ReaderFont { serif, sans }

// ----------------------------------------------------------------------------
// SEANS SONUÇ MODELİ
// ----------------------------------------------------------------------------
class ReadingSessionResult {
  final int durationSeconds;  // Seansta geçirilen süre (saniye)
  final int wordsExamined;    // Anlamına bakılan kelime sayısı
  final int wordsAdded;       // Kartlara eklenen kelime sayısı
  final int lastPage;         // Kaldığı son sayfa indeksi
  final int pagesRead;        // Seansta okunan net sayfa sayısı

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
  ReaderFont _currentFont = ReaderFont.serif;
  
  bool _showControls = true;
  bool _showSettings = false;
  String? _selectedWord;

  DateTime _sessionStartTime = DateTime.now();
  int _wordsExaminedCount = 0;
  int _wordsAddedCount = 0;

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _currentPage = widget.book.currentPage.clamp(0, widget.book.totalPages - 1);
    _initialStartPage = _currentPage;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // KİTAPTAN ÇIKIŞ VE SEANS PAKETLEME
  // --------------------------------------------------------------------------
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

  // --- OPTİK RENK VE TİPOGRAFİ GETTERLARI ---
  Color get _backgroundColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFFF4ECE0);
      case ReaderTheme.dark:
        return const Color(0xFF141416);
      case ReaderTheme.light:
        return const Color(0xFFFAF9F6);
    }
  }

  Color get _textColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFF382E25);
      case ReaderTheme.dark:
        return const Color(0xFFDCDCDA);
      case ReaderTheme.light:
        return const Color(0xFF212124);
    }
  }

  Color get _surfacePanelColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFFE8DCBE);
      case ReaderTheme.dark:
        return const Color(0xFF222226);
      case ReaderTheme.light:
        return Colors.white;
    }
  }

  Color get _panelBorderColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFFD8C8A4);
      case ReaderTheme.dark:
        return const Color(0xFF38383E);
      case ReaderTheme.light:
        return const Color(0xFFE5E5EA);
    }
  }

  Color get _accentColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFF9E6532);
      case ReaderTheme.dark:
        return const Color(0xFFE5A93C);
      case ReaderTheme.light:
        return const Color(0xFF3B5998);
    }
  }

  Color get _sliderInactiveColor {
    switch (_currentTheme) {
      case ReaderTheme.dark:
        return const Color(0xFF4A4A52);
      case ReaderTheme.sepia:
        return const Color(0xFFC8B998);
      case ReaderTheme.light:
        return const Color(0xFFD1D1D6);
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

  // --------------------------------------------------------------------------
  // HİBRİT SÖZLÜK VE KELİME KARTI POP-UP'I
  // --------------------------------------------------------------------------
  Future<void> _showWordDetails(String word) async {
    final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (cleanWord.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() {
      _selectedWord = cleanWord;
      _wordsExaminedCount++;
    });

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
                final meaning = result?.meaning ?? 'Çevriliyor...';
                final example = result?.example;

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
                          const SizedBox(height: 18),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              Row(
                                children: [
                                  if (isSaved)
                                    const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                                  const SizedBox(width: 4),
                                  IconButton.filledTonal(
                                    style: IconButton.styleFrom(
                                      backgroundColor: _textColor.withValues(alpha: 0.08),
                                    ),
                                    icon: Icon(Icons.volume_up_rounded, size: 20, color: _textColor),
                                    onPressed: () => HapticFeedback.selectionClick(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

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
                                  'Sözlük taranıyor...',
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
                            Text(
                              meaning,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _accentColor,
                              ),
                            ),
                            if (example != null && example.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                '"$example"',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: _textColor.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
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
                                  final saveMeaning = isOffline ? 'Anlam bekleniyor' : meaning;
                                  await DatabaseHelper.instance.addFlashcard(cleanWord, saveMeaning);
                                  if (mounted) {
                                    setState(() => _wordsAddedCount++);
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

  String _normalizePdfText(String rawText) {
    String text = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text.replaceAll(RegExp(r'\n\s*\n+'), '{{PARAGRAPH}}');
    text = text.replaceAll('\n', ' ');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll('{{PARAGRAPH}}', '\n\n');
    return text.trim();
  }

  List<InlineSpan> _buildInteractiveSpans(String text) {
    final cleanText = _normalizePdfText(text);
    final paragraphs = cleanText.split('\n\n');
    final spans = <InlineSpan>[];

    for (var p = 0; p < paragraphs.length; p++) {
      final paragraph = paragraphs[p].trim();
      if (paragraph.isEmpty) continue;

      final words = paragraph.split(' ');
      for (var word in words) {
        if (word.isEmpty) continue;
        final clean = word.replaceAll(RegExp(r'[^\w\s]'), '');
        final isSelected = _selectedWord != null && _selectedWord == clean;

        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => _showWordDetails(word),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isSelected ? _accentColor.withValues(alpha: 0.25) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('$word ', style: _readerTextStyle),
              ),
            ),
          ),
        );
      }

      if (p < paragraphs.length - 1) {
        spans.add(const TextSpan(text: '\n\n'));
      }
    }
    return spans;
  }

  Widget _buildSettingsSheet() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: _surfacePanelColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border(
          top: BorderSide(color: _panelBorderColor),
          bottom: BorderSide(color: _panelBorderColor),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('A', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textColor)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: _accentColor,
                    inactiveTrackColor: _sliderInactiveColor,
                    thumbColor: _accentColor,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2.5),
                    activeTickMarkColor: Colors.white.withValues(alpha: 0.7),
                    inactiveTickMarkColor: _currentTheme == ReaderTheme.dark
                        ? Colors.white.withValues(alpha: 0.4)
                        : _textColor.withValues(alpha: 0.3),
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
              Text('A', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textColor)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildColorPill(ReaderTheme.light, const Color(0xFFFAF9F6), 'Aydınlık'),
                  const SizedBox(width: 8),
                  _buildColorPill(ReaderTheme.sepia, const Color(0xFFF4ECE0), 'Sepya'),
                  const SizedBox(width: 8),
                  _buildColorPill(ReaderTheme.dark, const Color(0xFF141416), 'Gece'),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: _textColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _panelBorderColor),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _buildFontTab('Kitap', ReaderFont.serif),
                    _buildFontTab('Modern', ReaderFont.sans),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorPill(ReaderTheme theme, Color bg, String label) {
    final isSelected = _currentTheme == theme;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentTheme = theme);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _accentColor : _panelBorderColor,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _accentColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: theme == ReaderTheme.dark ? Colors.white70 : const Color(0xFF333333),
          ),
        ),
      ),
    );
  }

  Widget _buildFontTab(String label, ReaderFont font) {
    final isSelected = _currentFont == font;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentFont = font);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? _accentColor.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontFamily: font == ReaderFont.serif ? 'serif' : 'sans-serif',
            color: isSelected ? _accentColor : _textColor,
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
                setState(() {
                  _showControls = !_showControls;
                  if (!_showControls) _showSettings = false;
                });
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
                },
                itemBuilder: (context, index) {
                  final pageContent = widget.book.pages.isNotEmpty
                      ? widget.book.pages[index]
                      : 'İçerik bulunamadı.';

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      26,
                      MediaQuery.of(context).padding.top + 54,
                      26,
                      MediaQuery.of(context).padding.bottom + 64,
                    ),
                    child: Text.rich(
                      TextSpan(children: _buildInteractiveSpans(pageContent)),
                    ),
                  );
                },
              ),
            ),

            // Üst Bar
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
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
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _showSettings ? _accentColor.withValues(alpha: 0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _showSettings ? _accentColor : _panelBorderColor,
                              ),
                            ),
                            child: Text(
                              'Aa',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                fontFamily: 'serif',
                                color: _showSettings ? _accentColor : _textColor,
                              ),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() => _showSettings = !_showSettings);
                          },
                        ),
                      ],
                    ),
                    if (_showSettings) _buildSettingsSheet(),
                  ],
                ),
              ),
            ),

            // Alt Bar
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
                padding: EdgeInsets.fromLTRB(24, 10, 24, MediaQuery.of(context).padding.bottom + 8),
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
                            _pageController.jumpToPage(newPage);
                          },
                        ),
                      ),
                    ),
                    Text(
                      '${widget.book.totalPages}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textColor.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}