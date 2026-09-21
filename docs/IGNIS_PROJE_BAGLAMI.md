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
- **Faz G — gerçek cihaz testi sonrası hızlı teknik düzeltmeler** (kullanıcının
  15 ekran görüntüsü + ChatGPT'nin P0/P1/P2 değerlendirmesinden, kullanıcının
  onayladığı "hızlı/net teknik hatalar" kapsamı; Arena/İlerleme adlandırması,
  bottom sheet standardizasyonu, kart renk paleti birleştirme kasıtlı olarak
  ERTELENDİ — ayrı bir konuşma bekliyor):
  - `ayarlar.webp` kullanılmaması kullanıcı kararıyla netleşti — Profil'deki
    Ayarlar sheet'i o görseli hiç kullanmıyor, backlog'dan kapatıldı.
  - Rozet/başarım sistemi artık gerçekten çalışıyor: `library_screen.dart`'a
    eksik olan `stats_total_pages_read` ve `daily_pages_<tarih>` yazımları
    eklendi, `profile_screen.dart` artık her yüklemede
    `AchievementService.checkAndUnlockAchievements()`'ı çağırıp yeni rozeti
    `IgnisMomentDialog` ile kutluyor.
  - `flashcards_screen.dart`'taki "Geliştirici Test Modu" ve `profile_screen.dart`'taki
    "Dev/Test Araçları" artık `kDebugMode` arkasında — release APK'da hiç
    görünmüyor; eskiden `SharedPreferences`'ta kalıcı `dev_test_mode=true`
    kalıp release'de sonsuza dek Premium açabilen ciddi bir hata da (kullanıcının
    kendi test cihazında karşılaştığı) bu düzeltmeyle kapatıldı.
  - `primitives.dart`'taki `RuneTitle`/`EmptyWordPoolState` artık
    `Colors.white`/sabit gri yerine `DraconicTheme` tokenlarını okuyor —
    parşömen temada her ekranın üst başlığının/boş durum metninin
    görünmez olma şikayetinin kök nedeniydi.
  - `main.dart`'a `SystemUiMode.edgeToEdge` eklendi, sistem çubuğu
    renkleri/ikon parlaklığı artık tema değiştikçe (statik değil) yeniden
    uygulanıyor — "alt nav şeridi kopuk gri bant gibi duruyor" şikayeti.
  - Splash "kutu görünüyor" şikayeti kök nedeniyle çözüldü: PIL ile piksel
    analizi, hem `ignis_splash.png` hem Android 12+'ta kullanılan
    `app_icon.png`'nin düz `#0f172a` fonundan belirgin koyu kenar tonlarına
    sahip olduğunu gösterdi; `pubspec.yaml`'daki `flutter_native_splash.color`
    (→`#06070f`) ve `android_12.icon_background_color` (→`#030c1e`) görsellerin
    gerçek kenar tonuyla eşleştirildi. Ayrıca `ignis_splash.png` ortadan ~%25
    yakınlaştırılıp büyütüldü (kullanıcının "figür küçük" notu).
    **Kullanıcı tarafında kalan adım:** `dart run flutter_native_splash:create`
    çalıştırılmalı (Android kaynak dosyaları bu config'den otomatik üretiliyor,
    elle değiştirilmedi ki generator'la çakışmasın).
  - `flashcards_screen.dart`'ta Arena mod açıklamaları (`desc:`) `maxLines: 1`
    yüzünden cümle ortasında kesiliyordu ("4 seçenek arasından doğr...") —
    `maxLines: 2` yapıldı.
  - Ana Sayfa'daki "Hedef: X" yazısının ejderha görseliyle çakışıp
    kapanması: eksik genişlik kısıtı `SizedBox`+ellipsis ile giderildi
    (kullanıcının "ignis yazıları kapatıyor" notuyla aynı kök neden).
  - `DraconicTheme`'e yeni, bağımsız bir `tabLabel` tokeni eklendi (parşömen
    `#3B2F1F`, zindan `#EDE9FE`) — Dükkan'daki kategori sekmeleri ve
    Sözlük'teki filtre çiplerinin "açık temada okunamıyor" şikayeti için;
    mevcut `textSecondary` teknik olarak yeterli kontrasta sahipti ama bu
    özel bağlamda (küçük punto + çip zemini) yetersiz kaldığı bildirildi.
  - Ayarlar'daki "Dev/Test Araçları"na, bu fazda eklenen yeni Ignis
    poz/pop-up'larını (günlük hedef/loving, boss yenilgi/angry, savaştan
    çıkış/worried, rozet kutlaması/celebrating) test edebilmek için 4 yeni
    önizleme satırı eklendi.
  - Hesap Sistemi'nin temeli atıldı: `firebase_core`+`firebase_auth`
    eklendi, `lib/core/auth/auth_service.dart` + `lib/auth_screen.dart`
    (Giriş Yap/Kayıt Ol) yazıldı, `EntitlementRepository`'ye
    `linkToAccount`/`unlinkAccount` eklenerek RevenueCat kimliği hesaba
    bağlanacak şekilde kuruldu, Ayarlar'a "Hesap" satırı eklendi.
    `android/app/build.gradle.kts`'teki google-services Gradle eklentisi
    `google-services.json` dosyası VARSA uygulanacak şekilde KOŞULLU
    yapıldı — yani Firebase Console kurulumu tamamlanana kadar proje
    normal derlenmeye devam ediyor, hesap özellikleri o ana kadar sadece
    "henüz yapılandırılmadı" mesajı gösteriyor.
    **Kullanıcı tarafında kalan adım:** Firebase Console'da proje açma +
    Android app ekleme (paket adı artık `com.draconiclingua.ignis` — bkz.
    Faz H) + `google-services.json`'ı `android/app/` içine koyma +
    Email/Password sağlayıcısını Console'da açma.

- **Faz H — applicationId, 4 yeni Ayarlar bölümü, gerçek bildirimler,
  Arena/İlerleme adlandırması** (Faz G'de ertelenen kararların kullanıcı
  onayıyla uygulanması + bir sonraki mesajda "şimdi hallet" denen kalan üç
  madde):
  - `android/app/build.gradle.kts`'teki `applicationId`,
    `com.example.deneme1`'den gerçek `com.draconiclingua.ignis`'e
    değiştirildi. `namespace` (aynı dosyada) ve `MainActivity.kt`'nin
    gerçek Kotlin paket klasörü BİLEREK `com.example.deneme1` bırakıldı —
    o dosya, cihaz köprüsünün 7 klasör derinlik sınırı yüzünden hâlâ
    ulaşılamaz durumda (8 klasör derin). Bu sorun değil: Android Gradle
    Plugin'de `applicationId` ile `namespace`'in farklı olması resmî olarak
    desteklenir, Play Store/Firebase sadece `applicationId`'yi görür.
  - Ayarlar sheet'ine (`profile_screen.dart`) 4 yeni bölüm eklendi:
    **Erişilebilirlik** (Azaltılmış Hareket/Animasyon — `ThemeController`'a
    `reducedMotion` eklendi, açıkken cam/glow efektleri kapanıp
    `DevicePerformanceTier.low`'a düşüyor), **Bildirimler** (aşağıya bkz.),
    **Veri Yönetimi** ("İlerlemeyi Sıfırla" — `database_helper.dart`'a
    `resetAllProgress()` eklendi: flashcards/highlights/book_progress/
    daily_stats siliniyor, `dictionary` ve `cacheObject` BİLEREK
    dokunulmuyor), **Hakkında** (Sürüm, e-posta kopyalayan "Geri Bildirim
    Gönder", pasif "yakında" ibaresiyle Gizlilik/Kullanım Şartları
    placeholder'ları — eski tekrar eden "UYGULAMA BİLGİSİ" bölümü
    kaldırıldı).
  - **Bildirimler artık GERÇEK:** `flutter_local_notifications` +
    `timezone` + `flutter_timezone` eklendi,
    `lib/core/notifications/notification_service.dart` yazıldı. "Günlük
    Hatırlatma" kullanıcının seçtiği saatte, "Seri Kaybı Uyarısı" sabit
    21:30'da zamanlanmış yerel bildirim gönderiyor. Android 13+ çalışma
    zamanı izni, anahtar ilk açıldığında (veya "Seri Kaybı Uyarısı"
    varsayılan açık geldiği için uygulamanın ilk açılışında) isteniyor.
    `main.dart` her açılışta kayıtlı tercihlere göre bildirimleri yeniden
    kuruyor (`rearmFromPrefs`) — bu, Android'in reboot sonrası temizlediği
    alarmları da telafi ediyor. **Bilinen sınırlama:** "Seri Kaybı Uyarısı"
    kullanıcının o gün gerçekten pratik yapıp yapmadığını kontrol eden
    "akıllı" bir sistem DEĞİL, sabit saatli bir hatırlatma — gerçek koşullu
    kontrol için ayrı bir arka plan iş yöneticisi (WorkManager) kurulumu
    gerekir, bugünkü kapsamın dışında bırakıldı. Ayrıca reboot sonrası
    otomatik yeniden kurulum için BOOT_COMPLETED receiver'ı henüz
    eklenmedi (manifest izni hazır, ama receiver kodu yok) — pratikte
    kullanıcı uygulamayı bir kez açtığında hatırlatmalar kendiliğinden
    yeniden kuruluyor.
  - "İlerlemeyi Sıfırla" onayı güçlendirildi: kullanıcı artık "Bunun geri
    alınamayacağını anlıyorum..." kutucuğunu işaretlemeden "Evet, Sıfırla"
    butonu pasif/gri kalıyor — yanlışlıkla dokunmaya karşı ikinci bir kilit.
  - **Arena/İlerleme adlandırması netleştirildi:** alt bar etiketi
    "İlerleme"den "Sıralama"ya çevrildi (ekranın kendi başlığı zaten
    "Sıralama"ydı, etiket uyuşmuyordu); `leaderboard_screen.dart`'taki
    "12. Arena Sıralaması" başlığı "12. Lig Sıralaması"na çevrildi (Arena
    kelimesi zaten pratik/dövüş sekmesine ait, burada tekrarı aynı
    kafa karışıklığını geri getiriyordu).
  - **Bottom sheet standardizasyonu — denetlendi, ek değişikliğe gerek
    yoktu:** `profile_screen.dart`, `flashcards_screen.dart`,
    `reader_screen.dart`, `paywall_trigger.dart`, `book_journey_screen.dart`
    içindeki TÜM `showModalBottomSheet` çağrıları zaten aynı köşe yarıçapı
    (28), aynı arka plan (`#111827`) ve aynı tutamaç stilini (40×4,
    `#334155`) kullanıyor — tutarsızlık bulunamadı.
  - **Kart renk paleti — denetlendi, kasıtlı olmayan bir "pastel/krem"
    uyumsuzluğu bulunamadı:** kod taramasında bulunan tek pastel-dışı
    renkler (1) `reader_screen.dart`'taki okuma temaları (Sepya/Nordik/
    Espresso/Sakura) — bunlar kullanıcının kendi seçtiği, KASITLI çeşitli
    temalar, ve (2) `shop_screen.dart`'taki "Destansı Sandık" kartının
    indigo/pembe (`#1E1B4B`/`#EC4899`) renkleri — bu da RPG'lerdeki
    "epic/legendary nadir eşya" renk kodlamasına (mor/pembe = epik)
    benzeyen KASITLI bir vurgu gibi duruyor. Ekran görüntüsü olmadan bunun
    gerçekten "kullanıcının şikayet ettiği pastel kart" olup olmadığı
    kesin değil — kullanıcı hangi ekran/kartı kastettiğini netleştirirse
    (ekran görüntüsüyle) hedefli bir düzeltme yapılabilir.

## Kalan/bilinen backlog
- İleride: aydınlık temanın önceliklendirilmesi, RPG temasının biraz geri plana
  alınıp eğitim içeriğinin öne çekilmesi (kullanıcının notu, henüz uygulanmıyor).
- "Seri Kaybı Uyarısı" şu an sabit saatli bir hatırlatma; kullanıcının o gün
  gerçekten pratik yapıp yapmadığını kontrol eden koşullu/akıllı bir sistem
  DEĞİL (bkz. Faz H notu) — istenirse ayrı bir oturumda WorkManager tabanlı
  bir çözüm eklenebilir.
- Bildirimlerin reboot sonrası otomatik yeniden kurulması için
  BOOT_COMPLETED receiver'ı eklenmedi (manifest izni hazır) — şu an için
  uygulamanın bir kez açılması yeterli.
- Kart renk paletiyle ilgili kullanıcının asıl kastettiği ekran/kart hâlâ
  netleşmedi (bkz. Faz H notu) — ekran görüntüsü paylaşılırsa hedefli
  düzeltme yapılabilir.

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
