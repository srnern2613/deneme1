# 📚 İngilizce E-Kitap & Dil Öğrenme Uygulaması - Proje Durum ve Devam Belgesi

## 1. Proje Özeti ve Amacı
Bu proje; kullanıcıların kendi PDF ve TXT formatındaki İngilizce kitaplarını yükleyip okuyabildikleri, okurken bilmedikleri kelimelere dokunarak anında çevirisini görebildikleri ve bu kelimeleri otomatik olarak aralıklı tekrar (spaced repetition / flashcard) sistemine aktarabildikleri, **Apple Books / Kindle kalitesinde** bir mobil dil öğrenme uygulamasıdır.

---

## 2. Mevcut Mimari ve Tamamlanan Özellikler

### A. Veri Modeli (`lib/book_model.dart`)
* **`Book` Sınıfı:** Kitap kimliği (`id`), başlık, yazar, seviye etiketi, kapak emojisi, ayrıştırılmış sayfalar (`pages`), son okunan sayfa (`currentPage`), son okunma tarihi (`lastReadDate`) ve toplam okuma süresi (`totalReadSeconds`) alanlarını içerir.
* **Kalıcılık:** `SharedPreferences` ile JSON serileştirme (`toMap`/`fromMap`/`toJson`/`fromJson`) tam uyumludur.

### B. E-Kitap Okuma Motoru (`lib/reader_screen.dart`)
* **Hibrit Okuyucu Yapısı:** Yatay sayfalama (`PageView`) + metin taşmalarını engelleyen güvenli dikey kaydırma (`SingleChildScrollView`).
* **Akıllı Paragraf Birleştirme (`_normalizePdfText`):** PDF'lerden gelen yapay satır sonu (`\n`) kırılmalarını temizleyip akıcı kitap paragraflarına dönüştürme.
* **Optik Renk Paletleri (Color Science):**
  * **Aydınlık:** Keten kemik beyazı (`#F8F7F2`) + Karbon gri metin (`#212124`).
  * **Sıcak Sepya (Varsayılan):** Sıcak kitap kağıdı (`#F4ECE0`) + Espresso mürekkep (`#382E25`).
  * **Gece (AMOLED):** Parlamayan derin antrasit (`#141416`) + Mat perlit grisi metin (`#DCDCDA`).
* **Tipografi ve Üst "Aa" Ayar Paneli:**
  * Serif (Klasik Kitap) ve Sans (Modern) font geçişi.
  * Karanlık modda da net görünen kademeli yazı boyutu slider'ı (A- / A+).
* **Immersive Focus Mode:** Ekrana tek dokunuşla tüm barları animasyonlu şekilde gizleme/gösterme.
* **Haptik Geri Bildirim (Haptic Engine):** Sayfa çevirmede `selectionClick`, kelimeye dokunmada `lightImpact`, kartlara eklemede `mediumImpact`.
* **Hızlı Sayfa Atlama (Scrubber):** Alt barda anlık sayfa kaydırma slider'ı.
* **Seans Takipçisi (`ReadingSessionResult`):** Kitaptan çıkıldığında okunan süreyi, incelenen ve kartlara eklenen kelime sayılarını paketleyip geri döndürme.

### C. Kitaplık ve İstatistik Merkezi (`lib/library_screen.dart`)
* **Okuma Karnesi (Dashboard Bar):**
  * 🔥 Günlük Seri (Streak) takibi.
  * ⏱️ Toplam okuma süresi (dakika).
  * 🔍 İncelenen kelime sayısı.
  * 🔖 Kartlara eklenen kelime sayısı.
* **Dosya Ayrıştırma Motoru:** `file_selector` ve `syncfusion_flutter_pdf` kullanarak PDF/TXT dosyalarını sayfa bazlı içeri aktarma.
* **Gelişmiş Kitap Kartları:** Son okuma zamanı (Örn: *Dün*, *15 dk önce*), toplam okuma süresi ve dinamik ilerleme çubuğu (`progress`).

---

## 3. Alınan Kritik Kararlar ve Hafıza Notları

1. **Sayfalama Kararı (Hibrit vs. Dinamik):**
   * *Mevcut Durum:* Metin kaybını önlemek ve temel modülleri hızla tamamlamak için **Hibrit Yapı** (Yatay PageView + Emniyet Scroll) devrede.
   * *Gelecek Planı:* Uygulamanın tüm ana özellikleri bittiğinde `TextPainter` tabanlı tam **Kindle Tarzı Dinamik Yeniden Sayfalama Motoru**na geçilecek.

---

## 4. Sıradaki Geliştirme Yol Haritası (Kaldığımız Yer)

1. **Sözlük ve Kelime Çeviri Entegrasyonu:**
   * Okuyucuda kelimeye dokunulduğunda statik metin yerine **gerçek Türkçe anlam / bağlam çevirisi** getirilmesi.
   * Kelime seviyesi (A1-C2) rozetlerinin gösterilmesi.
2. **Kelime Kartları (Flashcards / Spaced Repetition) Bağlantısı:**
   * "Kelime Kartlarına Ekle" butonunun kelimeyi örnek cümlesiyle birlikte yerel veritabanına (`words_repository` / Hive / SQLite / Prefs) kaydetmesi.
   * Kelime tekrar modülünün (`flashcards_screen.dart`) bu havuzdan beslenmesi.
3. **Text-to-Speech (Sesli Dinleme / Audiobook Hibriti):**
   * Sayfayı doğal aksanla seslendirme ve okunan kelimeyi eşzamanlı vurgulama.
4. **Alışkanlık Takipçisi (`habit_tracker_screen.dart`) Entegrasyonu:**
   * Günlük okuma verilerinin alışkanlık zincirine otomatik yansıması.
5. **Dinamik Kindle Sayfalama Motoru Refaktörü:**
   * Projenin son aşamasında dikey kaydırmayı tamamen kaldıran piksel tabanlı sayfalama.