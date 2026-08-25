// ============================================================================
// DOSYA ADI: lib/book_model.dart
// AÇIKLAMA: Kitap Veri Modeli ve Kalıcı Durum Saklama Mantığı
// 
// Bu model; kitabın temel bilgilerini, PDF'ten ayrıştırılan tüm sayfalarını,
// kullanıcının kaldığı sayfayı ve istatistik merkezinde (Dashboard) gösterilecek
// okuma süresi ile son erişim tarihlerini taşır.
// ============================================================================

import 'dart:convert';

class Book {
  final String id;              // Kitaba özel benzersiz kimlik (Zaman damgası ile üretilir)
  final String title;           // Kitabın başlığı (Dosya adı veya hazır kitap ismi)
  final String author;          // Yazar adı
  final String level;           // CEFR Seviyesi (Örn: Başlangıç / B1, İleri / C1)
  final String icon;            // Kitaplık kartında gösterilecek kapak emojisi/simgesi
  final List<String> pages;     // PDF veya TXT'den ayrıştırılmış her bir sayfanın metin dizisi
  
  int currentPage;              // Kullanıcının en son okuduğu / kaldığı sayfa indeksi (0'dan başlar)
  DateTime? lastReadDate;       // Kitabın en son ne zaman açılıp okunduğunu tutan tarih damgası
  int totalReadSeconds;         // Bu kitapta toplam kaç saniye okuma yapıldığı

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

  // Toplam sayfa sayısını güvenli şekilde döndürür (Boşsa en az 1 sayfa kabul eder)
  int get totalPages => pages.isNotEmpty ? pages.length : 1;

  // Kitabın tamamlanma yüzdesini hesaplar (0.0 ile 1.0 arasında bir değer döner, progress bar için kullanılır)
  double get progress => totalPages > 0 ? (currentPage + 1) / totalPages : 0.0;

  // Nesneyi SharedPreferences veritabanına kaydetmek üzere Map formatına dönüştürür
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'level': level,
      'icon': icon,
      'pages': pages,
      'currentPage': currentPage,
      'lastReadDate': lastReadDate?.toIso8601String(), // Tarihi standart ISO formatında metne çevirir
      'totalReadSeconds': totalReadSeconds,
    };
  }

  // Hafızadan okunan Map verisini tekrar tip-güvenli Book nesnesine dönüştürür
  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      author: map['author'] ?? '',
      level: map['level'] ?? '',
      icon: map['icon'] ?? '📖',
      pages: List<String>.from(map['pages'] ?? []),
      currentPage: map['currentPage'] ?? 0,
      lastReadDate: map['lastReadDate'] != null ? DateTime.tryParse(map['lastReadDate']) : null,
      totalReadSeconds: map['totalReadSeconds'] ?? 0,
    );
  }

  // JSON formatına dönüştürme ve JSON'dan nesne üretme köprüleri
  String toJson() => json.encode(toMap());
  factory Book.fromJson(String source) => Book.fromMap(json.decode(source));
}