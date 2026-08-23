// ==============================================================
// flashcards_screen.dart
// --------------------------------------------------------------
// KELİME KARTLARI LİSTESİ VE EGZERSİZ BAŞLATMA EKRANI
// ==============================================================

// Flutter temel arayüz kütüphanesini dahil ediyoruz
import 'package:flutter/material.dart';

// Veritabanı yardımcı sınıfını çağırıyoruz
import 'database_helper.dart';

// Tam ekran egzersiz ekranını import ediyoruz
import 'flashcards_exercise_screen.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  // SQLite veritabanından çekilen kayıtlı kelime kartları
  List<Map<String, dynamic>> _cards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFlashcards();
  }

  // SQLite'tan kartları çeken metot
  void _loadFlashcards() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getFlashcards();
    if (mounted) {
      setState(() {
        _cards = data;
        _isLoading = false;
      });
    }
  }

  // Kartı veritabanından silen metot
  void _deleteCard(int id) async {
    await DatabaseHelper.instance.deleteFlashcard(id);
    _loadFlashcards();
  }

  // Egzersiz Ekranını Açan Metot
  void _startExercise() {
    if (_cards.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FlashcardsExerciseScreen(cards: _cards),
      ),
    ).then((_) {
      // Egzersizden geri dönüldüğünde listeyi tekrar günceller
      _loadFlashcards();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelime Kartlarım (SRS)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadFlashcards,
            tooltip: 'Yenile',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.style_outlined,
                        size: 64,
                        color: colors.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      const Text('Henüz kaydedilmiş kelime kartınız yok.'),
                      const SizedBox(height: 8),
                      Text(
                        'Sözlükten kelime ekleyerek egzersize başlayabilirsiniz.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),

                      // 1. BÖLÜM: Egzersiz Başlatma Butonu (Taşma Hatası Giderilmiş Alan)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            // Sol taraftaki metin alanı ekran genişliğine göre esner
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Toplam ${_cards.length} Kart Hazır',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colors.onPrimaryContainer,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Kaydırarak çalış ve tekrar et.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.onPrimaryContainer.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Sağdaki Egzersiz Butonu
                            FilledButton.icon(
                              onPressed: _startExercise,
                              icon: const Icon(Icons.play_arrow_rounded, size: 20),
                              label: const Text('Egzersiz'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 2. BÖLÜM: Kartların Listesi
                      Expanded(
                        child: ListView.builder(
                          itemCount: _cards.length,
                          itemBuilder: (context, index) {
                            final card = _cards[index];
                            return Dismissible(
                              key: ValueKey(card['id']),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: colors.error,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(Icons.delete_outline, color: Colors.white),
                              ),
                              onDismissed: (_) => _deleteCard(card['id']),
                              child: _FlashcardItem(
                                word: card['word'],
                                meaning: card['meaning'],
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

// Tekil Kart Arayüz Bileşeni
class _FlashcardItem extends StatefulWidget {
  final String word;
  final String meaning;

  const _FlashcardItem({required this.word, required this.meaning});

  @override
  State<_FlashcardItem> createState() => _FlashcardItemState();
}

class _FlashcardItemState extends State<_FlashcardItem> {
  bool _showMeaning = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _showMeaning = !_showMeaning),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.primaryContainer,
                child: Icon(
                  _showMeaning ? Icons.visibility_outlined : Icons.touch_app_outlined,
                  size: 18,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.word,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _showMeaning ? widget.meaning : 'Anlamı görmek için dokunun',
                      style: TextStyle(
                        fontSize: 13,
                        color: _showMeaning ? colors.primary : colors.onSurface.withValues(alpha: 0.5),
                        fontWeight: _showMeaning ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}