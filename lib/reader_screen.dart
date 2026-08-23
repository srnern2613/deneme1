// ==============================================================
// reader_screen.dart
// --------------------------------------------------------------
// METİN İÇİ SÖZLÜK ENTEGRASYONLU E-KİTAP OKUYUCU EKRANI
// ==============================================================

import 'package:flutter/material.dart';
import 'database_helper.dart';

class ReaderScreen extends StatefulWidget {
  final String title;
  final String author;
  final String content;

  const ReaderScreen({
    super.key,
    required this.title,
    required this.author,
    required this.content,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  // Yazı boyutu ayarı
  double _fontSize = 18.0;

  // Noktalama işaretlerini temizleyip sözlükte arama yapan ve alt pencereyi açan metot
  Future<void> _lookupWord(String rawWord) async {
    // Kelimenin başındaki ve sonundaki noktalama işaretlerini temizliyoruz
    final cleanWord = rawWord.replaceAll(RegExp(r"[^\w\s']"), '').trim();
    if (cleanWord.isEmpty) return;

    // Veritabanında kelimeyi arıyoruz
    final results = await DatabaseHelper.instance.searchWord(cleanWord);

    if (!mounted) return;

    // Alttan açılan Sözlük Penceresi (Modal Bottom Sheet)
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final hasResult = results.isNotEmpty;
        final meaning = hasResult ? results.first['meaning'] : 'Sözlükte anlam bulunamadı.';

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cleanWord,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                meaning,
                style: TextStyle(
                  fontSize: 16,
                  color: hasResult ? colors.primary : colors.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              if (hasResult)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.bookmark_add_rounded),
                    label: const Text('Kelime Kartlarıma (SRS) Ekle'),
                    onPressed: () async {
                      await DatabaseHelper.instance.addFlashcard(cleanWord, meaning);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('"$cleanWord" kelime kartlarına eklendi! 🌟'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Metni kelimelere bölüyoruz
    final words = widget.content.split(RegExp(r'\s+'));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 17)),
        actions: [
          // Yazı boyutu küçültme
          IconButton(
            icon: const Icon(Icons.text_decrease_rounded),
            onPressed: () {
              if (_fontSize > 14) setState(() => _fontSize -= 2);
            },
          ),
          // Yazı boyutu büyütme
          IconButton(
            icon: const Icon(Icons.text_increase_rounded),
            onPressed: () {
              if (_fontSize < 28) setState(() => _fontSize += 2);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.author,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Divider(height: 32),
            // Her kelimeye tıklanabilir Wrap düzeni
            Wrap(
              spacing: 5.0,
              runSpacing: 4.0,
              children: words.map((word) {
                return InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _lookupWord(word),
                  child: Text(
                    word,
                    style: TextStyle(
                      fontSize: _fontSize,
                      height: 1.6,
                      letterSpacing: 0.2,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}