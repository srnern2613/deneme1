# Draconic Lingua — UI/UX Düzeltme Listesi (iOS + Android)

Güncelleme: 18 Eylül 2026, üçüncü tur. Kapanan maddeler listeden çıkarıldı.
Kapsam: yalnızca UI ve etkileşim katmanı. Veri modeli, FSRS/SRS mantığı, XP ekonomisi değişmiyor.
Kod bu dosyada yok — her madde "ne + neden" seviyesinde.

## Kısıtlar
- `database_helper.dart` tablo yapıları (`learning_state`, `repetitions`, `interval`) ve `daily_learned_words_YYYY-MM-DD` gibi prefs anahtarları sabit
- `shop_screen.dart` → `_ChestOpeningDialog` / `_RuneSealPainter` / `_ShatterBurstPainter` dokunulmaz
- `flashcards_exercise` dummy şık fallback mantığı bozulmayacak
- `reader_screen` çıkışı `Navigator.pop(context, ReadingSessionResult(...))` ile dönmeye devam edecek (bkz. A-6)
- Renk/spacing değerleri tema token'larından okunacak, ham hex yazılmayacak (T-1 sonrası erişim `BuildContext` üzerinden)
- İkon: yalnızca phosphor. Emoji yok
- Arayüz dili Türkçe
- Gutenberg bilgi banner'ı kalacak — kaldırma önerisi iptal edildi

## Verilmiş kararlar
1. **Header XP:** tüm sekmelerde toplam XP. Sezon XP'si yalnızca Arena'nın sıralama bölümünde, açık "Sezon XP" etiketiyle.
2. **Bot isimleri:** tematik havuza geçildi.
3. **Arka planlar:** sekme başına farklı görsel, iskelet sabit — görsel üst ~180pt header bölgesinde, alta gradient scrim ile `background`'a karışarak. Geometri dört sekmede birebir aynı. Görselleri proje sahibi ekliyor.
4. **Scroll fiziği:** platform varsayılanı. Tek marka istisnası pull-to-refresh göstergesinin amber olması.
5. **Buton hiyerarşisi:** vurgu dolgudan gelir, renkten değil. Dört seviye, ekran başına en fazla bir birincil buton (C-1).
6. **Renk görevleri:** her renk tek işe sabitlenir (C-2). Magenta ve cyan sistemden çıkar.
7. **Tema:** iki tema, kullanıcı elle geçer — Karanlık (Zindan) ve Aydınlık (Parşömen). Sistem teması takibi yok.
8. **Sekme adı:** 3. sekmenin alt bar etiketi **"Arena"** olacak (şu an "Kelimeler"), ekran başlığıyla eşleşecek.

---

## P0 — Görünür kırıklıklar

**P0-A · Lobi'de RenderFlex overflow (yeni)**
"Devam Eden Kitaplar" karuselinin ilk (aktif) kartında `BOTTOM OVERFLOWED BY 1.00 PIXELS` şeridi görünüyor. Başlığa iki satır izni verilince aktif kart — çerçeve + iç padding farkı yüzünden — 1px taşıyor. Kart yüksekliği hâlâ içerikten türetiliyor; sabit yükseklikli tek kart bileşenine geçilmeli, aktif ve pasif kart aynı yüksekliği paylaşmalı.
→ Yayınlanmış üründe görünen Flutter hata şeridi. Bu, daha önce Arena karuselinde kapatılan hatanın Lobi'de tekrarı.

**P0-B · Kitaplık'ta iç içe scroll (eski P1-20, kötüleşti)**
"Kitaplarım (5)" listesi kendi kutusunda kayıyor. Şu anki görünüm: başlık, ardından ~300pt boşluk, ortada tek kitap kartı, altında kesik bir kart, sonra ~170pt daha ölü alan. Sağ kenarda iki ayrı scrollbar görünüyor.
Ekran tek `CustomScrollView` + `SliverList` yapısına geçmeli; iç liste ayrı scroll alanı olmaktan çıkmalı.
→ Kullanıcı kitaplarını göremiyor; ekranın yarısı boş.

**P0-C · Sezon XP verisi doğrulanmalı**
Header 446 (toplam XP) gösteriyor; liderlik tablosu "SEZON XP · haftalık sıfırlanır" başlığı altında Eren'i **yine 446** gösteriyor. Etiket eklendi ama arkasındaki veri ayrışmamış görünüyor.
Kontrol: liderlik satırları ayrı bir sezon sayacından mı besleniyor, yoksa toplam XP'yi mi okuyor? Ayrı değilse sezon sıfırlandığında liderlik 0'a düşecek, header 446'da kalacak — kafa karışıklığı çözülmemiş, ertelenmiş olur.
→ Etiket şu anda doğrulanamayan bir iddia taşıyor.

---

## P1 — Hiyerarşi ve tutarlılık

**P1-2 · Emoji** — Hâlâ duruyor: "Yeni kitap ✨", "Keşfedilmeyi bekliyor ✨", Gutenberg banner'ında 📜, liderlik tablosunda 👑🛡️⚡🦊, "ZİNDANA GİR ⚔", paywall'da 🔒 ve ⚡. Phosphor karşılıklarına geçilecek; liderlikte monokrom mühür/rune avatarı. → Kendi ikon kuralı + platformlar arası şekil farkı + estetik kırılma.

**P1-4 · Magenta ve cyan** — Lobi ve Kitaplık'ta "T" monogramı magenta, "P" mor; Arena pratik listesinde ikon karoları cyan/magenta; Arena ayarları sheet'inde seçili "Tüm Kelimeler" cyan. Hiçbiri beş renklik sistemde yok. → Sistem dışı renk anlamsız sinyal (bkz. C-2).

**P1-8 · Kesilen metinler** — Lobi'de "The Adventures o…", Profil'de "…sadece 31 XP k…", Arena pratik listesinde 5 satırın 5'inde açıklama kesik ("doğru anlam…", "hafız…", "tahtayı te…", "kelime…", "cümlede e…"). Başlıklara 2 satır, açıklamalara 2 satır veya kısaltılmış metin. Sonra ölçekleme testi (A-5 / I-2). → Bugün kesiliyorsa büyük yazıda dağılır.

**P1-12 · Lobi marka kilidi** — Logo + wordmark ≈150pt, ilk ekranın %11'i. Logo ≈40pt, wordmark başlık alanına. → Marka onboarding'in işi, ana ekranın işi bugünün görevi.

**P1-13 · Ana CTA başparmak dışında** — "Derse Başla" üst %30'da. Kahraman kartı kalır; kart görüş alanından çıkınca tab bar üstüne oturan yarı saydam aksiyon çubuğu belirir. → App Store "Get" davranışı.

**P1-14 · Etiketsiz kalkan** — Lobi HUD'unda değer/etiket yok. Durum eklenecek ("Seri koruma: 1") ya da Profil'e taşınacak. → İkon-only öğe bilmece kuruyor.

**P1-15 · "Günlük Durum" pasif** — Metin iyileşti ("Bugün henüz pratik yapmadın…") ama kart hâlâ tıklanabilir değil. Kartın tamamı → Zindan oturumu, chevron eklenecek. → Çekirdek döngüye giden en doğal yol kapalı.

**P1-17 · Profil ayarları eksik** — Görünüm, Satın Alımları Geri Yükle ve Sürüm eklendi. Eksik kalanlar: Premium, Bildirimler, Uygulama dili, Verilerimi sıfırla, Gizlilik/Şartlar. → Kullanıcı bu maddeleri Profil'de arar.

**P1-18 · Undo yok** — Kelime silme / kitap kaldırma / kart sıfırlama geri alınamıyor. Onay diyaloğu yerine aksiyon + 4-5 sn "Geri al" bildirimi; kalıcı silmede onay kalır. → HIG fault tolerance.

**P1-19 · 8pt grid** — Kart boşlukları hâlâ elden geçirilmedi. Tek token seti (`4, 8, 12, 16, 24, 32`). → Tek tek fark edilmiyor, toplamda özensiz.

**P1-11 · Header yeniden yapılandırması** — *(kapsam dışı bırakıldı, kayıt için duruyor)* Tek `ScreenScaffold`, scroll'da küçülen başlık, sabit geometrili görsel alanı + gradient scrim, sekme başına değişen asset.

---

## N — Bu turda ortaya çıkan yeni maddeler

**N-1 · Rozet taksonomisi dağılmış (Arena pratik listesi)**
Tek ekranda altı rozet stili var ve aynı sütunda üç farklı anlam taşıyorlar:

| Rozet | Ne söylüyor |
|---|---|
| `+6 XP`, `+5 XP` | Ödül miktarı |
| `Son 7s 30dk` + `2X XP` | Aciliyet + çarpan (tek satırda iki rozet) |
| `20 Kelime Gerekli` + kilit | Erişim koşulu |
| `ÜCRETSİZ` | Fiyat katmanı |
| `PREMIUM` ×3 | Fiyat katmanı |

Yapılacak: rozet sütununu tek anlama indir (ödül), erişim koşulu ve fiyat katmanını başka bir görsel dile taşı (kilit ikonu + gri satır yeterli).
→ Aynı konumda üç taksonomi, kullanıcının öğrenmesi gereken üç ayrı kural demek.

**N-2 · "PREMIUM" rozeti üç farklı renkte**
Mor, yeşil ve amber olarak çıkıyor. Aynı etiket üç renkteyse kullanıcı üç farklı şey sanır. Tek renge indirilecek.
→ Tek satırlık düzeltme, yüksek etki.

**N-3 · "ÜCRETSİZ" rozeti ters çalışıyor**
Yalnızca "Boşluk Doldurma"da var. Rozetsiz satırlar (Hızlı Test, SRS Hafıza) da ücretsiz ama rozet olmadığı için "demek ki bunlar ücretli" diye okunuyor. Ücretsizi işaretlemek yerine yalnızca premium'u işaretle.

**N-4 · Arena pratik listesinde ikon renkleri semantik değil**
Beş karo, beş renk (cyan, magenta, indigo, teal, emerald). Ekranın tamamı hafıza/pratik alanı olduğu için hepsi indigo ailesinde olmalı; ayrım ton veya ikonla yapılmalı.
→ Uygulamadaki en yoğun renk ihlali artık burası.

**N-5 · İki ekran da "Arena" adını taşıyor**
3. sekmenin başlığı "ARENA", 4. sekmenin başlığı "LİG ARENASI". Karar gereği 3. sekmenin alt bar etiketi "Arena" olacak; bu durumda 4. sekmenin başlığı ayrışmalı (öneri: "SIRALAMA" veya "LİG"), yoksa iki sekme aynı kelimeyle anılır.
→ Kullanıcı "arena" dediğinde hangisini kastettiğini bilemiyor.

**N-6 · "Parşömen" iki farklı şeyin adı**
Hem uygulama aydınlık teması, hem okuyucudaki kilitli bir okuma paleti — biri ücretsiz, biri kilitli. Birini yeniden adlandır.

**N-7 · Dokuz okuma teması, altısı kilitli**
T-7'de üç mod öngörülmüştü. Şu an 9 palet var; Gece/Sepya/Klasik dışındakiler kilitli. Okuma zemini rahatlık ve erişilebilirlik meselesi, kozmetik yükseltme değil — özellikle "OLED Siyah" pil ve göz konforu özelliği.
Yapılacak: üç temel mod ücretsiz kalsın, premium paletler ekstra olarak dursun. Kilitli paletlerde koşul/fiyat görünmeli (şu an sadece kilit ikonu var, premium mi ilerlemeyle mi açıldığı belirsiz).

**N-8 · "Mağaza Paletleri" terimi**
Okuma teması sheet'inin başlığı "Okuma Teması & Mağaza Paletleri". Master Plan'da mağaza kaldırılmıştı, terim geri sızmış.

**N-9 · Arena ayarları sheet'inde iki farklı seçim rengi**
"Tümü" amber, "Tüm Kelimeler" cyan. Aynı sheet, aynı bileşen tipi, iki renk. Seçim durumu tek renk olmalı (amber).

**N-10 · Koleksiyon Vitrini: 22 kilitli gri karo**
Yaklaşan Rozetler'e ilerleme çubuğu eklenmesi iyi olmuş, ama altındaki ızgara hâlâ yedi satırlık gri duvar; hiçbir karo neyle açıldığını söylemiyor.
Yapılacak: kilitli rozetlerde koşulu göster ("10 kitap oku"), ya da ızgarayı "Yakında açılacaklar" (3-4 karo) + "Tümünü gör" şeklinde kısalt.

**N-11 · Okuyucudaki "0 Av" rozeti etiketsiz**
Kısaltma ne anlama geldiğini söylemiyor. "0 kelime avlandı" gibi açık bir ifade veya ikon + sayı + kısa etiket.

**N-12 · "Görünüm" satırı ayrı kartta**
Satın Alımları Geri Yükle ve Sürüm bir kartta, Görünüm tek başına başka kartta. Hepsi aynı gruplu listede olmalı.

**N-13 · Seri 4 gün, okuma 0 dakika, kelime 0** *(ürün mantığı sorusu)*
Kitaplık'ta "4 Seri / 0 Dakika / 0 Kelime / 0 Kart" yan yana duruyor; Lobi ise "Bugün henüz pratik yapmadın" diyor. Seri yalnızca uygulamayı açmakla ilerliyorsa oyunlaştırmanın çekirdeği boşalıyor. Seri koşulunun en az bir tamamlanmış oturuma bağlanması değerlendirilmeli.

---

## C — Renk ve buton sistemi

**C-1 · Buton hiyerarşisi: vurgu dolgudan gelir, renkten değil**

| Seviye | Görünüm | Kullanım | Ekran başına |
|---|---|---|---|
| Birincil | Dolu amber + glow (aydınlık temada glow yerine gölge) | Bir sonraki adım | **en fazla 1** |
| İkincil | `surfaceLight` dolgu + `borderSubtle` çerçeve | Alternatif eylemler | serbest |
| Üçüncül | Sadece metin/ikon + chevron, dolgusuz | Navigasyon, liste satırları | serbest |
| Yıkıcı | Kırmızı, yalnızca onay adımında | Silme | — |

Tek `AppButton` bileşeni + `ButtonLevel` enum; seviye dışı buton üretilmeyecek.
Açık ihlaller: Arena karuselinde iki dolu "AL" butonu yan yana (biri emerald, biri indigo); Kitaplık'ta "Sözlük" ve "Kitap Ekle" aynı ağırlıkta iki dolgulu kart.

**C-2 · Renklerin sabit görevleri**

| Renk | Görev | Nerede |
|---|---|---|
| amber | Eylem ve enerji | Birincil CTA, aktif sekme, XP, seri alevi, seçili segment |
| indigo | Hafıza / bilişsel alan | Kelime kartları, SRS, Zindan, pratik modları, AI Koç |
| teal | Okuma alanı | Kitaplar, okuma süresi, okuma ilerlemesi |
| emerald | Ustalaşma ve başarı | Kalıcı hafıza, rozetler, tamamlandı durumları |
| red | Tehdit ve kayıp | Boss, seri kırılması, yıkıcı eylem |

Magenta, mor ve cyan çıkar. Liderlik tablosunda "Eren (Sen)" satırının indigo çerçevesi de değişmeli — indigo hafıza rengi, "sen" anlamı taşımamalı (amber uygun).

**C-3 · Renk tek başına bilgi taşımaz** — Her renkli öğenin yanında ikon veya metin olmalı. Renk körlüğü + koyu zeminde ton erimesi. Kontrol: ilerleme çubukları, durum rozetleri, liderlik satırları.

**C-4 · Glow bir seviye göstergesi, dekor değil** — Glow yalnızca birincil butonda ve aktif sekme göstergesinde. `enableHeavyGlow` false iken ve parşömen temasında glow yerine gölge + çerçeve.

---

## T — Tema sistemi (Zindan / Parşömen)

**T-1 · Tema mimarisi — önce bu**
Her semantik renk için iki varyant tutan yapı gerekiyor; renkler `ThemeExtension` üzerinden `BuildContext`'ten okunmalı, statik erişim kalkmalı.
**Kritik:** `#F59E0B` açık zeminde 4.5:1 kontrastı geçmiyor; semantik renkler parşömende aynı hex olamaz.
→ Bu madde yapılmadan diğer T maddeleri yapılamaz; C-2 ile aynı dosyalara dokunduğu için birlikte yapılmalı.

**T-2 · Parşömen paleti (taslak, kontrast testiyle son hali alınır)**
- zemin `#F5EFE3`, yüzey `#FDFAF3`, yükseltilmiş yüzey `#FFFFFF`, çerçeve `#E0D6C4`
- metin `#1C1917`, ikincil metin `#57534E`
- amber `#B45309`, indigo `#4338CA`, teal `#0369A1`, emerald `#047857`, red `#B91C1C`
Her biri kendi zemininde 4.5:1 (gövde) / 3:1 (büyük metin ve ikon) eşiğiyle doğrulanacak.

**T-3 · Efekt katmanının tema karşılığı**
glow → yumuşak gölge; cam/blur → opak yüzey + `borderSubtle` çerçeve; neon çerçeve → ince renkli kenar çizgisi. Parşömende derinlik gölge ve çerçeveden gelir, parlaklıktan değil.

**T-4 · Görsel asset'lerin tema varyantları** *(proje sahibinin işi)*
Ignis ve dekoratif görseller şeffaf zeminli olmalı; koyu kontur/gölgeyle çizilmiş haller parşömende kayboluyorsa açık varyant gerekir. Header arka plan görsellerinin de parşömen karşılığı gerekiyor.

**T-5 · `CustomPainter` kodları tema körü**
`_ChestOpeningDialog` / `_RuneSealPainter` / `_ShatterBurstPainter` renkleri gömülü; parşömende koyu kalırlar. İç mantığa dokunmadan renk parametrelerini dışarıdan almaları tercih edilir; mümkün değilse parşömende kendi koyu kartı içinde gösterilmeleri kabul edilebilir ara çözüm.

**T-6 · Tema anahtarı** — *Yapıldı* (Profil > Görünüm, iki seçenekli, sistem seçeneği yok). Kalan: tercihin kalıcılığı ve açılışta ilk karenin doğru temayla çizilmesi doğrulanmalı (açılışta tema sıçraması olmamalı); ayrıca N-12 gruplama düzeltmesi.

**T-7 · Okuyucu modları** — *Yapıldı, kapsam gözden geçirilecek* (bkz. N-7, N-8).

**T-8 · Her iki temada doğrulama**
Videoda Parşömen'e geçilmediği için tema uygulaması henüz doğrulanamadı. Kontrol edilecekler: ilerleme çubukları, disabled buton durumları, placeholder/ikincil metinler, ayırıcı çizgiler, seçili liste satırı, snackbar/undo bildirimi, header arka plan görselleri.

---

## Android

**A-1 · Edge-to-edge** — `targetSdk 35` ile zorunlu. Açılışta edge-to-edge + saydam çubuklar. **Sistem ikonu parlaklığı temaya bağlı:** Zindan'da açık ikon, Parşömen'de koyu ikon; tema değiştiğinde birlikte güncellenecek (T-1).

**A-2 · Alt inset cihazdan** — Jest çubuğu / 3 tuşlu navigasyon (≈48dp) / tam ekran. Sabit sayı yok; iki navigasyon moduyla da test.

**A-3 · Dokunma hedefi 48** — iOS 44, Material 48; 48'de birleş. Kontrol: chevron'lar, karusel içi butonlar, HUD pill'leri, segmented control seçenekleri.

**A-4 · 360dp genişlik** — Tüm yatay sığdırma kararları 360'ta doğrulanacak. Özellikle Kitaplık'taki 4'lü stat şeridi (şu an 393pt'de sığıyor, 360'ta kontrol edilmedi) ve Arena ayarlarındaki 4'lü kart limiti segmenti.

**A-5 · Font scale 2.0** — Android %200'e çıkıyor, 14+ doğrusal olmayan ölçekleme. Test tavanı 2.0. → P1-8 bu tavanda çözülmeli.

**A-6 · Predictive back / sistem geri** — `WillPopScope` → `PopScope`. Kritik: **reader_screen'de sistem geri tuşuyla çıkışta da `ReadingSessionResult` dönmeli**; aynı kontrol flashcards ve word boss oturumlarında. Ayrıca yeni eklenen bottom sheet'ler (Okuma Teması, Arena Pratik Ayarları, Paywall) geri tuşuyla kapanmalı, ekranı terk etmemeli. → Veri kaybı hatası.

**A-7 · Blur maliyeti** — `DevicePerformanceTier` low'da blur tamamen kapanacak; yerine opak `surfaceLight` + 1px `borderSubtle`. Aynı yedek görünüm parşömende her cihazda kullanılır (T-3), iki yol tek koddan beslenmeli.

**A-8 · Scroll fiziği** — Platform varsayılanı. `ScrollConfiguration` ile platforma bırakılacak; marka payı yalnızca amber pull-to-refresh.

**A-9 · Adaptif bileşenler** — Cupertino switch/slider/dialog kullanılan yerler `Switch.adaptive`, `showAdaptiveDialog` ve platform sayfa geçişine çevrilecek. Yeni eklenen Geliştirici Test Modu toggle'ı ve okuma boyutu slider'ı bu kapsamda.

**A-10 · `POST_NOTIFICATIONS`** — Android 13+ runtime izni. Seri hatırlatması eklenecekse önce gerekçe ekranı, reddedilirse tekrar sorma, Profil > Bildirimler'den açma yolu.

---

## iOS

**I-1** Dokunma hedefi 44 (A-3'teki 48 ile otomatik karşılanır); içerik kenar boşluğu 16.
**I-2** Dynamic Type test tavanı 1.3 — P1-8 burada doğrulanacak.
**I-3** Kenardan geri jestiyle reader/flashcards çıkışında da `ReadingSessionResult` dönmeli (A-6'nın iOS karşılığı).
**I-4** Home indicator `viewPadding.bottom`'dan; sabit 34 yazılmayacak.
**I-6** Seri kazanma / kelime ustalaşma / ders bitişinde hafif haptik; tek kod yolundan.
**I-7** Status bar ikon rengi temaya bağlanacak (A-1'in iOS karşılığı).

---

## Paylaşılan altyapı

1. `PlatformTokens` — `minTapTarget`, `bottomInset`, `scrollPhysics`, `blurEnabled`. Ekranlar buradan okur.
2. `Spacing` — `4, 8, 12, 16, 24, 32` (P1-19)
3. `BookCard` — sabit yükseklikli kitap kartı, aktif/pasif aynı geometride (P0-A)
4. `MemberAvatar` — phosphor monokrom, emoji yerine (P1-2)
5. `AppButton` + `ButtonLevel` — dört seviyeli buton (C-1)
6. `AppBadge` — tek anlamlı rozet bileşeni; varyant sayısı sınırlı (N-1, N-2, N-3)
7. `AppTheme` / `ThemeExtension` — her semantik renk için Zindan + Parşömen varyantı, context üzerinden (T-1)
8. `Elevation` — glow / gölge / çerçeve eşlemesini temaya ve `enableHeavyGlow`'a göre veren tek kaynak (C-4, T-3, A-7)
9. `UndoSnack` — geri alınabilir aksiyon (P1-18)
10. `SegmentedControl` — tek seçim rengi (amber), tüm sheet'lerde ortak (N-9)

---

## Kabul kriterleri

**Ortak**
- [ ] Hiçbir ekranda overflow şeridi yok (Lobi karuseli dahil)
- [ ] Kitaplık tek scroll alanı; başlık ile kartlar arasında boşluk yok, altta ölü alan yok
- [ ] Liderlik satırları gerçek sezon sayacından besleniyor
- [ ] Emoji yok; tüm ikonlar phosphor
- [ ] Magenta, mor ve cyan hiçbir yerde yok
- [ ] Varsayılan boyutta metin kesilmesi yok
- [ ] Silme/sıfırlamada undo var
- [ ] Alt bar 3. sekme "Arena"; 4. sekme başlığı ayrışmış

**Renk ve buton (C)**
- [ ] Her ekranda en fazla bir birincil buton
- [ ] Tüm butonlar `AppButton` üzerinden; seviye dışı buton yok
- [ ] Beş rengin her biri tek görevde
- [ ] Rozet sütunu tek anlam taşıyor; PREMIUM tek renkte
- [ ] Hiçbir bilgi yalnızca renkle taşınmıyor
- [ ] Glow yalnızca birincil buton ve aktif sekmede

**Tema (T)**
- [ ] Renkler context üzerinden okunuyor; statik renk erişimi kalmadı
- [ ] Parşömende gövde metni 4.5:1, büyük metin ve ikon 3:1 geçiyor
- [ ] Parşömende hiçbir yerde glow yok
- [ ] Ignis ve dekoratif görseller parşömen zeminde doğru duruyor
- [ ] Tema tercihi kalıcı; açılışta tema sıçraması yok
- [ ] Status/navigation bar ikon rengi temayla değişiyor
- [ ] İki temada kontrol edildi: ilerleme çubukları, disabled butonlar, placeholder metinler, ayırıcılar, seçili satır, undo bildirimi
- [ ] Okuyucuda üç temel mod ücretsiz; kilitli paletlerde koşul görünüyor

**Android**
- [ ] Edge-to-edge kurulu, içerik sistem çubukları altında kalmıyor
- [ ] Jest **ve** 3 tuşlu navigasyonla test edildi
- [ ] 360dp'de taşma yok
- [ ] Font scale 2.0'da okunabilir
- [ ] Sistem geri tuşuyla reader çıkışında oturum sonucu kaydediliyor
- [ ] Bottom sheet'ler geri tuşuyla kapanıyor, ekranı terk etmiyor
- [ ] Low tier'da blur kapalı, 60fps'e yakın

**iOS**
- [ ] Dynamic Type 1.3'te bozulma yok
- [ ] Kenardan geri jestiyle reader çıkışında oturum sonucu kaydediliyor
- [ ] Dokunma hedefleri ≥44

---

## Sıra

1. **P0:** P0-A (Lobi overflow), P0-B (Kitaplık iç scroll), P0-C (sezon XP verisi)
2. **Tema + renk altyapısı birlikte:** T-1, T-2, T-3, C-2, C-4 — aynı dosyalara dokundukları için tek geçişte
3. **Buton ve rozet sistemi:** C-1, C-3, N-1, N-2, N-3, N-4, N-9 → `AppButton`, `AppBadge`, `SegmentedControl`
4. **Adlandırma ve terim temizliği:** N-5, N-6, N-8, N-11
5. **Emoji ve ikon temizliği:** P1-2
6. **Hiyerarşi:** P1-12, P1-13, P1-14, P1-15, N-10, N-12
7. **Profil tamamlama:** P1-17, P1-18
8. **Platform mekanikleri:** A-6, A-7, A-1, I-7
9. **Erişilebilirlik ve iki temada geçiş:** P1-8, P1-19, A-5, I-2, T-8
10. **Asset varyantları** *(proje sahibi)*: T-4, T-5
11. **Ürün kararı:** N-13 (seri koşulu)

Her adım sonunda 360dp Android + 393pt iPhone genişliğinde, **iki temada birden** görsel kontrol.

---

## Yayın öncesi kontrol

- [ ] Geliştirici Test Modu release build'de derlenmiyor (`kDebugMode` / ayrı flavor) — geliştirme sırasında kalması planlandı, mağaza build'ine girmemeli
- [ ] Paywall'da fiyat görünüyor veya RevenueCat satın alma ekranına yönlendiriliyor
- [ ] Profil'de Satın Alımları Geri Yükle çalışıyor
- [ ] Gizlilik politikası ve kullanım şartları bağlantıları mevcut
