# Ejderha Rotası V2 — Faz 8: Test, Kademeli Yayınlama & İzleme

Bu faz kod değil süreç fazı: Faz 1-7'de yapılan değişikliklerin gerçek cihazda kırılmadığını doğrulamak, riski azaltacak şekilde yayınlamak ve yayından sonra sorunları erken yakalamak için bir kontrol listesi.

## 1. Regresyon Test Kontrol Listesi (Faz 1-7'ye özel)

Her madde, o fazda değişen koda karşılık geliyor — rastgele bir "genel test" değil, tam olarak neyin kırılabileceğine odaklı.

### Faz 1 — Elmas Ekonomisi Kaldırma
- [ ] Alt navigasyon 5 sekme: Ana Sayfa, Dersler, Kelimeler, İlerleme, Profil (Mağaza/Diğer yok)
- [ ] Hiçbir ekranda elmas rozeti/sayacı görünmüyor (Lobi, Kitaplık, Kelimeler/Arena, Profil, Liderlik)
- [ ] Arena'daki 3 mikro görevin ödülü yalnızca XP (elmas yok), ödül alma (`AL` butonu) çalışıyor ve XP doğru ekleniyor
- [ ] `xp_shop_service.dart`'taki `@Deprecated` gem metodlarını çağıran hiçbir yeni kod yok (derleme uyarısı olarak görünür)

### Faz 2 — RevenueCat / Paywall
- [ ] Uygulama açılışta çökmüyor (`EntitlementRepository.instance.init()` başarısız olsa bile try/catch ile yutuluyor)
- [ ] `RevenueCatConfig`'e gerçek Android/iOS API anahtarları ve `premiumEntitlementId` girildi mi? (girilmeden mağaza akışı test edilemez)
- [ ] Kalkan yokken (Kitaplık, Profil, Alışkanlık Takipçisi ekranlarındaki `PaywallTrigger` sarmalı rozetler) dokununca merkezi paywall açılıyor
- [ ] Premium satın alındıktan sonra `isPremiumNotifier` güncelleniyor ve kilitli özellikler anında açılıyor (ekranı yeniden açmaya gerek kalmadan)
- [ ] Premium kullanıcı için `streak_freeze_service.dart`'taki kalkan asla düşmüyor

### Faz 3 — Yerel Veri & FSRS
- [ ] **Kritik**: v15'ten v16'ya yükseltme testi — eski bir APK/build'den (fsrs_* kolonları olmadan) güncelleme yapıldığında `_onUpgradeDB` çöküyor mu, yoksa kolonlar sorunsuz ekleniyor mu? (Gerçek cihazda eski sürümü kurup üstüne yeni sürümü yükleyerek test edilmeli — emülatörde temiz kurulum bunu YAKALAMAZ.)
- [ ] "Zindana Gir" ana butonu Karma Mod'u açıyor, mod dağılımı gerçekten rastgele (arka arkaya 5-6 kelime deneyip aynı modun art arda gelmediğini gözlemle)
- [ ] Karma Mod'da her üç soru tipi de (Hızlı Test, Eşleştirme, Dinle & Yaz) doğru çalışıyor, çeldiriciler anlamlı
- [ ] Karma Mod sonrası hem V1 sisteminin (`learning_state`, `interval`) hem FSRS'in (`fsrs_due_at`, `fsrs_stability`) güncellendiğini veritabanından doğrula
- [ ] Vadesi gelen kart yokken (`FsrsRepository.getDueCards()` boş) eski `_cards` havuzuna sorunsuz düşüyor
- [ ] Alttaki 4 manuel mod butonu (Hızlı Test, SRS Hafıza, Eşleştirme, Dinle&Yaz) eskisi gibi çalışıyor

### Faz 4 — Kitaplık Sadeleştirmesi
- [ ] İnce bilgi bandındaki tüm sayılar (dalış süresi, keşfedilen, havuzdaki kelime, seri) doğru
- [ ] Kompakt kitap kartlarında ilerleme yüzdesi ve keşif/usta sayıları doğru, "oynat" butonu okuyucuyu açıyor
- [ ] Kalkan rozeti paywall'ı tetikliyor (Faz 2 ile aynı davranış, sadece görünüm değişti)

### Faz 5 — Arena Odaklılık
- [ ] Yatay kaydırılabilir görev kartları düzgün kaydırılıyor, taşma yok
- [ ] "AL" butonu, kilit ve tamamlandı ikonları doğru durumlarda gösteriliyor
- [ ] Liderlik tablosu (yükselme/düşme hatları dahil) hiç bozulmadı

### Faz 6 — Minimal Profil
- [ ] Isı haritası ve eski sekme seçici artık YOK, başarılar bölümü her zaman görünür
- [ ] Ayarlar tarzı istatistik listesindeki 4 satır doğru ekranlara yönlendiriyor
- [ ] Avatara dokununca çerçeve popup'ı açılıyor; Premium değilken kilitli çerçeveye dokununca paywall açılıyor, satın alma sonrası popup yeniden açılıp seçim yapılabiliyor; Premium'da çerçeve seçimi anında uygulanıyor ve aktif çerçeve avatarda görünüyor

### Faz 7 — AI Koç
- [ ] Supabase Edge Function deploy edildi, `ai_coach_config.dart`'a gerçek URL/anon key girildi (`AiCoachConfig.isConfigured == true`)
- [ ] Yapılandırma eksikken ekran çökmüyor, anlamlı uyarı mesajı gösteriyor
- [ ] Ücretsiz kullanıcı günlük 5 mesaj sonra kota uyarısı/paywall görüyor; gece yarısı geçince (`_todayKey()` tarih değişince) kota sıfırlanıyor
- [ ] Premium kullanıcı "Sınırsız" rozetini görüyor, kota kontrolüne takılmıyor
- [ ] Ana Sayfa'daki "AI Koç Ignis'e sor" bandı sohbet ekranını açıyor

## 2. Kademeli Yayınlama (Staged Rollout)

Yerel-öncelikli mimari sayesinde geri dönüşü zor bir sunucu migrasyonu yok — asıl risk **veritabanı şema yükseltmesi (v15→v16)** ve **paywall'ın yanlış kilitlemesi**. Buna göre:

1. **Dahili test (kapalı)**: Kendi cihazında + varsa 1-2 güvendiğin kullanıcıda, gerçek eski veriyle (temiz kurulum değil, üstüne yükleme) test et. Faz 3'teki migrasyon maddesi özellikle burada doğrulanmalı.
2. **Play Console / App Store Console kademeli yayın**: Google Play "staged rollout" (%5 → %20 → %50 → %100) veya iOS'ta "phased release" kullan — ilk yüzdede yalnızca crash/ANR oranını izle, en az 24-48 saat bekle.
3. **Geri alma planı**: Eğer v16 migrasyonunda kritik bir hata çıkarsa, bir sonraki acil sürümde `_onUpgradeDB`'ye düzeltici bir `if (oldVersion < 17)` bloğu eklenir — asla v16 bloğunu geriye dönük değiştirme (zaten yükselmiş kullanıcılarda tekrar çalışmaz).
4. **RevenueCat sandbox testi**: Gerçek mağazaya göndermeden önce RevenueCat'in sandbox modunda satın alma/iade/restore akışlarını test et — Premium'un yanlışlıkla herkese açık kalması ya da hiç açılmaması en yüksek gelir riski.

## 3. İzleme (Monitoring)

Şu anda projede bir crash/hata izleme SDK'sı entegre değil. Faz 8'in önerdiği minimum kurulum:

1. **Crash & ANR izleme**: Firebase Crashlytics (öneri — zaten Firebase ekosistemine yakın, Supabase ile birlikte kullanılabilir) veya Sentry Flutter SDK'sı ekle. Kurulum tek seferlik: `pubspec.yaml`'a paket eklenir, `main()` içinde `runZonedGuarded` + `FlutterError.onError` ile sarılır.
2. **Özellikle izlenmesi gerekenler**:
   - `database_helper.dart` → `_onUpgradeDB` içindeki `catch (_) {}` bloklarını loglamaya çevir (şu an sessizce yutuluyor) — migrasyon hatası sessiz kalırsa fark edilmez.
   - `AiCoachRepository.sendMessage` içindeki `catch` — Edge Function hataları (502, timeout) sıklığını izle, LLM maliyet/kötüye kullanım sinyali olabilir.
   - `EntitlementRepository` içindeki `Purchases` SDK hataları — Premium doğrulamasının sessiz başarısız olması doğrudan gelir kaybı demek.
3. **Supabase tarafı**: Edge Function loglarını (`supabase functions logs ai-coach`) haftalık gözden geçir; anormal istek hacmi/kötüye kullanım belirtisi ararsan Edge Function'a basit bir IP/istek-sayısı rate limiti eklemek gelecekte düşünülebilir (şu an yok — mimari gereği sunucu tarafında kullanıcı kimliği yok).
4. **Analytics (opsiyonel ama önerilir)**: Hangi özelliklerin kullanıldığını görmek için basit bir olay izleme (Firebase Analytics veya PostHog) — özellikle Karma Mod kullanım oranı ve AI Koç günlük aktif kullanıcı sayısı, bir sonraki geliştirme önceliklerini belirlemede işe yarar.

## 4. Yayın Öncesi Son Kontrol

- [ ] `flutter analyze` sıfır hata/uyarı ile temiz
- [ ] Gerçek cihazda (emülatör değil) tam bir kullanıcı akışı: kitap oku → kelime keşfet → Zindana gir (Karma Mod) → Arena'da görev tamamla → Profil'de çerçeve dene → AI Koç'a soru sor
- [ ] `pubspec.yaml` sürüm numarası (`version: 1.0.0+1`) artırıldı
- [ ] RevenueCat, Supabase ve (varsa) Crashlytics/Sentry API anahtarları hepsi PLACEHOLDER değil, gerçek değerlerle dolu
