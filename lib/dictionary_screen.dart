// ============================================================================
// DOSYA ADI: lib/dictionary_screen.dart
// AÇIKLAMA: 5 Kademeli Learning State Destekli Sözlük ve Kelime Koleksiyonu
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'database_helper.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  
  // 0: Tümü, 1: DISCOVERED, 2: LEARNING, 3: REVIEWING, 4: FAMILIAR, 5: MASTERED
  int _selectedFilterIndex = 0;

  int _totalMasteredCount = 0;
  int _totalLearningCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData('');
  }

  Future<void> _loadData(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final flashcards = await DatabaseHelper.instance.getFlashcards();
      if (!mounted) return;

      _totalMasteredCount = flashcards.where((c) => (c['learning_state'] == 'MASTERED' || (c['is_mastered'] as int? ?? 0) == 1)).length;
      _totalLearningCount = flashcards.where((c) => (c['learning_state'] != 'MASTERED' && (c['is_mastered'] as int? ?? 0) == 0)).length;

      List<Map<String, dynamic>> results = [];

      if (_selectedFilterIndex == 0) {
        if (query.trim().isNotEmpty) {
          final rawResults = await DatabaseHelper.instance.searchWord(query);
          if (!mounted) return;
          results = rawResults.map((e) => Map<String, dynamic>.from(e)).toList();
        } else {
          results = flashcards.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } else {
        final stateFilter = _getStateKeyForIndex(_selectedFilterIndex);
        results = flashcards.where((card) {
          final s = card['learning_state'] as String? ?? 'LEARNING';
          return s == stateFilter;
        }).map((e) => Map<String, dynamic>.from(e)).toList();

        if (query.trim().isNotEmpty) {
          final q = query.toLowerCase().trim();
          results = results.where((item) {
            final w = (item['word'] as String? ?? '').toLowerCase();
            final m = (item['meaning'] as String? ?? '').toLowerCase();
            return w.contains(q) || m.contains(q);
          }).toList();
        }
      }

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _getStateKeyForIndex(int index) {
    switch (index) {
      case 1:
        return 'DISCOVERED';
      case 2:
        return 'LEARNING';
      case 3:
        return 'REVIEWING';
      case 4:
        return 'FAMILIAR';
      case 5:
        return 'MASTERED';
      default:
        return 'ALL';
    }
  }

  Future<void> _deleteWordPermanently(Map<String, dynamic> item) async {
    final word = item['word'] as String;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF1F2937)),
        ),
        title: Text(
          'Koleksiyondan Çıkar',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '"$word" kelimesini koleksiyonundan ve tekrarlarından kaldırmak istediğine emin misin?',
          style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal', style: GoogleFonts.outfit(color: const Color(0xFF94A3B8))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Kaldır', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      HapticFeedback.mediumImpact();
      await DatabaseHelper.instance.removeFlashcardByWord(word);
      if (!mounted) return;
      _loadData(_searchController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$word" koleksiyondan çıkarıldı.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildLearningStateBadge(String state) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (state) {
      case 'MASTERED':
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF34D399);
        label = 'Usta (Mastered)';
        icon = Icons.check_circle_rounded;
        break;
      case 'FAMILIAR':
        bg = const Color(0xFFFBBF24).withValues(alpha: 0.15);
        fg = const Color(0xFFFDE68A);
        label = 'Aşina';
        icon = Icons.verified_outlined;
        break;
      case 'REVIEWING':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        fg = const Color(0xFFF59E0B);
        label = 'Tekrarda';
        icon = Icons.loop_rounded;
        break;
      case 'LEARNING':
        bg = const Color(0xFF818CF8).withValues(alpha: 0.15);
        fg = const Color(0xFF818CF8);
        label = 'Öğreniliyor';
        icon = Icons.auto_stories_rounded;
        break;
      case 'DISCOVERED':
      default:
        bg = const Color(0xFF38BDF8).withValues(alpha: 0.15);
        fg = const Color(0xFF38BDF8);
        label = 'Keşfedildi';
        icon = Icons.search_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B14),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '📚 Kelime Defteri & Sözlük',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Öğreniliyor', '$_totalLearningCount', const Color(0xFF818CF8)),
                    Container(height: 28, width: 1, color: const Color(0xFF1F2937)),
                    _buildStatItem('Mastered Words', '$_totalMasteredCount', const Color(0xFF10B981)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _searchController,
                onChanged: (text) => _loadData(text),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Koleksiyonunda ara...',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
                  prefixIcon: const Icon(PhosphorIcons.magnifyingGlassBold, color: Color(0xFF64748B), size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(PhosphorIcons.xBold, color: Color(0xFF64748B), size: 18),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _searchController.clear();
                            _loadData('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF111827),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF1F2937), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip(0, 'Tümü', PhosphorIcons.rowsBold),
                    const SizedBox(width: 8),
                    _buildFilterChip(1, 'Keşfedildi', PhosphorIcons.magnifyingGlassBold),
                    const SizedBox(width: 8),
                    _buildFilterChip(2, 'Öğreniliyor', PhosphorIcons.bookBookmarkBold),
                    const SizedBox(width: 8),
                    _buildFilterChip(3, 'Tekrarda', PhosphorIcons.arrowClockwiseBold),
                    const SizedBox(width: 8),
                    _buildFilterChip(4, 'Aşina', PhosphorIcons.sparkleBold),
                    const SizedBox(width: 8),
                    _buildFilterChip(5, 'Mastered', PhosphorIcons.trophyBold),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                    : _searchResults.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    PhosphorIcons.tray,
                                    size: 44,
                                    color: Color(0xFF334155),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Bu filtrede kayıtlı kelime bulunmuyor.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13.5),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _searchResults.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _searchResults[index];
                              final String word = item['word'] ?? '';
                              final String meaning = item['meaning'] ?? '';
                              final String? bookTitle = item['book_title'];
                              final String? contextSentence = item['context_sentence'];
                              final String currentState = item['learning_state'] as String? ?? 'LEARNING';
                              final bool isMastered = currentState == 'MASTERED' || (item['is_mastered'] as int? ?? 0) == 1;

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111827),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isMastered ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFF1F2937), 
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                word,
                                                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 17, color: Colors.white),
                                              ),
                                              const SizedBox(width: 8),
                                              if (bookTitle != null && bookTitle.isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.06),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    bookTitle,
                                                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            meaning,
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF38BDF8),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14.5,
                                            ),
                                          ),
                                          if (contextSentence != null && contextSentence.trim().isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              '"$contextSentence"',
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFF94A3B8),
                                                fontSize: 11.5,
                                                fontStyle: FontStyle.italic,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          const SizedBox(height: 10),
                                          _buildLearningStateBadge(currentState),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        PhosphorIcons.trashBold,
                                        color: Color(0xFFEF4444),
                                        size: 19,
                                      ),
                                      tooltip: 'Koleksiyondan Çıkar',
                                      onPressed: () => _deleteWordPermanently(item),
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

  Widget _buildStatItem(String title, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildFilterChip(int index, String label, IconData icon) {
    final bool isSelected = _selectedFilterIndex == index;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
      ),
      label: Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          HapticFeedback.selectionClick();
          setState(() => _selectedFilterIndex = index);
          _loadData(_searchController.text);
        }
      },
      selectedColor: const Color(0xFF6366F1),
      backgroundColor: const Color(0xFF111827),
      labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF94A3B8)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF1F2937),
          width: 1.5,
        ),
      ),
    );
  }
}