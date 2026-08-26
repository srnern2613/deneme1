// ==============================================================
// dictionary_screen.dart
// --------------------------------------------------------------
// SÖZLÜK & KELİME ARAMA EKRANI (HAFIZALI & SARI İKONLU)
// ==============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // (Dokunma haptic geri bildirimleri için içe aktarıldı)
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

  @override
  void initState() {
    super.initState();
    _loadData('');
  }

  Future<void> _loadData(String query) async {
    setState(() => _isLoading = true);

    final savedCards = await DatabaseHelper.instance.getFlashcards();
    final Set<String> savedNames = savedCards
        .map((card) => (card['word'] as String).toLowerCase().trim())
        .toSet();

    final results = await DatabaseHelper.instance.searchWord(query);

    if (mounted) {
      setState(() {
        _savedWordNames = savedNames;
        _searchResults = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBookmark(String word, String meaning) async {
    HapticFeedback.selectionClick(); // (Kelime kartı kaydetme/çıkarma butonuna tıklandığında akıcı his verir)
    final cleanWord = word.trim();
    final lowerWord = cleanWord.toLowerCase();
    final isAlreadySaved = _savedWordNames.contains(lowerWord);

    if (isAlreadySaved) {
      final allCards = await DatabaseHelper.instance.getFlashcards();
      final targetCard = allCards.firstWhere(
        (card) => (card['word'] as String).toLowerCase().trim() == lowerWord,
        orElse: () => {},
      );

      if (targetCard.isNotEmpty && targetCard['id'] != null) {
        await DatabaseHelper.instance.deleteFlashcard(targetCard['id'] as int);
      }

      setState(() {
        _savedWordNames.remove(lowerWord);
      });

      if (!mounted) return;
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

      setState(() {
        _savedWordNames.add(lowerWord);
      });

      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çevrimdışı Sözlük'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (text) => _loadData(text),
              decoration: InputDecoration(
                hintText: 'Kelime veya anlam ara...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          HapticFeedback.lightImpact(); // (Arama temizleme tuşuna basıldığında dokunma hissi verir)
                          _searchController.clear();
                          _loadData('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            'Eşleşen kelime bulunamadı.',
                            style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)),
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(), // (Sözlük listesinde iOS tarzı akıcı yaylanma efekti sağlandı)
                          itemCount: _searchResults.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _searchResults[index];
                            final String word = item['word'] ?? '';
                            final String meaning = item['meaning'] ?? '';
                            final String? example = item['example'];

                            final bool isSaved = _savedWordNames.contains(word.toLowerCase().trim());

                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                title: Text(
                                  word,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      meaning,
                                      style: TextStyle(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (example != null && example.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        example,
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          fontSize: 12,
                                          color: colors.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                    color: isSaved ? Colors.amber[700] : colors.onSurface.withValues(alpha: 0.4),
                                    size: 26,
                                  ),
                                  tooltip: isSaved ? 'Koleksiyondan Çıkar' : 'Flashcard Ekle',
                                  onPressed: () => _toggleBookmark(word, meaning),
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