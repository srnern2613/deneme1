// ============================================================================
// DOSYA ADI: lib/library_screen.dart
// AÇIKLAMA: Kitaplık, Hibrit Navigasyon Banner'ı, Akıllı Boş Durumlar ve
//            Reaktif AppHeader Entegrasyonu.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'book_model.dart';
import 'default_books.dart';
import 'reader_screen.dart';
import 'book_journey_screen.dart';
import 'database_helper.dart';
import 'streak_freeze_service.dart';
import 'xp_shop_service.dart';
import 'dictionary_screen.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'core/design_system/primitives.dart'; // ScreenHeaderBadge & RuneTitle
import 'core/entitlement/paywall_trigger.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Book> _books = [];
  bool _isLoading = false;

  int _streakDays = 1;
  bool _hasFreezeShield = true;
  int _totalReadMinutes = 0;
  int _totalWordsExamined = 0;
  int _totalWordsSaved = 0;

  final Map<String, Map<String, dynamic>> _bookStatsCache = {};

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    
    await DefaultBooksManager.seedDefaultBooksIfNeeded();

    // EJDERHA ROTASI V2 — FAZ 2: Kalkan durumu artık TEK yerden
    // (checkAndUpdateStreak, Premium'u da hesaba katan) okunuyor — ayrı
    // bir XpShopService.hasFreezeShield() çağrısı tutarsızlığa yol açıyordu.
    final streakResult = await StreakFreezeService.instance.checkAndUpdateStreak();
    await XpShopService.instance.getTotalXp();

    if (!mounted) return;
    setState(() {
      _totalReadMinutes = prefs.getInt('stats_total_read_minutes') ?? 0;
      _totalWordsExamined = prefs.getInt('stats_total_words_examined') ?? 0;
      _totalWordsSaved = prefs.getInt('stats_total_words_saved') ?? 0;
      _streakDays = streakResult['streakDays'] ?? 1;
      _hasFreezeShield = streakResult['hasFreezeShield'] ?? false;
    });

    final bookDataList = prefs.getStringList('saved_books');
    if (bookDataList != null && bookDataList.isNotEmpty) {
      setState(() {
        _books = bookDataList.map((str) => Book.fromJson(str)).toList();
      });
    }

    _loadBookJourneyStats();
  }

  Future<void> _loadBookJourneyStats() async {
    for (var book in _books) {
      try {
        final data = await DatabaseHelper.instance.getBookJourneyData(
          bookTitle: book.title,
          bookId: book.id,
        );
        if (mounted) {
          setState(() {
            _bookStatsCache[book.title] = data;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _saveBooksToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> bookDataList = _books.map((b) => b.toJson()).toList();
    await prefs.setStringList('saved_books', bookDataList);
  }

  Future<void> _saveStatsToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('stats_total_read_minutes', _totalReadMinutes);
    await prefs.setInt('stats_total_words_examined', _totalWordsExamined);
    await prefs.setInt('stats_total_words_saved', _totalWordsSaved);
  }

  Future<void> _pickAndProcessFile() async {
    try {
      HapticFeedback.selectionClick();
      const XTypeGroup typeGroup = XTypeGroup(label: 'documents', extensions: <String>['txt', 'pdf']);
      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      if (file == null) return;

      setState(() => _isLoading = true);
      final fileName = file.name;
      List<String> pages = [];

      if (fileName.toLowerCase().endsWith('.txt')) {
        final fullText = await file.readAsString();
        final chunks = RegExp(r'.{1,1000}(\s|$)', dotAll: true).allMatches(fullText);
        pages = chunks.map((m) => m.group(0)?.trim() ?? '').where((s) => s.isNotEmpty).toList();
      } else if (fileName.toLowerCase().endsWith('.pdf')) {
        final bytes = await file.readAsBytes();
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        for (int i = 0; i < document.pages.count; i++) {
          final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
          if (pageText.trim().isNotEmpty) pages.add(pageText.trim());
        }
        document.dispose();
      }

      if (pages.isEmpty) pages = ['Belgede okunabilir metin bulunamadı.'];

      final newBook = Book(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: fileName.replaceAll(RegExp(r'\.(pdf|txt)$', caseSensitive: false), ''),
        author: 'Yüklenen Kitap',
        level: 'Kullanıcı Kitabı',
        icon: fileName.toLowerCase().endsWith('.pdf') ? '📕' : '📄',
        pages: pages,
        lastReadDate: DateTime.now(),
      );

      setState(() {
        _books.insert(0, newBook);
        _isLoading = false;
      });

      await _saveBooksToStorage();
      if (!mounted) return;
      _openReader(newBook);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openReader(Book book) async {
    HapticFeedback.selectionClick();
    final result = await Navigator.push<ReadingSessionResult>(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(
          book: book,
          onPageChanged: (newPage) {
            book.currentPage = newPage;
            book.lastReadDate = DateTime.now();
            _saveBooksToStorage();

            final safeTotal = book.pages.isEmpty ? 1 : book.pages.length;
            DatabaseHelper.instance.updateBookReadingProgress(
              bookId: book.id,
              bookTitle: book.title,
              currentPage: newPage,
              totalPages: safeTotal,
              chapterInfo: 'Sayfa ${newPage + 1}',
            );
          },
        ),
      ),
    );

    if (result != null) {
      final int validDurationSeconds = result.durationSeconds;
      final int calculatedMinutes = (validDurationSeconds / 60).ceil().toInt();
      final int actualMinutes = validDurationSeconds < 15 ? 0 : (calculatedMinutes > 0 ? calculatedMinutes : 1);
      final int addedPages = actualMinutes > 0 ? result.pagesRead : 0;
      
      if (actualMinutes > 0 && addedPages > 0) {
        final earnedXp = actualMinutes * 10;
        await XpShopService.instance.addXp(earnedXp);

        setState(() {
          book.currentPage = result.lastPage;
          book.lastReadDate = DateTime.now();
          book.totalReadSeconds += validDurationSeconds;
          _totalReadMinutes += actualMinutes;
          _totalWordsExamined += result.wordsExamined;
        });

        await _saveBooksToStorage();
        await _saveStatsToStorage();
      }
    }

    _loadAllData();
  }

  void _openBookJourney(Book book) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookJourneyScreen(
          bookTitle: book.title,
          bookId: book.id,
          author: book.author,
          onContinueReading: () => _openReader(book),
        ),
      ),
    ).then((_) => _loadAllData());
  }

  void _openDictionary() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DictionaryScreen())).then((_) => _loadAllData());
  }

  Widget _buildLibraryHeaderRow() {
    return Row(
      children: [
        const ScreenHeaderBadge(icon: PhosphorIcons.booksBold, color: Color(0xFF10B981)),
        const SizedBox(width: 12),
        const Expanded(
          child: RuneTitle(title: 'Kitaplık', subtitle: 'Kişisel Kütüphane & Okuma'),
        ),
        _buildLibraryHeaderStatPill(
          icon: PhosphorIcons.lightningBold,
          color: const Color(0xFF38BDF8),
          listenable: XpShopService.instance.xpNotifier,
        ),
      ],
    );
  }

  Widget _buildLibraryHeaderStatPill({required IconData icon, required Color color, required ValueListenable<int> listenable}) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFF1F2937), width: 1),
        ),
        child: ValueListenableBuilder<int>(
          valueListenable: listenable,
          builder: (context, value, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Text('$value', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      );
  }

  // EJDERHA ROTASI V2 — FAZ 4: Eski büyük "Bilgi Havuzu" haftalık rapor
  // kartının (ikonlu 3 kutulu grid + üstte iki rozet) yerine, tek satırlık
  // ince bir bilgi bandı. Aynı veriler (dalış süresi, keşfedilen/havuzdaki
  // kelime, seri, kalkan) korunuyor — sadece dikey yer kaplaması azaltıldı.
  Widget _buildReadingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937), width: 1),
      ),
      child: Row(
        children: [
          // EJDERHA ROTASI V2 — FAZ 2: Kalkan yokken rozet PaywallTrigger ile
          // sarılı — dokunuş merkezi paywall'ı açar.
          PaywallTrigger(
            onUnlocked: _loadAllData,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_hasFreezeShield ? '🛡️' : '⏳', style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text('$_streakDays G.', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: const Color(0xFFF59E0B))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 16, color: const Color(0xFF1F2937)),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                _buildBannerStat(icon: PhosphorIcons.timerBold, value: '$_totalReadMinutes dk', color: const Color(0xFF38BDF8)),
                _buildBannerStat(icon: PhosphorIcons.magnifyingGlassBold, value: '$_totalWordsExamined', color: const Color(0xFF10B981)),
                _buildBannerStat(icon: PhosphorIcons.cardsBold, value: '$_totalWordsSaved', color: const Color(0xFF818CF8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerStat({required IconData icon, required String value, required Color color}) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11.5, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // --- HİBRİT YATAY BANNER (SÖZLÜK VE KİTAP EKLE) ---
  Widget _buildHybridBanner() {
    return Row(
      children: [
        Expanded(
          child: _buildBannerButton(
            icon: PhosphorIcons.bookBookmarkBold,
            title: 'Sözlük',
            subtitle: 'Kelimelerim',
            color: const Color(0xFF10B981),
            onTap: _openDictionary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBannerButton(
            icon: PhosphorIcons.filePlusBold,
            title: _isLoading ? 'İşleniyor' : 'Kitap Ekle',
            subtitle: 'PDF / TXT',
            color: const Color(0xFFF59E0B),
            onTap: _isLoading ? null : _pickAndProcessFile,
          ),
        ),
      ],
    );
  }

  Widget _buildBannerButton({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback? onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white), textAlign: TextAlign.center, maxLines: 1),
            const SizedBox(height: 2),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: color.withValues(alpha: 0.8)), textAlign: TextAlign.center, maxLines: 1),
          ],
        ),
      ),
    );
  }

  // --- AKILLI BOŞ DURUM (SMART EMPTY STATE) ---
  Widget _buildEmptyLibraryState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(PhosphorIcons.booksBold, size: 48, color: Color(0xFFF59E0B)),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 1200.ms),
          const SizedBox(height: 20),
          Text(
            'Kütüphanen Şu An Sessiz',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Yukarıdaki "Kitap Ekle" butonuna dokunarak kendi PDF veya TXT kitabını yükle ve kelimeleri avlamaya başla!',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8), height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      // Lobi'deki gibi nefes alan, custom başlık alanı — standart AppBar
      // sıkışıklığı yerine SafeArea içinde serbest bir Row. Sağdaki
      // rozetler AppHeader'ın kullandığı AYNI canlı ValueNotifier'ları
      // dinler; hiçbir yeni state veya iş mantığı eklenmedi.
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              _buildLibraryHeaderRow(),
              const SizedBox(height: 16),
              _buildReadingBanner(),

              const SizedBox(height: 12),
              // Dikey Yığılmayı Önleyen Hibrit Banner
              _buildHybridBanner(),
              const SizedBox(height: 16),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    const Text('📜', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Klasik eserler Project Gutenberg (gutenberg.org) kamu malı koleksiyonundandır.',
                        style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Text('Kitaplarım (${_books.length})', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 10),

              Expanded(
                child: _books.isEmpty
                  ? _buildEmptyLibraryState()
                  : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _books.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final book = _books[index];
                    final stats = _bookStatsCache[book.title];

                    final int totalPages = book.pages.isEmpty ? 1 : book.pages.length;
                    final int currentPage = book.currentPage.clamp(0, totalPages);
                    final double readingRatio = (currentPage / totalPages).clamp(0.0, 1.0);
                    final int readingPercentage = (readingRatio * 100).toInt();

                    final int discoveredWords = stats?['total_words'] as int? ?? 0;
                    final int masteredWords = stats?['mastered_count'] as int? ?? 0;

                    // Sıfır Veri Kontrolü (Smart Conditional Render)
                    final bool isUntouched = (currentPage == 0 && discoveredWords == 0 && masteredWords == 0);

                    // EJDERHA ROTASI V2 — FAZ 4: Kompakt kitap kartı — tek
                    // satır ikon+başlık+yazar, ince bir ilerleme çubuğu ve
                    // sağda küçük bir "devam" ikon butonu. Eski geniş
                    // rozet/buton satırları kaldırıldı.
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF1F2937), width: 1),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openBookJourney(book),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Text(book.icon, style: const TextStyle(fontSize: 22)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        book.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13.5, color: Colors.white),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isUntouched
                                            ? '${book.author} · Keşfedilmeyi bekliyor ✨'
                                            : '${book.author} · %$readingPercentage · 🧠$discoveredWords ⭐$masteredWords',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                                      ),
                                      if (!isUntouched) ...[
                                        const SizedBox(height: 5),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: readingRatio,
                                            minHeight: 4,
                                            backgroundColor: const Color(0xFF334155),
                                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFFF59E0B),
                                    foregroundColor: const Color(0xFF070B14),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    _openReader(book);
                                  },
                                  icon: const Icon(PhosphorIcons.playBold, size: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}