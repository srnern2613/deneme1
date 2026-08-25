// ============================================================================
// DOSYA ADI: lib/reader_screen.dart
// AÇIKLAMA: Apple Books & Kindle Seviyesi Akıllı E-Kitap Okuma Motoru
// 
// Temel Yetenekler:
// 1. Dokunsal Geri Bildirim (Haptic Engine): Sayfa çevirmede ve kelimeye dokunmada mikro titreşimler.
// 2. Optik Renk Paletleri: Göz yormayan Aydınlık, Sıcak Sepya ve Derin OLED Gece temaları.
// 3. Immersive Focus Mode: Ekrana tek dokunuşla tüm barları gizleyip sadece kitaba odaklanma.
// 4. Seans Takipçisi: Kitaptan çıkış anında okuma süresi ve kelime analizini hesaplayıp döndürme.
// ============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'book_model.dart';

// Okuma esnasında seçilebilecek temalar
enum ReaderTheme { light, sepia, dark }

// Yazı tipi türleri (Kitap fontu veya Modern font)
enum ReaderFont { serif, sans }

// ----------------------------------------------------------------------------
// SEANS SONUÇ MODELİ
// Okuyucu ekranından çıkıldığında ana kitaplık ekranına aktarılacak istatistik paketi
// ----------------------------------------------------------------------------
class ReadingSessionResult {
  final int durationSeconds;  // Kullanıcının bu seans boyunca okuduğu toplam süre (saniye)
  final int wordsExamined;    // Sözlükten anlamına baktığı toplam kelime sayısı
  final int wordsAdded;       // Kelime havuzuna / kartlarına eklediği kelime sayısı
  final int lastPage;         // Okumayı bıraktığı son sayfa numarası

  ReadingSessionResult({
    required this.durationSeconds,
    required this.wordsExamined,
    required this.wordsAdded,
    required this.lastPage,
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
  // Sayfa kaydırma kontrolcüsü ve kalınan sayfa indeksi
  late PageController _pageController;
  late int _currentPage;

  // Görünüm Durumları (Varsayılan olarak en çok tercih edilen Sepya + Serif başlar)
  double _fontSize = 17.5;
  ReaderTheme _currentTheme = ReaderTheme.sepia;
  ReaderFont _currentFont = ReaderFont.serif;
  
  // Arayüz Görünürlük Kontrolleri
  bool _showControls = true;     // Üst ve alt barların ekranda olup olmadığı
  bool _showSettings = false;     // Üstteki "Aa" ayar panelinin açık olup olmadığı
  String? _selectedWord;         // O an dokunulan kelimenin vurgulanması için tutulan değişken

  // Seans İstatistik Sayıcıları
  DateTime _sessionStartTime = DateTime.now(); // Okuma başladığı an kaydedilir
  int _wordsExaminedCount = 0;                 // İncelenen kelime sayacı
  int _wordsAddedCount = 0;                    // Kartlara eklenen kelime sayacı

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    // Kitabın son kalınan sayfasını yükle (Aralık dışına taşmayı clamp ile engelle)
    _currentPage = widget.book.currentPage.clamp(0, widget.book.totalPages - 1);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // KİTAPTAN ÇIKIŞ VE SEANS PAKETLEME FONKSİYONU
  // Geri tuşuna basıldığında süreyi hesaplar, haptik titreşim verir ve sonucu geri fırlatır.
  // --------------------------------------------------------------------------
  void _handleExit() {
    HapticFeedback.lightImpact(); // Çıkış yapıldığında parmakta hafif bir dokunsal his
    final duration = DateTime.now().difference(_sessionStartTime);
    final totalSeconds = duration.inSeconds;

    final result = ReadingSessionResult(
      durationSeconds: totalSeconds,
      wordsExamined: _wordsExaminedCount,
      wordsAdded: _wordsAddedCount,
      lastPage: _currentPage,
    );

    Navigator.pop(context, result); // Sonucu bir önceki sayfaya teslim et
  }

  // --------------------------------------------------------------------------
  // OPTİK RENK VE TİPOGRAFİ HESAPLAYICILARI
  // --------------------------------------------------------------------------
  
  // Sayfanın ana arka plan rengi
  Color get _backgroundColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFFF4ECE0); // Sıcak e-kitap kağıdı tonu
      case ReaderTheme.dark:
        return const Color(0xFF141416); // Parlamayan mat OLED siyahı
      case ReaderTheme.light:
        return const Color(0xFFFAF9F6); // Göz yormayan soft kırık beyaz
    }
  }

  // Metinlerin mürekkep rengi
  Color get _textColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFF382E25); // Tok espresso kahvesi
      case ReaderTheme.dark:
        return const Color(0xFFDCDCDA); // Kamaşma yapmayan mat gümüş ton
      case ReaderTheme.light:
        return const Color(0xFF212124); // Karbon gri
    }
  }

  // Üst menü ve açılır panellerin yükseltilmiş (surface) katman rengi
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

  // Panellerin kenarlık çizgisi rengi
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

  // Vurgu ve buton rengi
  Color get _accentColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFF9E6532); // Kehribar tonu
      case ReaderTheme.dark:
        return const Color(0xFFE5A93C); // Gece modunda parlayan altın sarısı
      case ReaderTheme.light:
        return const Color(0xFF3B5998); // Klasik mavi
    }
  }

  // Gece modunda kaybolmayan slider ray rengi
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

  // Metnin genel tipografi stili
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
  // SÖZLÜK VE KELİME KARTI POP-UP FONKSİYONU
  // Bir kelimeye tıklandığında alttan açılan şık detay penceresi
  // --------------------------------------------------------------------------
  void _showWordDetails(String word) {
    // Kelimenin başındaki/sonundaki noktalama işaretlerini temizler
    final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '');
    if (cleanWord.isEmpty) return;

    // Dokunma anında haptik tıklama ver ve sayacı 1 artır
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
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üstteki tutma çizgisi (Handle)
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
                // Sesli Telaffuz Butonu
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: _textColor.withValues(alpha: 0.08),
                  ),
                  icon: Icon(Icons.volume_up_rounded, size: 20, color: _textColor),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Kelime anlamı, çevirisi ve örnek cümleleri burada listelenecek.',
              style: TextStyle(
                fontSize: 14,
                color: _textColor.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 22),
            // Kelime Kartlarına Ekleme Butonu
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  // Başarılı ekleme haptik onayı
                  HapticFeedback.mediumImpact();
                  setState(() => _wordsAddedCount++);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      content: Text('"$cleanWord" kelime kartlarına eklendi!'),
                    ),
                  );
                },
                icon: const Icon(Icons.bookmark_add_rounded, size: 20),
                label: const Text('Kelime Kartlarına Ekle', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      // Pop-up kapandığında kelimedeki seçili arka plan rengini sıfırla
      setState(() => _selectedWord = null);
    });
  }

  // --------------------------------------------------------------------------
  // METİN AYRIŞTIRMA VE AKICI PARAGRAF DÜZENLEYİCİSİ
  // PDF'lerdeki yapay satır sonu (\n) bozulmalarını temizleyip akıcı paragraflar kurar.
  // --------------------------------------------------------------------------
  String _normalizePdfText(String rawText) {
    String text = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text.replaceAll(RegExp(r'\n\s*\n+'), '{{PARAGRAPH}}');
    text = text.replaceAll('\n', ' ');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll('{{PARAGRAPH}}', '\n\n');
    return text.trim();
  }

  // Metindeki tüm kelimeleri tek tek tıklanabilir WidgetSpan öğelerine böler
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
                  // Kelimeye dokunulduğunda hafifçe arkasını aydınlat
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

  // --------------------------------------------------------------------------
  // ÜSTTEN AÇILAN GÖRÜNÜM VE TEMA AYARLARI PANELİ ("Aa")
  // --------------------------------------------------------------------------
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
          // 1. Satır: Yazı Boyutu Ayar Kaydırıcısı
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
          // 2. Satır: Renk Temaları ve Yazı Tipi Seçici
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

  // Renk Teması Seçim Hapı
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

  // Yazı Tipi Seçim Sekmesi
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
      canPop: false, // Fiziksel geri tuşuna basıldığında doğrudan çıkışı engeller
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleExit(); // Güvenli şekilde seans verisiyle çıkış yap
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: Stack(
          children: [
            // ----------------------------------------------------------------
            // 1. KATMAN: Sayfa Okuma Alanı & Immersive Dokunma Dinleyicisi
            // ----------------------------------------------------------------
            GestureDetector(
              onTap: () {
                // Ekrana dokunulduğunda barları gizle veya göster
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
                  // Sayfa her çevrildiğinde minik bir tıklama hissi ver
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

            // ----------------------------------------------------------------
            // 2. KATMAN: Üst Bar ve "Aa" Ayarları (Animasyonlu Açılır / Kapanır)
            // ----------------------------------------------------------------
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
                        // "Aa" Ayar Butonu
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

            // ----------------------------------------------------------------
            // 3. KATMAN: Alt Sayfa Numarası ve Hızlı Atlama Çubuğu (Scrubber)
            // ----------------------------------------------------------------
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