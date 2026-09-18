# Draconic Lingua — UI/UX Düzeltme Listesi (iOS + Android)

Kaynak: Lobi / Kitaplık / Arena / Profil ekran görüntüleri üzerinden HIG + Material uyum analizi.
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

## Verilmiş kararlar (tartışmaya açık değil)
1. **Header XP:** tüm sekmelerde toplam XP. Sezon XP'si yalnızca Arena'nın sıralama bölümünde, açık "Sezon XP" etiketiyle.
2. **Bot isimleri:** geliştirme sırasında mevcut haliyle kalabilir; proje sahibi dışında birinin göreceği ilk build'den önce değişecek (TestFlight + Play internal/closed test dahil).
3. **Arka planlar:** sekme başına farklı görsel kullanılacak, iskelet sabit kalacak — görsel yalnızca üst ~180pt header bölgesinde, alta gradient scrim ile `background`'a karışarak; scroll alanının arkasında görsel yok. Geometri dört sekmede birebir aynı. Görselleri proje sahibi kendisi ekliyor, kodlayan taraf yalnızca çerçeveyi kurar.
4. **Scroll fiziği:** platform varsayılanı. Marka vurgusu scroll'da aranmayacak; tek istisna pull-to-refresh göstergesinin amber olması.
5. **Buton hiyerarşisi:** vurgu dolgudan gelir, renkten değil. Dört seviye, ekran başına en fazla bir birincil buton (C-1).
6. **Renk görevleri:** her renk tek işe sabitlenir, uygulamanın tamamında (C-2). Magenta sistemden çıkar.
7. **Tema:** iki tema, kullanıcı elle geçer — **Karanlık (zindan)** ve **Aydınlık (parşömen)**. Sistem teması takibi ve üçüncü seçenek yok. Aydınlık tema jenerik beyaz değil, parşömen/antik kütüphane yorumu: karanlık tema dünyanın gecesi, aydınlık tema aynı dünyanın gündüzü (T bölümü).

---

## P0 — Görünür kırıklıklar

**P0-1 · Alt bar içeriği kesiyor** (Profil, Arena, Lobi)
Profil'de "Yaklaşan Rozetler" ilk satırı, Arena'da 5. sıra, Lobi'de "Günlük Seri" kartı tab bar altında yarım kalıyor. Scroll view alt padding'i = bar yüksekliği + `viewPadding.bottom` + 16, cihazdan okunacak.
→ Kullanıcı listenin bittiğini sanıyor.

**P0-2 · Arena karuselinde RenderFlex overflow**
"Mikro-Meydan Okumalar" üçüncü kartında kırmızı overflow şeridi ekranda. Kart yüksekliği içerikten türetildiği için en uzun içerik (uzun başlık + buton) taşıyor. Sabit genişlik/yükseklikli tek kart bileşeni, buton alanı dibe sabit.
→ Yayınlanmış üründe görünen Flutter hata şeridi.

**P0-3 · Türkçe uppercase**
"KITAPLIK" → KİTAPLIK, "LIG ARENASI" → LİG ARENASI. `toUpperCase()` locale-agnostic, `i → I` üretiyor. `i → İ` dönüşümünü uppercase'den önce yapan extension, tüm caps başlıklarda.
→ Hata tam olarak en çok bakılan yerde.

**P0-4 · XP pill'i iki metrik gösteriyor**
`app_header.dart`: Lobi/Kitaplık/Profil'de 396 (toplam), Arena'da 150 (sezon). Aynı ikon, aynı form. **Karar: header her sekmede toplam XP gösterir**, Arena dahil.
Bağlı iş: Arena sıralama satırları sezon XP'si gösteriyor (sen 150, Seydihan 130). Header toplam XP'ye sabitlenince aynı ekranda 396 ve 150 yan yana durmaya devam eder — bu yüzden sıralama bölümüne "Sezon XP" başlığı/etiketi eklenmesi bu maddenin parçası. Etiket eklenmezse karışıklık çözülmemiş, sadece yer değiştirmiş olur.
→ 396 → 150 geçişi "XP'm gitti" olarak okunuyor.

**P0-5 · Profil ile Arena çelişiyor**
Profil: "#2. Sırada, Seydihan'ı geçmek için 31 XP". Arena: kullanıcı #1, 150 XP (Seydihan 130). Profil bayat önbellek okuyor. Tek kaynak; eşitlenemezse Profil'den sıra/XP farkı kaldırılıp sadece Arena girişi bırakılır.
→ Çelişen iki sayı ikisinin de güvenilirliğini siliyor.

**P0-6 · Bot isimleri**
Arena sıralamasında "Zenci" (ırkçı hakaret) ve "Çinli" var. Havuz tamamen değişecek, Ignis evreninden tematik isimler, tek sabit listede.
**Zamanlama:** yerel geliştirmede mevcut haliyle kalabilir. Sınır yayın değil, **proje sahibi dışında birinin göreceği ilk build** — TestFlight ve Play internal/closed test dahil. Bir tester ekran görüntüsü paylaştığında geri dönüşü yok.
→ App Store + Play ret riski.

**P0-7 · Ignis rozeti kapatıyor**
Sezon kartında ejderha "#1. Sıra" pill'inin üstünde ve rozet kart kenarından taşıyor. Ejderha arka plana düşük opaklıkta, ya da rozet sol tarafa.
→ Dekoratif katman bilgi katmanının üstünde.

---

## P1 — Hiyerarşi ve tutarlılık

**P1-1 · Amber enflasyonu** — Kitaplık'ta her kitap satırında parlak amber play butonu. Amber yalnızca aktif kitapta kalır (birincil), diğer satırlar üçüncül seviyeye iner (chevron). Kural C-1'de. → Ana CTA rengi dağıtılınca vurgu ölüyor.

**P1-2 · Emoji** — Kitap avatarları (🎨🍇🍸) ve Arena avatarları (🛡️👑⚡🦊🎯). Phosphor tabanlı monokrom mühür/rune avatarına geçilecek. → Kendi ikon kuralı + platformlar arası şekil farkı + estetik kırılma.

**P1-3 · Kitap kimliği ikiye ayrılmış** — Lobi'de harf monogramı (T/P/T), Kitaplık'ta emoji. Tek `BookCover` (monogram + kitaba deterministik atanan palet rengi). → Aynı kitap iki ekranda tanınmıyor.

**P1-4 · Palet kayması** — Lobi monogramlarında ve Profil ikon karolarında magenta var, sistemde yok. Magenta çıkıyor; renklerin sabit görevleri C-2'de tanımlı. → Sistem dışı renk anlamsız sinyal.

**P1-5 · Profil satır yüksekliği** — ~86pt. iOS gruplu liste 44–60, Material 56–72. Dikey padding düşecek. → 4 satır için scroll ediliyor.

**P1-6 · Kitaplık istatistik şeridi** — 4 sütun × ~82pt; etiketler 2 satıra kırılıyor, kart yüksekliği eşitlenmemiş. 2×2 grid veya tek satır özet (`1 gün · 0 dk · 0 kelime · 0 kart`). → 360dp'de kesin taşıyor (A-4).

**P1-7 · Sıfır duvarı** — Lobi'de 0/5 + 0 yeni + üç kitapta %0; Kitaplık'ta 4 istatistikten 3'ü 0; Profil'de %0. Değer 0 iken sayı yerine davet varyantı ("İlk kelimeni avla"). → İlk oturum, kalma kararının verildiği yer.

**P1-8 · Kesilen metinler** — Varsayılan boyutta 4 kesilme: "The Adventures o…", "…sadece 31 XP k…", "Odaklı Ç… Seansı", "Devam ediyor" yarım. Başlıklara 2 satır, tek satıra sığmayan açıklamalar kart içine. Sonra ölçekleme testi (A-5 / I-2). → Bugün kesiliyorsa büyük yazıda dağılır.

**P1-9 · Şifreli meta** — "Mark Twain · %0 · 🧠4 ⭐0" → "%0 okundu · 4 kart". → MVP testlerinde çıkan bilişsel yükün tipik örneği.

**P1-10 · Gutenberg banner'ı** — Kalıcı yer tutuyor; "Kitap Ekle" akışına veya ekran altı dipnota. → Her açılışta okunmayan metin listeyi aşağı itiyor.

**P1-11 · Header: sabit iskelet, değişken görsel** — Şu an her sekmede ikon + caps başlık + alt başlık + pill ≈ 110pt chrome; Profil'de arkada zindan görseli `y≈150`'de keskin dikişle bitiyor, diğerlerinde düz zemin.
Kurulacak yapı: tek `ScreenScaffold`, scroll'da küçülen başlık, arkada `Stack`'in en alt katmanında ~180pt yüksekliğinde görsel alanı + alta doğru `background` rengine giden `LinearGradient` scrim. **Bu geometri (yükseklik, scrim eğrisi, başlık konumu, padding) dört sekmede birebir aynı; yalnızca görsel asset'i sekmeye göre parametre olarak gelir.** Scroll edilen içerik alanının arkasında görsel yok.
İkinci ayrışma katmanı (ücretsiz): her sekme kendi semantik rengini vurgu tonu olarak alır — Kitaplık emerald, Kelimeler indigo, Arena amber, Profil teal.
Kontrast: her görsel farklı parlaklık dağılımına sahip olduğu için scrim opaklığı asset başına ayarlanabilir olmalı; başlık metni her sekmede okunur kalmalı.
→ Sekme değişirken içerik değişir, yapı değişmez. Dört ayrı iskelet dört ayrı uygulama hissi verir.

**P1-12 · Lobi marka kilidi** — Logo + wordmark ≈150pt, ilk ekranın %11'i. Logo ≈40pt, wordmark başlık alanına, scroll'da küçülme. → Marka onboarding'in işi, ana ekranın işi bugünün görevi.

**P1-13 · Ana CTA başparmak dışında** — "Derse Başla" üst %30'da. Kahraman kartı kalır; kart görüş alanından çıkınca tab bar üstüne oturan yarı saydam aksiyon çubuğu belirir. → App Store "Get" davranışı.

**P1-14 · Etiketsiz kalkan** — Lobi HUD'unda değer/etiket yok. Durum eklenecek ("Seri koruma: 1") ya da Profil'e taşınacak. → İkon-only öğe bilmece kuruyor.

**P1-15 · "Günlük Durum" pasif** — 25 bekleyen tekrar çekirdek döngü ama kart tıklanabilir görünmüyor. Kartın tamamı → Zindan oturumu, chevron eklenecek. → Aksiyona dönüşmeyen sayı gürültü.

**P1-16 · Kod karışımı** — "Mastered Words Vitrini" → "Kalıcı Hafıza"; açıklama kısalacak ("4 kelimeden 0'ı kalıcı hafızada"). → Türkçe arayüz kararıyla çelişiyor.

**P1-17 · Profil "Ayarlar" olmayı tamamlamamış** — İstatistikler üstte kompakt blok; altına Premium, Bildirimler, Uygulama dili, Verilerimi sıfırla, **Satın alımları geri yükle**, Gizlilik/Şartlar, Sürüm. → Master Plan'daki iOS Ayarlar hedefi; geri yükleme App Store zorunluluğu.

**P1-18 · Undo yok** — Kelime silme / kitap kaldırma / kart sıfırlama geri alınamıyor. Onay diyaloğu yerine aksiyon + 4-5 sn "Geri al" bildirimi (aksiyon çubuğunun üstünde); kalıcı silmede onay kalır. → HIG fault tolerance: kontrol vermek > her adımda izin istemek.

**P1-19 · 8pt grid kayması** — Kart boşlukları 12/14/20 arasında geziniyor. Tek token seti (`4, 8, 12, 16, 24, 32`). → Tek tek fark edilmiyor, toplamda özensiz.

**P1-20 · İç içe scroll** — Kitaplık'ta kitap listesi ayrı scroll alanı gibi: 4. kart tepeden yarım, altta büyük boşluk. Ekran tek sliver yapıya. → İçerik sonu yanlış gösteriliyor.

---

## C — Renk ve buton sistemi

Mevcut sorunun kaynağı: beş renk aynı anda iki iş yapıyor — hem anlam taşıyor (başarı, bilgi, tehlike) hem kategori/dekor görevi görüyor (Profil'deki dört renkli ikon karosu, kitap monogramlarının rastgele renkleri). Bir renk iki iş yapınca kullanıcı hiçbirini öğrenemiyor. İkinci sorun: butonlarda hiyerarşi yok, sadece renk var — Kitaplık'ta beş parlak amber daire, Arena'da dolu indigo "AL", Lobi'de glow'lu ana CTA; hepsi dolu ve parlak olduğu için hepsi birincil görünüyor.

**C-1 · Buton hiyerarşisi: vurgu dolgudan gelir, renkten değil**

| Seviye | Görünüm | Kullanım | Ekran başına |
|---|---|---|---|
| Birincil | Dolu amber + glow (aydınlık temada glow yerine gölge) | Bir sonraki adım | **en fazla 1** |
| İkincil | `surfaceLight` dolgu + `borderSubtle` çerçeve, normal metin rengi | Alternatif eylemler | serbest |
| Üçüncül | Sadece metin/ikon + chevron, dolgusuz | Navigasyon, liste satırları | serbest |
| Yıkıcı | Kırmızı, yalnızca onay adımında | Silme | — |

Tek `AppButton` bileşeni + `ButtonLevel` enum. Seviye dışı buton üretilmeyecek.
Uygulama sonuçları: Kitaplık'taki beş amber daire → aktif kitapta birincil, diğerleri üçüncül (P1-1). Arena karuselindeki "AL" kendi kartı bağlamında birincil kalabilir, çünkü o kartta tek eylem o. Lobi'de "Derse Başla" ekranın tek birincil butonu.
→ Her şey birincil görünürse kullanıcı nereden başlayacağını seçemiyor.

**C-2 · Renklerin sabit görevleri**

Her renk uygulamanın tamamında **tek** iş yapar:

| Renk | Görev | Nerede |
|---|---|---|
| amber | Eylem ve enerji | Birincil CTA, aktif sekme, XP, seri alevi |
| indigo | Hafıza / bilişsel alan | Kelime kartları, SRS, Zindan, AI Koç |
| teal | Okuma alanı | Kitaplar, okuma süresi, okuma ilerlemesi |
| emerald | Ustalaşma ve başarı | Kalıcı hafıza, rozetler, tamamlandı durumları |
| red | Tehdit ve kayıp | Boss, seri kırılması, yıkıcı eylem |

Magenta ve sistem dışı tüm renkler çıkar. Kazanç: Profil'deki ikon karoları rastgele renk olmaktan çıkıp **navigasyon kodu** haline geliyor — "Okuma Süresi" teal, "Kelime Havuzu" indigo, "Koleksiyon" emerald, "Seri" amber — ve aynı renkler Lobi istatistiklerinde, Kitaplık şeridinde, Zindan'da da aynı kalıyor. Kullanıcı üçüncü oturumda rengi görüp okumadan ne olduğunu biliyor.
→ Renk bu uygulamada dekor değil, dil.

**C-3 · Renk tek başına bilgi taşımaz**
Her renkli öğenin yanında ikon veya metin olmalı. Gerekçe iki katlı: renk körlüğü (erkeklerde ~%8) ve bu kadar koyu bir zeminde ton farklarının erimesi. Özellikle ilerleme çubukları, durum rozetleri ve liderlik tablosu satırları kontrol edilecek.

**C-4 · Glow bir seviye göstergesi, dekor değil**
Şu an glow birden çok yerde. Kural: glow yalnızca birincil butonda ve aktif sekme göstergesinde. `enableHeavyGlow` false iken (düşük performanslı cihaz) ve aydınlık temada glow yerine gölge + çerçeve kullanılır.
→ Her yerde glow varsa glow hiçbir şey söylemiyor.

---

## T — Tema sistemi (Karanlık / Aydınlık)

Karar: iki tema, kullanıcı elle geçer, sistem teması takip edilmez. Aydınlık tema jenerik beyaz değil **parşömen** — antik el yazması / eski kütüphane. Böylece aydınlık mod "markanın kapatılmış hali" değil, aynı dünyanın ikinci yüzü oluyor.

**T-1 · Tema mimarisi — önce bu, sonra diğer T maddeleri**
Tek renk seti yerine **her semantik renk için iki varyant** tutan bir yapı gerekiyor. `DraconicTheme` bugün sabit hex'ler veriyor; bunun `ThemeExtension` (veya eşdeğeri) üzerinden `BuildContext`'ten okunan bir yapıya dönmesi gerekiyor. Ekranlar `DraconicTheme.primaryAmber` gibi statik erişim yerine context üzerinden okuyacak.
**Kritik:** `#F59E0B` açık zeminde 4.5:1 kontrastı geçmiyor. Semantik renkler aydınlık temada aynı hex olamaz, koyulaştırılmış varyant şart.
→ Bu madde yapılmadan diğer T maddeleri yapılamaz; C-2 ile birlikte tek seferde kurulmalı.

**T-2 · Parşömen paleti (başlangıç değerleri, kontrast testiyle son hali alınır)**
- zemin `#F5EFE3`, yüzey `#FDFAF3`, yükseltilmiş yüzey `#FFFFFF`, çerçeve `#E0D6C4`
- metin `#1C1917`, ikincil metin `#57534E`
- amber `#B45309`, indigo `#4338CA`, teal `#0369A1`, emerald `#047857`, red `#B91C1C`
Not: bunlar taslak; her biri kendi zemininde 4.5:1 (gövde metni) / 3:1 (büyük metin ve ikon) eşiğiyle doğrulanacak.

**T-3 · Efekt katmanının tema karşılığı**
Karanlık temanın derinliği glow ve blur'dan geliyor; aydınlık temada ikisi de çalışmıyor — glow açık zeminde kir gibi görünür.
Eşleme: glow → yumuşak gölge; cam/blur → opak yüzey + `borderSubtle` çerçeve; neon çerçeve → ince renkli kenar çizgisi.
Katman hissi aydınlık temada **gölge ve çerçeveden** gelir, parlaklıktan değil.
→ Aynı bileşen iki temada aynı hiyerarşiyi vermeli, aynı efektle değil.

**T-4 · Görsel asset'lerin tema varyantları** *(proje sahibinin işi, kod değil)*
Ignis ve dekoratif görseller şeffaf zeminli olmalı, yoksa aydınlık temada koyu kutu içinde durur. Ignis'in koyu kontur/gölge ile çizilmiş halleri parşömen zeminde kayboluyorsa açık tema varyantı gerekir.
Header arka plan görselleri de aynı durumda — her sekmenin görselinin aydınlık karşılığı gerekiyor (header yapısı bu turda değişmiyor, ama asset planı bunu kapsamalı).
→ Tema geçişinin en pahalı kalemi kod değil, illüstrasyon.

**T-5 · `CustomPainter` kodları tema körü**
Sandık açılışı, rune mührü ve parçalanma animasyonları (`_ChestOpeningDialog`, `_RuneSealPainter`, `_ShatterBurstPainter`) dokunulmaz listesinde ve renkleri büyük ihtimalle gömülü. Aydınlık temada koyu kalırlar.
Yaklaşım: painter'ların iç mantığına dokunmadan yalnızca renk parametrelerini dışarıdan alacak şekilde ele alınması — mümkün değilse aydınlık temada bu animasyonların koyu bir yüzey üzerinde (kendi koyu kartı içinde) gösterilmesi kabul edilebilir ara çözüm.
V2'de mağaza kalktığı için etki alanı küçük; ödül animasyonları başka yerde kullanılacaksa bu madde büyür.

**T-6 · Tema anahtarının yeri ve davranışı**
Profil > Görünüm altında iki seçenekli segmented control: **Zindan (Karanlık)** / **Parşömen (Aydınlık)**. Sistem seçeneği yok.
Tercih `shared_preferences`'ta saklanır (yeni anahtar; mevcut anahtarlara dokunulmaz). Uygulama açılışında ilk kare doğru temayla çizilmeli — açılışta karanlıktan aydınlığa sıçrama olmamalı.
Geçiş anında yumuşak renk animasyonu (~200ms) kullanılır, sert sıçrama değil.
Varsayılan: Karanlık.

**T-7 · Okuyucu ekranı ayrı ele alınır**
`reader_screen` uzun metin okuma ekranı ve uygulama temasından bağımsız kendi zemin seçimine sahip olmalı: Karanlık / Sepya / Aydınlık.
Gerekçe: parlak ortamda gözbebeği küçülür, koyu zemindeki ince metin bulanıklaşır — güneş altında koyu zeminde okumak fiziksel olarak zor. Kindle ve Apple Books bu yüzden ayrı okuma modu veriyor.
Okuyucu zemini uygulama temasını takip edebilir ama kullanıcı ayrıca değiştirebilmeli; bu tercih de ayrı anahtarda saklanır.

**T-8 · Her iki temada doğrulama**
Tema eklemek, mevcut her ekranı iki kere kontrol etmek demek. Özellikle: ilerleme çubukları, devre dışı (disabled) buton durumları, placeholder/ikincil metinler, ayırıcı çizgiler, seçili liste satırı, snackbar/undo bildirimi. Bunlar tek temada tasarlandığında diğerinde tipik olarak kayboluyor.

---

## Android

**A-1 · Edge-to-edge** — `targetSdk 35` ile zorunlu: sistem çubukları içeriğin üstüne biniyor. Açılışta edge-to-edge + saydam çubuklar kurulacak. **Sistem ikonu parlaklığı temaya bağlı:** karanlık temada açık ikon, parşömen temada koyu ikon — sabit yazılmayacak, tema değiştiğinde birlikte güncellenecek (T-1). → Kurulmazsa P0-1'in daha ağır hali; tema ile bağlanmazsa aydınlık temada saat ve pil görünmez olur.

**A-2 · Alt inset cihazdan** — Jest çubuğu / 3 tuşlu navigasyon (≈48dp) / tam ekran. Sabit sayı yok; iki navigasyon moduyla da test. → 3 tuşlu cihazda sabit değer bir satır daha yiyor.

**A-3 · Dokunma hedefi 48** — iOS 44, Material 48. Tek sayıda birleş: 48 ikisini de karşılıyor. Kontrol: chevron'lar, karusel içi butonlar, HUD pill'leri.

**A-4 · 360dp genişlik** — iPhone tabanı 375–393, Android'de 360 yaygın. Tüm yatay sığdırma kararları 360'ta doğrulanacak; P1-6 burada tercih değil ihtiyaç.

**A-5 · Font scale 2.0** — Android %200'e çıkıyor, 14+ doğrusal olmayan ölçekleme. Test tavanı 2.0 (iOS 1.3). → P1-8 bu tavanda çözülmeli.

**A-6 · Predictive back / sistem geri** — `WillPopScope` → `PopScope`. Kritik: **reader_screen'de sistem geri tuşuyla çıkışta da `ReadingSessionResult` dönmeli**; aynı kontrol flashcards ve word boss oturumlarında. → Aksi halde dakika/kelime/XP kaybı. Bu bir veri kaybı hatası, P0 gibi ele alınmalı.

**A-7 · Blur maliyeti** — `BackdropFilter` Android orta/alt segmentte iOS'tan belirgin pahalı. `DevicePerformanceTier` low'da blur **tamamen kapanacak**, sigma azaltmakla yetinilmeyecek; yerine opak `surfaceLight` + 1px `borderSubtle`. Aynı yedek görünüm parşömen temasında her cihazda kullanılır (T-3), yani bu iki yol tek koddan beslenmeli. → Yarım blur hem bulanık hem yavaş.

**A-8 · Scroll fiziği — karar verildi: platform varsayılanı** — Android stretch, iOS bounce. `ScrollConfiguration` ile platforma bırakılacak, hiçbir yerde bounce zorlanmayacak. Marka payı tek yerde: pull-to-refresh göstergesi amber. → Kullanıcı scroll hissini markaya değil kaliteye atfediyor; Android'de bounce "kötü port edilmiş" olarak okunur. Marka algısı renk, tipografi, Ignis ve kendi bileşen animasyonlarında (XP sayacı, seri alevi, sandık açılışı) yaşıyor.

**A-9 · Adaptif bileşenler** — Cupertino switch/slider/dialog kullanılan yerler `Switch.adaptive`, `showAdaptiveDialog` ve platform sayfa geçişine çevrilecek. → Görsel kimlik platformdan bağımsız, mekanik platforma ait.

**A-10 · `POST_NOTIFICATIONS`** — Android 13+ runtime izni. Seri hatırlatması eklenecekse önce gerekçe ekranı, reddedilirse tekrar sorma, Profil > Bildirimler'den açma yolu. → Bağlamsız istek reddedilir, ikinci şans yok.

---

## iOS

**I-1** Dokunma hedefi 44 (A-3'teki 48 ile otomatik karşılanır); içerik kenar boşluğu 16.
**I-2** Dynamic Type test tavanı 1.3 — P1-8 burada doğrulanacak.
**I-3** Kenardan geri jestiyle reader/flashcards çıkışında da `ReadingSessionResult` dönmeli (A-6'nın iOS karşılığı).
**I-4** Home indicator `viewPadding.bottom`'dan; sabit 34 yazılmayacak.
**I-5** "Satın alımları geri yükle" (P1-17 içinde) — App Store zorunluluğu.
**I-6** Seri kazanma / kelime ustalaşma / ders bitişinde hafif haptik; tek kod yolundan, Android'de de çalışır.
**I-7** Status bar ikon rengi temaya bağlanacak (A-1'in iOS karşılığı): karanlık temada açık, parşömen temada koyu.

---

## Paylaşılan altyapı (listenin çoğunu tek yerden çözer)

1. `PlatformTokens` — `minTapTarget`, `bottomInset`, `scrollPhysics`, `blurEnabled` (performans tier ile birlikte). Ekranlar buradan okur; `Platform.isAndroid` kontrolü dağılmaz.
2. `Spacing` — `4, 8, 12, 16, 24, 32` (P1-19)
3. `ScreenScaffold` — tek başlık + scroll + alt inset davranışı (P0-1, P1-11)
4. `BookCover` — monogram + deterministik palet rengi (P1-3)
5. `MemberAvatar` — phosphor monokrom, emoji yerine (P1-2)
6. `StatStrip` / `StatTile` — eşit yükseklik, 2×2 ↔ tek satır modu (P1-6)
7. `ChallengeCard` — sabit boyutlu karusel kartı (P0-2)
8. `TrCase` extension — Türkçe uppercase (P0-3)
9. `UndoSnack` — geri alınabilir aksiyon (P1-18)
10. `EmptyStateVariant` — 0 değerinde davet gösteren istatistik (P1-7)
11. `AppButton` + `ButtonLevel` — dört seviyeli buton (C-1); seviye dışı buton üretilmez
12. `AppTheme` / `ThemeExtension` — her semantik renk için karanlık + parşömen varyantı, context üzerinden okunur (T-1). Statik `DraconicTheme.x` erişimleri buraya taşınır
13. `Elevation` — glow / gölge / çerçeve eşlemesini temaya ve `enableHeavyGlow`'a göre veren tek kaynak (C-4, T-3, A-7)
14. `ThemeController` — tema tercihi, `shared_preferences` kalıcılığı, açılışta ilk kareyi doğru temayla çizme (T-6)

---

## Kabul kriterleri

**Ortak**
- [ ] Alt bar hiçbir ekranda içeriği kesmiyor; son kart ile bar arası ≥16
- [ ] Hiçbir yerde overflow şeridi yok
- [ ] KİTAPLIK / LİG ARENASI doğru
- [ ] Header XP pill'i her sekmede toplam XP; Arena sıralaması "Sezon XP" etiketli
- [ ] Profil sırası = Arena sırası
- [ ] Header görsel alanının yüksekliği/scrim'i/padding'i dört sekmede aynı; yalnızca asset değişiyor
- [ ] Her sekmede header başlığı arka plan görselinin üzerinde okunur
- [ ] Hiçbir yerde bounce fiziği zorlanmıyor; pull-to-refresh amber
- [x] Bot isimleri arasında etnik/kimlik temelli isim yok — ✅ 18.09.2026, `leaderboard_screen.dart` + `profile_screen.dart` (bkz. `yayin_oncesi_kontrol_listesi.md`)
- [ ] Dekoratif görsel hiçbir bilgi öğesini kapatmıyor
- [ ] Amber tek ana aksiyonda
- [ ] Emoji yok; tüm ikonlar phosphor
- [ ] Aynı kitap her ekranda aynı görünüyor
- [ ] Tema dışı renk ve ham hex yok
- [ ] Varsayılan boyutta metin kesilmesi yok
- [ ] 0 değerli istatistikler davet gösteriyor
- [ ] Silme/sıfırlamada undo var

**Renk ve buton (C)**
- [ ] Her ekranda en fazla bir birincil buton var
- [ ] Tüm butonlar `AppButton` üzerinden; seviye dışı buton yok
- [ ] Beş rengin her biri tek görevde; magenta hiçbir yerde yok
- [ ] Profil ikon karolarının renkleri Lobi ve Kitaplık'taki aynı kavramlarla eşleşiyor
- [ ] Hiçbir bilgi yalnızca renkle taşınmıyor (ikon/metin eşlik ediyor)
- [ ] Glow yalnızca birincil buton ve aktif sekmede

**Tema (T)**
- [ ] Renkler context üzerinden okunuyor; statik renk erişimi kalmadı
- [ ] Parşömen temada gövde metni 4.5:1, büyük metin ve ikon 3:1 geçiyor
- [ ] Parşömen temada hiçbir yerde glow yok; derinlik gölge ve çerçeveden geliyor
- [ ] Ignis ve dekoratif görseller parşömen zeminde doğru duruyor
- [ ] Tema anahtarı Profil > Görünüm'de, iki seçenekli, tercih kalıcı
- [ ] Uygulama açılışında tema sıçraması yok (ilk kare doğru temada)
- [ ] Status/navigation bar ikon rengi temayla birlikte değişiyor
- [ ] İki temada da kontrol edildi: ilerleme çubukları, disabled butonlar, placeholder metinler, ayırıcılar, seçili satır, undo bildirimi
- [ ] Okuyucuda Karanlık / Sepya / Aydınlık seçilebiliyor, tercih kalıcı

**Android**
- [ ] Edge-to-edge kurulu, içerik sistem çubukları altında kalmıyor
- [ ] Jest **ve** 3 tuşlu navigasyonla test edildi
- [ ] 360dp'de taşma yok
- [ ] Font scale 2.0'da okunabilir
- [ ] Sistem geri tuşuyla reader çıkışında oturum sonucu kaydediliyor
- [ ] Low tier'da blur kapalı, 60fps'e yakın
- [ ] Bildirim izni gerekçeli (özellik eklendiyse)

**iOS**
- [ ] Dynamic Type 1.3'te bozulma yok
- [ ] Kenardan geri jestiyle reader çıkışında oturum sonucu kaydediliyor
- [ ] Profil'de satın alımları geri yükle var
- [ ] Dokunma hedefleri ≥44

---

## Sıra

1. **Tema + renk altyapısı birlikte:** `AppTheme`/`ThemeExtension`, `Elevation`, C-2 renk görevleri → T-1, T-2, T-3, C-2, C-4. Karanlık tema görünümü bu adımda değişmez; yalnızca renkler statik erişimden context'e taşınır ve parşömen varyantı tanımlanır.
   *Neden önce:* C-2 ve T-1 aynı dosyalara dokunuyor. Ayrı yapılırsa tüm ekranlar iki kez elden geçer.
2. **Platform altyapısı:** `PlatformTokens`, `Spacing`, `TrCase`, `ScreenScaffold` → P0-1, P0-3, P1-19, A-1, A-2, A-3
   *(P1-11 header yeniden yapılandırması bu turda kapsam dışı; `ScreenScaffold` yalnızca scroll + alt inset davranışını üstlenir.)*
3. **Veri kaybı ve performans:** A-6, A-7
4. **Kalan P0:** P0-2, P0-4, P0-5, P0-6, P0-7
5. **Buton hiyerarşisi:** `AppButton` + `ButtonLevel`, tüm ekranların butonları geçirilir → C-1, C-3, P1-1
6. **Bileşen birleştirme:** P1-2, P1-3, P1-6, P1-9
7. **Hiyerarşi:** P1-7, P1-12, P1-13, P1-15, P1-20
8. **Profil + tema anahtarı:** P1-5, P1-16, P1-17, P1-18, I-5, T-6
9. **Okuyucu modları:** T-7
10. **Erişilebilirlik ve iki temada geçiş:** P1-8, A-5, I-2, T-8, I-7
11. **Asset varyantları** *(proje sahibi)*: T-4, T-5

Her adım sonunda 360dp Android + 393pt iPhone genişliğinde görsel kontrol. 1. adımdan sonra her kontrol **iki temada birden** yapılır.
