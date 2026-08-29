// ============================================================================
// DOSYA ADI: lib/dictionary_screen.dart
// AÇIKLAMA: Faz 2 - Clash Royale Tarzı "My Word Collection" & Mastered Arşivi
// GÖREVLER & DÜZELTMELER:
//   1. 5 Aşamalı SRS Hiyerarşisi ve Mastered Kalıcı Başarı Vitrini.
//   2. Asenkron yarış durumlarına karşı mounted güvenliği.
//   3. Performans dostu lazy-loading liste yapısı.
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
  // Arama metin kutusu kontrolcüsü
  final TextEditingController _searchController = TextEditingController();
  
  // Ekranda listelenecek filtrelenmiş kelimelerin listesi
  List<Map<String, dynamic>> _searchResults = [];
  
  // Yüklenme durumu bayrağı
  bool _isLoading = false;
  
  // Seçili filtre sekmesi: 0 = Tüm Sözlük, 1 = Öğreniliyor, 2 = Ustalaşılanlar (Mastered)
  int _selectedFilterIndex = 1;

  // Koleksiyon istatistik sayaçları
  int _totalMasteredCount = 0;
  int _totalLearningCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData('');
  }

  /// Asenkron veri yükleme ve yarış durumu korumalı state yönetimi
  Future<void> _loadData(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final flashcards = await DatabaseHelper.instance.getFlashcards();
      if (!mounted) return;

      _totalMasteredCount = flashcards.where((c) => (c['is_mastered'] as int? ?? 0) == 1).length;
      _totalLearningCount = flashcards.where((c) => (c['is_mastered'] as int? ?? 0) == 0).length;

      List<Map<String, dynamic>> results = [];

      if (_selectedFilterIndex == 0) {
        final rawResults = await DatabaseHelper.instance.searchWord(query);
        if (!mounted) return;
        results = rawResults.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        results = flashcards.where((card) {
          final isMastered = (card['is_mastered'] as int? ?? 0) == 1;
          if (_selectedFilterIndex == 1) {
            return !isMastered;
          } else {
            return isMastered;
          }
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

  /// Kelimeyi koleksiyondan kalıcı olarak silen güvenli operasyon
  Future<void> _deleteWordPermanently(Map<String, dynamic> item) async {
    final word = item['word'] as String;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: Text(
          'Koleksiyondan Çıkar',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '"$word" kelimesini koleksiyonundan ve SRS tekrarlarından kaldırmak istediğine emin misin?',
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

  String _getMasteryStageTitle(int reps) {
    if (reps <= 0) return 'DISCOVERED';
    if (reps == 1) return 'SEEN';
    if (reps == 2) return 'REMEMBERED';
    if (reps == 3) return 'STRONG';
    if (reps == 4) return 'NEAR MASTERY';
    return 'MASTERED';
  }

  Color _getMasteryStageColor(int reps) {
    if (reps <= 0) return const Color(0xFF64748B);
    if (reps == 1) return const Color(0xFF38BDF8);
    if (reps == 2) return const Color(0xFF818CF8);
    if (reps == 3) return const Color(0xFFA855F7);
    if (reps == 4) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
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
          '📚 My Word Collection',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            children: [
              // --- 1. KOLEKSİYON İSTATİSTİK ÖZET KARTI ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Öğreniliyor', '$_totalLearningCount', const Color(0xFF38BDF8)),
                    Container(height: 28, width: 1, color: Colors.white.withValues(alpha: 0.1)),
                    _buildStatItem('🏆 Mastered Words', '$_totalMasteredCount', Colors.amber),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // --- 2. KELİME ARAMA ÇUBUĞU ---
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

              // --- 3. KATEGORİ VE DURUM FİLTRELEME ---
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip(0, 'Tüm Sözlük', PhosphorIcons.bookBookmarkBold),
                    const SizedBox(width: 8),
                    _buildFilterChip(1, 'Öğreniliyor', PhosphorIcons.brainBold),
                    const SizedBox(width: 8),
                    _buildFilterChip(2, '🏆 Mastered Words', PhosphorIcons.trophyBold),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // --- 4. KELİME LİSTESİ VE KOLEKSİYON KARTLARI ---
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
                                  Icon(
                                    _selectedFilterIndex == 2 ? PhosphorIcons.trophy : PhosphorIcons.tray,
                                    size: 48,
                                    color: const Color(0xFF334155),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _selectedFilterIndex == 2
                                        ? 'Henüz mastered kelime yok 🌱\nTekrarları tamamlayarak kalıcı koleksiyonuna katabilirsin.'
                                        : 'Bu filtrede kayıtlı kelime bulunmuyor.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13.5, height: 1.4),
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
                              
                              final int repetitions = item['repetitions'] as int? ?? 0;
                              final bool isMastered = (item['is_mastered'] as int? ?? 0) == 1;
                              final stageTitle = _getMasteryStageTitle(repetitions);
                              final stageColor = _getMasteryStageColor(repetitions);

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isMastered 
                                      ? const Color(0xFF1E1B4B).withValues(alpha: 0.45) 
                                      : const Color(0xFF111827).withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isMastered ? Colors.amber.withValues(alpha: 0.5) : const Color(0xFF1F2937), 
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
                                          if (isMastered)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(PhosphorIcons.crownSimpleBold, color: Colors.amber, size: 12),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'MASTERED • KALICI HAFIZA',
                                                    style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.amber),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: stageColor.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: stageColor.withValues(alpha: 0.4)),
                                                  ),
                                                  child: Text(
                                                    stageTitle,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: stageColor,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Row(
                                                  children: List.generate(5, (dotIndex) {
                                                    final bool isFilled = dotIndex < repetitions;
                                                    return Container(
                                                      width: 6.5,
                                                      height: 6.5,
                                                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: isFilled ? stageColor : const Color(0xFF334155),
                                                      ),
                                                    );
                                                  }),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '$repetitions/5',
                                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
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
      label: Text(label, style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold)),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          HapticFeedback.selectionClick();
          setState(() => _selectedFilterIndex = index);
          _loadData(_searchController.text);
        }
      },
      selectedColor: const Color(0xFF4F46E5),
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