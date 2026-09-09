// ============================================================================
// DOSYA ADI: lib/library_screen.dart
// AÇIKLAMA: Kitaplık, Hibrit Navigasyon Banner'ı ve Akıllı Boş Durumlar (Smart Empty States)
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
import 'shop_screen.dart';
import 'dictionary_screen.dart';

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

    final streakResult = await StreakFreezeService.instance.checkAndUpdateStreak();
    await XpShopService.instance.getGemsBalance();
    await XpShopService.instance.getTotalXp();
    final shieldStatus = await XpShopService.instance.hasFreezeShield();

    if (!mounted) return;
    setState(() {
      _totalReadMinutes = prefs.getInt('stats_total_read_minutes') ?? 0;
      _totalWordsExamined = prefs.getInt('stats_total_words_examined') ?? 0;
      _totalWordsSaved = prefs.getInt('stats_total_words_saved') ?? 0;
      _streakDays = streakResult['streakDays'] ?? 1;
      _hasFreezeShield = shieldStatus;
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

  void _openShopScreen() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShopScreen())).then((_) => _loadAllData());
  }

  void _openDictionary() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DictionaryScreen())).then((_) => _loadAllData());
  }

  Widget _buildReadingDashboard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(PhosphorIcons.chartLineUpBold, size: 18, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 8),
                  Text('Haftalık Karne', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14.5, color: Colors.white)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (_hasFreezeShield ? const Color(0xFF38BDF8) : Colors.grey).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _hasFreezeShield ? const Color(0xFF38BDF8) : Colors.grey),
                    ),
                    child: Row(
                      children: [
                        Text(_hasFreezeShield ? '🛡️' : '⏳', style: const TextStyle(fontSize: 10)),
                        const SizedBox(width: 3),
                        Text(_hasFreezeShield ? 'Kalkan' : 'Yok', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 10, color: _hasFreezeShield ? const Color(0xFF93C5FD) : Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5))),
                    child: Row(
                      children: [
                        const Icon(PhosphorIcons.fireBold, size: 12, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text('$_streakDays G.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 10.5, color: const Color(0xFFF59E0B))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatMetric(icon: PhosphorIcons.timerBold, label: 'Okuma Süresi', value: '$_totalReadMinutes dk', accentColor: const Color(0xFF38BDF8)),
              const SizedBox(width: 10),
              _buildStatMetric(icon: PhosphorIcons.magnifyingGlassBold, label: 'İncelenen', value: '$_totalWordsExamined Kelime', accentColor: const Color(0xFF10B981)),
              const SizedBox(width: 10),
              _buildStatMetric(icon: PhosphorIcons.cardsBold, label: 'Havuzda', value: '$_totalWordsSaved Kelime', accentColor: const Color(0xFF818CF8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetric({required IconData icon, required String label, required String value, required Color accentColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(color: const Color(0xFF070B14), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1F2937))),
        child: Column(
          children: [
            Icon(icon, size: 18, color: accentColor),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12.5, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ],
        ),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kitaplık', style: GoogleFonts.outfit(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                      Text('Kişisel Kütüphane & Okuma', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12)),
                    ],
                  ),
                  Row(
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: XpShopService.instance.gemsNotifier,
                        builder: (context, gems, _) {
                          return InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _openShopScreen,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF38BDF8))),
                              child: Row(
                                children: [
                                  const Icon(PhosphorIcons.diamondBold, color: Color(0xFF38BDF8), size: 15),
                                  const SizedBox(width: 5),
                                  Text('$gems', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<int>(
                        valueListenable: XpShopService.instance.xpNotifier,
                        builder: (context, xp, _) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF59E0B))),
                            child: Row(
                              children: [
                                const Icon(PhosphorIcons.lightningBold, color: Color(0xFFF59E0B), size: 15),
                                const SizedBox(width: 4),
                                Text('$xp XP', style: GoogleFonts.outfit(color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              
              _buildReadingDashboard(),
              
              const SizedBox(height: 14),
              // Dikey Yığılmayı Önleyen Hibrit Banner
              _buildHybridBanner(),
              const SizedBox(height: 18),
              
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
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
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

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => _openBookJourney(book),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(book.icon, style: const TextStyle(fontSize: 26)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  book.title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15.5, color: Colors.white),
                                                ),
                                              ),
                                              if (book.level.isNotEmpty && book.level != 'Kullanıcı Kitabı') ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                                                  ),
                                                  child: Text(
                                                    book.level,
                                                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            book.author,
                                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(PhosphorIcons.caretRightBold, size: 16, color: Color(0xFF64748B)),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                if (isUntouched) ...[
                                  // Hiç başlanmamış (0 veri) kitabı için pozitif rozet
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(PhosphorIcons.sparkleBold, color: Color(0xFFFDE68A), size: 16),
                                        const SizedBox(width: 8),
                                        Text('Keşfedilmeyi Bekliyor ✨', style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  // Başlanmış kitaplar için gerçek istatistikler ve progress bar
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '📖 %$readingPercentage okundu',
                                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                                      ),
                                      Text(
                                        'Sayfa ${currentPage + 1} / $totalPages',
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: readingRatio,
                                      minHeight: 6,
                                      backgroundColor: const Color(0xFF070B14),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                                    ),
                                  ),
                                ],
                                
                                const SizedBox(height: 14),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (isUntouched) 
                                      Text(
                                        'İlk kelimeni avla!',
                                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                                      )
                                    else
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF818CF8).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              '🧠 $discoveredWords keşif',
                                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF818CF8)),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              '⭐ $masteredWords usta',
                                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                                            ),
                                          ),
                                        ],
                                      ),

                                    SizedBox(
                                      height: 38,
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFFF59E0B),
                                          foregroundColor: const Color(0xFF070B14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                        ),
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          _openReader(book);
                                        },
                                        icon: const Icon(PhosphorIcons.playBold, size: 14),
                                        label: Text(
                                          isUntouched ? 'BAŞLA' : 'DEVAM ET',
                                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                                        ),
                                      ),
                                    ),
                                  ],
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