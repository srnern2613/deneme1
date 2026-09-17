# Geliştirme Yol Haritası ve Yayın Kontrol Listesi

Bu doküman `faz8_test_rollout_izleme.md`'yi **tamamlar, tekrar etmez**. Faz 8 "kod doğru çalışıyor mu" sorusunu kapsıyor; bu doküman "v1'de ne olacak ve nasıl yayınlanacak" sorusunu kapsıyor.

## Güncel kararlar (özet)

| Karar | Gerekçe |
|---|---|
| **Play Store hesabı ertelendi** | Önce ürün güçlendirilecek. Maddeler Aşama 5'te bekliyor, silinmedi. |
| **Bulut hesabı / Supabase yedekleme ertelendi** | Sıfır kullanıcı varken hesap altyapısı kurmak, kimsenin yaşamadığı bir sorunu çözmek. Android Auto Backup ~%80'ini ücretsiz veriyor (Aşama 1). |
| **AI Koç mevcut haliyle kalıyor** | Dokunulmayacak. Sohbet ekranı ve Edge Function kodu duruyor; v1'de gizli kalabilir. |
| **"Ignis" = maskot anları, AI değil** | İstenen şey: karakterin doğru anlarda poz + veriye dayalı mesajla ekrana çıkması (Duolingo tarzı). LLM gerekmiyor. Bu, **v1'in yıldız özelliği**. |
| **Ignis sıklığı: ölçülü** | Günde en fazla 1 önemli an + seans sonları. Çok sık çıkarsa ödül değil kesinti olur. |
| **Yeni pratik modları** | Cümlede Boşluk Doldurma **ücretsiz** (vitrin özelliği), Ters Test / Sadece Dinleme / Hız Turu **Premium**. |
| **Uygulama adı: Ignis** | Karakterin adı uygulamanın adı oldu. `Draconic Lingua` artık **marka/yayıncı adı**. |
| **Lokalizasyon: ayrı uygulama modeli** | Tek çok-dilli uygulama yerine, her dil çifti için **ayrı uygulama + aynı evrenden ayrı karakter**. Ignis = Türkçe↔İngilizce. |

---

## Marka yapısı ve çok-uygulamalı strateji

**Karar:** Tek bir çok-dilli uygulama yerine, her dil çifti için ayrı uygulama. Her biri aynı evrenden farklı bir karakterin adını ve tasarımını taşır, ama **aynı motoru** kullanır.

- **Draconic Lingua** — marka / yayıncı adı (Play Console "Developer name"). Tüm uygulamalar bunun altında çıkar.
- **Ignis** — Türkçe ↔ İngilizce uygulaması (bugün elimizdeki)
- *(gelecek)* — İspanyolca ↔ İngilizce için ayrı karakter, ayrı isim, ayrı uygulama

**Neden mantıklı:** Çok-dilli tek uygulama, çalışma zamanı dil değiştirme altyapısı (dil seçici, kalıcılık, Intl/ARB araçları) gerektiriyordu. Ayrı uygulama modelinde bunların hiçbiri yok. Daha önemlisi: **bugünkü uygulama yarının planı için bedel ödemiyor** — Ignis Türkçe metinlerle yayına çıkar, doğrulanır, ve çeviri işi ancak 2. uygulamayı yaptığında gündeme gelir.

**Ayrıca:** İspanyolca mağaza vitrininde İspanyolca bir isimle çıkmak ASO açısından daha iyi sıralanır, ve bir uygulama tutmazsa diğerini etkilemez.

### ⚠️ Bu stratejinin tek kritik şartı: TEK kod tabanı

Proje klasörünü kopyalayıp ikinci uygulamayı oradan yapmak, bu planın battığı yerdir. Üç ay sonra iki kod tabanı birbirinden ayrışır ve her hata iki kez, farklı satır numaralarında düzeltilir. Doğrusu **Flutter flavors**: aynı kod, derleme zamanında değişen uygulama adı, `applicationId`, karakter görselleri ve metin seti. Bir hatayı bir kez düzeltirsin, tüm uygulamalar düzelir.

**Dürüst uyarı:** Ayrı uygulama modeli, metinleri koddan çıkarma işinden **kurtarmıyor** — sadece çalışma zamanı dil değiştirme makinesinden kurtarıyor (tahmini %30-40 tasarruf). Asıl kazanç, o işi **2. uygulamaya kadar ertelemek**.

### Bugün yapılacak ucuz hazırlık (sonra pahalıya patlar)

- [ ] **Karakter adını ve görsellerini tek bir yerden yönet.** Aşama 2'de maskot sistemini yazarken karakterin adı ve poz dosya yolları koda dağılırsa, 2. karakter için mesaj bankasında kelime avına çıkmak gerekir. Bunun yerine `lib/core/branding/app_branding.dart` gibi tek bir dosyada tutulsun (karakter adı, görsel yolu ön eki, vurgu renkleri). Mesaj şablonlarında karakterin adı **düz metin olarak yazılmasın**, değişkenden gelsin.
  - Bugünkü maliyeti ≈ sıfır (o kodu zaten yazacağız). Sonra eklemenin maliyeti yüksek. `uuid` maddesiyle aynı mantık.
- [ ] **Paket adı marka yapısını yansıtsın:** `com.draconiclingua.ignis` → ileride `com.draconiclingua.<karakter2>`. (Aşama 5'te uygulanacak, ama isim kararı şimdi verilsin.)
- [ ] **Tema sınıfını yeniden adlandırma.** `DraconicTheme` / `draconic_theme.dart` olduğu gibi kalsın — artık marka düzeyinde ortak tasarım sistemi anlamına geliyor, ki bu doğru. Kod yapısı marka yapısını yansıtıyor: Draconic Lingua = ortak motor + tasarım dili, Ignis = onun üstüne kurulu bir ürün.

### İsim değişikliği — durum

Yapıldı (diskte doğrulandı): `pubspec.yaml` (`name: ignis` + açıklama) · `AndroidManifest.xml` (`android:label="Ignis"`) · `main.dart` (MaterialApp başlığı + logo yedek metni + dosya başlığı).

- [ ] **`flutter pub get` çalıştır** (pubspec `name` değişti). Kodda hiç `package:deneme1` importu yok — hepsi göreli import — bu yüzden kırılma beklenmiyor, ama IDE'yi yeniden başlatmak gerekebilir.
- [ ] **Logo görselini yenile.** Ana sayfadaki `assets/images/lobi_logo1.png` görselinde muhtemelen hâlâ "Draconic Lingua" yazıyor. Asıl görünen marka orada — "Ignis" olarak yeniden üretilmeli. (Koddaki metin sadece görsel yüklenemezse çıkan yedek.)
- [ ] **iOS tarafı:** `ios/Runner/Info.plist` içindeki `CFBundleDisplayName`. (iOS şimdilik gündemde değil, sırası gelince.)
- [ ] **Mağaza adı ASO için tanımlayıcı taşısın.** Tek başına "Ignis" bir arama yapana ne olduğunu anlatmıyor, üstelik aynı adı taşıyan başka şeyler var (ör. bir otomobil modeli). Uygulama içi ad ve ikon "Ignis" kalsın; mağaza vitrininde "Ignis: İngilizce Kelime Öğren" gibi bir biçim kullan.
- [ ] **Play Store'da "Ignis" adıyla başka uygulama var mı diye bak** (ad çakışması ve arama görünürlüğü için).

---

## SIRA — Aşamalar

| Aşama | İş |
|---|---|
| **0** | Veri modeli temeli (tek migrasyon) |
| **1** | Yedekleme güvencesi (Android Auto Backup) |
| **2** | **Ignis Anları** — maskot + istatistik sistemi (v1'in yıldızı) |
| **3** | Yeni pratik modları |
| **4** | Tasarım toparlama |
| **5** | Yayın hazırlığı (ertelendi) |

### Hemen yapılacak küçük işler (aşama beklemez)

- [ ] **Liderlik tablosundaki ırkçı test isimlerini temizle. (ACİL)** `lib/leaderboard_screen.dart` satır ~99-108'de rakip adı olarak **"Zenci"** ve **"Çinli"** geçiyor. "Zenci" Türkçede ırkçı bir hakarettir. 2 dakikalık iş, bekletme.
- [ ] **Alışkanlıklar kalıcı değil.** `lib/habit_tracker_screen.dart` içinde `_habits` sadece bellekte; kullanıcının eklediği hedefler uygulama kapanınca kayboluyor.
- [ ] `pubspec.yaml` placeholder'ları: `name: deneme1`, `description: "A new Flutter project."`

---

## Aşama 0 — Veri modeli temeli (TEK migrasyon: v16 → v17)

> **Neden tek migrasyon:** Aşama 2'nin (Ignis Anları) istatistik tablosuna ihtiyacı var; `uuid`/`updated_at` ise ileride hesap sistemine geçilirse zorunlu. Ayrı ayrı yapılırsa v17, v18, v19 diye üç migrasyon olur — ve migrasyon bu uygulamanın **en riskli işlemi** (Faz 8 de v15→v16'yı en yüksek risk olarak işaretliyor). Tek seferde geçmek test yükünü üçte bire indirir.

- [x] **`flashcards` tablosuna ekle:** ✅ 17.09.2026 — `database_helper.dart` v17
  - `uuid` — cihazdan bağımsız kalıcı kimlik. Yeni kartlarda otomatik atanıyor; mevcut kartlara upgrade sırasında geriye dönük dolduruluyor.
  - `updated_at` — son değişiklik zamanı. Ana yazma noktalarında (`addFlashcard`, `discoverWord`, `promoteToLearning`, `demoteToDiscovered`, `recordMultiModalResult`, `updateFlashcardSrsProgress`) set ediliyor.
- [x] **Yeni tablo: günlük istatistik (`daily_stats`)** ✅ 17.09.2026 — tarih + mod kırılımlı (yeni kelime, tekrar, doğru, yanlış). Yazma noktaları: `recordMultiModalResult` (her doğru/yanlış cevap) ve yeni kelime ekleme akışı (`addFlashcard`, `promoteToLearning`). Okuma tarafı için `getDailyStatsRange`, `getTodayStatsSummary`, `getDueTomorrowCount` hazır — Aşama 2'nin istatistik motoru doğrudan bunları kullanabilir.
  - Not: Okuma verisi zaten tarihe göre tutuluyor (`daily_pages_<tarih>`, `daily_minutes_<tarih>`), ama kelime verisi **yalnızca kümülatif**. Günlük kırılım olmadan "bugün şu kadar öğrendin" ve trend hesaplanamaz. Bu sorun artık çözüldü.
  - Teknik not: `_touchDailyStat` bilerek `db.transaction()` bloğunun **dışında** çağrılıyor (`addFlashcard` içinde) — aynı bağlantı üzerinden transaction içindeyken txn dışı bir sorgu çağırmak sqflite'ı kilitleyebilir.
- [ ] **Migrasyon testi (kritik, HENÜZ YAPILMADI):** Eski sürümü gerçek cihaza kur → üstüne yeni sürümü yükle → veri kaybı var mı kontrol et. Emülatörde temiz kurulum bu hatayı **yakalamaz**.

---

## Aşama 1 — Yedekleme Güvencesi (Android Auto Backup)

Hesap sistemi yerine seçilen ucuz yol. Android, API 23+ hedefleyen uygulamalarda **varsayılan olarak** uygulamanın SQLite veritabanını ve SharedPreferences'ını kullanıcının Google Drive'ında özel bir alana yedekliyor (kullanıcının Drive kotasından düşmüyor), ve yeni cihaz kurulumunda/Play'den yeniden kurulumda **otomatik geri yüklüyor**. Manifest'te `android:allowBackup` yazmıyor → varsayılan `true` → **muhtemelen şu an zaten çalışıyor.**

### Kritik tuzak: 25 MB kotası

Limit **uygulama başına 25 MB**. Veri aşarsa sistem `onQuotaExceeded()` çağırıp **hiçbir şeyi yedeklemiyor** — kısmi yedek yok, komple iptal. Senin uygulamada yüklenen PDF'lerin **tüm sayfa metni** `saved_books` içinde SharedPreferences'ta duruyor; birkaç kitap bu limiti rahatlıkla aşar ve o anda kelimelerin yedeklenmesi de sessizce durur.

- [ ] **Kitap metinlerini SharedPreferences'tan çıkar**, dosya veya SQLite tarafına taşı.
  - Yan kazanç: `shared_preferences` açılışta dosyanın tamamını belleğe yüklüyor. Kitap metinleri orada durdukça uygulama her açılışta megabaytlarca veriyi RAM'e okuyor — başlangıç performansı bundan zarar görüyor olabilir.
- [ ] Manifest'e `android:allowBackup="true"` açıkça yaz + veri çıkarma kurallarıyla (`dataExtractionRules`) kitap metinlerini **hariç tut**. Kelimeler, ilerleme, XP, seri 25 MB'ın çok altında kalsın.
- [ ] Test: gerçek cihazda uygulamayı kaldır → Play/adb ile tekrar kur → kelimeler geri geldi mi?

### Bu çözümün sınırları (bilerek kabul ediliyor)

Kullanıcının Google hesabı yoksa veya cihaz ayarlarından yedeklemeyi kapattıysa koruma yok · Android'den iPhone'a taşınmıyor · aynı anda iki cihazda kullanılamıyor · **sana görünürlük vermiyor** ("son yedek 3 gün önce" gösteremezsin). Gerçek hesap sistemi bunları çözer — gerçek kullanıcılar olunca tekrar değerlendirilecek.

---

## Aşama 2 — Ignis Anları (v1'in yıldız özelliği)

> Karakterin doğru anlarda bir poz ve veriye dayalı bir mesajla ekrana çıkması. **AI yok, sunucu yok, hesap yok** — tamamen yerel veriden besleniyor.

**Faz A ile çelişmiyor:** Ignis'i her ekranın köşesinden kaldırmıştık; sürekli duran maskot görsel gürültüdür, kullanıcı iki gün sonra onu görmez. Anlarda çıkan maskot ise ödül olur. Duolingo da Duo'yu her ekrana yapıştırmıyor.

### Hazır olan altyapı

- `celebration_dialog.dart` → seans sonu modalı **zaten kurulu**. Karar: **bunu zenginleştir**, ayrı popup açma (iki pencere üst üste kapatmak kötü deneyim).
- `coach_messages.dart` → mesaj bankası zaten var (`getFeedback`, `getFlashcardCheer`, `getWrongAnswerEncouragement`). Veri şablonlarıyla genişletilecek.
- `IgnisCharacterPortrait` (primitives.dart) → Faz A'da silmeyip bıraktığımız widget. Poz parametresi alacak şekilde genişletilecek.

### Yapılacaklar

- [ ] **İLK ADIM: `lib/core/branding/app_branding.dart`.** Karakter adı, poz görsellerinin yol ön eki ve vurgu renkleri tek dosyada toplansın. Maskot sistemi baştan bunun üzerine kurulursa, ileride 2. karakterli uygulama bir yapılandırma değişikliği olur; kurulmazsa mesaj bankasında kelime avı olur. (Bkz. "Marka yapısı" bölümü.)
- [ ] **Yerel istatistik motoru** (`lib/core/coach/`) — Aşama 0'daki tabloyu okur:
  - Bugün / bu hafta öğrenilen ve tekrar edilen kelime sayısı
  - **Projeksiyon:** "bu hızla 1 haftada ~X kelime" (son 7 günlük ortalamadan)
  - Geçen haftaya karşı trend
  - Havuz durumu: toplam / öğreniliyor / kalıcı hafızada
  - Yarın kaç kelimenin tekrar vakti geliyor (FSRS `fsrs_due_at` hazır — bedava veri)
  - En çok zorlanılan 5 kelime · ihmal edilen mod
- [ ] **Poz seti (üretilecek görseller):** kutlama (kollar havada) · bilgili/öğretmen (istatistik gösterirken) · endişeli (seri tehlikede) · üzgün (seri kırıldı) · selamlama (uzun aradan sonra dönüş) · düşünen (içgörü verirken). Altı poz yeter.
- [ ] **GÖRSEL OPTİMİZASYONU (önemli):** Mevcut görseller çok ağır — `ignis_avatar_badge.png` **2 MB**, `ignis_avatar.png` 1.1 MB. Bunlar 24-34 piksel boyutunda gösteriliyor; her karede 2 MB'lık görsel açılıp 26 piksele sıkıştırılıyor (bellek + hız kaybı). Altı pozu bu boyutta eklemek APK'ya ~12 MB bindirir.
  - Pozları ekranda görünecek boyutun 2-3 katında üret (popup için 400-600 piksel yeter), **WebP**'ye çevir, tanesi **<100 KB** olsun. Gözle fark edilmez.
  - Mevcut iki görseli de aynı şekilde küçült.
- [ ] **Tetikleyiciler ve öncelik sırası:**
  - Seans sonu (mevcut modal — her seans)
  - Seri kilometre taşları (7 / 30 / 100 gün)
  - Seri tehlikede (akşam olmuş, hâlâ pratik yok)
  - Uzun aradan sonra dönüş
  - Yeni kişisel rekor
  - Kelime kilometre taşları (50. / 100. kalıcı kelime)
  - Haftalık özet
  - Hız içgörüsü ("bu hızla...")
- [ ] **Sıklık kontrolü — sistemi batıran tek şey çok sık çıkmasıdır. Karar: ölçülü.**
  - Günde **en fazla 1 önemli an** + seans sonları
  - Aynı anda birden fazla tetikleyici oluşursa **en önemlisi** gösterilir
  - Mesaj tipi başına bekleme süresi (aynı tebrik üst üste çıkmasın)
  - **Egzersizin ortasında asla çıkmaz**
  - Tek dokunuşla kapanır
- [ ] **Mesaj şablonları** `coach_messages.dart` içinde veri değişkenleriyle ("bugün {X} kelime öğrendin, bu hızla hafta sonunda {Y}")
- [ ] Ignis Anları **Premium'a kilitlenmeyecek** — bu temel etkileşim ve elde tutma özelliği. Premium, pratik modlarıyla satılıyor.

---

## Aşama 3 — Yeni Pratik Modları

Mevcut modlar: Hızlı Test, SRS Hafıza, Eşleştirme, Dinle & Yaz, Karma Mod, Word Boss.

| Yeni mod | Erişim | Açıklama |
|---|---|---|
| **Cümlede Boşluk Doldurma** | **ÜCRETSİZ** | Kelimenin kullanıcının **kendi kitabında** geçtiği gerçek cümle, kelime boşluk bırakılmış. `context_sentence` alanı zaten dolu. |
| **Ters Test (TR → EN)** | Premium | Türkçe anlamı gör, İngilizce kelimeyi bul. Aktif üretimi test eder. |
| **Sadece Dinleme** | Premium | Kelimeyi yazısını görmeden duy, anlamını seç. TTS zaten `en-US` sabit çalışıyor. |
| **Hız Turu (60 sn)** | Premium | Süreye karşı maksimum doğru. Arena/liderlik ile iyi çalışır. |
| *Telaffuz Pratiği* | *Premium, ileride* | *Ses tanıma ile telaffuz kontrolü. En pahalı, en "premium" hissettiren.* |

**Cümle doldurma neden ücretsiz:** Uygulamanın "bu farklıymış" dedirten tek anı bu — cümle kullanıcının okuduğu kitaptan geliyor, rakiplerin kopyalayamayacağı özellik. Ücretsiz tarafta hiç "vay" anı bırakmazsan kimse Premium'u merak etmez.

**Uygulama notları:**
- [ ] Cümle doldurma: `context_sentence` boş olan kelimeler bu moda girmemeli; havuz yetersizse `EmptyWordPoolState` göster
- [ ] Ters Test: `quiz_exercise_screen.dart`'tan türetilecek — çeldiriciler artık İngilizce kelimeler olmalı
- [ ] Hız Turu: mevcut test mantığı + geri sayım; seans sonu modalıyla uyumlu
- [ ] Premium kilitleri **merkezi `PaywallTrigger` üzerinden** (proje kuralı — yeni kilit mantığı yazma)

---

## Aşama 4 — Tasarım Toparlama

- [ ] **Arena ızgarası yeniden düzenlenmeli.** Şu an 2×2'de 4 mod var; yenilerle 8 olacak. 2×4 grid mi, "Temel / Premium" kategorili liste mi, yatay gruplar mı — karar verilecek.
- [ ] **Ana Sayfa'da "Günlük Durum" kartı** (Ignis Anları'nın kalıcı, sessiz versiyonu — popup beklemeden istatistik görünsün)
- [ ] Ignis popup'ının görsel dili: modal boyutu, poz yerleşimi, animasyon (mevcut `flutter_animate` kullanılabilir)
- [ ] Premium kilit görsellerinin tüm yeni modlarda tutarlı olması

---

## Aşama 5 — Yayın Hazırlığı (ERTELENDİ)

Ürün hazır olduğunda buraya dönülecek. Maddeler silinmedi, bekliyor.

### Geri dönüşü olmayanlar (yayından sonra değişmez)

- [ ] **Paket adını değiştir.** Şu an `com.example.deneme1`. Play `com.example.*` kabul etmiyor ve paket adı ilk yüklemeden sonra **asla** değişmiyor. `android/app/build.gradle.kts` → `namespace` (~8) ve `applicationId` (~19). Kotlin klasör yapısı ve `MainActivity.kt` içindeki `package` satırı da güncellenmeli.
- [ ] **Release keystore oluştur** (şu an debug anahtarıyla imzalanıyor — `build.gradle.kts` ~36). `key.properties` ve `.jks` **`.gitignore`'a** eklenmeli. İki ayrı yerde yedekle. **Play App Signing'i aç.**

### Teknik

- [ ] **Hedef API 36.** Yeni uygulamalar için Android 16 (API 36) zorunlu; son tarih 31 Ağustos 2026'ydı (uzatma 1 Kasım 2026'ya kadar istenebiliyor). `targetSdk = flutter.targetSdkVersion` Flutter sürümünden miras alınıyor — gerçek değeri doğrula, 36 değilse elle sabitle ve tam regresyon testi yap.
- [ ] **APK değil App Bundle:** `flutter build appbundle --release`
- [ ] RevenueCat ürünlerini Play Console'da oluştur, gerçek cihazda satın alma + restore test et
- [ ] Release build'de uçtan uca ağ testi (INTERNET izni eklendi ama release'te doğrulanmadı)
- [ ] `flutter analyze` temiz

### Play Console

- [ ] Hesap aç, **kimlik doğrulamasını erken başlat** (25 $ tek seferlik, doğrulama günler sürebiliyor)
- [ ] **12 testçi / kesintisiz 14 gün kapalı test.** 13 Kasım 2023 sonrası açılan **bireysel** hesaplar için zorunlu; testçi çıkıp girerse sayaç sıfırlanır. Kurumsal hesaplar muaf.
- [ ] Gizlilik politikası URL'si · Data Safety formu · içerik derecelendirme anketi
- [ ] Store listing: ad, açıklamalar, 2+ ekran görüntüsü, 1024×500 feature graphic, 512×512 ikon
- [ ] `versionCode` her yüklemede artmalı
- [ ] *(Hesap sistemi eklenirse)* uygulama içi **hesap silme** yolu + **web silme bağlantısı** — Play zorunluluğu

### Sahte sosyal kanıt kararı

- [ ] Liderlik tablosu ve Mikro-Meydan Okumalar hâlâ uydurma veri. Seçenekler: dürüstçe etiketle, tek kişilik hâline çevir, ya da gerçek veriye bağla. **Aşama 0'daki istatistik tablosu bu veriyi zaten üretecek** — görevleri gerçeğe bağlamak artık kolay.

---

## Ertelenen kararlar ve gerekçeleri

Bunlar iptal değil, **beklemede**. Gerekçeleri burada duruyor ki ileride sıfırdan tartışılmasın.

- **Bulut hesabı / Supabase yedekleme.** Sıfır kullanıcı varken kimsenin yaşamadığı bir sorunu çözüyordu; yanında kalıcı yükümlülükler getiriyordu (hesap silme ekranı, web silme sayfası, KVKK/GDPR, destek yükü). **Ne zaman dönülür:** gerçek kullanıcılar "telefonumu değiştirdim" demeye başladığında, iOS'a geçildiğinde, ya da sunucu tarafında kimlik gerektiren bir özellik çıktığında. `uuid` alanı Aşama 0'da eklendiği için kapı açık.
- **AI Koç Katman 2 (LLM kişiselleştirme).** Sohbet ekranı ve Edge Function kodu yazılı duruyor, `ai_coach_config.dart` placeholder'da. v1'de gizli kalabilir. Not: kişiselleştirilmiş metin üretmek için **hesap gerekmiyor** — cihaz istatistikleri istek gövdesinde gönderir, sunucu hiçbir şey saklamaz.
- **Lokalizasyon (İspanyolca/Portekizce).** Uygulama kendi pazarında doğrulanmadı; ayrıca hiç i18n altyapısı yok (tüm metinler koda gömülü Türkçe) — tahmini 10-12 çalışma oturumu / 2-4 hafta.

---

## Ortam riski — proje klasörünün yeri ✅ ÇÖZÜLDÜ (17.09.2026)

> **Durum:** Proje `C:\dev\projects\flutter\deneme1` → **`C:\src\ignis`** adresine taşındı, Drive senkronizasyonundan çıkarıldı. Yedekleme artık GitHub'da (`github.com/srnern2613/deneme1`). Çöp klasörler (`build/`, `.dart_tool/`, `.widget_preview/`, `.tmp.driveupload/`) temizlendi, `.tmp.driveupload` dosyaları repodan da çıkarıldı.
>
> Süreç boyunca teşhis doğrulandı: git'in kendisi bile `.git/objects` içindeki bir klasörü silemedi ("Deletion of directory failed"), ve `Move-Item` dosyaları kopyalayabildi ama kaynağı silemedi. İkisi de dosya kilidi kanıtıydı.
>
> Aşağıdaki kayıt, sorunun ne olduğunun geçmişe dönük dokümantasyonu olarak duruyor.

### Eski durum (arşiv)

Proje kökünde `.tmp.driveupload` var; klasör Google Drive ile senkronize. İki risk:

1. Drive, `build/` ve `.dart_tool/` altındaki binlerce geçici dosyayı senkronlamaya çalışır — build yavaşlar/bozulur.
2. **Muhtemel açıklama:** Bu oturumlarda **dört kez**, dosyayı diske yazdığımız hâlde yazılmadığını gördük (yazma başarılı raporlandı, dosya eski içerikle kaldı; ikinci denemede geçti). Drive istemcisinin aynı dosyaya aynı anda dokunması bunu açıklayabilir.

**Kanıt:** `.tmp.driveupload` klasöründe **450'den fazla geçici dosya** var (bazıları 4-5 MB) ve zaman damgaları çok yeni — Drive bu klasörü sürekli, aktif olarak yüklüyor.

### Çözüm sırası

- [ ] **1. Önce güvenlik ağı: her şeyi git'e commit et.** Taşıma sırasında bir şey ters giderse kayıp olmasın.
  `git status` → `git add -A` → `git commit -m "Ignis rename + doküman güncellemeleri"`
- [ ] **2. GitHub'da *private* repo aç ve push et.** Drive'ın yedekleme rolünü bu devralacak. `.gitignore` zaten doğru (`build/`, `.dart_tool/`, `.idea/`, `*.iml` hariç tutulmuş).
- [ ] **3. IDE'yi ve emülatörü tamamen kapat.** Çalışan `flutter run` varsa durdur.
- [ ] **4. Çöp klasörleri sil** (hepsi yeniden üretilir, taşımayı da hızlandırır): `build/`, `.dart_tool/`, `.widget_preview/`, `.tmp.driveupload/`
- [ ] **5. Projeyi Drive'ın görmediği bir yere taşı**, ör. `C:\src\ignis`.
  *Alternatif:* Drive ayarlarından senkronu durdurmak (gear → Tercihler → "Bilgisayarımdaki klasörler" → ilgili klasör → senkronu durdur). Daha az müdahale ama Drive "buluttan da silinsin mi?" diye sorar — yanlış tıklama riski var. **Taşıma daha güvenli**, çünkü hangi üst klasörün senkronlandığını bulmak zorunda kalmazsın.
- [ ] **6. Yeni konumda:** `flutter pub get` → IDE'yi yeni yoldan aç.
- [ ] **7. Bonus:** Yeni klasörü Windows Defender gerçek zamanlı taramasından hariç tut — Flutter build süreleri belirgin şekilde kısalır.
- [ ] **8. Doğrulama:** Taşıma sonrası yazma hataları devam ediyor mu? Durursa suçlu Drive'dı. Devam ederse antivirüs veya IDE dosya kilidi aramak gerekir.

> **Not (ileride):** Keystore oluşturulduğunda `key.properties` ve `*.jks` **commit edilmeden önce** `.gitignore`'a eklenmeli — şu an listede yoklar.

---

## Yayın sonrası — izlenecek veriler

D1/D7/D30 tutma · ücretsiz→Premium dönüşüm · kaç kullanıcı **kendi kitabını** yüklüyor (asıl farklılaştırıcı) · kullanıcı başına eklenen kelime · **Ignis popup'larını gören kullanıcıların tutma farkı** · cümle doldurma modunun kullanım oranı · crash/ANR.

Türkiye'de dönüşüm çok düşük çıkarsa sorun dil değil ürün demektir, ve çeviri onu çözmez.
