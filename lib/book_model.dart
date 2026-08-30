// ============================================================================
// DOSYA ADI: lib/book_model.dart
// AÇIKLAMA: Kitap Veri Modeli ve JSON Dönüştürücüleri
// ============================================================================

import 'dart:convert';

class Book {
  final String id;
  final String title;
  final String author;
  final String level;
  final String icon;
  final List<String> pages;
  
  int currentPage;
  DateTime? lastReadDate;
  int totalReadSeconds;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.level,
    required this.icon,
    required this.pages,
    this.currentPage = 0,
    this.lastReadDate,
    this.totalReadSeconds = 0,
  });

  int get totalPages => pages.isNotEmpty ? pages.length : 1;
  double get progress => totalPages > 0 ? (currentPage + 1) / totalPages : 0.0;
  String get progressPercentage => '${(progress * 100).toInt()}%';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'level': level,
      'icon': icon,
      'pages': pages,
      'currentPage': currentPage,
      'lastReadDate': lastReadDate?.toIso8601String(),
      'totalReadSeconds': totalReadSeconds,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      author: map['author']?.toString() ?? '',
      level: map['level']?.toString() ?? 'B1',
      icon: map['icon']?.toString() ?? '📖',
      pages: (map['pages'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      currentPage: (map['currentPage'] as num?)?.toInt() ?? 0,
      lastReadDate: map['lastReadDate'] != null ? DateTime.tryParse(map['lastReadDate'].toString()) : null,
      totalReadSeconds: (map['totalReadSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  String toJson() => json.encode(toMap());
  factory Book.fromJson(String source) => Book.fromMap(json.decode(source) as Map<String, dynamic>);
}