# PROJE ANAYASASI, MİMARİ KONTROL VE AJAN GELİŞTİRME KURALLARI
# Dosya Adı: PROJECT_RULES.md
# Statü: Dokunulmaz / Bağlayıcı Kural Seti

================================================================================
1. ÜRÜN KONSEPTİ VE OYUN DÖNGÜSÜ (CORE LOOP)
================================================================================
* Kitap Okuma ve Kelime Avı (ReaderScreen): Kullanıcı hem sistemdeki hazır klasikleri hem de kendi yüklediği metinleri/kitapları okur. Bilinmeyen kelimelere dokunarak bağlamı koparmadan avlar ve sözlüğe kaydeder.
* Çok Modlu Pratik ve Egzersiz Ekosistemi:
  - SRS Flashcards (FlashcardsExerciseScreen): Aralıklı tekrar (Spaced Repetition) algoritmasıyla çalışan, unutma eğrisine duyarlı çift taraflı hafıza kartları.
  - 4 Şıklı Quiz (QuizExerciseScreen): Avlanan kelimelerin anlamlarını seçenekler arasından tanıma ve test refleksi kazandırma modu.
  - Kelime Eşleştirme Arenası (MatchExerciseScreen): İngilizce kelimeler ile Türkçe karşılıklarını zamana karşı panoda birleştiren eşleme oyunu.
  - Yazarak Çalışma / İmla Modu (Writing & Spelling Exercise): Anlamı ve sesli ipucu verilen kelimeyi aktif geri çağırma (active recall) yöntemiyle yazdırarak imla hafızasını pekiştirme modu.
* RPG Word Boss Savaşları (WordBossBattleScreen): Egzersizlerde hata yapılan veya zorlanılan kelimeler "Word Boss"a dönüşür; çok turlu (harf tamamlama, anlam, imla) rövanş arenasında alt edilir.
* Sosyal Rekabet & Tutundurma (Retention): Günlük seri (Streak), lig arenası (Leaderboard), vitrin unvanları ve elmas/XP mağaza ekonomisi (XpShopService) ile kullanıcı bağlılığı korunur.

================================================================================
2. GELİŞTİRME İŞ AKIŞI VE DANIŞMANLIK PROTOKOLÜ (ZORUNLU 4 ADIM)
================================================================================
Herhangi bir yeni özellik, refaktör veya bug çözümü talebinde KOD YAZMADAN ÖNCE şu adımlar sırasıyla işletilmelidir:
1. Risk ve Etki Analizi: Yapılacak değişikliğin mevcut veritabanı, SharedPreferences, ekran döngüleri ve kullanıcı deneyimi (UX) üzerindeki olası regresyon riskleri listelenir.
2. Psikoloji, Mimari ve Pazarlama Önerileri: Kodlamaya geçmeden önce insan psikolojisi (FOMO, prestij gösterisi, kayıptan kaçınma), temiz mimari ve pazarlama stratejisi (ASO, kancalar) açısından proaktif iyileştirme önerileri sunulur.
3. Onay Kapısı: Önerilen değişiklikler veya alternatif mimariler KULLANICININ AÇIK ONAYI ALINMADAN koda dökülmez.
4. Kod Üretimi: Onay geldikten sonra kod üretilir. İsteğe göre tam dosya veya noktasal fonksiyon yaması (patch) olarak eksiksiz teslim edilir.

================================================================================
3. TEKNİK DOKUNULMAZLIKLAR VE VERİ BÜTÜNLÜĞÜ
================================================================================
Aşağıdaki teknik kurallardan herhangi bir sapma kesinlikle yasaktır:

* SQLite Bütünlüğü (database_helper.dart):
  - `words` tablosu kolonları ve tipleri sabittir:
    * `id` (INTEGER PK AUTOINCREMENT)
    * `word` (TEXT UNIQUE)
    * `meaning` (TEXT)
    * `repetitions` (INTEGER DEFAULT 0)
    * `interval` (REAL DEFAULT 1.0)
    * `ease_factor` (REAL DEFAULT 2.5)
    * `learning_state` (TEXT: Sadece 'DISCOVERED', 'LEARNING', 'MASTERED' alabilir)
    * `boss_level` (INTEGER DEFAULT 1)
    * `cooldown_until` (TEXT ISO8601)
  - `book_journey_data` tablosundaki `book_id` ve `book_title` anahtarları `Book` modeliyle birebir eşleşir; silinemez, formatı bozulamaz.
  - Sürüm yükseltmelerinde (`onUpgrade`) tekilleştirme yapılırken asla `DELETE WHERE id NOT IN (SELECT MAX(id)...)` kullanılmaz. Öncelik sırası korunur: MASTERED > LEARNING > DISCOVERED.

* SharedPreferences Format Kilitleri:
  - Tarih Damgası: `daily_learned_words_YYYY-MM-DD` ve `streak_completed_YYYY-MM-DD` anahtarlarında iki basamaklı sıfır dolgusu (`padLeft(2, '0')`) zorunludur. Format bozulursa seri sıfırlanır.
  - Kitap Modeli Serileştirme (`saved_books`): `Book` modelindeki `id`, `title`, `author`, `currentPage`, `pages` (`List<String>`), `lastReadDate`, `icon` alanları eksiksiz korunur.
  - Sabit Ekonomi Anahtarları: `user_gems`, `total_xp`, `streak_freeze_count`, `active_cosmetics`, `double_xp_expiry_time` isimleri sabittir.

* Singleton ve Reaktivite Sözleşmesi:
  - `XpShopService.instance.gemsNotifier` ve `xpNotifier` değişkenleri final `ValueNotifier<int>` nesneleridir. Asla yeniden örneğinlenemez (`= ValueNotifier(...)` yapılamaz), sadece `.value = newValue` ile güncellenir.

* Seslendirme Altyapısı (TtsService):
  - Arka plan ses servisleri kaldırılmış olsa bile `TtsService.speak()` ve `TtsService.stop()` çağrıları ile `'en-US'` dil motoru `ReaderScreen` ve tüm pratik ekranlarından (Flashcard, Quiz, Match, Writing, Boss) kaldırılamaz.

* Navigasyon ve Ekran Yaşam Döngüsü:
  - `ReaderScreen` pop edilirken geriye mutlaka `ReadingSessionResult(readMinutes: ..., pagesRead: ...)` nesnesi döndürmelidir.
  - `RootScreen`'de lobi sekmesine her geçildiğinde ve alt ekranlardan (oyunlar, kitaplık, mağaza) dönüldüğünde `.then((_) => refreshDashboardStats())` zinciri işletilmelidir.
  - Egzersiz ekranları havuzda 4'ten az kelime varken tetiklenirse çökmemeli; otomatik sahte şıklar/harfler veya güvenli yönlendirme üretmelidir.
  - Asenkron `await` işlemlerinden sonra `setState` çağrılmadan önce mutlaka `if (!mounted) return;` kontrolü yer almalıdır.

================================================================================
4. GÖRSEL DİL VE TASARIM SİSTEMİ (DESIGN SYSTEM)
================================================================================
* Atmosfer: Derin karanlık, neon vurgulu, cam efektli (Glassmorphism), modern oyun lobisi hissi.
* Sabit Renk Paleti:
  - Zemin (Background): #070B14 (Derin Gece Siyahı)
  - Kart ve Yüzeyler: #0F172A, #111827
  - Panel Kenarlıkları: #1F2937 veya Colors.white.withValues(alpha: 0.1)
  - Birincil Vurgu (Primary Accent): #F59E0B (Kehribar Altın - Aksiyon ve Ödüller)
  - Başarı & Canlı Seri: #10B981 (Zümrüt Yeşili)
  - Bilgi & Okuma: #38BDF8 (Elektrik Mavisi)
  - Bilişsel / SRS: #818CF8, #6366F1 (İndigo Moru)
  - Tehlike & Boss: #EF4444 (Kızıl - Word Boss ve Kritik Seri Uyarıları)
* Tipografi:
  - Başlıklar, sayaçlar, butonlar ve rozetler: GoogleFonts.outfit() (FontWeight.w800 / w900)
  - Gövde metinleri ve açıklamalar: GoogleFonts.inter() (FontWeight.w400 / w500)
* İkon Paketi: phosphoricons_flutter (PhosphorIcons.*) kullanılır.

================================================================================
5. OYUNLAŞTIRMA VE PSİKOLOJİK PRENSİPLER
================================================================================
* Statü & Gösteriş (Prestige Flex): Satın alınan çerçeve, unvan ve taçlar hem Profilde hem Leaderboard sıralamasında görünür.
* Kayıptan Kaçınma (Loss Aversion): Seri tehlikedeyse arayüz acil durum renklerine bürünür, dondurucu öne çıkarılır.
* Değişken Ödül (Gacha): Mağazada elmas tüketimini artıran şanslı sandık ve süreli güçlendiriciler teşvik edilir.
* Sıfır Sürtünme (Zero Friction): Kullanıcı hiçbir aşamada kilitli veya çözümsüz ekranda bırakılmaz.