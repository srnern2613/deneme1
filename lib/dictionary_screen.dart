// ==============================================================
// dictionary_screen.dart
// --------------------------------------------------------------
// SÖZLÜK & KELİME ARAMA EKRANI (HAFIZALI & SARI İKONLU)
// 
// Bu ekran:
// 1. Yerel veritabanındaki kelimeleri listeler ve arama yaptırır.
// 2. Kullanıcının daha önce kaydettiği kartları tespit eder.
// 3. Kayıtlı olan kelimelere doğrudan dolu sarı ikon (amber) koyar.
// 4. İkona tıklandığında anında kart ekler veya siler (Toggle mantığı).
// ==============================================================

// Flutter Material bileşenlerini dahil ediyoruz
import 'package:flutter/material.dart';

// Veritabanı sorguları için oluşturduğumuz SQLite yardımcı sınıfı
import 'database_helper.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  // Kullanıcının arama kutusuna yazdığı metni kontrol eden controller
  final TextEditingController _searchController = TextEditingController();

  // Arama sonucunda listelenecek kelimeleri tutan dinamik liste
  List<Map<String, dynamic>> _searchResults = [];

  // Kullanıcının daha önce Flashcard olarak eklediği kelimelerin sadece isimlerini tutan Set kümesi.
  // Set kullanmamızın sebebi: "Bu kelime kayıtlı mı?" kontrolünün (contains) anında (O(1)) yapılmasıdır.
  Set<String> _savedWordNames = {};

  // Veritabanından veriler yüklenirken dönen çarkı kontrol eden bayrak
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Ekran ilk açıldığında hem kayıtlı kartları öğreniyoruz hem de tüm kelimeleri listeliyoruz
    _loadData('');
  }

  // Hem kullanıcının kayıtlı Flashcard'larını hem de sözlük kelimelerini eşzamanlı çeken metot
  Future<void> _loadData(String query) async {
    setState(() => _isLoading = true);

    // 1. Kullanıcının mevcut flashcard kayıtlarını çekiyoruz
    final savedCards = await DatabaseHelper.instance.getFlashcards();
    
    // Sadece kelime isimlerini küçük harfe çevirip hızlı erişim kümesine (Set) aktarıyoruz
    final Set<String> savedNames = savedCards
        .map((card) => (card['word'] as String).toLowerCase().trim())
        .toSet();

    // 2. Arama kutusundaki kelimeye göre sözlük tablosunda arama yapıyoruz
    final results = await DatabaseHelper.instance.searchWord(query);

    // Ekran hâlâ aktifse arayüzü güncelliyoruz
    if (mounted) {
      setState(() {
        _savedWordNames = savedNames;
        _searchResults = results;
        _isLoading = false;
      });
    }
  }

  // Bir kelimenin sağındaki yer imi (bookmark) butonuna basıldığında çalışan metot
  Future<void> _toggleBookmark(String word, String meaning) async {
    final cleanWord = word.trim();
    final lowerWord = cleanWord.toLowerCase();
    final isAlreadySaved = _savedWordNames.contains(lowerWord);

    if (isAlreadySaved) {
      // -----------------------------------------------------------
      // DURUM A: Kelime zaten kayıtlıysa -> Flashcards tablosundan siliyoruz
      // -----------------------------------------------------------
      // Önce ilgili kelimenin veritabanındaki id'sini bulmak için listeyi tarıyoruz
      final allCards = await DatabaseHelper.instance.getFlashcards();
      final targetCard = allCards.firstWhere(
        (card) => (card['word'] as String).toLowerCase().trim() == lowerWord,
        orElse: () => {},
      );

      if (targetCard.isNotEmpty && targetCard['id'] != null) {
        await DatabaseHelper.instance.deleteFlashcard(targetCard['id'] as int);
      }

      // Ekranda ikonu anında boş ikona çeviriyoruz
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
      // -----------------------------------------------------------
      // DURUM B: Kelime kayıtlı değilse -> Flashcards tablosuna ekliyoruz
      // -----------------------------------------------------------
      await DatabaseHelper.instance.addFlashcard(cleanWord, meaning);

      // Ekranda ikonu anında sarı/dolu ikona çeviriyoruz
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
            // 1. BÖLÜM: Arama Kutusu
            TextField(
              controller: _searchController,
              // Kullanıcı her harf yazdığında veya sildiğinde listeyi yeniden filtreler
              onChanged: (text) => _loadData(text),
              decoration: InputDecoration(
                hintText: 'Kelime veya anlam ara...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
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

            // 2. BÖLÜM: Kelime Kartları Listesi
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
                          itemCount: _searchResults.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _searchResults[index];
                            final String word = item['word'] ?? '';
                            final String meaning = item['meaning'] ?? '';
                            final String? example = item['example'];

                            // Bu kelimenin hafızamızdaki kayıtlılar kümesinde olup olmadığını kontrol ediyoruz
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
                                // SAĞDAKİ DURUMSAL BUTON (KAYITLIYSA SARI VE DOLU)
                                trailing: IconButton(
                                  icon: Icon(
                                    isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                    // Kayıtlıysa amber/sarı, değilse standart tema rengi
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