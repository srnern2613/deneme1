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

## Marka yapısı ve çok dilli TEK uygulama stratejisi (GÜNCEL — 18.09.2026)

**Karar değişti — eski "ayrı uygulama" planı yürürlükten kalktı.** Proje sahibi marka algısı/büyüme tek yerde toplansın istiyor: TEK uygulama, TEK kod tabanı, TEK Play/App Store kaydı. Hem **arayüz dili** hem **öğrenilen dil çifti** kullanıcı tarafından uygulama içinden seçilebilir olacak. Aklındaki diller: İngilizce, İspanyolca, Portekizce (Türkçe zaten var) — teorik olarak bunlar arasında herhangi bir kaynak↔hedef kombinasyonu (örn. arayüz İspanyolca iken Portekizce öğrenmek).

**İki bağımsız eksen olduğu netleşti, bunları ayrı ayrı çözmek gerekiyor:**
1. **Arayüz dili (chrome)** — buton/başlık/dialog metinleri. Şu an TAMAMEN Türkçe sabit string, `intl`/ARB çeviri altyapısı yok. Kullanıcı: arayüz de çok dilli olsun istedi (İspanyolca konuşan biri kendi dilinde gezinip başka bir dil öğrenebilsin) — bu, en büyük kalem.
2. **İçerik dil çifti (source/target)** — hangi dilden hangi dile öğreniliyor. Sözlük servisi, TTS sesi, kitap kütüphanesi, kelime türü etiketleri buna bağlı; bugün hepsi örtük olarak "bilinen: Türkçe, öğrenilen: İngilizce" varsayıyor.

**Zamanlama kararı:** Mimari değişikliğe **şimdi başlanmıyor** — bu büyük bir iş, mevcut P0/A-6 iş listesini kesmeyecek. Burada bir **gelecek planı** olarak yazılıyor; amaç, bundan sonra eklenen kodun bu planı zorlaştırmaması.

### Bugün yapılacak ucuz hazırlık (sonra pahalıya patlar)

- [ ] **Yeni eklenen (düzenlenen değil) her UI string'i tek noktadan gelsin.** Tam `intl`/ARB kurulumuna henüz geçilmiyor (mevcut ~yüzlerce sabit Türkçe string'e dokunmak ayrı, planlı bir iş) — ama bundan sonra bir ekrana YENİ bir metin eklenirken düz literal yerine o dosyanın üstünde tek bir sabitler bloğunda toplanması, ileride mekanik ARB ayıklamasını ucuzlatır. Davranış aynı kalır, sadece arama-değiştirme tek noktadan olur.
- [ ] **`database_helper.dart`'taki dokunulmaz tablolara dil çifti alanı DİREKT eklenmeyecek.** İçerik dil çifti (`content_language_pair` gibi) yeni, ek bir alan/tablo olarak gelecek, varsayılanı bugünkü "tr-en" olacak — geriye dönük veri bozulmaz. (Kısıtlar bölümündeki mevcut madde geçerliliğini koruyor.)
- [ ] **`dictionary_service.dart` ve `tts_service.dart`'ın bugün örtük olarak İngilizce'ye özel olup olmadığı incelenmeli** (henüz bakılmadı) — ileride bir `LanguagePair` parametresi alacak şekilde imzaların nasıl genişleyeceği önceden düşünülsün, ama şimdi implement edilmiyor.
- [ ] **Kelime türü etiketleri** (`_posTranslations` gibi haritalar — bugün `'noun': 'İSİM'` şeklinde tek dile sabit) çok arayüz-dilli plana göre her arayüz dili için ayrı harita gerektirecek; bu iş `intl` migrasyonuyla birlikte ele alınacak, şimdi dokunulmuyor.
- [ ] **Paket adı / `applicationId` / bundle id TEK kalıyor** — eski "Flutter flavors, karakter başına ayrı build" planı iptal. `com.draconiclingua.ignis` tüm dil çiftleri için aynı kalacak.
- [ ] **Tema sınıfı adı değişmiyor.** `DraconicTheme` / `draconic_theme.dart` olduğu gibi kalıyor — marka düzeyinde ortak tasarım sistemi olarak zaten doğru isimlendirilmiş.

<details>
<summary>Eski karar (17.09.2026, artık geçersiz — referans için saklanıyor)</summary>

Önceki plan: her dil çifti için ayrı uygulama, aynı evrenden farklı karakter/isim, ortak `Draconic Lingua` markası altında, Flutter flavors ile tek kod tabanından derlenen ayrı build'ler. Gerekçe "bugünkü uygulama yarının planı için bedel ödemiyor" idi (çalışma zamanı dil değiştirme altyapısı kurulmasın diye). Proje sahibi bu kararı 18.09.2026'da tersine çevirdi: ayrı uygulamaların marka algısını ve büyümeyi böleceğini, tek uygulamayı yönetmenin daha az yorucu olacağını belirtti.

</details>

### İsim değişikliği — durum

Yapıldı (diskte doğrulandı): `pubspec.yaml` (`name: ignis` + açıklama) · `AndroidManifest.xml` (`android:label="Ignis"`) · `main.dart` (MaterialApp başlığı + logo yedek metni + dosya başlığı).

- [ ] **`flutter pub get` çalıştır** (pubspec `name` değişti). Kodda hiç `package:deneme1` importu yok — hepsi göreli import — bu yüzden kırılma beklenmiyor, ama IDE'yi yeniden başlatmak gerekebilir.
- [ ] **Logo görselini yenile.** Ana sayfadaki `assets/images/lobi_logo1.png` görselinde muhtemelen hâlâ "Draconic Lingua" yazıyor. Asıl görünen marka orada — "Ignis" olarak yeniden üretilmeli. (Koddaki metin sadece görsel yüklenemezse çıkan yedek.)
- [ ] **iOS tarafı:** `ios/Runner/Info.plist` içindeki `CFBundleDisplayName`. (iOS şimdilik gündemde değil, sırası gelince.)
- [x] **Mağaza adı kararı: "Ignis Kitaptan İngilizce Öğren"** ✅ 17.09.2026 — 30 karakter (Play limiti tam), iki nokta olmadan (":" ile 31 karakter olup sığmıyordu). "İngilizce öğren" yüksek hacimli arama terimi, "Kitaptan" farklılaştırıcı (kitap-temelli kelime avlama rakiplerde yok), marka ("Ignis") önde. Uygulama içi ad/ikon "Ignis" kalıyor, bu sadece mağaza vitrini başlığı.
  - Not: App Store'da "Ignis: Bite-Size Learning" adında ayrı bir öğrenme uygulaması zaten var — yasal bir sorun değil (o da tescilsiz görünüyor) ama ASO'da karışma riski var, bu yüzden tek kelime "Ignis" değil tanımlayıcı ekli başlık seçildi.
- [ ] **Play Store'da "Ignis" adıyla başka uygulama var mı diye bak** (ad çakışması ve arama görünürlüğü için) — App Store'da bir tane bulundu, Play Store'a henüz bakılmadı.

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

### Paralel: UI/UX Düzeltme Listesi (HIG + Material uyum turu)

Ayrı, kapsamlı bir doküman: `docs/draconic_lingua_ui_iyilestirme_listesi_1.md` (18.09.2026'da eklendi). Ekran görüntüsü analizinden çıkan P0/P1 kırıklıkları, renk/buton sistemi (C), iki temalı tema mimarisi (T — Karanlık/Zindan + Aydınlık/Parşömen), Android/iOS platform uyumu (A/I) ve bunların hepsini tek yerden çözen paylaşılan altyapı bileşenlerini kapsıyor. Kendi "Sıra" (uygulama önceliği) sırası var, Aşama 0-5'ten bağımsız ilerliyor.

- [x] **Sıra 1 (kısmen) — Tema + renk altyapısı.** ✅ 18.09.2026 — `draconic_theme.dart`'taki `DraconicTheme` (zaten bir `ThemeExtension` idi, sadece `primitives.dart`'ta kullanılıyordu) genişletildi: `isDark` alanı + `textPrimary/textSecondary/textMuted` metin tokenleri eklendi; **T-2 parşömen paleti** taslak değerleriyle `DraconicTheme.parchment()` factory'si olarak koda girdi (T-3 gereği blur/glow parşömende `lowEnd()` ile aynı opak-yüzey yolunu kullanıyor). Yeni `core/theme/theme_controller.dart` (`ThemeController`) eklendi: `shared_preferences`'ta kalıcı, `main()`'de `runApp`'ten önce yükleniyor (açılışta tema sıçraması yok), `.toggle()`/`.setDark()` ile değişiyor. `main.dart`'taki `MyApp` artık `ThemeController`'ı dinleyip `MaterialApp`'i buna göre yeniden çiziyor; eskiden ölü duran `_toggleTheme`/`onToggleTheme` artık gerçek.
  **Bilinçli olarak bu turda YAPILMADI:** (1) ~600 ham hex literal içeren 20+ ekran dosyasının `Theme.of(context).extension<DraconicTheme>()` üzerinden okumaya geçirilmesi (T-1'in geri kalanı) — bu, doğrulaması `flutter analyze`/görsel kontrol gerektiren büyük, çok-turlu bir iş; (2) Profil > Görünüm'deki segmented control anahtarı (T-6 UI'ı, Sıra 8'de planlı); (3) C-2 renk görevi ataması (mevcut ekranlar hâlâ eski ham renkleri kullanıyor). Karanlık temanın GÖRÜNÜMÜ bu adımda hiç değişmedi — doküman bunu açıkça istiyor ("Sıra 1" notu).
  **Karar (17.09.2026):** ~600 ham hex'lik ekran migrasyonu **en sona saklandı** — proje sahibi "duruma göre bakarız" dedi. Bu iş beklemede, Sıra'nın geri kalanı ondan bağımsız ilerliyor.
- [x] **Sıra 2 (kısmen) — P0-3 ve P0-1 çözüldü.** ✅ 18.09.2026
  **P0-3 (Türkçe uppercase):** Yeni `core/design_system/tr_case.dart` → `String.toUpperCaseTr()` extension'ı (Dart'ın locale-agnostic `toUpperCase()`'i `i`'yi `I` yapıyor, doğrusu `İ`). Kök neden tek yerdeymiş: **hem "KITAPLIK" hem "LIG ARENASI" aynı paylaşılan `RuneTitle` widget'ından** (`core/design_system/primitives.dart`) geliyordu — tek satırlık değişiklik (`title.toUpperCase()` → `title.toUpperCaseTr()`) her iki hatayı ve `RuneTitle` kullanan tüm diğer ekran başlıklarını aynı anda düzeltti. Aynı bug'ın iki küçük yan örneği de (`reader_screen.dart` ve `flashcards_exercise_screen.dart`'taki Türkçe kelime türü fallback'leri) aynı extension'la düzeltildi.
  **P0-1 (alt bar içeriği kesiyor):** Yeni `core/design_system/platform_tokens.dart` → `PlatformTokens.scrollBottomPadding(context)` TEK formülü (bar yüksekliği + `viewPadding.bottom` + 16). Profil, Arena (`flashcards_screen.dart`) ve Lobi (`main.dart`)'deki üç ana scroll view'ın sabit yazılmış alt padding'i (110/110/100) bu formülle değiştirildi.
  **Bilinçli olarak bu turda YAPILMADI:** `Spacing` (8pt grid, P1-19), `ScreenScaffold` (P1-11 header birleştirmesi — kapsamı büyük, Sıra 2 notunda "bu turda kapsam dışı" deniyor), A-1/A-2/A-3 (edge-to-edge, Android inset, dokunma hedefi denetimi — cihazda görsel doğrulama gerektiriyor, kod tarafında `PlatformTokens.minTapTarget` sabiti hazır ama henüz hiçbir yerde kullanılmadı).
- [x] **Sıra 3 (kısmen) — A-6 (veri kaybı, P0 gibi ele alındı) çözüldü.** ✅ 18.09.2026 — `reader_screen.dart` sistem geri/kenar jestini zaten `PopScope(canPop:false)` ile yakalayıp `_handleExit()`'e yönlendiriyordu (bu turda doğrulandı, dokunulmadı). `flashcards_exercise_screen.dart`, `word_boss_battle_screen.dart`, `mixed_dungeon_session_screen.dart` — üçü de `PopScope`/`WillPopScope` kullanmıyordu; sistem geri (ve iOS'ta edge-swipe) sessizce, sormadan ekranı kapatıyordu, kapatma butonuyla aynı yoldan geçmiyordu. Üçüne de `PopScope(canPop: false, onPopInvokedWithResult: ...)` + ortak bir `_confirmExit()` onay diyaloğu eklendi; AppBar'daki kapatma (X) butonu da artık aynı `_confirmExit()`'i çağırıyor, böylece iki çıkış yolu tutarlı. Not: bu 3 ekranda `ReadingSessionResult` benzeri bir sonuç nesnesi hiç yoktu — ilerleme (XP/SRS puanı) her cevapta veritabanına (V1 + FSRS paralel yazım) anlık kaydediliyor, dolayısıyla "kaybolan" şey bir sonuç nesnesi değil, kazara-çıkış anındaki uyarı eksikliğiydi; onay diyaloğu bunu kapatıyor.
  **A-7 (blur maliyeti) de tamamlandı, Sıra 3 kapandı.** ✅ 18.09.2026 — `lib/` genelinde taranan 3 `BackdropFilter` kullanımından `core/design_system/primitives.dart`'taki `GlassPanel` zaten koşulluydu (`glassBlurSigma <= 0` iken BackdropFilter hiç kurulmuyor, `DraconicTheme.lowEnd()` bu değeri zaten `0.0` yapıyordu — sorun veri modelinde değil tüketimindeydi). Asıl ihlal `shop_screen.dart`'taki 2 ham `BackdropFilter` çağrısıydı (`_showInsufficientGemsDialog` sigma 14, `_startChestOpeningCeremony` sigma 18) — ikisi de `DraconicTheme`'e hiç bakmadan, cihaz gücünden bağımsız her zaman blur uyguluyordu. `DevicePerformanceTier.low`'da `BackdropFilter` artık hiç kurulmuyor (GlassPanel'deki desenle aynı); `barrierColor` zaten %88-%96 opak olduğu için blur'suz hâlde de arkaplan yeterince kapanıyor, ayrı bir opak fallback yüzeyi gerekmedi. `_ChestOpeningDialog`/`_RuneSealPainter`/`_ShatterBurstPainter` (dokunulmaz) içeriklerine dokunulmadı, sadece dışlarındaki `BackdropFilter` sarmalayıcısı koşullu hâle getirildi.
  Not: `GlassPanel`'in düşük-tier fallback rengi dokümanın önerdiği tam `surfaceLight`/`borderSubtle` token'ları yerine hardcoded `surfaceDark` (alpha 0.65) + beyaz-alpha kenarlık kullanıyor — işlevsel olarak doğru (opak, tek katman) ama tam renk parite değil; küçük bir kozmetik iyileştirme olarak P1'e not düşülebilir, bu turda dokunulmadı (kapsam dışı, token tasarrufu).
- [x] **Sıra 4 (kısmen) — Kalan P0'lardan P0-4 ve P0-5 çözüldü; P0-2 ve P0-7 zaten çözülmüş bulundu.** ✅ 18.09.2026
  **P0-4 (XP pill iki metrik gösteriyor):** İnceleme sonucu header pill'inin TÜM sekmelerde (Lobi/Kitaplık/Arena/Profil) aynı `XpShopService.instance.xpNotifier`'dan (tek kaynak, `user_total_xp`) beslendiği doğrulandı — kodda ayrı bir "sezon XP" alanı yoktu, iki farklı veri kaynağı yoktu. Asıl eksik, dokümanın "Verilmiş kararlar"ındaki #1 maddesiydi: Arena'nın sıralama listesindeki XP sayıları (`simulatedLeague`, header'dan bağımsız bir simülasyon) hiç etiketlenmemişti. `leaderboard_screen.dart`'a "SEZON XP · haftalık sıfırlanır" etiketi eklendi (sıralama listesinin hemen üstünde), böylece aynı ekranda görünen iki farklı sayı artık açıkça ayrışıyor.
  **P0-5 (Profil ile Arena çelişiyor):** Kök neden bulundu — `main.dart`'taki `IndexedStack` Arena ve Profil sekmelerini de (Kelimeler'de daha önce düzeltilen bug ile birebir aynı şekilde) canlı tutuyordu, yani her ikisinin de rank/XP hesaplaması yalnızca İLK açılışta çalışıyor, sekmeler arası geçişte hiç tazelenmiyordu. `leaderboard_screen.dart`'a public `refreshLeagueData()` sarmalayıcısı eklendi (zaten var olan `profile_screen.dart`'taki `refreshProfileData()` ile aynı desen); `main.dart`'taki `_onTabTapped`'e Arena (index 3) ve Profil (index 4) için bu tazeleme çağrıları eklendi — Kelimeler/Ana Sayfa sekmelerinde zaten var olan düzeltmeyle aynı desen. Not: bu TAM birleştirme değil — iki ekran hâlâ ayrı `simulatedLeague` kopyalarını okuyor (P0-6'da senkron tutulmuşlardı), sadece artık her sekmeye dönüşte güncel veriyle yeniden hesaplanıyorlar; anlık çelişki riski büyük ölçüde azaldı ama teorik olarak sıfırlanmadı (doğru çözüm: tek bir paylaşılan lig servisi — kapsam dışı bırakıldı).
  **P0-2 (Arena karuselinde overflow):** Kod incelendiğinde `leaderboard_screen.dart`'taki `_buildChallengeCard()`'ın önceki bir turda ("EJDERHA ROTASI V2 Faz C" yorumu) zaten `SingleChildScrollView` ile taşma-korumalı hale getirildiği görüldü — kartın içeriği sabit yükseklikli `SizedBox` içinde, `Expanded`/`Flexible` eksikliği yok. Kod tarafında değişiklik yapılmadı; hâlâ cihazda görsel olarak overflow görülüyorsa (ör. büyük font scale'de) bildirmen yeterli, o zaman kart yüksekliği veya başlık `maxLines` ayarı ile küçük bir ek düzeltme yapılır.
  **P0-7 (Ignis rozeti kapatıyor):** Arena'daki lig özet kartında ("EJDERHA ROTASI V2 Faz A — Ignis Temizliği" yorumu) maskotun daha önce tamamen kaldırıldığı görüldü; "#1. Sıra" pill'i artık hiçbir görselin üstünde değil, sade bir satırda duruyor. Kodda bu haliyle P0-7'nin tarif ettiği çakışma yok — dokümandaki ekran görüntüsü muhtemelen bu temizlikten önceki bir sürüme aitti. `main.dart`'taki Lobi'nin ayrı bir kartında (Ignis + "Sen yaparsın!" rozeti) benzer bir `Positioned` kullanımı var ama Arena/rank pill'iyle ilgisi yok — karıştırılmasın diye ayrı not düşüldü, dokunulmadı.
- [x] **Sıra 5 (kısmen) — C-1 buton hiyerarşisi bileşeni kuruldu, ekran migrasyonu başlamadı.** ✅ 18.09.2026 — `core/design_system/primitives.dart`'a `ButtonLevel` enum (primary/secondary/tertiary/destructive) + `AppButton` widget'ı eklendi (C-1 tablosundaki 4 seviyeyi birebir uyguluyor: birincil dolu amber+glow, ikincil surfaceLight dolgu+borderSubtle çerçeve, üçüncül sadece metin/ikon, yıkıcı kırmızı). C-4 gereği glow yalnızca `enableHeavyGlow && isDark` iken; aydınlık temada veya düşük performans katmanında glow yerine gölge+çerçeve. `AppButton.icon` adında kompakt, sadece-ikon bir varyant da var (liste satırı aksiyonları için). Eski `NeonButton` hiçbir yerde kullanılmıyordu (grep ile doğrulandı, sıfır risk) — dokunulmadı, referans olarak duruyor.
  **P1-1 de tamamlandı.** ✅ 18.09.2026 — Proje sahibine "aktif kitap" tanımı soruldu, cevap: "kullanıcı en son neyle etkileşime girdiyse o olsun". Meğer yeni bir alan/migrasyon hiç gerekmiyormuş: `Book.lastReadDate` zaten her sayfa değişiminde güncelleniyordu (`library_screen.dart` `_openReader`, `main.dart` `_openReaderDirectly`), sadece Kitaplık ekranı bunu okumuyordu. `library_screen.dart`'a `_mostRecentlyOpenedBook` getter'ı eklendi (en yeni `lastReadDate`'e sahip kitap); kitap satırındaki buton artık `AppButton.icon` — yalnızca bu kitap için `ButtonLevel.primary` (dolu amber, play ikonu), diğer tüm satırlar `ButtonLevel.tertiary` (dolgusuz, chevron ikonu). Fonksiyonel davranış aynı kaldı (her iki buton da `_openReader`'ı çağırıyor), sadece görsel hiyerarşi değişti.
  **Bilinçli olarak bu turda YAPILMADI:** Tüm ekranların diğer butonlarının `AppButton`'a geçirilmesi (asıl "Sıra 5" işinin gövdesi) — bu, hex renk migrasyonu gibi çok dosyalı, büyük bir iş, henüz başlamadı; P1-1 tek, isim verilmiş bir örnek olarak seçilip bitirildi.
- [x] **Sıra 6 (kısmen) — Bileşen birleştirme: P1-3 ve P1-9 tamamlandı.** ✅ 18.09.2026 — Aynı kitap Lobi'de harf monogramı, Kitaplık'ta emoji ile farklı görünüyordu (P1-3). `core/design_system/primitives.dart`'a paylaşılan `BookCover` widget'ı eklendi (harf monogramı + `title.length % 5` ile deterministik palet rengi — renkler `main.dart`'taki eski `_getBookBadgeColor`'dan birebir taşındı, davranış aynı; hex'lerin tema token'larına taşınması ayrı, planlı bir iş — P1-4/C-2). Lobi'deki (`main.dart`) 15 satırlık elle yazılmış monogram `Container`'ı ve `_getBookBadgeColor` metodu kaldırılıp `BookCover(title: book.title)` ile değiştirildi; `library_screen.dart`'taki emoji `Text(book.icon)` da `BookCover(title: book.title, size: 34)` ile değiştirildi. Aynı pasoda P1-9 (şifreli meta metin) de çözüldü: Kitaplık satırındaki `'${book.author} · %$readingPercentage · 🧠$discoveredWords ⭐$masteredWords'` gibi emoji-ağırlıklı satır, dokümanın hedeflediği sade formata (`'%$readingPercentage okundu · $discoveredWords kart'`) çevrildi; yazar adı ve ⭐ ustalık sayısı satırdan kaldırıldı (doğrudan doküman örneğindeki gibi).
  **P1-6 da tamamlandı.** ✅ 18.09.2026 — `library_screen.dart`'taki 4'lü istatistik ızgarasında etiketler ("Gün Serisi", "Dakika Okuma", "Keşfedilen Kelime", "Kaydedilen Kart") 2 satıra kırılıp kart yüksekliğini bozuyordu. Yeniden ızgara tasarımına gidilmedi (daha büyük, riskli bir değişiklik) — etiketler tek kelimeye indirildi ("Seri", "Dakika", "Kelime", "Kart") ve `_buildStatTile`'daki etiket metni `maxLines: 1` + ellipsis yapıldı, böylece hiçbir koşulda 2 satıra kırılmıyor.
  **Bilinçli olarak bu turda YAPILMADI:** P1-2 (varsayılan kitap ikonlarının ve Arena/`leaderboard_screen.dart`'taki `simulatedLeague` bot avatarlarının emoji yerine Phosphor ikonlarıyla değiştirilmesi) — daha sübjektif bir görsel tasarım kararı gerektiriyor, token bütçesi gereği ertelendi, proje sahibiyle teyit edilmedi.
- [x] **Sıra 7 — Hiyerarşi: P1-7, P1-13, P1-15 tamamlandı; P1-12 ve P1-20 zaten çözülmüş/gereksiz bulundu.** ✅ 18.09.2026 — **P1-7:** Lobi'deki "0/5 Kelime" ve "%0 okundu", Profil'deki "%0 Tamamlandı" gibi çıplak sıfırlar davet metnine çevrildi ("Bugün henüz kelime öğrenmedin", "Yeni kitap ✨", "Henüz başlamadın"); Kitaplık'ın istatistik ızgarası ve Lobi'nin alt-metrikleri bilinçli olarak sayı bırakıldı (Apple Sağlık tarzı kutucuklarda 0 anlamlıdır). **P1-13:** `main.dart`'a `ScrollController` eklendi; hero karttaki "Derse Başla" scroll'da görünmez olunca (offset > 380), ekranın altında `AnimatedSlide`/`AnimatedOpacity` ile beliren yarı saydam bir aksiyon çubuğu ekleniyor — App Store "Get" davranışı. **P1-15:** "Günlük Durum" kartı artık `Material`+`InkWell` ile tıklanabilir, aynı `_onStartLessonTap` akışına gidiyor. **P1-12:** ölçüldüğünde logo zaten ~97pt (dokümanın tahmin ettiği ~150pt değil), scroll'da küçülme animasyonu P1-2 gibi sübjektif/büyük bir iş olarak ertelendi. **P1-20:** kod incelendiğinde iç içe scroll yapısı zaten yoktu (tek `Expanded` + `ListView.separated`) — değişiklik gerekmedi.
- [x] **Sıra 8 (kısmen) — Profil+tema anahtarı: P1-5, P1-16, P1-18 tamamlandı; P1-17 ve I-5 kısmen; T-6 bloklu.** ✅ 18.09.2026 — **P1-5:** Profil satır padding'i 13→9, satır yüksekliği iOS aralığına indi. **P1-16:** "Mastered Words Vitrini" → "Kalıcı Hafıza". **P1-18:** `habit_tracker_screen.dart`'taki kaydırarak silme (`Dismissible`) hiç onay/undo içermiyordu — 4 saniyelik "Geri Al" `SnackBar`'ı eklendi (silinen öğe+index saklanıp geri ekleniyor); `dictionary_screen.dart`'ta zaten onay diyaloğu vardı, dokunulmadı; `library_screen.dart`'ta kitap kaldırma özelliği hiç yok, kapsam dışı kaldı. **P1-17 (kısmen) + I-5:** `EntitlementRepository`'ye bağımsız `restorePurchases()` eklendi; Profil'e yeni bir "Ayarlar" bölümü (`_buildAyarlarSection`) kondu — "Satın Alımları Geri Yükle" (çalışıyor) ve "Sürüm" (pubspec'ten elle "1.0.0", `package_info_plus` eklenmediği için sabit). Premium/Bildirimler/Uygulama dili/Verilerimi sıfırla/Gizlilik-Şartlar satırları bilinçli olarak eklenmedi — her biri ya eksik altyapıya (bildirim izni, çok-dilli mimari) ya gerçek olmayan içeriğe (yasal linkler) ya da riskli bir kapsam kararına (hangi verinin silineceği) bağlı, sahte/pasif satır eklemek yanıltıcı olurdu.
  **T-6 düzeltme + tamamlandı.** ✅ 18.09.2026 — Önce yanlışlıkla "bloklu" diye işaretlemiştim; `main.dart`'ta Sıra 1'den kalma tam bir `ThemeController`/`DraconicTheme` (parşömen paleti dahil) zaten var olduğu ortaya çıktı, yalnızca hiçbir ekranda gerçek bir anahtar yoktu. Profil > Görünüm'e "Zindan"/"Parşömen" iki butonlu seçici eklendi (`ThemeController.instance.setDark()`, `shared_preferences`'a kalıcı). Sınır: T-1'in geri kalanı (ekranların ~600 ham hex'i token'lara taşıması) yapılmadığı için anahtar gerçekten çalışıp tercihi saklıyor ama şu an görünür etkisi sınırlı.
- [x] **Sıra 9 — T-7 zaten çözülmüş bulundu.** ✅ 18.09.2026 — `reader_screen.dart` incelendiğinde dokümanın istediğinden daha kapsamlı bir sistemin zaten var olduğu görüldü: `ReaderTheme` enum'ı ücretsiz Karanlık/Sepya/Aydınlık + 6 mağaza kozmetiği içeriyor, uygulama temasından tamamen bağımsız, "Aa" ayar panelinden seçiliyor, `XpShopService` ile ayrı anahtarda saklanıyor. Kod tarafında değişiklik gerekmedi.
- [x] **Sıra 10 (kısmen) — P1-8'in 2/4 örneği düzeltildi; A-5/I-2/T-8/I-7 cihaz gerektiriyor.** ✅ 18.09.2026 — Lobi'deki dar kitap kartında uzun başlık ("The Adventures of Tom Sawyer") tek satıra sığmıyordu, `maxLines: 2`'ye çıkarıldı; Profil'deki lig rakibi metninde `maxLines` hiç yoktu (yalnız etkisiz bir `overflow: ellipsis` vardı), `maxLines: 1` eklendi. Diğer 2 örnek ("Odaklı Ç… Seansı", "Devam ediyor") koda bakılarak bulunamadı — tahminle yanlış yeri değiştirmemek için dokunulmadı. A-5 (font scale %200), I-2 (Dynamic Type 1.3x), T-8 (iki temada doğrulama) ve I-7 (durum çubuğu ikon rengi) cihazda test/tam tema gerektiriyor, bu oturumda yapılamadı.
- [ ] **Sıra 11 — Asset varyantları (T-4/T-5): proje sahibinin kendi işi, dokunulmadı.** Doküman bunu açıkça proje sahibine bırakıyor (illüstrasyon/painter varyantları) — kod tarafında yapılacak bir şey yok.

### Hemen yapılacak küçük işler (aşama beklemez)

- [x] **Liderlik tablosundaki ırkçı test isimlerini temizle. (ACİL)** ✅ 18.09.2026 — `lib/leaderboard_screen.dart`'ta "Zenci"/"Çinli" → "Alevkanat"/"Gölgeavcı" (Ignis evreninden tematik isimler). Aynı sabit isim havuzunun **birebir kopyası** `profile_screen.dart`'ta da vardı (Lig sıralamasını Profil kartı için salt-okunur tekrar hesaplıyor) — orada da düzeltildi, iki dosya senkron kaldı.
- [ ] **Alışkanlıklar kalıcı değil.** `lib/habit_tracker_screen.dart` içinde `_habits` sadece bellekte; kullanıcının eklediği hedefler uygulama kapanınca kayboluyor.
- [x] **"Kelimeler" sekmesi yeni eklenen kelimeyi/kilit açılışını göstermiyordu** ✅ 17.09.2026 — `main.dart`'taki bottom nav `IndexedStack` kullandığı için `FlashcardsScreen` sekmeye her dönüşte yeniden yüklenmiyordu (Ana Sayfa sekmesi için bu zaten düzeltilmişti, Kelimeler için unutulmuştu). `flashcards_screen.dart`'a `refreshCardsAndStats()` eklendi, `main.dart` her "Kelimeler" sekmesine geçişte çağırıyor. Kullanıcı testinde doğrulandı — yeni kullanıcı kitaptan kelime avlayıp hemen pratiğe geçebiliyor artık.
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
- [x] **Migrasyon testi** ✅ 17.09.2026 — v16 şemasıyla kurulup 4 test kelimesi eklendi (`seldom, pride, bending, finish`), sonra **kaldırmadan** üstüne v17 kuruldu: uygulama çökmedi, 4 kelime de korundu. Test emülatörde yapıldı (`sdk gphone64 x86 64`) — gerçek cihazda **henüz** tekrarlanmadı, Aşama 5'e (yayın hazırlığı) geçmeden önce gerçek cihazda bir kez daha doğrulanmalı.

---

## Aşama 1 — Yedekleme Güvencesi (Android Auto Backup)

Hesap sistemi yerine seçilen ucuz yol. Android, API 23+ hedefleyen uygulamalarda **varsayılan olarak** uygulamanın SQLite veritabanını ve SharedPreferences'ını kullanıcının Google Drive'ında özel bir alana yedekliyor (kullanıcının Drive kotasından düşmüyor), ve yeni cihaz kurulumunda/Play'den yeniden kurulumda **otomatik geri yüklüyor**. Manifest'te `android:allowBackup` yazmıyor → varsayılan `true` → **muhtemelen şu an zaten çalışıyor.**

### Kritik tuzak: 25 MB kotası

Limit **uygulama başına 25 MB**. Veri aşarsa sistem `onQuotaExceeded()` çağırıp **hiçbir şeyi yedeklemiyor** — kısmi yedek yok, komple iptal. Senin uygulamada yüklenen PDF'lerin **tüm sayfa metni** `saved_books` içinde SharedPreferences'ta duruyor; birkaç kitap bu limiti rahatlıkla aşar ve o anda kelimelerin yedeklenmesi de sessizce durur.

- [x] **Kitap metinlerini SharedPreferences'tan çıkar** ✅ 17.09.2026 — yeni `lib/core/storage/book_storage_service.dart`: sayfa metni ayrı bir SQLite dosyasında (`book_content.db`), künye (başlık/yazar/ilerleme) hafif haliyle SharedPreferences'ta. Eski kayıtlar otomatik taşınıyor (`loadBooks()` içinde self-healing migration, ayrı adım gerekmez). Çağrı noktaları güncellendi: `main.dart`, `library_screen.dart`, `default_books.dart` (5 varsayılan roman dahil).
- [x] Manifest'e `android:allowBackup="true"` açıkça yazıldı + iki kural dosyasıyla (`res/xml/data_extraction_rules.xml` API 31+, `res/xml/backup_rules.xml` API 23-30) `book_content.db` yedekten hariç tutuldu.
- [ ] **Test: gerçek cihazda uygulamayı kaldır → tekrar kur → kelimeler geri geldi mi?** HENÜZ YAPILMADI — Google hesabına bağlı gerçek cihaz gerektiriyor, Aşama 5'e yakın migration testiyle birlikte tekrar doğrulanacak. Emülatörde temel sağlamlık testi (kitaplar açılıyor, kelimeler duruyor, çökme yok) yapıldı.

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

- [x] **İLK ADIM: `lib/core/branding/app_branding.dart`.** ✅ 17.09.2026 — karakter adı, poz görsel yolu (`poseAsset()`), vurgu rengi tek dosyada. Pozlar üretilene kadar mevcut rozet görseline düşüyor (bkz. Poz seti maddesi).
- [x] **Yerel istatistik/tetikleyici motoru** ✅ 17.09.2026 — `lib/core/coach/ignis_moments_engine.dart`. Aşama 0'daki `daily_stats`/`flashcards` tablolarını okuyor:
  - Bugün öğrenilen/tekrar edilen kelime sayısı ve **projeksiyon** ("bu hızla haftada ~X kelime", son 7 gün ortalaması) — **yapıldı**
  - Seri kilometre taşı (7/30/100 gün) — **yapıldı**, `StreakFreezeService` üzerinden
  - Yarın tekrar vakti gelen kelime sayısı (`getDueTomorrowCount`) — **yapıldı**
  - Geçen haftaya karşı trend, en çok zorlanılan 5 kelime, ihmal edilen mod — **henüz yok**, sonraki geçişte eklenecek
  - ✅ 17.09.2026 — dört egzersiz tipinin tamamına bağlandı: `flashcards_exercise_screen.dart` (`_finishSrs`), `quiz_exercise_screen.dart` (`_finishQuiz`), `spelling_exercise_screen.dart` (`_finishSpelling`), `match_exercise_screen.dart` (`_finishGame`)
  - Sıklık kuralı ("ölçülü": günde en fazla 1 önemli an) `SharedPreferences` ile uygulanıyor
- [x] **Mevcut modal zenginleştirildi** ✅ 17.09.2026 — `celebration_dialog.dart`'a opsiyonel `ignisMomentTitle`/`ignisMomentMessage` alanı eklendi (null verilirse eski davranış aynen korunur, ayrı popup açılmadı — karar buydu).
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
- [x] Cümle doldurma: `context_sentence` boş olan kelimeler bu moda girmemeli; havuz yetersizse `EmptyWordPoolState` göster — **YAPILDI**: `lib/cloze_exercise_screen.dart` oluşturuldu (quiz ekranından türetilmiş 4 şıklı yapı, ama seçenekler İngilizce kelimeler ve soru cümle içindeki boşluk). Filtre: `context_sentence` dolu VE kelime cümlede kelime-sınırıyla (`\b...\b`, case-insensitive) geçiyor olmalı. Arena'ya (`flashcards_screen.dart`) 5. grid kartı olarak "Boşluk Doldurma" eklendi, **kilitsiz** (ücretsiz vitrin — proje kararı). `recordMultiModalResult` mode: `'cloze'`. `flutter analyze` bekleniyor.
- [x] Ters Test: `quiz_exercise_screen.dart`'tan türetilecek — çeldiriciler artık İngilizce kelimeler olmalı — **YAPILDI**: `lib/reverse_quiz_screen.dart` oluşturuldu (Türkçe anlam gösterilir, seçenekler İngilizce kelimeler, doğru cevap işaretlendikten sonra telaffuz çalınır — hile riski yok çünkü seçim zaten yapılmış). Arena'ya 6. grid kartı olarak eklendi, `PaywallTrigger` ile sarılı (merkezi kilit — proje kuralına uygun, yeni kilit mantığı yazılmadı). `recordMultiModalResult` mode: `'reverse_quiz'`. `flutter analyze` bekleniyor.
- [x] Sadece Dinleme: TTS zaten `en-US` sabit çalışıyor — **YAPILDI**: `lib/listening_exercise_screen.dart` oluşturuldu (quiz yapısından türetildi, kelimenin yazısı cevaplanana kadar gizli, otomatik + tekrar dinle butonu, seçenekler Türkçe anlamlar). Arena'ya 7. grid kartı olarak eklendi, `PaywallTrigger` ile sarılı. `recordMultiModalResult` mode: `'listening'`.
- [x] Hız Turu: mevcut test mantığı + geri sayım; seans sonu modalıyla uyumlu — **YAPILDI**: `lib/speed_round_screen.dart` oluşturuldu. Soru başına sayaç YOK, tek bir 60 saniyelik oturum sayacı var; havuz tükenirse otomatik yeniden karılıp devam ediyor ("süreye karşı maksimum doğru"). Başlangıç ekranı ("60 Saniyen Var!") + `arena_session_limit` bilerek uygulanmıyor (kısıtlı sayıda soru fikriyle çelişir). Seans sonu modalında en uzun seri de gösteriliyor. Arena'ya 8. grid kartı olarak eklendi, `PaywallTrigger` ile sarılı. `recordMultiModalResult` mode: `'speed_round'`.
- [x] Premium kilitleri **merkezi `PaywallTrigger` üzerinden** (proje kuralı — yeni kilit mantığı yazma) — **YAPILDI**: Ters Test, Sadece Dinleme ve Hız Turu'nun üçü de `core/entitlement/paywall_trigger.dart`'taki mevcut `PaywallTrigger` widget'ıyla sarılı; hiçbir yeni kilit/tıklama-mağaza mantığı yazılmadı.

**Aşama 3 durumu: 4/4 mod tamamlandı** (Cümlede Boşluk Doldurma ücretsiz, Ters Test / Sadece Dinleme / Hız Turu Premium). Arena grid'i artık 2x2 değil 2 sütun × 4 satır (8 kart) — Aşama 4'te tasarım toparlaması sırasında düzen yeniden değerlendirilebilir.

### Aşama 3 sonrası kullanıcı testinde bulunan 4 sorun — hepsi düzeltildi (17.09.2026)

- [x] **Hafıza Zindanı (Karma Mod) yeni pratik tiplerini hiç kullanmıyordu.** `mixed_dungeon_session_screen.dart`'taki `_MixedMode` enum'u sadece `quiz/match/spelling` biliyordu — Cümlede Boşluk Doldurma, Ters Test, Sadece Dinleme hiçbir zaman karma havuzuna girmiyordu. **YAPILDI**: enum'a `cloze`, `reverseQuiz`, `listening` eklendi. Yeni `_eligibleModesFor(card, isPremium)` her kart için hangi modların uygun olduğunu belirliyor: `cloze` sadece geçerli `context_sentence`'ı olan kartlarda havuza girer; `reverseQuiz`/`listening` sadece `EntitlementRepository.instance.isPremium` true ise (ücretsiz kullanıcının karşısına ASLA çıkmaz). `speedRound` (Hız Turu) BİLEREK eklenmedi — o tek bir 60sn oturum sayacına dayanıyor, kart-bazlı rastgele seçim modeline uymuyor, kendi ayrı Arena kartında kalıyor.
- [x] **Geliştirici Test Modu Premium özellikleri açmıyordu, test edilemiyordu.** **YAPILDI**: `EntitlementRepository`'ye `devTestOverrideNotifier` eklendi; `isPremium` getter'ı artık `isPremiumNotifier.value || devTestOverrideNotifier.value`. `flashcards_screen.dart`'taki "Geliştirici Test Modu" switch'i artık `EntitlementRepository.instance.setDevTestOverride(val)` da çağırıyor — switch açıkken TÜM Premium kilitleri (PaywallTrigger'lar dahil) anında açılıyor, kapatılınca otomatik tekrar kilitleniyor. `PaywallTrigger` artık iki notifier'ı da (`Listenable.merge`) dinliyor.
- [x] **Premium karta tıklayınca hiçbir şey olmuyordu.** Kök neden: `PaywallTrigger._handleTap` doğrudan `RevenueCat.presentPaywallIfNeeded`'ı çağırıyordu — RevenueCat ürünleri henüz yapılandırılmadığı (test ortamı) için sessizce başarısız oluyordu (hata yakalanıp yutuluyordu, kullanıcıya HİÇBİR geri bildirim yoktu). **YAPILDI**: `PaywallTrigger` artık dokunuşta ÖNCE Ignis karakterli bir bilgilendirme kartı (bottom sheet) açıyor — "Ignis bunu Premium'a sakladı 🔒" + özellik adı + "Premium'a Geç ⚡" / "Şimdi Değil" butonları. Kullanıcı "Premium'a Geç" derse RevenueCat paywall'ı açılır. Böylece RevenueCat yapılandırması ne durumda olursa olsun kullanıcı her tıklamada bir geri bildirim görür.
- [x] **SRS'de (Hafıza Zindanı) Ignis Anı hiç çıkmıyordu.** Kök neden: kullanıcının test ettiği "Hafıza Zindanı (SRS)" ana butonu asıl olarak `MixedDungeonSessionScreen`'i açıyor (flip-card SRS ekranını değil) — ve o ekranın `_finishSession()`'ı diğer 4 egzersiz ekranından (quiz/spelling/match/flip-card srs) farklı olarak Ignis Anı motoruna HİÇ bağlanmamıştı. **YAPILDI**: `_finishSession()` artık `IgnisMomentsEngine.instance.getSessionEndMoment()` çağırıp `CelebrationDialog`'a `ignisMomentTitle`/`ignisMomentMessage` geçiriyor — tam olarak diğer 4 ekranla aynı desen.

`flutter analyze` kullanıcı tarafından teyit edilmeli.

### Ekran görüntüsüyle bulunan 2 sorun daha — hepsi düzeltildi (17.09.2026)

- [x] **Hafıza Zindanı'nda "Dinle & Yaz" modu kelimeyi hem büyük yazı hem de harf harf gösteriyordu — kopyalama gibi oluyordu, dinleyip yazma değil.** Kök neden: `mixed_dungeon_session_screen.dart`'taki `_buildPromptCard()`, `spelling` modunu da `quiz`/`match` ile aynı `case` bloğunda değerlendirip ortak `_buildWordCard(word)`'u çağırıyordu — bu da kelimeyi düz metin olarak ekrana yazıyordu. **YAPILDI**: `spelling` için ayrı bir `case` bloğu eklendi; artık kelime metni HİÇ gösterilmiyor, yerine yeşil bir sesli okuma butonu (`Icons.volume_up_rounded` → `TtsService.instance.speakWord(word)`) ve kartın Türkçe anlamı (veya "Dinle ve kelimeyi hecele" fallback'i) gösteriliyor.
- [x] **Seans sonunda Ignis hiç görsel olarak çıkmıyordu, sadece düz metin vardı.** **YAPILDI**: `celebration_dialog.dart`'a `ignisMomentPose` alanı eklendi; Ignis Anı kutusu artık düz metin değil, solda `AppBranding.poseAsset(pose)` ile karakterin görseli (yuvarlak köşeli, `errorBuilder` ile ikon fallback'i) + sağda köşesi sivri bir konuşma balonu (isim etiketi + başlık + mesaj) şeklinde bir `Row`. Bu poz bilgisini iletebilmek için `ignisMomentPose: ignisMoment?.pose` parametresi 9 çağıran ekranın hepsine eklendi: `mixed_dungeon_session_screen.dart`, `cloze_exercise_screen.dart`, `reverse_quiz_screen.dart`, `listening_exercise_screen.dart`, `speed_round_screen.dart`, `match_exercise_screen.dart`, `quiz_exercise_screen.dart`, `spelling_exercise_screen.dart`, `flashcards_exercise_screen.dart`.

`flutter analyze` kullanıcı tarafından teyit edilmeli.

---

## Aşama 4 — Tasarım Toparlama

- [x] **Arena ızgarası yeniden düzenlendi.** ✅ 17.09.2026 — Kullanıcı kararı Apple tasarım diline bırakılınca: 2×4 kare ızgara yerine **iOS Ayarlar tarzı "inset grouped" liste** seçildi. `flashcards_screen.dart`'ta `_buildGridPracticeCard` (kare kart) kaldırıldı; yerine `_buildSectionLabel` (küçük büyük-harf gri başlık), `_buildPracticeSection` (rounded-corner tek kapsayıcı + satırlar arası ince ayraç) ve `_buildPracticeRow` (dolgu renkli ikon karesi + başlık/açıklama + ödül rozeti + chevron/kilit ikonu) geldi. 8 mod artık **"TEMEL PRATİKLER"** (Hızlı Test, SRS Hafıza, Eşleştirme, Dinle & Yaz, Boşluk Doldurma) ve **"PREMIUM PRATİKLER"** (Ters Test, Sadece Dinleme, Hız Turu) olmak üzere iki gruplu karta ayrıldı. Kilit/FOMO/Premium/tıklama mantığının hiçbiri değişmedi — sadece görünüm. Kullanılmayan hale gelen `dart:ui` import'u da temizlendi.
- [ ] **Seans sonu Ignis Anı kutusu (istatistik yazış şekli + bilgilendirme pop-up'ı) görsel olarak güncellensin.** Kullanıcı notu (17.09.2026): şu anki hali "ilerde güzel durmuyor" — avatar + konuşma balonu eklendi ama düzen/tipografi/istatistik sunumu daha sonra elden geçirilmeli.
- [x] **Ana Sayfa'da "Günlük Durum" kartı eklendi.** ✅ 17.09.2026 — `ignis_moments_engine.dart`'a popup sıklık kısıtına (günde 1) tabi OLMAYAN yeni `getDailyStatusSnapshot()` metodu ve `IgnisDailyStatus` veri sınıfı eklendi (bugünkü yeni kelime, tekrar, yarın bekleyen, haftalık projeksiyon). `main.dart`'taki `DashboardScreen`'e AI Koç bandının altına, kitap listesinin üstüne `_buildIgnisDailyStatusCard()` eklendi: Ignis rozeti + "GÜNLÜK DURUM" etiketi, 3 kompakt istatistik (Yeni Kelime/Tekrar/Yarın Bekleyen) ve haftalık projeksiyon satırı. Bugün hiç pratik yapılmadıysa nazik bir davet mesajı gösteriyor. `refreshDashboardStats()` her çağrıldığında (sekme geçişi, resume) tazeleniyor.
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
