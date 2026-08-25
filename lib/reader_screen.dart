// ============================================================================
// DOSYA ADI: lib/reader_screen.dart
// AÇIKLAMA: Apple Books & Kindle Seviyesi Akıllı E-Kitap Okuma Motoru
//
// MİMARİ VE ÇALIŞMA MANTIĞI:
// 1. Sayfalama ve Gezinme: PageView widget'ı kullanılarak yatay sayfa geçişi sağlanır.
//    Metin taşmalarını önlemek için sayfa içi hafif kaydırma (SingleChildScrollView)
//    emniyet supabı olarak devrededir.
// 2. Sayfa İlerlemesi Tespiti: Kullanıcının kitaba başladığı ilk sayfa (_initialStartPage)
//    ile ayrıldığı son sayfa (_currentPage) karşılaştırılarak seansta okunan net sayfa
//    sayısı hesaplanır ve ReadingSessionResult nesnesiyle geri döndürülür.
// 3. Optik Renk Paletleri: Göz yorgunluğunu önleyen yumuşak Keten Beyazı, Doğal Sıcak
//    Sepya ve Derin OLED Gece temaları arasında anlık geçiş imkanı sunar.
// 4. Haptik Geri Bildirim: Sayfa çevirme, kelime seçme ve menü açma eylemlerinde
//    cihaz donanımının titreşim motorunu (HapticFeedback) tetikler.
// ============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'book_model.dart';

// Okuma esnasında seçilebilecek görsel renk temaları
enum ReaderTheme { light, sepia, dark }

// Yazı tipi türleri (Klasik Serif Kitap Fontu veya Modern Sans-Serif Font)
enum ReaderFont { serif, sans }

// ----------------------------------------------------------------------------
// SEANS SONUÇ MODELİ
// Okuyucudan çıkış yapıldığında ana ekrandaki "Bugün Okunan" kartını ve
// kitaplıktaki okuma karnesini beslemek üzere geriye fırlatılan veri paketidir.
// ----------------------------------------------------------------------------
class ReadingSessionResult {
  final int durationSeconds;  // Bu seans boyunca kitapta geçirilen toplam süre (saniye)
  final int wordsExamined;    // Sözlük penceresi açılarak incelenen kelime sayısı
  final int wordsAdded;       // Kelime kartlarına (Flashcards) eklenen kelime sayısı
  final int lastPage;         // Kullanıcının okumayı bıraktığı son sayfa indeksi
  final int pagesRead;        // Bu okuma seansında tamamlanan net sayfa adedi

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
  // Sayfalar arası geçişi denetleyen PageView kontrolcüsü
  late PageController _pageController;
  
  // Aktif sayfa ve oturumun başladığı ilk sayfa değişkenleri
  late int _currentPage;
  late int _initialStartPage;

  // Görünüm ve tipografi durumları (Varsayılan olarak sıcak sepya ve serif başlar)
  double _fontSize = 17.5;
  ReaderTheme _currentTheme = ReaderTheme.sepia;
  ReaderFont _currentFont = ReaderFont.serif;
  
  // Arayüz kontrol elemanlarının görünürlük bayrakları
  bool _showControls = true;   // Üst ve alt barların ekranda olup olmadığı
  bool _showSettings = false;   // "Aa" biçimlendirme panelinin açık olup olmadığı
  String? _selectedWord;       // Dokunulan kelimenin vurgulanması için tutulan metin

  // Seans ölçüm sayaçları
  DateTime _sessionStartTime = DateTime.now(); // Okuma başladığı anda mühürlenen zaman
  int _wordsExaminedCount = 0;                 // İncelenen kelimelerin toplam sayısı
  int _wordsAddedCount = 0;                    // Kartlara eklenen kelimelerin toplam sayısı

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    // Kitabın son kalınan sayfasını güvenli aralıkta (clamp) başlatıyoruz
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
  // KİTAPTAN ÇIKIŞ VE SEANS VERİSİNİ PAKETLEME FONKSİYONU
  // Geri butonuna basıldığında süreyi ve okunan net sayfayı hesaplayıp ana ekrana iletir.
  // --------------------------------------------------------------------------
  void _handleExit() {
    HapticFeedback.lightImpact(); // Çıkış esnasında hafif dokunsal onay
    final duration = DateTime.now().difference(_sessionStartTime);
    final totalSeconds = duration.inSeconds;

    // Okunan net sayfa sayısını tespit ediyoruz:
    // Eğer ileri doğru sayfa çevrildiyse fark alınır.
    // Eğer aynı sayfada en az 20 saniye okuma yapıldıysa o sayfa da okundu (1) kabul edilir.
    int pagesDelta = _currentPage - _initialStartPage;
    int pagesRead = pagesDelta > 0 ? pagesDelta : (totalSeconds >= 20 ? 1 : 0);

    final result = ReadingSessionResult(
      durationSeconds: totalSeconds,
      wordsExamined: _wordsExaminedCount,
      wordsAdded: _wordsAddedCount,
      lastPage: _currentPage,
      pagesRead: pagesRead,
    );

    Navigator.pop(context, result); // Seans paketini teslim ederek sayfayı kapat
  }

  // --------------------------------------------------------------------------
  // OPTİK RENK VE TİPOGRAFİ HESAPLAYICILARI (COLOR SCIENCE)
  // --------------------------------------------------------------------------
  
  // Kitap sayfasının ana arka plan rengi
  Color get _backgroundColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFFF4ECE0); // Göz dinlendirici sarımtırak kitap kağıdı
      case ReaderTheme.dark:
        return const Color(0xFF141416); // Parlama yapmayan mat OLED gece siyahı
      case ReaderTheme.light:
        return const Color(0xFFFAF9F6); // Yumuşak kırık keten beyazı
    }
  }

  // Metinlerin baskı mürekkebi rengi
  Color get _textColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFF382E25); // Tok espresso kahvesi
      case ReaderTheme.dark:
        return const Color(0xFFDCDCDA); // Göz kamaştırmayan mat perlit grisi
      case ReaderTheme.light:
        return const Color(0xFF212124); // Karbon gri tonu
    }
  }

  // Üst menü, alt çubuk ve açılır kutuların yükseltilmiş yüzey rengi
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

  // Panellerin ince sınır çizgisi rengi
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

  // Vurgu ve odaklanma rengi
  Color get _accentColor {
    switch (_currentTheme) {
      case ReaderTheme.sepia:
        return const Color(0xFF9E6532); // Sıcak kehribar kahvesi
      case ReaderTheme.dark:
        return const Color(0xFFE5A93C); // Gece modunda parlayan altın sarısı
      case ReaderTheme.light:
        return const Color(0xFF3B5998); // Klasik kurşuni mavi
    }
  }

  // Karanlık modda da kaybolmayan slider arka plan çizgisi rengi
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

  // Kitap sayfasının satır aralığı ve font stili
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
  // SÖZLÜK VE KELİME KARTI POP-UP MODÜLÜ
  // Bir kelimeye tıklandığında açılan anlam ve kelime kartı ekleme penceresi
  // --------------------------------------------------------------------------
  void _showWordDetails(String word) {
    // Kelimenin etrafındaki noktalama işaretlerini temizliyoruz
    final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '');
    if (cleanWord.isEmpty) return;

    // Dokunma anında haptik tıklama ver ve inceleme sayacını artır
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
            // Üst tutamaç çizgisi
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
                // Sesli Telaffuz Butonu (TTS Hazırlığı)
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
            // Kelime Kartına Ekleme Butonu
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
                  HapticFeedback.mediumImpact(); // Başarılı ekleme haptik onayı
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
      // Pencere kapandığında kelime üzerindeki sarı seçim vurgusunu kaldırıyoruz
      setState(() => _selectedWord = null);
    });
  }

  // --------------------------------------------------------------------------
  // AKILLI PARAGRAF VE METİN BİRLEŞTİRME ALGORİTMASI
  // PDF dosyalarındaki yapay satır sonlarını (\n) temizleyip akıcı paragraflar üretir.
  // --------------------------------------------------------------------------
  String _normalizePdfText(String rawText) {
    String text = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    // Çift satır sonlarını gerçek paragraf olarak işaretle
    text = text.replaceAll(RegExp(r'\n\s*\n+'), '{{PARAGRAPH}}');
    // Satır içi yapay tek satır sonlarını boşluğa çevir
    text = text.replaceAll('\n', ' ');
    // Çoklu boşlukları teke indir
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    // Paragrafları geri yükle
    text = text.replaceAll('{{PARAGRAPH}}', '\n\n');
    return text.trim();
  }

  // Sayfadaki tüm kelimeleri tek tek dokunulabilir WidgetSpan elemanlarına dönüştürür
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
                  // Dokunulan kelimenin arkasını hafifçe renklendir
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
  // ÜSTTEN AÇILAN GÖRÜNÜM VE TEMA AYAR KUTUSU ("Aa")
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
          // 1. Satır: Yazı Boyutu Kademeli Kaydırıcısı
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
          // 2. Satır: Renk Temaları ve Font Tipi
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
      canPop: false, // Donanımsal geri tuşunu yakalayıp seans verisiyle çıkışı tetikler
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleExit();
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: Stack(
          children: [
            // ----------------------------------------------------------------
            // 1. KATMAN: Kitap Sayfası ve Immersive Mod Dokunma Alanı
            // ----------------------------------------------------------------
            GestureDetector(
              onTap: () {
                // Ekrana dokunulduğunda barları aç veya kapat
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
                  // Sayfa çevrilme haptik efekti
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
            // 2. KATMAN: Üst Bar ve "Aa" Ayarları (Animasyonlu Açılır / Gizlenir)
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
            // 3. KATMAN: Alt İlerleme ve Hızlı Sayfa Atlama Barı (Scrubber)
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