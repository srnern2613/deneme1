// ============================================================================
// DOSYA ADI: lib/default_books.dart
// AÇIKLAMA: Akıllı Sayfalama, Stop-Words ve Tire Ayıklama Destekli Gutenberg Yöneticisi
// ============================================================================

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'book_model.dart';

class DefaultBooksManager {
  static const String _seededKey = 'is_gutenberg_books_seeded_v11';

  static final List<Map<String, String>> _bookConfigs = [
    {
      'id': 'gutenberg_tom_sawyer_01',
      'title': 'The Adventures of Tom Sawyer',
      'author': 'Mark Twain',
      'level': 'B1',
      'icon': '🎨',
      'path': 'assets/books/tom_sawyer.txt',
    },
    {
      'id': 'gutenberg_pride_prejudice_02',
      'title': 'Pride and Prejudice',
      'author': 'Jane Austen',
      'level': 'B2',
      'icon': '👒',
      'path': 'assets/books/pride_and_prejudice.txt',
    },
    {
      'id': 'gutenberg_great_gatsby_03',
      'title': 'The Great Gatsby',
      'author': 'F. Scott Fitzgerald',
      'level': 'B2',
      'icon': '🍸',
      'path': 'assets/books/great_gatsby.txt',
    },
    {
      'id': 'gutenberg_dorian_gray_04',
      'title': 'The Picture of Dorian Gray',
      'author': 'Oscar Wilde',
      'level': 'C1',
      'icon': '🖼️',
      'path': 'assets/books/dorian_gray.txt',
    },
    {
      'id': 'gutenberg_frankenstein_05',
      'title': 'Frankenstein',
      'author': 'Mary Shelley',
      'level': 'B2',
      'icon': '⚡',
      'path': 'assets/books/frankenstein.txt',
    },
  ];

  static Future<void> seedDefaultBooksIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isSeeded = prefs.getBool(_seededKey) ?? false;

    if (!isSeeded) {
      List<String> existingBookList = prefs.getStringList('saved_books') ?? [];

      for (var config in _bookConfigs) {
        try {
          String rawText = await rootBundle.loadString(config['path']!);

          const startMarker = "START OF THE PROJECT GUTENBERG";
          int startIndex = rawText.indexOf(startMarker);
          if (startIndex != -1) {
            int lineBreakIndex = rawText.indexOf('\n', startIndex);
            if (lineBreakIndex != -1) {
              rawText = rawText.substring(lineBreakIndex);
            }
          }

          rawText = rawText.replaceAll(RegExp(r'([—–-])'), r' $1 ');

          List<String> pages = [];
          List<String> paragraphs = rawText
              .split(RegExp(r'\n\s*\n'))
              .map((p) => p.replaceAll('\n', ' ').trim())
              .where((p) => p.isNotEmpty)
              .toList();

          String currentPageBuffer = "";
          const int maxPageChars = 850; 

          for (var paragraph in paragraphs) {
            if ((currentPageBuffer.length + paragraph.length) < maxPageChars) {
              currentPageBuffer += (currentPageBuffer.isEmpty ? "" : "\n\n") + paragraph;
            } else {
              if (currentPageBuffer.isNotEmpty) {
                pages.add(currentPageBuffer);
              }
              currentPageBuffer = paragraph;
            }
          }
          if (currentPageBuffer.isNotEmpty) {
            pages.add(currentPageBuffer);
          }

          if (pages.isEmpty) {
            pages = [rawText];
          }

          final book = Book(
            id: config['id']!,
            title: config['title']!,
            author: config['author']!,
            level: config['level']!,
            icon: config['icon']!,
            pages: pages,
          );

          existingBookList.removeWhere((str) {
            try {
              return Book.fromJson(str).id == book.id;
            } catch (_) {
              return false;
            }
          });

          existingBookList.add(book.toJson());
        } catch (_) {}
      }

      await prefs.setStringList('saved_books', existingBookList);
      await prefs.setBool(_seededKey, true);
    }
  }

  static bool isValidWordToSave(String word) {
    final clean = word.trim().toLowerCase();
    
    const Set<String> stopWords = {
      'the', 'and', 'to', 'of', 'a', 'an', 'in', 'is', 'it', 'you', 'that', 
      'he', 'was', 'for', 'on', 'are', 'with', 'as', 'i', 'his', 'they', 
      'be', 'at', 'one', 'have', 'this', 'from', 'or', 'had', 'by', 'hot', 
      'word', 'but', 'what', 'some', 'we', 'can', 'out', 'other', 'were', 
      'all', 'there', 'when', 'up', 'use', 'your', 'how', 'said', 
      'each', 'she', 'which', 'do', 'their', 'time', 'if', 'will', 'way', 
      'about', 'many', 'then', 'them', 'would', 'write', 'like', 'so', 
      'these', 'her', 'long', 'make', 'thing', 'see', 'him', 'two', 'has', 
      'look', 'more', 'day', 'could', 'go', 'come', 'did', 'my', 'sound', 
      'no', 'most', 'number', 'who', 'over', 'know', 'water', 'than', 
      'call', 'first', 'people', 'may', 'down', 'side', 'been', 'now', 'find'
    };

    if (stopWords.contains(clean)) {
      return false;
    }

    final regex = RegExp(r'^[a-z]{2,}$');
    return regex.hasMatch(clean);
  }
}