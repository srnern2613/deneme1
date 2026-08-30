// ============================================================================
// DOSYA ADI: lib/library_screen.dart
// AÇIKLAMA: Tür Hataları Giderilmiş ve Semantik Renkli Kitaplık
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'book_model.dart';
import 'reader_screen.dart';
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
  int _userGems = 50;
  int _userTotalXp = 100;

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
    final streakResult = await StreakFreezeService.instance.checkAndUpdateStreak();
    final gems = await XpShopService.instance.getGemsBalance();
    final xp = await XpShopService.instance.getTotalXp();
    final shieldStatus = await XpShopService.instance.hasFreezeShield();

    if (!mounted) return;
    setState(() {
      _totalReadMinutes = prefs.getInt('stats_total_read_minutes') ?? 0;
      _totalWordsExamined = prefs.getInt('stats_total_words_examined') ?? 0;
      _totalWordsSaved = prefs.getInt('stats_total_words_saved') ?? 0;
      _streakDays = streakResult['streakDays'] ?? 1;
      _hasFreezeShield = shieldStatus;
      _userGems = gems;
      _userTotalXp = xp;
    });

    final bookDataList = prefs.getStringList('saved_books');
    if (bookDataList != null && bookDataList.isNotEmpty) {
      setState(() {
        _books = bookDataList.map((str) => Book.fromJson(str)).toList();
      });
    } else {
      final defaultBooks = [
        Book(
          id: '1',
          title: "Alice's Adventures in Wonderland",
          author: 'Lewis Carroll',
          level: 'Başlangıç / B1',
          icon: '🐇',
          lastReadDate: DateTime.now().subtract(const Duration(hours: 2)),
          totalReadSeconds: 420,
          pages: [
            'Alice was beginning to get very tired of sitting by her sister on the bank...',
          ],
        ),
      ];
      setState(() => _books = defaultBooks);
      _saveBooksToStorage();
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
      setState(() => _isLoading = false);
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
        final updatedXp = await XpShopService.instance.addXp(earnedXp);

        setState(() {
          book.currentPage = result.lastPage;
          book.lastReadDate = DateTime.now();
          book.totalReadSeconds += validDurationSeconds;
          _totalReadMinutes += actualMinutes;
          _totalWordsExamined += result.wordsExamined;
          _userTotalXp = updatedXp;
        });

        await _saveBooksToStorage();
        await _saveStatsToStorage();
      }
    }
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
              _buildStatMetric(icon: PhosphorIcons.cardsBold, label: 'Kartlara Eklenen', value: '$_totalWordsSaved Kelime', accentColor: const Color(0xFF818CF8)),
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
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _openShopScreen,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF38BDF8))),
                          child: Row(
                            children: [
                              const Icon(PhosphorIcons.diamondBold, color: Color(0xFF38BDF8), size: 15),
                              const SizedBox(width: 5),
                              Text('$_userGems', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF59E0B))),
                        child: Row(
                          children: [
                            const Icon(PhosphorIcons.lightningBold, color: Color(0xFFF59E0B), size: 15),
                            const SizedBox(width: 4),
                            Text('$_userTotalXp XP', style: GoogleFonts.outfit(color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildReadingDashboard(),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _openDictionary,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35), width: 1.5)),
                  child: Row(
                    children: [
                      const Icon(PhosphorIcons.bookBookmarkBold, color: Color(0xFF10B981), size: 17),
                      const SizedBox(width: 14),
                      Expanded(child: Text('Çevrimdışı Sözlük & Kelime Defteri', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white))),
                      const Icon(PhosphorIcons.caretRightBold, color: Color(0xFF34D399), size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _isLoading ? null : () {
                  HapticFeedback.lightImpact();
                  _pickAndProcessFile();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1.5)),
                  child: Row(
                    children: [
                      const Icon(PhosphorIcons.plusBold, color: Color(0xFFF59E0B), size: 17),
                      const SizedBox(width: 14),
                      Expanded(child: Text(_isLoading ? 'Kitap İşleniyor...' : 'Yeni PDF veya TXT Kitap Ekle', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white))),
                      const Icon(PhosphorIcons.caretRightBold, color: Color(0xFFF59E0B), size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Kitaplarım (${_books.length})', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _books.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final book = _books[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF1F2937))),
                      child: Row(
                        children: [
                          Text(book.icon, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white)),
                                Text(book.author, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: const Color(0xFF070B14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _openReader(book);
                            },
                            child: Text(book.currentPage > 0 ? 'Devam Et' : 'Oku', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
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