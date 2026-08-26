// ============================================================================
// DOSYA ADI: lib/library_screen.dart
// AÇIKLAMA: Ana Kitaplık, PDF Yükleyici ve Okuma İstatistik Merkezi (Dashboard)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'book_model.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Book> _books = [];
  bool _isLoading = false;

  int _streakDays = 1;
  int _totalReadMinutes = 0;
  int _totalWordsExamined = 0;
  int _totalWordsSaved = 0;

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

    setState(() {
      _totalReadMinutes = prefs.getInt('stats_total_read_minutes') ?? 0;
      _totalWordsExamined = prefs.getInt('stats_total_words_examined') ?? 0;
      _totalWordsSaved = prefs.getInt('stats_total_words_saved') ?? 0;
      _streakDays = _calculateStreak(prefs.getString('stats_last_active_date'));
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
        Book(
          id: '2',
          title: 'The Adventures of Sherlock Holmes',
          author: 'Arthur Conan Doyle',
          level: 'Orta Seviye / B2',
          icon: '🕵️',
          lastReadDate: DateTime.now().subtract(const Duration(days: 1)),
          totalReadSeconds: 680,
          pages: [
            'To Sherlock Holmes she is always the woman. I have seldom heard him mention her under any other name. In his eyes she eclipses and predominates the whole of her sex.',
            'It was not that he felt any emotion akin to love for Irene Adler. All emotions were abhorrent to his cold, precise but admirably balanced mind.',
          ],
        ),
      ];
      setState(() => _books = defaultBooks);
      _saveBooksToStorage();
    }
  }

  int _calculateStreak(String? lastActiveStr) {
    if (lastActiveStr == null) return 1;
    final lastActive = DateTime.tryParse(lastActiveStr);
    if (lastActive == null) return 1;

    final now = DateTime.now();
    final difference = DateTime(now.year, now.month, now.day)
        .difference(DateTime(lastActive.year, lastActive.month, lastActive.day))
        .inDays;

    if (difference == 0) return _streakDays;
    if (difference == 1) return _streakDays + 1;
    return 1;
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
      HapticFeedback.selectionClick(); // (Dosya seçici açılırken hafif dokunsal geri bildirim sağlar)
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
    HapticFeedback.selectionClick(); // (Okuma seansı başlatılırken dokunma hissi verir)
    
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
      final int addedMinutes = (result.durationSeconds / 60).ceil();
      final int addedPages = result.pagesRead;
      final todayKey = _getTodayKey();

      final prefs = await SharedPreferences.getInstance();
      
      final int currentDailyPages = prefs.getInt('daily_pages_$todayKey') ?? 0;
      final int currentDailyMinutes = prefs.getInt('daily_minutes_$todayKey') ?? 0;

      await prefs.setInt('daily_pages_$todayKey', currentDailyPages + addedPages);
      await prefs.setInt('daily_minutes_$todayKey', currentDailyMinutes + (addedMinutes > 0 ? addedMinutes : 1));

      setState(() {
        book.currentPage = result.lastPage;
        book.lastReadDate = DateTime.now();
        book.totalReadSeconds += result.durationSeconds;

        _totalReadMinutes += (addedMinutes > 0 ? addedMinutes : 1);
        _totalWordsExamined += result.wordsExamined;
        _totalWordsSaved += result.wordsAdded;
      });

      await _saveBooksToStorage();
      await _saveStatsToStorage();

      if (!mounted) return;
      
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
                    const Text(
                      'Okuma Karnene İşlendi! 🎉',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                    ),
                    Text(
                      '${result.durationSeconds ~/ 60} dk okundu • ${result.wordsExamined} kelime incelendi',
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
              Row(
                children: [
                  const Icon(Icons.insights_rounded, size: 20, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Haftalık Okuma Karnesi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      '$_streakDays Gün',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepOrange),
                    ),
                  ],
                ),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _pickAndProcessFile,
        elevation: 2, // (Gölge derinliği sabitlenerek geçişlerdeki titreşim engellendi)
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
                HapticFeedback.lightImpact(); // (Yeni kitap ekle kartına dokunulduğunda yumuşak tıklama hissi)
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
                physics: const BouncingScrollPhysics(), // (Kitap listesinde iOS tarzı akıcı yaylanma efekti sağlandı)
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
                              HapticFeedback.selectionClick(); // (Kitap okuma/devam et butonuna basıldığında dokunma hissi verir)
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