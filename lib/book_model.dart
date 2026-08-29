// ============================================================================
// DOSYA ADI: lib/book_model.dart
// AÇIKLAMA: Kitap Veri Modeli, Tip-Güvenli JSON Ayrıştırma & İlerleme Mantığı
// ============================================================================

import 'dart:convert';

class Book {
  final String id;              // Kitaba özel benzersiz UUID / Zaman damgası[cite: 5]
  final String title;           // Kitap başlığı[cite: 5]
  final String author;          // Yazar adı[cite: 5]
  final String level;           // CEFR Seviyesi (A1, A2, B1, B2, C1, C2)[cite: 5]
  final String icon;            // Kitaplık kartı simgesi[cite: 5]
  final List<String> pages;     // Ayrıştırılmış sayfa metinleri[cite: 5]
  
  int currentPage;              // En son okunan sayfa indeksi (0 tabanlı)[cite: 5]
  DateTime? lastReadDate;       // Son erişim tarihi[cite: 5]
  int totalReadSeconds;         // Toplam okunan süre (sn)[cite: 5]

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

  /// Toplam sayfa sayısını güvenli döner[cite: 5]
  int get totalPages => pages.isNotEmpty ? pages.length : 1;

  /// 0.0 - 1.0 aralığında okuma tamamlanma yüzdesi[cite: 5]
  double get progress => totalPages > 0 ? (currentPage + 1) / totalPages : 0.0;

  /// Yüzdelik string formatı (Örn: %45)
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