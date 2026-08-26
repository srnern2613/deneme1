// ============================================================================
// DOSYA ADI: lib/library_screen.dart
// AÇIKLAMA: Duolingo Elmas Modeli, Sağ Üst Cüzdan ve Anti-Hile Entegrasyonlu Kitaplık
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'book_model.dart';
import 'reader_screen.dart';
import 'achievement_service.dart';
import 'streak_freeze_service.dart';
import 'xp_shop_service.dart';

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

        if (newlyUnlocked.isNotEmpty) {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Text('🎉', style: TextStyle(fontSize: 28)),
                  SizedBox(width: 10),
                  Text('Yeni Başarım!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tebrikler, harika bir adım attın ve yeni bir rozetin kilidini açtın:'),
                  const SizedBox(height: 12),
                  ...newlyUnlocked.map((badge) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('🏆 $badge', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                  )),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Harika!'),
                ),
              ],
            ),
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            backgroundColor: const Color(0xFF222226),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.amber, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '+$earnedXp XP Kazanıldı! 🎉',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                      Text(
                        '$actualMinutes dk okundu • Toplam: $_userTotalXp XP',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  void _openShopModal() {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) => StatefulBuilder(
        builder: (modalContext, setModalState) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Text('🛍️', style: TextStyle(fontSize: 26)),
                      SizedBox(width: 10),
                      Text('Elmas Mağazası', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text('💎 $_userGems Elmas', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyan)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Günlük hedeflerden kazandığın elmaslarla serini koru!', style: TextStyle(fontSize: 12.5, color: Colors.grey)),
              const SizedBox(height: 20),

              _buildShopItem(
                emoji: '🛡️',
                title: 'Seri Kalkanı (Streak Freeze)',
                price: '30 💎',
                desc: 'Bir gün uygulamaya giremediğinde serini korur.',
                onBuy: () async {
                  bool success = await XpShopService.instance.spendGems(30);
                  if (success) {
                    await XpShopService.instance.setFreezeShield(true);
                    final newGems = await XpShopService.instance.getGemsBalance();
                    if (!mounted) return;
                    setState(() {
                      _userGems = newGems;
                      _hasFreezeShield = true;
                    });
                    setModalState(() {});
                    nav.pop();
                    messenger.showSnackBar(const SnackBar(content: Text('🛡️ Seri Kalkanı Başarıyla Satın Alındı!')));
                  } else {
                    messenger.showSnackBar(const SnackBar(content: Text('❌ Yetersiz Elmas!')));
                  }
                },
              ),
              const SizedBox(height: 12),

              _buildShopItem(
                emoji: '⚡',
                title: 'Çift XP İksiri (24 Saat)',
                price: '50 💎',
                desc: '24 saat boyunca okuduğun her sayfadan 2 kat XP kazanırsın.',
                onBuy: () async {
                  bool success = await XpShopService.instance.spendGems(50);
                  if (success) {
                    await XpShopService.instance.activateDoubleXp();
                    final newGems = await XpShopService.instance.getGemsBalance();
                    if (!mounted) return;
                    setState(() => _userGems = newGems);
                    setModalState(() {});
                    nav.pop();
                    messenger.showSnackBar(const SnackBar(content: Text('⚡ Çift XP İksiri Aktif Edildi!')));
                  } else {
                    messenger.showSnackBar(const SnackBar(content: Text('❌ Yetersiz Elmas!')));
                  }
                },
              ),
              const SizedBox(height: 12),

              _buildShopItem(
                emoji: '👑',
                title: 'Altın Profil Tacı',
                price: '80 💎',
                desc: 'Profil kartında isminin üzerine parlayan efsanevi taç ekler.',
                onBuy: () async {
                  bool success = await XpShopService.instance.spendGems(80);
                  if (success) {
                    await XpShopService.instance.buyItem('golden_crown');
                    final newGems = await XpShopService.instance.getGemsBalance();
                    if (!mounted) return;
                    setState(() => _userGems = newGems);
                    setModalState(() {});
                    nav.pop();
                    messenger.showSnackBar(const SnackBar(content: Text('👑 Altın Profil Tacı Envantere Eklendi!')));
                  } else {
                    messenger.showSnackBar(const SnackBar(content: Text('❌ Yetersiz Elmas!')));
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShopItem({required String emoji, required String title, required String price, required String desc, required VoidCallback onBuy}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onBuy,
            child: Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  String _formatLastRead(DateTime? date) {
    if (date == null) return 'Henüz okunmadı';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays == 1) return 'Dün';
    return '${diff.inDays} gün önce';
  }

  Widget _buildReadingDashboard(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primaryContainer.withValues(alpha: 0.6),
            colors.surfaceContainerHighest.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.insights_rounded, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Haftalık Karne',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: _hasFreezeShield ? Colors.blue.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(_hasFreezeShield ? '🛡️' : '⏳', style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 3),
                        Text(
                          _hasFreezeShield ? 'Kalkan' : 'Yok',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: _hasFreezeShield ? Colors.blue : Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 3),
                        Text(
                          '$_streakDays G.',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.deepOrange),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatMetric(
                icon: Icons.timer_outlined,
                label: 'Okuma Süresi',
                value: '$_totalReadMinutes dk',
                accentColor: colors.primary,
              ),
              const SizedBox(width: 12),
              _buildStatMetric(
                icon: Icons.search_rounded,
                label: 'İncelenen',
                value: '$_totalWordsExamined Kelime',
                accentColor: Colors.teal,
              ),
              const SizedBox(width: 12),
              _buildStatMetric(
                icon: Icons.bookmark_added_outlined,
                label: 'Kartlara Eklenen',
                value: '$_totalWordsSaved Kelime',
                accentColor: Colors.purple,
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
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: accentColor),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('İngilizce Kitaplık', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          // 💎 Elmas Butonu
          Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _openShopModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 3),
                      Text(
                        '$_userGems',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.cyan[700]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ⚡ XP Butonu
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 3),
                    Text(
                      '$_userTotalXp',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.amber),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _pickAndProcessFile,
        elevation: 2,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.upload_file_rounded, key: ValueKey('icon_upload')),
        ),
        label: Text(_isLoading ? 'Yükleniyor...' : 'Kitap Yükle'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildReadingDashboard(colors),
            
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _isLoading ? null : () {
                HapticFeedback.lightImpact();
                _pickAndProcessFile();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: colors.primary,
                      child: Icon(Icons.add_rounded, color: colors.onPrimary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Yeni PDF veya TXT Kitap Ekle',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: colors.onSurface),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: colors.primary, size: 20),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            Text(
              'Kitaplarım (${_books.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 10),
            
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: _books.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final book = _books[index];
                  final readMinutes = (book.totalReadSeconds / 60).round();

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.35)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 68,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.primaryContainer.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(book.icon, style: const TextStyle(fontSize: 26)),
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
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${book.author} • ${book.totalPages} Sayfa',
                                  style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.6)),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Son okuma: ${_formatLastRead(book.lastReadDate)}${readMinutes > 0 ? ' • $readMinutes dk' : ''}',
                                  style: TextStyle(fontSize: 10, color: colors.primary, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: book.progress,
                                  borderRadius: BorderRadius.circular(4),
                                  minHeight: 5,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _openReader(book);
                            },
                            child: Text(book.currentPage > 0 ? 'Devam Et' : 'Oku', style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}