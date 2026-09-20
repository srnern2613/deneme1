# Ignis (Draconic Lingua) — Proje Bağlam Dosyası

> Bu dosya, ChatGPT gibi başka bir AI'ya projeyi hızlıca ve düşük token maliyetiyle
> tanıtmak için hazırlanmıştır. Kod değişikliği için değil, planlama/danışma
> amaçlıdır — gerçek dosya değişiklikleri Claude (Cowork) üzerinden, geliştiricinin
> bilgisayarına bağlı oturumda yapılır.

## Ne bu uygulama?
**Draconic Lingua (kod adı: Ignis)** — "Duolingo meets MasterClass" vizyonuyla, karanlık
fantezi (dark fantasy) RPG estetiğinde bir dil öğrenme + kitap okuma uygulaması.
Kullanıcı ("Maceracı") PDF/TXT kitap okuyarak hedef dilde kelime dağarcığını
geliştiriyor, bilmediği kelimeleri bağlamdan avlıyor, SRS (FSRS tabanlı aralıklı
tekrar) ile kalıcı hafızaya kazıyor. Oyunlaştırma: kelime boss'ları, günlük seri
(streak), XP, başarımlar; rehber maskot "Ignis" adında bir ejderha.

Arayüz dili şu an Türkçe. Uzun vadede tek kod tabanından çoklu arayüz dili +
çoklu öğrenilen dil (İngilizce, İspanyolca, Portekizce) desteklenecek şekilde
planlanıyor.

## Teknoloji
- Flutter (vanilla, ağırlıklı StatefulWidget — Riverpod/Bloc gerekmedikçe yok)
- sqflite (yerel DB), shared_preferences (streak/XP/tarih damgaları)
- file_selector + syncfusion_flutter_pdf (PDF metin ayıklama)
- flutter_animate + CustomPaint (mağaza/rozet animasyonları)
- phosphoricons_flutter — **tek ikon kaynağı**, standart Material ikonlar yasak
- Tipografi: başlıklar `GoogleFonts.lora()`, ara başlıklar `GoogleFonts.outfit()`, gövde `GoogleFonts.inter()`
- Tema sistemi: `core/theme/draconic_theme.dart` — `DraconicTheme` adlı bir
  `ThemeExtension`, iki eksen taşıyor: `performanceTier` (blur/glow — cihaz gücü)
  ve `isDark` (Karanlık/Zindan ↔ Aydınlık/Parşömen palet). Ekranlar
  `Theme.of(context).extension<DraconicTheme>()!` ile okuyor; ham hex renk
  YAZMAK yerine token kullanmak proje kuralı (T-1 migrasyonu — ✅ tamamlandı,
  Eylül 2026).
- UI primitifleri: `GlassPanel`, `DungeonCard`, `NeonButton` (`core/design_system/primitives.dart`)
- Sekme arka planları: her ana sekme/ekran `assets/images/` altında kendi
  temalı `.webp` görseliyle açılıyor (`ana_sayfa.webp`, `kitaplik.webp`,
  `calis_kartlar.webp`, `basarimlar.webp`, `profil.webp`, `dukkan.webp`,
  `sozluk.webp`, `yolculuk_harita.webp`) — hepsi aynı desen: `Stack` içinde
  `Positioned.fill(Image.asset(..., fit: BoxFit.cover, alignment: Alignment.topCenter))`
  + üstüne `theme.background`'a erisen bir `LinearGradient` katmanı, en
  üstte asıl `SafeArea` içeriği.

## Mimari / iş modeli kararları
- **Local-First + Serverless Lite**: MVP'de tam backend (Node/Python+Postgres) yok.
  FSRS/AttemptLog verisi cihaz içi DB'de (repository pattern ile ileride buluta
  taşınabilir şekilde soyutlanmış). Premium doğrulama tamamen **RevenueCat**'e
  devredilmiş (kendi backend'inde fatura doğrulama yok, cihaz bazlı anonim ID).
  AI koç için ileride Supabase Edge Functions / Firebase Cloud Functions ile
  sadece proxy+rate-limit yapan sunucusuz fonksiyonlar kullanılacak.
- **Ejderha Rotası V2 (Master Plan)** — büyük bir sadeleştirme geçirdi: elmas
  ekonomisi kaldırıldı → salt Ücretsiz/Premium (Freemium); alt bar 5 sekmeye indi
  (Ana Sayfa, Dersler/Kitaplık, Kelimeler/Zindan, İlerleme/Arena, Profil); kilitli
  özellikler merkezi bir Paywall pop-up'ına yönleniyor.

## Dokunulmaz kurallar (asla değiştirilmez)
- `database_helper.dart`'taki tablo yapıları (`learning_state`, `repetitions`, `interval`)
- `shared_preferences`'taki `daily_learned_words_YYYY-MM-DD` gibi anahtar formatları
- Async işlem sonrası `if (!mounted) return;` zorunlu
- `shop_screen.dart`'taki `_ChestOpeningDialog`/`_RuneSealPainter`/`_ShatterBurstPainter` animasyon kodu
- `reader_screen`'den çıkışta `Navigator.pop(context, ReadingSessionResult(...))` zorunlu
- `flashcards_exercise`'daki sahte şık (dummy) fallback mantığı

## Tamamlanan UI/UX düzeltme fazları (Eylül 2026, kullanıcı emülatör testi geri bildirimine göre)
Kullanıcı uygulamayı test edip Türkçe bir geri bildirim listesi gönderdi; 6 fazlık
bir yol haritasına bölündü ve cihaz üzerinde teker teker doğrulandı:

- **Faz A** — Global tema düzeltmeleri: parşömen (aydınlık) palet kalibrasyonu
  (siyaha yakın metin yerine sıcak koyu kahve `#2C221E`; kart zemini `#E6DEC9`),
  ana sayfa arkaplan overlay opaklığı azaltıldı (~%85 → %70-75). ✅ Tamam
- **Faz B** — Profil ekranı restructure: sağ üstte 44×44pt dişli ikon → tema
  değiştirme/satın alımları geri yükleme/versiyon bilgisi içeren bottom sheet;
  22 rozetlik kalabalık grid yerine 3 rozetlik özet satırı + "Başarı Odası" sheet'i;
  istatistik listesi → 2×2 grid. ✅ Tamam
- **Faz C** — Ana sayfa ergonomisi: saat bazlı selamlama metni eklendi, sonra
  kullanıcı isteğiyle tekrar kaldırıldı ("İyi günler, Eren" artık yok); sticky
  CTA bar ve üstteki seri (streak) göstergesi zaten kuralları karşılıyordu. ✅ Tamam
- **Faz D** — Arena'daki "Zindan Kapalı" boş-havuz banner'ı, hemen üstündeki Word
  Boss banner'ıyla renk çatışması yaratan sert kırmızı/mor "alarm" görünümünden,
  `GlassPanel` tabanlı yumuşak/iOS-tarzı translucent bir karta taşındı; aktif
  "Hafıza Zindanı" amber hero kartı bilinçli olarak dokunulmadı (hero-kart muafiyeti). ✅ Tamam
- **Faz E** — Kitaplık'ta kısa kitap listelerinde liste altında kalan boş alan;
  önce listenin son öğesi olarak küçük bir özet kart denendi (yetersiz kaldı —
  kart küçük kalıp altında/üstünde hâlâ çıplak Scaffold görünüyordu), sonra
  `SliverFillRemaining` + `SizedBox.expand` ile "OKUMA YOLCULUĞUN" kartı kalan
  alanın TAMAMINI kaplayacak şekilde düzeltildi; emülatörde doğrulandı. ✅ Tamam
- **Faz F** — Duolingo tarzı karakter pop-up'ı (`IgnisMomentDialog` — streak
  kaybı/kutlama durumları, blur backdrop, 24pt radius, thumb-zone CTA
  butonları) + `CelebrationDialog`'a gömülü Ignis konuşma balonu + Profil
  ayarlarında "Dev/Test Araçları" bölümü (pop-up'ları elle tetikleyen test
  butonları) + duygu ifadeli poz görselleri (`AppBranding.poseAsset`):
  `celebrating`→excited.webp, `teacher`→thinking.webp, `sad`→sad.webp,
  `greeting`→happy.webp (paywall sheet'inde kullanılıyor). ✅ Tamam
- **Faz F2** — Kalan duygu görselleri (angry/loving/worried-suspicious) için
  yeni tetikleyici noktalar: (1) Ana Sayfa'da günlük kelime hedefi ilk kez
  tamamlandığında `loving` pozuyla ayrı bir kutlama pop-up'ı (streak
  kilometre taşından bağımsız, kendi günlük kilidi —
  `IgnisMomentsEngine.getDailyGoalCompletedMoment`); (2) Word Boss
  savaşında hiç maskot YOKTU — zafer diyaloğuna `celebrating`, yenilgi
  diyaloğuna `angry` (kullanıcıya değil bosse kızgın/azimli ton), savaştan
  çıkış onayına `worried` pozu eklendi. ✅ Tamam
- **Kitaplık footer düzeltmesi (2. tur)** — Faz E'deki "OKUMA YOLCULUĞUN"
  `SliverFillRemaining` kartı kullanıcı talebiyle tamamen kaldırıldı; kitap
  listesi artık doğal boyutunda bitiyor. ✅ Tamam
- **Alt sekme etiketi kontrastı** — parşömen (aydınlık) temada alt navigasyon
  sekme isimleri `main.dart`'ta `selectedLabelStyle`/`unselectedLabelStyle`'a
  açıkça `color:` verilerek düzeltildi (tema tokenları zaten doğruydu, sorun
  stilin rengi devralmamasıydı). ✅ Tamam
- **Uygulama ikonu/splash** — Android 12+ native splash API sınırlaması
  (tam afiş yerine sabit ~240dp dairesel ikon) `flutter_native_splash`
  `android_12.image`'ı ikon-uyumlu görsele yönlendirilerek; ikonun beyaz
  daire içinde küçülmesi `flutter_launcher_icons`'a açık
  `adaptive_icon_background`/`adaptive_icon_foreground` eklenerek çözüldü.
  `app_icon.png` kullanıcının referans görseliyle güncellendi. ✅ Tamam
- **T-1 tema-token migrasyonu** — tüm egzersiz/mini-oyun ekranları (quiz/match/
  spelling/cloze/reverse-quiz/listening/speed-round/mixed-dungeon/word-boss/
  flashcards-exercise) ve `design_lab_screen.dart` dahil, tüm dosyalarda
  tamamlandı. ✅ Tamam
- **Sekme arka planları** — kullanıcının hazırladığı temalı `.webp` görselleri
  ilgili ekranlara eklendi: Ana Sayfa, Dersler/Kitaplık, Arena/Kartlar,
  İlerleme/Sıralama, Profil, Dükkan, Sözlük, Kitap Yolculuğu. Ana Sayfa ve
  Profil'deki eski görseller (`lobi_arkaplan.png`, `profile_background_pic.png`)
  yeni setle değiştirildi. ✅ Tamam

## Kalan/bilinen backlog
- `ayarlar.webp` görseli henüz kullanılmadı — karşılığı Profil ekranındaki
  "Ayarlar" bottom sheet'i, tam ekran arka plan deseni orada doğal
  görünmeyebilir; kullanıcıyla netleştirilmeli.
- `achievement_service.dart`'taki `checkAndUnlockAchievements()` hiçbir
  ekrandan ÇAĞRILMIYOR — rozet sistemi kodda var ama hiçbir yerde
  tetiklenmiyor/gösterilmiyor gibi görünüyor; ayrı bir iş olarak ele alınmalı
  (bu oturumun kapsamı dışında bırakıldı, riskli/büyük bir refactor gerektirir).
- İleride: aydınlık temanın önceliklendirilmesi, RPG temasının biraz geri plana
  alınıp eğitim içeriğinin öne çekilmesi (kullanıcının notu, henüz uygulanmıyor),
  Firebase hesap sistemi + buna bağlı lig/liderlik tablosu.

## Geliştirme süreci notu
- Kod C:\src\ignis altında, Windows makinede; değişiklikler bir cihaz köprüsü
  üzerinden (stage → düzenle → commit → re-stage ile doğrula) uygulanıyor.
- Bu oturumda birkaç kez, VS Code'da açık kalan eski dosya sekmelerinin
  autosave ile diski ezip commit edilen düzeltmeleri sessizce eski hâline
  döndürdüğü görüldü — düzeltme: ilgili dosya sekmeleri kapatılıp Auto Save
  geçici kapatıldı.

---
*Bu dosyanın amacı: ChatGPT'ye (veya başka bir AI'ya) projeyi tek seferde, tüm
sohbet geçmişini kopyalamadan tanıtmak. Her yeni faz tamamlandığında bu dosya
güncellenip ChatGPT projesine tekrar yüklenmelidir — gerçek zamanlı otomatik
senkron YOKTUR, güncelleme elle yapılır.*
