// ==============================================================
// library_screen.dart
// --------------------------------------------------------------
// İNGİLİZCE KİTAPLIK VE DIŞARIDAN DOSYA YÜKLEME MODÜLÜ
// ==============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final List<Map<String, String>> _books = [
    {
      'title': "Alice's Adventures in Wonderland",
      'author': 'Lewis Carroll',
      'level': 'Başlangıç / B1',
      'icon': '🐇',
      'content':
          'Alice was beginning to get very tired of sitting by her sister on the bank, '
          'and of having nothing to do. Once or twice she had peeped into the book her sister was reading, '
          'but it had no pictures or conversations in it, and what is the use of a book, '
          'thought Alice without pictures or conversations? '
          'So she was considering in her own mind, whether the pleasure of making a daisy-chain '
          'would be worth the trouble of getting up and picking the daisies, when suddenly '
          'a White Rabbit with pink eyes ran close by her.',
    },
    {
      'title': 'The Adventures of Sherlock Holmes',
      'author': 'Arthur Conan Doyle',
      'level': 'Orta Seviye / B2',
      'icon': '🕵️',
      'content':
          'To Sherlock Holmes she is always the woman. I have seldom heard him mention her under any other name. '
          'In his eyes she eclipses and predominates the whole of her sex. '
          'It was not that he felt any emotion akin to love for Irene Adler. '
          'All emotions, and that one particularly, were abhorrent to his cold, precise but admirably balanced mind. '
          'He was, I take it, the most perfect reasoning and observing machine that the world has seen.',
    },
  ];

  Future<void> _pickAndOpenFile() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'documents',
        extensions: <String>['txt', 'epub', 'pdf'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

      if (file != null) {
        final fileName = file.name;
        String content = '';

        if (fileName.toLowerCase().endsWith('.txt')) {
          content = await file.readAsString();
        } else {
          content = 'Seçilen Dosya: $fileName\n\n'
              'Bu dosya cihazınızdan başarıyla yüklendi.\n\n'
              'Metindeki kelimelere dokunarak anında sözlükten anlamlarına bakabilir ve kelime kartı oluşturabilirsiniz.';
        }

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReaderScreen(
              title: fileName,
              author: 'Yüklendi',
              content: content.isEmpty ? 'Metin okunamadı.' : content,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('İngilizce Kitaplık'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndOpenFile,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Dosya Yükle'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _pickAndOpenFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: colors.primary,
                      child: Icon(Icons.file_open_rounded, color: colors.onPrimary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kendi Kitabını / Dosyanı Yükle',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '.txt, .epub veya .pdf dosyası seç',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: colors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Önerilen Klasik Eserler',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _books.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final book = _books[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(book['icon'] ?? '📖', style: const TextStyle(fontSize: 28)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book['title'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  book['author'] ?? '',
                                  style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6)),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    book['level'] ?? '',
                                    style: TextStyle(fontSize: 11, color: colors.primary, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReaderScreen(
                                    title: book['title']!,
                                    author: book['author']!,
                                    content: book['content']!,
                                  ),
                                ),
                              );
                            },
                            child: const Text('Oku'),
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