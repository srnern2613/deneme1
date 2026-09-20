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
import 'core/storage/book_storage_service.dart';
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
import 'core/theme/draconic_theme.dart'; // T-1: yapısal renkler artık temadan

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

  // P1-1 (Amber enflasyonu): "aktif kitap" = kullanıcının en son etkileşime
  // girdiği kitap. `Book.lastReadDate` zaten her sayfa değişiminde
  // güncelleniyor (bkz. _openReader / main.dart _openReaderDirectly) — yeni
  // bir alan/migrasyon gerekmedi, mevcut veriyi okumak yeterli.
  Book? get _mostRecentlyOpenedBook {
    Book? result;
    for (final b in _books) {
      if (b.lastReadDate == null) continue;
      if (result == null || b.lastReadDate!.isAfter(result.lastReadDate!)) {
        result = b;
      }
    }
    return result;
  }

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

    // AŞAMA 1: kitap sayfa metni artık book_content.db'de (Android Auto
    // Backup kotası dışında); BookStorageService bunu şeffaf birleştirir.
    final loadedBooks = await BookStorageService.loadBooks();
    if (loadedBooks.isNotEmpty) {
      setState(() {
        _books = loadedBooks;
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
    // AŞAMA 1: sayfa metni book_content.db'ye, hafif künye SharedPreferences'a.
    await BookStorageService.saveBooks(_books);
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
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Row(
      children: [
        ScreenHeaderBadge(icon: PhosphorIcons.booksBold, color: theme.successEmerald),
        const SizedBox(width: 12),
        const Expanded(
          child: RuneTitle(title: 'Kitaplık', subtitle: 'Kişisel Kütüphane & Okuma'),
        ),
        _buildLibraryHeaderStatPill(
          icon: PhosphorIcons.lightningBold,
          color: theme.infoTeal,
          listenable: XpShopService.instance.xpNotifier,
        ),
      ],
    );
  }

  Widget _buildLibraryHeaderStatPill({required IconData icon, required Color color, required ValueListenable<int> listenable}) {
    // T-1: yapısal renkler (kart zemini/çerçevesi/metni) artık temadan —
    // sadece `color` parametresi (ikon vurgusu) çağıran yerden geliyor.
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.surfaceDark.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: theme.borderSubtle, width: 1),
        ),
        child: ValueListenableBuilder<int>(
          valueListenable: listenable,
          builder: (context, value, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Text('$value', style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      );
  }

  // EJDERHA ROTASI V2 — FAZ B "Kitaplık Üst İstatistik Modernizasyonu":
  // Eski tek satırlık, emoji + ayraçlarla sıkıştırılmış "bilgi bandı" yerine
  // her biri kendi anlamını AÇIKÇA anlatan (ikon + değer + etiket), Apple
  // Sağlık tarzı 4'lü minimalist istatistik ızgarası. Metin karmaşası
  // (çıplak sayılar, belirsiz emoji, "G." gibi kısaltmalar) tamamen kaldırıldı.
  Widget _buildStatsOverviewRow() {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Row(
      children: [
        Expanded(
          child: PaywallTrigger(
            onUnlocked: _loadAllData,
            child: _buildStatTile(
              icon: _hasFreezeShield ? PhosphorIcons.shieldCheckBold : PhosphorIcons.fireBold,
              value: '$_streakDays',
              // P1-6: 2 satıra kırılan uzun etiket yerine tek kelime — tile
              // yüksekliği artık 4 kutuda da eşit.
              label: 'Seri',
              color: _hasFreezeShield ? theme.infoTeal : theme.primaryAmber,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            icon: PhosphorIcons.timerBold,
            value: '$_totalReadMinutes',
            label: 'Dakika',
            color: theme.infoTeal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            icon: PhosphorIcons.magnifyingGlassBold,
            value: '$_totalWordsExamined',
            label: 'Kelime',
            color: theme.successEmerald,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            icon: PhosphorIcons.cardsBold,
            value: '$_totalWordsSaved',
            label: 'Kart',
            color: theme.cognitiveIndigo,
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile({required IconData icon, required String value, required String label, required Color color}) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: theme.surfaceDark.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 17, color: theme.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: theme.textSecondary, height: 1.2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- HİBRİT YATAY BANNER (SÖZLÜK VE KİTAP EKLE) ---
  Widget _buildHybridBanner() {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Row(
      children: [
        Expanded(
          child: _buildBannerButton(
            icon: PhosphorIcons.bookBookmarkBold,
            title: 'Sözlük',
            subtitle: 'Kelimelerim',
            color: theme.successEmerald,
            onTap: _openDictionary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBannerButton(
            icon: PhosphorIcons.filePlusBold,
            title: _isLoading ? 'İşleniyor' : 'Kitap Ekle',
            subtitle: 'PDF / TXT',
            color: theme.primaryAmber,
            onTap: _isLoading ? null : _pickAndProcessFile,
          ),
        ),
      ],
    );
  }

  Widget _buildBannerButton({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback? onTap}) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
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
            Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: theme.textPrimary), textAlign: TextAlign.center, maxLines: 1),
            const SizedBox(height: 2),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: color.withValues(alpha: 0.8)), textAlign: TextAlign.center, maxLines: 1),
          ],
        ),
      ),
    );
  }

  // --- AKILLI BOŞ DURUM (SMART EMPTY STATE) ---
  Widget _buildEmptyLibraryState() {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.primaryAmber.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(PhosphorIcons.booksBold, size: 48, color: theme.primaryAmber),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 1200.ms),
          const SizedBox(height: 20),
          Text(
            'Kütüphanen Şu An Sessiz',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: theme.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Yukarıdaki "Kitap Ekle" butonuna dokunarak kendi PDF veya TXT kitabını yükle ve kelimeleri avlamaya başla!',
            style: GoogleFonts.inter(fontSize: 13, color: theme.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // UI/UX Düzeltme Listesi — Faz E: kısa kitap listelerinde ListView'in
  // altında kalan boş alanı, kitap listesinin doğal bir parçası olarak
  // dolduran özet kart. Yeni veri kaynağı/ağ çağrısı eklenmedi — mevcut
  // _books ve _bookStatsCache üzerinden türetiliyor.
  Widget _buildLibraryJourneyFooter() {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    final int totalBooks = _books.length;
    final int startedBooks = _books.where((b) {
      final discoveredWords = _bookStatsCache[b.title]?['total_words'] as int? ?? 0;
      return b.currentPage > 0 || discoveredWords > 0;
    }).length;
    final int finishedBooks = _books.where((b) {
      final total = b.pages.isEmpty ? 1 : b.pages.length;
      final current = b.currentPage.clamp(0, total);
      return total > 1 && current >= total - 1;
    }).length;

    final String message = finishedBooks > 0
        ? '$totalBooks kitaptan $finishedBooks\'ini tamamladın, $startedBooks\'inde ilerliyorsun. Böyle devam! 🔥'
        : startedBooks > 0
            ? '$totalBooks kitaptan $startedBooks\'inde ilerliyorsun. Bir sayfa daha oku, seriyi büyüt! 📖'
            : 'Kitaplığında $totalBooks kitap seni bekliyor. Birine başlamak için dokun! ✨';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.surfaceDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.booksBold, size: 16, color: theme.textMuted),
              const SizedBox(width: 8),
              Text(
                'OKUMA YOLCULUĞUN',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: theme.textMuted, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: GoogleFonts.inter(fontSize: 12.5, color: theme.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Scaffold(
      backgroundColor: theme.background,
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
              _buildStatsOverviewRow(),

              const SizedBox(height: 12),
              // Dikey Yığılmayı Önleyen Hibrit Banner
              _buildHybridBanner(),
              const SizedBox(height: 16),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.surfaceDark.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Text('📜', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Klasik eserler Project Gutenberg (gutenberg.org) kamu malı koleksiyonundandır.',
                        style: GoogleFonts.inter(fontSize: 10.5, color: theme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Text('Kitaplarım (${_books.length})', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: theme.textPrimary)),
              const SizedBox(height: 10),

              Expanded(
                child: _books.isEmpty
                  ? _buildEmptyLibraryState()
                  : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  // UI/UX Düzeltme Listesi — Faz E: kısa kitap listelerinde
                  // ListView'in altında kalan "boş alan" artık çıplak
                  // bırakılmıyor — listenin son satırı olarak bir "Okuma
                  // Yolculuğun" özet kartı ekleniyor (bkz.
                  // _buildLibraryJourneyFooter). Bu, listeyle birlikte
                  // kayar; uzun listelerde en alta düşer, kısa listelerde
                  // hemen son kitabın altında görünür — hiçbir zaman
                  // "yüzen" veya kopuk durmaz.
                  itemCount: _books.length + 1,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == _books.length) {
                      return _buildLibraryJourneyFooter();
                    }
                    final book = _books[index];
                    final stats = _bookStatsCache[book.title];
                    final bool isActive = book.id == _mostRecentlyOpenedBook?.id;

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
                        color: theme.surfaceDark.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.borderSubtle, width: 1),
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
                                // P1-3: emoji yerine Lobi'yle aynı BookCover
                                // (harf monogramı + deterministik renk) —
                                // aynı kitap artık iki ekranda da aynı görünüyor.
                                BookCover(title: book.title, size: 34),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        book.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13.5, color: theme.textPrimary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        // P1-9: "Mark Twain · %0 · 🧠4 ⭐0" gibi
                                        // şifreli emoji-meta yerine düz metin.
                                        isUntouched
                                            ? 'Keşfedilmeyi bekliyor ✨'
                                            : '%$readingPercentage okundu · $discoveredWords kart',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(fontSize: 10.5, color: theme.textSecondary),
                                      ),
                                      if (!isUntouched) ...[
                                        const SizedBox(height: 5),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: readingRatio,
                                            minHeight: 4,
                                            backgroundColor: theme.borderSubtle,
                                            valueColor: AlwaysStoppedAnimation<Color>(theme.infoTeal),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // C-1/P1-1: yalnızca en son açılan kitap birincil
                                // (dolu amber) kalıyor; diğerleri üçüncül (chevron,
                                // dolgusuz) — "ekran başına en fazla bir birincil
                                // buton" kuralı artık kitap satırlarında da geçerli.
                                AppButton.icon(
                                  icon: isActive ? PhosphorIcons.playBold : PhosphorIcons.caretRightBold,
                                  level: isActive ? ButtonLevel.primary : ButtonLevel.tertiary,
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    _openReader(book);
                                  },
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