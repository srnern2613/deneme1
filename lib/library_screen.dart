// ============================================================================
// DOSYA ADI: lib/library_screen.dart
// AÇIKLAMA: Sözlük / Kelime Defteri Kancası Eklenmiş Kitaplık Ekranı
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
import 'achievement_service.dart';
import 'streak_freeze_service.dart';
import 'xp_shop_service.dart';
import 'shop_screen.dart';
import 'celebration_dialog.dart';
import 'dictionary_screen.dart'; // <--- Çevrimdışı Sözlük İçe Aktarıldı[cite: 10]

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
  int _userTotalXp = 100;
  int _userGems = 50;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final streakResult = await StreakFreezeService.instance.checkAndUpdateStreak();
    final xp = await XpShopService.instance.getTotalXp();
    final gems = await XpShopService.instance.getGemsBalance();
    final shieldStatus = await XpShopService.instance.hasFreezeShield();

    if (!mounted) return;
    setState(() {
      _totalReadMinutes = prefs.getInt('stats_total_read_minutes') ?? 0;
      _totalWordsExamined = prefs.getInt('stats_total_words_examined') ?? 0;
      _totalWordsSaved = prefs.getInt('stats_total_words_saved') ?? 0;
      _streakDays = streakResult['streakDays'];
      _hasFreezeShield = shieldStatus;
      _userTotalXp = xp;
      _userGems = gems;
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
            'Alice was beginning to get very tired of sitting by her sister on the bank, and of having nothing to do. Once or twice she had peeped into the book her sister was reading, but it had no pictures or conversations in it.',
            'So she was considering in her own mind, whether the pleasure of making a daisy-chain would be worth the trouble of getting up and picking the daisies, when suddenly a White Rabbit with pink eyes ran close by her.',
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
    await prefs.setString('stats_last_active_date', DateTime.now().toIso8601String());
  }

  Future<void> _pickAndProcessFile() async {
    try {
      HapticFeedback.selectionClick();
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'documents',
        extensions: <String>['txt', 'pdf'],
      );

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
          if (pageText.trim().isNotEmpty) {
            pages.add(pageText.trim());
          }
        }
        document.dispose();
      }

      if (pages.isEmpty) {
        pages = ['Belgede okunabilir metin bulunamadı.'];
      }

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: $e')),
      );
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
      final int calculatedMinutes = (validDurationSeconds / 60).ceil();
      final int actualMinutes = validDurationSeconds < 15 ? 0 : (calculatedMinutes > 0 ? calculatedMinutes : 1);
      
      final int addedPages = actualMinutes > 0 ? result.pagesRead : 0;
      
      if (actualMinutes > 0 && addedPages > 0) {
        final earnedXp = actualMinutes * 10;
        final updatedXp = await XpShopService.instance.addXp(earnedXp);

        final todayKey = _getTodayKey();
        final prefs = await SharedPreferences.getInstance();
        
        final int currentDailyPages = prefs.getInt('daily_pages_$todayKey') ?? 0;
        final int currentDailyMinutes = prefs.getInt('daily_minutes_$todayKey') ?? 0;

        await prefs.setInt('daily_pages_$todayKey', currentDailyPages + addedPages);
        await prefs.setInt('daily_minutes_$todayKey', currentDailyMinutes + actualMinutes);

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

        final newlyUnlocked = await AchievementService.instance.checkAndUnlockAchievements(
          totalPagesRead: currentDailyPages + addedPages,
          totalFlashcards: _totalWordsSaved,
          totalReadMinutes: _totalReadMinutes,
        );

        if (!mounted) return;

        CelebrationDialog.show(
          context,
          emoji: '🎉',
          title: 'Harika Okuma Seansı!',
          subtitle: '$actualMinutes dakika boyunca $addedPages sayfa okudun. Zihnin gelişim ivmesi yakaladı!',
          earnedXp: earnedXp,
          actionLabel: 'Süper, Devam Et!',
        );

        if (newlyUnlocked.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 1400), () {
            if (!mounted) return;
            CelebrationDialog.show(
              context,
              emoji: '🏆',
              title: 'Yeni Başarım Kilidi Açıldı!',
              subtitle: newlyUnlocked.map((b) => '• ${b.title}').join('\n'),
              actionLabel: 'Harika!',
            );
          });
        }
      }
    }
  }

  void _openShopScreen() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ShopScreen()),
    ).then((_) => _loadAllData());
  }

  void _openDictionary() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const DictionaryScreen()),
    ).then((_) => _loadAllData());
  }

  String _formatLastRead(DateTime? date) {
    if (date == null) return 'Henüz okunmadı';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays == 1) return 'Dün';
    return '${diff.inDays} gün önce';
  }

  Widget _buildReadingDashboard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1B4B).withValues(alpha: 0.9),
            const Color(0xFF0F172A).withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4)),
        ],
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
                  Text(
                    'Haftalık Karne',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14.5, color: Colors.white),
                  ),
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
                        Text(
                          _hasFreezeShield ? 'Kalkan' : 'Yok',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 10, color: _hasFreezeShield ? const Color(0xFF93C5FD) : Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(PhosphorIcons.fireBold, size: 12, color: Colors.orange),
                        const SizedBox(width: 3),
                        Text(
                          '$_streakDays G.',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 10.5, color: Colors.orange),
                        ),
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
              _buildStatMetric(
                icon: PhosphorIcons.timerBold,
                label: 'Okuma Süresi',
                value: '$_totalReadMinutes dk',
                accentColor: const Color(0xFF38BDF8),
              ),
              const SizedBox(width: 10),
              _buildStatMetric(
                icon: PhosphorIcons.magnifyingGlassBold,
                label: 'İncelenen',
                value: '$_totalWordsExamined Kelime',
                accentColor: const Color(0xFF10B981),
              ),
              const SizedBox(width: 10),
              _buildStatMetric(
                icon: PhosphorIcons.cardsBold,
                label: 'Kartlara Eklenen',
                value: '$_totalWordsSaved Kelime',
                accentColor: const Color(0xFFA855F7),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF070B14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1F2937)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: accentColor),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12.5, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
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
              _buildModernHeader(),
              const SizedBox(height: 18),

              _buildReadingDashboard(),
              const SizedBox(height: 14),

              // --- ÇEVRİMİÇİ / ÇEVRİMDIŞI SÖZLÜK HIZLI ERİŞİM BUTONU ---
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _openDictionary,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(PhosphorIcons.bookBookmarkBold, color: Color(0xFF0F172A), size: 17),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Çevrimdışı Sözlük & Kelime Defteri',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white),
                        ),
                      ),
                      const Icon(PhosphorIcons.caretRightBold, color: Color(0xFF34D399), size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              
              // --- YENİ KİTAP EKLEME BUTONU ---
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _isLoading ? null : () {
                  HapticFeedback.lightImpact();
                  _pickAndProcessFile();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: Color(0xFF38BDF8),
                          shape: BoxShape.circle,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                              )
                            : const Icon(PhosphorIcons.plusBold, color: Color(0xFF0F172A), size: 17),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _isLoading ? 'Kitap İşleniyor...' : 'Yeni PDF veya TXT Kitap Ekle',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white),
                        ),
                      ),
                      const Icon(PhosphorIcons.caretRightBold, color: Color(0xFF38BDF8), size: 18),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 18),
              Text(
                'Kitaplarım (${_books.length})',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: _books.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final book = _books[index];
                    final readMinutes = (book.totalReadSeconds / 60).round();

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(book.icon, style: const TextStyle(fontSize: 24)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${book.author} • ${book.totalPages} Sayfa',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Son okuma: ${_formatLastRead(book.lastReadDate)}${readMinutes > 0 ? ' • $readMinutes dk' : ''}',
                                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF34D399), fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: book.progress,
                                    minHeight: 5,
                                    backgroundColor: const Color(0xFF1F2937),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _openReader(book);
                            },
                            child: Text(
                              book.currentPage > 0 ? 'Devam Et' : 'Oku',
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
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

  Widget _buildModernHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kitaplık',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
            Text(
              'Kişisel Kütüphane & Okuma',
              style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _openShopScreen,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5), width: 1.5),
                ),
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
              decoration: BoxDecoration(
                color: const Color(0xFF111827).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIcons.lightningBold, color: Colors.orange, size: 15),
                  const SizedBox(width: 4),
                  Text('$_userTotalXp', style: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}