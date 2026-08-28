// ============================================================================
// DOSYA ADI: lib/dictionary_screen.dart
// AÇIKLAMA: Read-only Hataları Giderilmiş Sözlük Ekranı
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
  Set<String> _savedWordNames = {};
  bool _isLoading = false;
  bool _onlySavedFilter = false;

  @override
  void initState() {
    super.initState();
    _loadData('');
  }

  Future<void> _loadData(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final savedCards = await DatabaseHelper.instance.getFlashcards();
      final Set<String> savedNames = savedCards
          .map((card) => (card['word'] as String).toLowerCase().trim())
          .toSet();

      List<Map<String, dynamic>> results;
      if (_onlySavedFilter) {
        results = List.from(savedCards);
        if (query.trim().isNotEmpty) {
          final q = query.toLowerCase().trim();
          results = results.where((item) {
            final w = (item['word'] as String).toLowerCase();
            final m = (item['meaning'] as String).toLowerCase();
            return w.contains(q) || m.contains(q);
          }).toList();
        }
      } else {
        // SQLite'tan gelen listeyi değiştirilebilir yapmak için List.from() ile sarmalıyoruz
        final rawResults = await DatabaseHelper.instance.searchWord(query);
        results = rawResults.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      if (!mounted) return;
      setState(() {
        _savedWordNames = savedNames;
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBookmark(Map<String, dynamic> item) async {
    HapticFeedback.selectionClick();
    final word = item['word'] as String;
    final meaning = item['meaning'] as String;
    final cleanWord = word.trim();
    final lowerWord = cleanWord.toLowerCase();
    final isAlreadySaved = _savedWordNames.contains(lowerWord);

    if (isAlreadySaved) {
      await DatabaseHelper.instance.removeFlashcardByWord(cleanWord);
      
      if (!mounted) return;
      setState(() {
        _savedWordNames.remove(lowerWord);
        if (_onlySavedFilter) {
          _searchResults.removeWhere((element) => (element['word'] as String).toLowerCase().trim() == lowerWord);
        }
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$cleanWord" kelime kartlarından çıkarıldı.'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      await DatabaseHelper.instance.addFlashcard(cleanWord, meaning);

      if (!mounted) return;
      setState(() {
        _savedWordNames.add(lowerWord);
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$cleanWord" kelime kartlarına eklendi! 🌟'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteWordPermanently(Map<String, dynamic> item) async {
    final word = item['word'] as String;
    final id = item['id'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFF334155))),
        title: Text('Kelimeyi Sil', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('"$word" kelimesini sözlükten ve kartlardan kalıcı olarak silmek istediğine emin misin?', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal', style: GoogleFonts.outfit(color: const Color(0xFF94A3B8))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Tamamen Sil', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedback.mediumImpact();
      final db = await DatabaseHelper.instance.database;
      
      if (id != null) {
        await db.delete('dictionary', where: 'id = ?', whereArgs: [id]);
      } else {
        await db.delete('dictionary', where: 'word = ? COLLATE NOCASE', whereArgs: [word]);
      }
      
      await DatabaseHelper.instance.removeFlashcardByWord(word);

      if (!mounted) return;
      setState(() {
        _searchResults.removeWhere((element) => element['word'].toString().toLowerCase() == word.toLowerCase());
        _savedWordNames.remove(word.toLowerCase().trim());
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$word" sözlükten tamamen silindi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
          'Çevrimdışı Sözlük & Defter',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (text) => _loadData(text),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Kelime veya anlam ara...',
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
              const SizedBox(height: 12),

              Row(
                children: [
                  ChoiceChip(
                    label: Text('Tüm Sözlük', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                    selected: !_onlySavedFilter,
                    selectedColor: const Color(0xFF4F46E5),
                    backgroundColor: const Color(0xFF111827),
                    labelStyle: TextStyle(color: !_onlySavedFilter ? Colors.white : const Color(0xFF94A3B8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _onlySavedFilter = false);
                        _loadData(_searchController.text);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('⭐ Kelime Defterim (${_savedWordNames.length})', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                    selected: _onlySavedFilter,
                    selectedColor: const Color(0xFF4F46E5),
                    backgroundColor: const Color(0xFF111827),
                    labelStyle: TextStyle(color: _onlySavedFilter ? Colors.white : const Color(0xFF94A3B8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _onlySavedFilter = true);
                        _loadData(_searchController.text);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                    : _searchResults.isEmpty
                        ? Center(
                            child: Text(
                              _onlySavedFilter ? 'Henüz kaydedilmiş kelime bulunmuyor.' : 'Eşleşen kelime bulunamadı.',
                              style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
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
                              final String? example = item['example'];

                              final bool isSaved = _savedWordNames.contains(word.toLowerCase().trim());

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111827).withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            word,
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            meaning,
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF38BDF8),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          if (example != null && example.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              example,
                                              style: GoogleFonts.inter(
                                                fontStyle: FontStyle.italic,
                                                fontSize: 11.5,
                                                color: const Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        isSaved ? PhosphorIcons.bookmarkSimpleBold : PhosphorIcons.bookmarkSimple,
                                        color: isSaved ? Colors.amber : const Color(0xFF64748B),
                                        size: 22,
                                      ),
                                      tooltip: isSaved ? 'Koleksiyondan Çıkar' : 'Flashcard Ekle',
                                      onPressed: () => _toggleBookmark(item),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        PhosphorIcons.trashBold,
                                        color: Color(0xFFEF4444),
                                        size: 20,
                                      ),
                                      tooltip: 'Sözlükten Sil',
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
}