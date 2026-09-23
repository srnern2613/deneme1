// ============================================================================
// DOSYA ADI: lib/main.dart
// AÇIKLAMA: Ignis (Draconic Lingua markası) - Boşluğu Alınmış Büyük Logo ve
// Kontrastlı İlerleme Barları (Tam Kod)
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/auth/auth_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/theme_controller.dart';
import 'core/entitlement/entitlement_repository.dart';
import 'core/storage/book_storage_service.dart';
import 'database_helper.dart';
import 'book_model.dart';
import 'default_books.dart';
import 'library_screen.dart';
import 'flashcards_screen.dart';
import 'reader_screen.dart';
import 'habit_tracker_screen.dart';
import 'profile_screen.dart';
import 'leaderboard_screen.dart';
import 'xp_shop_service.dart';
import 'streak_freeze_service.dart';
import 'ai_coach_screen.dart';
import 'core/coach/ignis_moments_engine.dart';
import 'ignis_moment_dialog.dart'; // Faz F: Duolingo tarzı seri-kaybı pop-up'ı
import 'core/design_system/platform_tokens.dart';
import 'core/design_system/primitives.dart'; // BookCover (P1-3)
import 'core/theme/draconic_theme.dart'; // T-1: Lobi yapısal renkleri temadan
import 'core/branding/app_branding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Hesap Sistemi — Firebase. google-services.json eklenmeden bu satır hata
  // fırlatır. BİLEREK ayrı bir try/catch içinde: aşağıdaki asıl servis
  // başlatma zincirini (kitaplar/XP/entitlement/tema) bu yüzden atlamak
  // istemiyoruz — Firebase kurulana kadar sadece hesap özellikleri
  // (Giriş Yap/Kayıt Ol) çalışmaz, uygulamanın geri kalanı etkilenmez.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase başlatma hatası (google-services.json eksik olabilir): $e');
  }

  try {
    await DefaultBooksManager.seedDefaultBooksIfNeeded();
    await XpShopService.instance.init();
    // Ejderha Rotası V2 — Faz 2: RevenueCat entitlement katmanı. Uygulama
    // her açılışta bunu önce kurmalı ki PaywallTrigger'lar doğru premium
    // durumuyla render edilsin.
    await EntitlementRepository.instance.init();
    // UI/UX Düzeltme Listesi — T-6: tema tercihi runApp'ten ÖNCE yüklenmeli
    // ki ilk kare doğru temayla çizilsin (açılışta karanlık→aydınlık
    // sıçraması olmasın).
    await ThemeController.instance.init();
  } catch (e) {
    debugPrint('Servis başlatma hatası: $e');
  }

  // Edge-to-edge: Android'in alt 3-tuş/gesture navigasyon şeridi artık
  // ayrı, kopuk bir gri/beyaz bant gibi durmasın diye sistem çubuklarının
  // ARKASINA çiziyoruz (Android 15/SDK 35 hedefleyen uygulamalarda zaten
  // zorunlu olan davranış). Gerçek kontroller/içerik hâlâ MediaQuery
  // insets'iyle (bkz. PlatformTokens.scrollBottomPadding, SafeArea) güvenli
  // bölgede tutuluyor — burada sadece ARKA PLAN sistem çubuklarının altından
  // geçiyor.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // NOT: Sistem çubuğu ikon parlaklığı/rengi artık burada SABİT
  // ayarlanmıyor — tema (Zindan/Parşömen) her değiştiğinde MyApp.build()
  // içinde yeniden uygulanıyor (bkz. aşağıdaki AnimatedBuilder), açılış
  // dahil ilk kare de oradan doğru temayla çizilir.

  runApp(const MyApp());

  // P0-D — Açılış performansı optimizasyonu: aşağıdaki iki iş İLK KARENİN
  // içeriğini/doğruluğunu HİÇBİR şekilde etkilemiyordu (hesap bağlantısını
  // geri yükleme sadece Profil'deki hesap rozetini ilgilendiriyor; bildirim
  // kurulumu/izin isteği hiçbir ekranın görünümünü değiştirmiyor) ama yine de
  // runApp()'tan ÖNCE, sırayla await ediliyorlardı — bu da özellikle
  // "Seri Kaybı Uyarısı" için Android 13+ izin diyaloğunun kullanıcı DAHA
  // İLK KAREYİ bile görmeden açılmasına sebep oluyordu (kötü UX) ve genel
  // açılış süresini uzatıyordu. Artık runApp()'tan SONRA, ilk kare zaten
  // ekrandayken arka planda çalışıyorlar — davranışları/sonuçları birebir
  // aynı, sadece kullanıcıyı bekletmiyorlar.
  unawaited(_runDeferredStartupTasks());
}

/// Bkz. yukarıdaki not — ilk karenin doğruluğu için gerekli OLMAYAN, ama
/// uygulamanın geri kalanında (Ayarlar/Profil, zamanlanmış bildirimler)
/// gerekli olan başlangıç işleri. Kendi try/catch'i var ki burada oluşacak
/// bir hata (ör. bildirim izni reddi) ana başlatma akışını etkilemesin.
Future<void> _runDeferredStartupTasks() async {
  try {
    // Zaten oturum açık bir hesap varsa (uygulama yeniden açıldıysa)
    // RevenueCat kimliğini tekrar o hesaba bağla.
    await AuthService.instance.restoreAccountLinkIfNeeded();
    // Ayarlar → Bildirimler: bildirim eklentisini kur ve kullanıcının daha
    // önce kaydettiği tercihlere göre (varsa) zamanlanmış hatırlatmaları
    // yeniden kur. Bu, reboot sonrası Android'in temizlediği alarmları da
    // telafi eder (bkz. NotificationService dosya başı notu).
    await NotificationService.instance.init();
    final prefs = await SharedPreferences.getInstance();
    final dailyReminderEnabled = prefs.getBool('notif_daily_reminder_enabled') ?? false;
    final streakLossAlertEnabled = prefs.getBool('notif_streak_loss_enabled') ?? true;
    // "Seri Kaybı Uyarısı" varsayılan olarak AÇIK geliyor — kullanıcı hiç
    // Ayarlar'ı açmasa bile bu bildirimi alabilsin diye, Android 13+ izni
    // burada, uygulamanın ilk açılışında bir kez istenir. Kullanıcı isterse
    // Ayarlar → Bildirimler'den anahtarı kapatıp izni reddedebilir.
    if (dailyReminderEnabled || streakLossAlertEnabled) {
      await NotificationService.instance.requestPermission();
    }
    await NotificationService.instance.rearmFromPrefs(
      dailyReminderEnabled: dailyReminderEnabled,
      reminderHour: prefs.getInt('notif_reminder_hour') ?? 20,
      reminderMinute: prefs.getInt('notif_reminder_minute') ?? 0,
      streakLossAlertEnabled: streakLossAlertEnabled,
    );
  } catch (e) {
    debugPrint('Ertelenmiş başlatma işi hatası: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // UI/UX Düzeltme Listesi — T-6: tema artık ThemeController'dan (Karanlık/
  // Zindan ↔ Aydınlık/Parşömen, kullanıcı elle geçer, sistem teması takip
  // edilmez) besleniyor. _toggleTheme, ThemeController.instance.toggle()'ı
  // çağırıp AnimatedBuilder ile tüm MaterialApp'i yeniden çiziyor — ekranlar
  // hâlâ kendi ham hex'lerini kullandığı için bu turda GÖRÜNÜR bir değişiklik
  // yaratmaz (bkz. Sıra 1'in notu), ama anahtarın kendisi artık gerçek.
  void _toggleTheme() {
    HapticFeedback.lightImpact();
    ThemeController.instance.toggle();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final draconicTheme = ThemeController.instance.current;

        // Gerçek cihaz testinde: (1) durum çubuğu ikonları temaya bakmadan
        // hep "açık/light" kalıyordu — Parşömen'in krem zemininde neredeyse
        // görünmez oluyordu; (2) alt Android navigasyon şeridi varsayılan
        // opak rengiyle uygulamanın arka planından kopuk, ayrı bir bant gibi
        // duruyordu. Tema her değiştiğinde (bu builder yeniden çalıştığında)
        // ikisini de aktif DraconicTheme'e göre yeniden uyguluyoruz.
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: draconicTheme.isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: draconicTheme.isDark ? Brightness.dark : Brightness.light, // iOS
            systemNavigationBarColor: draconicTheme.background,
            systemNavigationBarIconBrightness: draconicTheme.isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
        );

        return MaterialApp(
          title: 'Ignis',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: draconicTheme.isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: draconicTheme.background,
            extensions: <ThemeExtension<dynamic>>[
              draconicTheme,
            ],
          ),
          themeMode: draconicTheme.isDark ? ThemeMode.dark : ThemeMode.light,
          home: RootScreen(onToggleTheme: _toggleTheme),
        );
      },
    );
  }
}

class RootScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const RootScreen({super.key, required this.onToggleTheme});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _currentIndex = 0; 
  
  final GlobalKey<_DashboardScreenState> _dashboardKey = GlobalKey<_DashboardScreenState>();
  // BUG DÜZELTMESİ: FlashcardsScreenState ayrı dosyada ve private
  // (_FlashcardsScreenState) olduğu için buradan tip olarak referans
  // verilemiyor; State<FlashcardsScreen> ile tutup çağrıda dynamic cast
  // kullanıyoruz (aynı _dashboardKey deseninin bu sınırlama içindeki hâli).
  final GlobalKey<State<FlashcardsScreen>> _flashcardsKey = GlobalKey<State<FlashcardsScreen>>();
  // P0-5: Arena ve Profil de IndexedStack ile canlı tutuluyordu, aynı
  // "sekmeye dönünce tazelenmiyor" bug'ı bu ikisinde de vardı — Profil'in
  // kendi lig/rank hesaplaması Arena'nınkiyle aynı anda güncellenmediği için
  // birbirinden bayat kalabiliyordu (P0-5). LeaderboardScreenState private
  // olduğu için flashcards ile aynı desen (State<T> + dynamic cast); Profil
  // için public ProfileScreenState kullanılabiliyor.
  final GlobalKey<State<LeaderboardScreen>> _leaderboardKey = GlobalKey<State<LeaderboardScreen>>();
  final GlobalKey<ProfileScreenState> _profileKey = GlobalKey<ProfileScreenState>();
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(
        key: _dashboardKey,
        // Ejderha Rotası V2 — Faz 1: Mağaza sekmesi kalktı; "mağazaya git"
        // kısayolları artık Profil sekmesine yönlendiriyor (Seri Koruma vb.
        // haklar Faz 2'den itibaren Premium/PaywallTrigger üzerinden sunulacak).
        onNavigateToShop: () => _onTabTapped(4),
        onNavigateToLibrary: () => _onTabTapped(1),
        onNavigateToFlashcards: () => _onTabTapped(2),
      ),
      const LibraryScreen(),
      FlashcardsScreen(
        key: _flashcardsKey,
        onNavigateToLibrary: () => _onTabTapped(1),
        onNavigateToShop: () => _onTabTapped(4),
      ),
      LeaderboardScreen(key: _leaderboardKey),
      ProfileScreen(key: _profileKey),
    ];
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentIndex = index;
    });
    if (index == 0) {
      _dashboardKey.currentState?.refreshDashboardStats();
    } else if (index == 2) {
      // BUG DÜZELTMESİ: IndexedStack bu sekmeyi canlı tuttuğu için yeni
      // eklenen kelimeler/kilit sayaçları tazelenmiyordu (bkz.
      // flashcards_screen.dart refreshCardsAndStats yorumu).
      (_flashcardsKey.currentState as dynamic)?.refreshCardsAndStats();
    } else if (index == 3) {
      // P0-5: Arena'ya her dönüşte lig/XP verisi tazelensin.
      (_leaderboardKey.currentState as dynamic)?.refreshLeagueData();
    } else if (index == 4) {
      // P0-5: Profil'e her dönüşte rank/XP farkı tazelensin — Arena'yla
      // aynı anda güncel kalmaları garanti değil (ayrı simulatedLeague
      // kopyaları hâlâ var) ama en azından ikisi de "son ziyaret" kadar
      // taze olur, tab arası geçişte gözle görülür çelişki azalır.
      _profileKey.currentState?.refreshProfileData();
    }
  }

  @override
  Widget build(BuildContext context) {
    // T-1: alt bar 5 sekmenin hepsinde ortak — tema burada değişince tüm
    // uygulamada tek noktadan değişiyor.
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Scaffold(
      backgroundColor: theme.background,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.background,
          border: Border(top: BorderSide(color: theme.borderSubtle, width: 1)),
        ),
        child: BottomNavigationBar(
          backgroundColor: theme.background,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          selectedItemColor: theme.primaryAmber,
          unselectedItemColor: theme.textMuted,
          // Parşömen (aydınlık) temaya geçildiğinde sekme isimlerinin
          // okunaksız kalmaması için rengi burada da AÇIKÇA belirtiyoruz —
          // sadece selected/unselectedItemColor'a güvenmek yerine.
          selectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: theme.primaryAmber),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: theme.textMuted),
          items: const [
            BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(PhosphorIcons.compassBold)), label: 'Ana Sayfa'),
            BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(PhosphorIcons.bookOpenBold)), label: 'Dersler'),
            // Karar #8: bu sekmenin ekran başlığı zaten "Arena" (flashcards_screen)
            // — alt bar etiketi de eşleşsin.
            BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(PhosphorIcons.swordBold)), label: 'Arena'),
            // Ertelenen tasarım kararı — Arena/İlerleme adlandırma netliği:
            // bu sekmenin ekranı (leaderboard_screen.dart) kendi başlığını
            // zaten "Sıralama" olarak kullanıyordu ama alt bar etiketi hâlâ
            // "İlerleme" kalmıştı — ekrana girince başlığın değişmesi kafa
            // karıştırıyordu. Artık ikisi de "Sıralama"; "Arena" (pratik/
            // dövüş) ile "Sıralama" (lig/rank) artık net şekilde ayrışıyor.
            BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(PhosphorIcons.chartBarBold)), label: 'Sıralama'),
            BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(PhosphorIcons.userBold)), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToShop;
  final VoidCallback onNavigateToLibrary;
  final VoidCallback onNavigateToFlashcards;

  const DashboardScreen({
    super.key,
    required this.onNavigateToShop,
    required this.onNavigateToLibrary,
    required this.onNavigateToFlashcards,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _todayLearnedCards = 0;
  int _dailyTargetCards = 5;
  int _currentStreak = 7;
  int _totalReadMinutes = 0;
  bool _isLoading = true;
  List<Book> _userBooks = [];
  Book? _activeBook;
  // AŞAMA 4 — Ana Sayfa "Günlük Durum" kartı: Ignis Anları'nın kalıcı, sessiz
  // versiyonu. Popup beklemeden her zaman güncel istatistik gösterir.
  IgnisDailyStatus? _dailyStatus;

  // P1-13: "Derse Başla" hero kartı scroll'da görünürlükten çıkınca,
  // tab bar üstüne oturan yarı saydam bir aksiyon çubuğu belirir
  // (App Store "Get" davranışı) — böylece CTA başparmak menzili dışına
  // düşse bile her zaman erişilebilir kalır.
  final ScrollController _scrollController = ScrollController();
  bool _showStickyCta = false;

  // Hero öneri karuseli: kullanıcıya göre dinamik kartlar. Aşağıdaki iki
  // sayaç kartlardan hangilerinin gösterileceğine karar veriyor.
  final PageController _heroPageController = PageController();
  int _heroPage = 0;
  int _bossCount = 0;
  int _dueReviewCount = 0;

  @override
  void initState() {
    super.initState();
    refreshDashboardStats();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > 380;
    if (shouldShow != _showStickyCta) {
      setState(() => _showStickyCta = shouldShow);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _heroPageController.dispose();
    super.dispose();
  }

  void _onStartLessonTap() {
    if (_activeBook != null) {
      _openReaderDirectly(_activeBook!);
    } else {
      widget.onNavigateToFlashcards();
    }
  }

  Future<void> refreshDashboardStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      
      final streakResult = await StreakFreezeService.instance.checkAndUpdateStreak();
      // Faz F: seri gerçekten kırıldıysa (kalkan da yoksa) Duolingo tarzı
      // "üzgün Ignis" pop-up'ı — günde en fazla 1 kez (bkz.
      // IgnisMomentsEngine._prefsLastStreakLossDateKey).
      final streakLossMoment = await IgnisMomentsEngine.instance.getStreakLossMoment(streakResult);
      final todayKey = _getTodayKey();
      
      final learnedToday = prefs.getInt('daily_learned_words_$todayKey') ?? 0;
      final target = prefs.getInt('active_daily_word_target') ?? 5;
      final readMins = prefs.getInt('stats_total_read_minutes') ?? 0;

      // Faz F2: seri kaybı anıyla AYNI frame'de iki pop-up birden açılmasın
      // diye — seri kaybı önceliklidir, o yoksa günlük hedef anına bakılır.
      final IgnisMoment? dailyGoalMoment = streakLossMoment == null
          ? await IgnisMomentsEngine.instance.getDailyGoalCompletedMoment(
              learnedToday: learnedToday,
              target: target,
            )
          : null;
      // Elmas/XP artık uygulamanın tek gerçek kaynağı olan XpShopService
      // üzerinden okunuyor (diğer 6 ekranla birebir aynı kaynak ve
      // ValueNotifier'lar) — eskiden burada kullanılan 'gems_balance' /
      // 'total_xp' anahtarları hiçbir yerde yazılmıyordu, bu yüzden Lobi
      // diğer ekranlarla senkron değildi.
      await XpShopService.instance.getGemsBalance();
      await XpShopService.instance.getTotalXp();
      final dailyStatus = await IgnisMomentsEngine.instance.getDailyStatusSnapshot();

      // Hero öneri karuseli için — biri başarısız olsa bile Lobi'nin geri
      // kalanı yüklenmeye devam etsin diye ayrı ayrı korunuyor.
      int bossCount = 0;
      int dueReviewCount = 0;
      try {
        bossCount = await DatabaseHelper.instance.getActiveBossCount();
      } catch (_) {}
      try {
        dueReviewCount = await DatabaseHelper.instance.getDueTodayCount();
      } catch (_) {}

      // AŞAMA 1: kitap sayfa metni artık book_content.db'de (Android Auto
      // Backup kotası dışında); BookStorageService bunu şeffaf birleştirir.
      List<Book> parsedBooks = await BookStorageService.loadBooks();
      parsedBooks.sort((a, b) {
        final dateA = a.lastReadDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.lastReadDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      if (!mounted) return;
      setState(() {
        _currentStreak = streakResult['streakDays'] ?? (prefs.getInt('current_streak_days') ?? 7);
        _todayLearnedCards = learnedToday;
        _dailyTargetCards = target;
        _totalReadMinutes = readMins;
        _userBooks = parsedBooks;
        _activeBook = parsedBooks.isNotEmpty ? parsedBooks.first : null;
        _dailyStatus = dailyStatus;
        _bossCount = bossCount;
        _dueReviewCount = dueReviewCount;
        _isLoading = false;
      });

      // Faz F: setState'ten SONRA, bir sonraki frame çizildikten sonra
      // gösteriliyor — build sırasında dialog açmaya çalışmak hataya yol
      // açar. mounted kontrolü hem burada hem callback içinde tekrarlanıyor
      // çünkü addPostFrameCallback asenkron bir aralıkta çalışıyor.
      if (streakLossMoment != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          IgnisMomentDialog.show(
            context,
            pose: streakLossMoment.pose,
            title: streakLossMoment.title,
            message: streakLossMoment.message,
            primaryLabel: 'Yeniden Başla 💪',
          );
        });
      } else if (dailyGoalMoment != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          IgnisMomentDialog.show(
            context,
            pose: dailyGoalMoment.pose,
            title: dailyGoalMoment.title,
            message: dailyGoalMoment.message,
            primaryLabel: 'Harika, Devam! 🔥',
          );
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _openHabitTracker() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const HabitTrackerScreen()),
    ).then((_) => refreshDashboardStats());
  }

  Future<void> _openReaderDirectly(Book book) async {
    HapticFeedback.selectionClick();
    await Navigator.push<ReadingSessionResult>(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(
          book: book,
          onPageChanged: (newPage) {
            book.currentPage = newPage;
            book.lastReadDate = DateTime.now();
          },
        ),
      ),
    );
    refreshDashboardStats();
  }

  // P1-3: kitap monogramı/rengi artık core/design_system/primitives.dart'taki
  // paylaşılan BookCover widget'ından geliyor (Kitaplık'la aynı mantık).
  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  // AŞAMA 4 — "Günlük Durum" kartı: Apple tarzı sade istatistik satırı.
  // Ignis Anları'ndaki (getSessionEndMoment) AYNI veri kaynağını kullanır
  // ama günde-1-kez kısıtı yok — her zaman güncel durumu gösterir.
  Widget _buildIgnisDailyStatusCard() {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    final status = _dailyStatus;
    final hasActivity = status?.hasActivityToday ?? false;

    // P1-15: kart artık pasif değil — dokununca zindan/pratik akışına götürüyor
    // (hero CTA'nın kullandığı aynı callback).
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onNavigateToFlashcards,
        borderRadius: BorderRadius.circular(18),
        child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceDark.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/mascot/ignis_avatar_badge.png',
                  width: 20,
                  height: 20,
                  fit: BoxFit.cover,
                  // P0-D: kaynak dosya 2MB'ın üzerinde (yüksek çözünürlüklü);
                  // cacheWidth/cacheHeight vermeden Flutter tam çözünürlükte
                  // decode edip sonra 20x20'ye küçültüyordu — her açılan
                  // ekranda gereksiz onlarca MB'lık bellek/CPU maliyeti.
                  cacheWidth: (20 * MediaQuery.of(context).devicePixelRatio).round(),
                  cacheHeight: (20 * MediaQuery.of(context).devicePixelRatio).round(),
                  errorBuilder: (context, error, stackTrace) => const Icon(PhosphorIcons.sparkleBold, color: Color(0xFFFDE68A), size: 16),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'GÜNLÜK DURUM',
                style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w800, color: theme.textMuted, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasActivity)
            Text(
              'Bugün henüz pratik yapmadın. Bir seans tamamla, Ignis ilerlemeni burada gösterecek.',
              style: GoogleFonts.inter(fontSize: 12.5, color: theme.textSecondary, height: 1.4),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _buildDailyStatusStat(
                    icon: PhosphorIcons.sparkleBold,
                    color: theme.successEmerald,
                    value: '${status!.newWordsToday}',
                    label: 'Yeni Kelime',
                  ),
                ),
                Expanded(
                  child: _buildDailyStatusStat(
                    icon: PhosphorIcons.arrowClockwiseBold,
                    color: theme.infoTeal,
                    value: '${status.reviewsToday}',
                    label: 'Tekrar',
                  ),
                ),
                Expanded(
                  child: _buildDailyStatusStat(
                    icon: PhosphorIcons.clockBold,
                    color: theme.primaryAmber,
                    value: '${status.dueTomorrow}',
                    label: 'Yarın Bekleyen',
                  ),
                ),
              ],
            ),
            if (status.weeklyProjection > 0) ...[
              const SizedBox(height: 12),
              Container(height: 1, color: theme.borderSubtle),
              const SizedBox(height: 12),
              Text(
                'Bu hızla bir haftada ~${status.weeklyProjection} kelime öğrenmiş olacaksın.',
                style: GoogleFonts.inter(fontSize: 12, color: theme.textSecondary, height: 1.4),
              ),
            ],
          ],
        ],
      ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HERO ÖNERİ KARUSELİ
  // ---------------------------------------------------------------------------

  /// Kullanıcının o anki durumuna göre öncelik sıralı öneri kartları üretir.
  /// İlk kart her zaman "Günün Görevi"dir; toplam en fazla 4 kart.
  List<_HeroSuggestion> _buildHeroSuggestions(DraconicTheme theme, double goalProgress) {
    final list = <_HeroSuggestion>[];
    final goalDone = _dailyTargetCards > 0 && _todayLearnedCards >= _dailyTargetCards;
    final hasActivityToday = _dailyStatus?.hasActivityToday ?? false;

    // 1) Günün Görevi — her zaman ilk sırada.
    list.add(_HeroSuggestion(
      eyebrow: goalDone ? 'HEDEF TAMAM' : 'GÜNÜN GÖREVİ',
      icon: goalDone ? PhosphorIcons.sealCheckBold : PhosphorIcons.scrollBold,
      accent: goalDone ? theme.successEmerald : theme.primaryAmber,
      title: _activeBook != null ? _activeBook!.title : 'Kelime Egzersizi',
      subtitle: _todayLearnedCards == 0
          ? 'Bugün henüz kelime öğrenmedin • Hedef: $_dailyTargetCards'
          : 'Günlük Hedef • $_todayLearnedCards/$_dailyTargetCards Kelime',
      ctaLabel: _activeBook != null ? 'Okumaya Devam' : 'Derse Başla',
      ctaIcon: PhosphorIcons.playFill,
      pose: goalDone ? 'celebrating' : (_activeBook != null ? 'reading' : 'happy'),
      progress: goalProgress,
      onTap: _onStartLessonTap,
    ));

    // 2) Seri tehlikede — bugün hiç pratik yoksa ve korunacak bir seri varsa.
    if (!hasActivityToday && _currentStreak >= 2) {
      list.add(_HeroSuggestion(
        eyebrow: 'SERİNİ KORU',
        icon: PhosphorIcons.fireBold,
        accent: theme.dangerRed,
        title: '$_currentStreak günlük serin tehlikede',
        subtitle: 'Bugün henüz pratik yapmadın. 2 dakikalık hızlı bir tur yeter.',
        ctaLabel: 'Hızlı Tur',
        ctaIcon: PhosphorIcons.lightningBold,
        pose: 'sleepy',
        onTap: widget.onNavigateToFlashcards,
      ));
    }

    // 3) Boss kelimeler — sık yanıldığın, bekleme süresi dolmuş kelimeler.
    if (_bossCount > 0) {
      list.add(_HeroSuggestion(
        eyebrow: 'BOSS UYARISI',
        icon: PhosphorIcons.swordBold,
        accent: theme.dangerRed,
        title: _bossCount == 1 ? 'İnatçı bir kelime meydan okuyor' : '$_bossCount inatçı kelime meydan okuyor',
        subtitle: 'Sık yanıldığın kelimeleri Arena\'da alt et, XP kap.',
        ctaLabel: 'Arenaya Git',
        ctaIcon: PhosphorIcons.swordBold,
        pose: 'warrior',
        onTap: widget.onNavigateToFlashcards,
      ));
    }

    // 4) Tekrar bekleyen kelimeler.
    if (_dueReviewCount > 0) {
      list.add(_HeroSuggestion(
        eyebrow: 'TEKRAR ZAMANI',
        icon: PhosphorIcons.arrowClockwiseBold,
        accent: theme.infoTeal,
        title: '$_dueReviewCount kelime tekrar bekliyor',
        subtitle: 'Bugün vakti gelen kelimeler — unutmadan pekiştir.',
        ctaLabel: 'Tekrar Et',
        ctaIcon: PhosphorIcons.cardsBold,
        pose: 'teacher',
        onTap: widget.onNavigateToFlashcards,
      ));
    }

    // 5) Bitmeye yakın bir kitap (aktif kitap zaten 1. kartta).
    final nearFinish = _userBooks.where((b) {
      if (identical(b, _activeBook)) return false;
      final total = b.totalPages;
      if (total <= 1) return false;
      final ratio = b.currentPage / total;
      return ratio >= 0.6 && ratio < 1.0;
    }).toList();
    if (nearFinish.isNotEmpty) {
      final book = nearFinish.first;
      final remaining = (book.totalPages - book.currentPage - 1).clamp(1, 99999);
      list.add(_HeroSuggestion(
        eyebrow: 'SONA YAKLAŞTIN',
        icon: PhosphorIcons.trophyBold,
        accent: theme.successEmerald,
        title: book.title,
        subtitle: 'Bitirmene sadece $remaining sayfa kaldı!',
        ctaLabel: 'Kitabı Bitir',
        ctaIcon: PhosphorIcons.bookOpenBold,
        pose: 'proud',
        onTap: () => _openReaderDirectly(book),
      ));
    }

    // 6) Hiç açılmamış yeni bir kitap.
    final fresh = _userBooks.where((b) => !identical(b, _activeBook) && b.currentPage == 0 && b.lastReadDate == null).toList();
    if (fresh.isNotEmpty) {
      final book = fresh.first;
      list.add(_HeroSuggestion(
        eyebrow: 'YENİ MACERA',
        icon: PhosphorIcons.compassBold,
        accent: theme.cognitiveIndigo,
        title: book.title,
        subtitle: 'Henüz açmadığın bir kitap seni bekliyor.',
        ctaLabel: 'Keşfet',
        ctaIcon: PhosphorIcons.bookOpenBold,
        pose: 'explorer',
        onTap: () => _openReaderDirectly(book),
      ));
    }

    // Durum kartları en fazla 4; Alışkanlıklar kartı ise HER ZAMAN en sonda
    // — kullanıcı alışkanlık takibini buradan da keşfedebilsin.
    final result = list.take(4).toList();
    result.add(_HeroSuggestion(
      eyebrow: 'ALIŞKANLIKLAR',
      icon: PhosphorIcons.targetBold,
      accent: theme.primaryAmber,
      title: 'Günlük hedeflerini işaretle',
      subtitle: 'Okuma hedefini ve kendi alışkanlıklarını takip et, zinciri kırma.',
      ctaLabel: 'Alışkanlıklarım',
      ctaIcon: PhosphorIcons.caretRightBold,
      pose: 'greeting',
      onTap: _openHabitTracker,
    ));
    return result;
  }

  Widget _buildHeroCarousel(DraconicTheme theme, double goalProgress) {
    final suggestions = _buildHeroSuggestions(theme, goalProgress);
    // Kart sayısı yenilemede azalırsa geçersiz sayfada kalmayalım.
    final activePage = _heroPage.clamp(0, suggestions.length - 1);
    final activeAccent = suggestions[activePage].accent;

    return Column(
      children: [
        SizedBox(
          height: 206,
          child: PageView.builder(
            controller: _heroPageController,
            physics: const BouncingScrollPhysics(),
            itemCount: suggestions.length,
            onPageChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() => _heroPage = i);
            },
            itemBuilder: (context, index) => Padding(
              // Kartlar arasında kaydırırken nefes alan küçük bir boşluk.
              padding: const EdgeInsets.symmetric(horizontal: 3),
              // Kart sabit yükseklikte — çok büyük sistem yazı boyutunda
              // taşmasın diye yazı ölçeği kart içinde sınırlandırılıyor.
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.1,
                child: _buildHeroCard(theme, suggestions[index]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Sayfa göstergesi: aktif nokta uzayan, kartın vurgu rengini alan bir hap.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(suggestions.length, (i) {
            final isActive = i == activePage;
            return GestureDetector(
              onTap: () => _heroPageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? activeAccent : theme.borderSubtle,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildHeroCard(DraconicTheme theme, _HeroSuggestion s) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    const double mascotSize = 132;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          s.onTap();
        },
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.surfaceLight.withValues(alpha: 0.92), theme.surfaceDark.withValues(alpha: 0.96)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: s.accent.withValues(alpha: 0.35), width: 1.2),
            boxShadow: [
              BoxShadow(
                // Açık (Parşömen) temada renkli gölge kremin üstünde kirli bir
                // leke gibi duruyordu — orada nötr, çok hafif bir gölge.
                color: theme.isDark ? s.accent.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            // Maskot kartın alt kenarından "yükseliyor" — alt kenara yaslı ve
            // yuvarlak köşeden kırpılıyor; yazıların üstüne binmiyor.
            borderRadius: BorderRadius.circular(23),
            child: Stack(
              children: [
                // Maskotun arkasında vurgu renginde yumuşak bir ışık halesi —
                // karakteri karta "oturtuyor", yapıştırılmış gibi durmuyor.
                Positioned(
                  right: -40,
                  bottom: -50,
                  child: Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        // Koyu temada karakteri öne çıkaran hale, açık temada
                        // yoğun kalınca krem zeminde çamurlu bir leke
                        // oluşturuyordu — orada belirgin şekilde hafifletildi.
                        colors: [s.accent.withValues(alpha: theme.isDark ? 0.28 : 0.12), s.accent.withValues(alpha: 0.0)],
                      ),
                    ),
                  ),
                ),
                // Maskot: büst pozu, alt kenara yaslı, metne doğru bakacak
                // şekilde yatay çevrilmiş.
                Positioned(
                  right: -6,
                  bottom: 0,
                  child: Transform.flip(
                    flipX: true,
                    child: Image.asset(
                      AppBranding.poseAsset(s.pose),
                      width: mascotSize,
                      height: mascotSize,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      cacheWidth: (mascotSize * dpr).round(),
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                // İçerik: sağda maskota yer bırakan sabit bir boşlukla.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, mascotSize - 14, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(s.icon, size: 13, color: s.accent),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              s.eyebrow,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(color: s.accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lora(color: theme.textPrimary, fontSize: 19, fontWeight: FontWeight.bold, height: 1.15),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        s.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: theme.textSecondary, fontSize: 11.5, height: 1.3),
                      ),
                      const Spacer(),
                      if (s.progress != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: s.progress,
                            minHeight: 6,
                            backgroundColor: theme.borderSubtle,
                            valueColor: AlwaysStoppedAnimation<Color>(s.accent),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [s.accent.withValues(alpha: 0.8), s.accent]),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(color: s.accent.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(s.ctaIcon, size: 13, color: theme.background),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                s.ctaLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(color: theme.background, fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyStatusStat({required IconData icon, required Color color, required String value, required String label}) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: theme.textMuted, fontSize: 10, height: 1.2),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.background,
        body: Center(child: CircularProgressIndicator(color: theme.primaryAmber)),
      );
    }

    final double goalProgress = _dailyTargetCards > 0 ? (_todayLearnedCards / _dailyTargetCards).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(
        children: [
          // 1. KATMAN: KALE SİLUETLİ ARKA PLAN GÖRSELİ VE KARANLIK GEÇİŞ[cite: 3]
          Positioned.fill(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/section_illustrations/ana_sayfa.webp',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
                // UI/UX Düzeltme Listesi — Faz A3: üst kısımdaki katman
                // önceden çok erken opaklaşıyordu (0.3 → 0.8 arasında %40'lık
                // mesafede) ve özellikle Parşömen temasında kale silueti/
                // draconic motif üstteki ilk ekranda görünmez oluyordu.
                // Değerler hafifletildi ki motif hissi hâlâ süzülsün, alt
                // içerik okunabilirliği için son durak (theme.background,
                // tam opak) değişmedi.
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.background.withValues(alpha: 0.15),
                          theme.background.withValues(alpha: 0.65),
                          theme.background,
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 2. KATMAN: LOBİ İÇERİĞİ[cite: 3]
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              // UI/UX Düzeltme Listesi — P0-1: sabit 100 yerine gerçek bar
              // yüksekliği + viewPadding.bottom + 16'dan okunuyor.
              padding: EdgeInsets.fromLTRB(20.0, 16.0, 20.0, PlatformTokens.scrollBottomPadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // UI/UX Düzeltme Listesi — kullanıcı isteğiyle üstteki
                  // saate-göre-değişen "İyi günler, Eren" selamlaması
                  // kaldırıldı (kod içine sabit yazılmış isim istenmiyordu).
                  // --- 1. ÜST MARKA (DİKEY LOGO - SCALE İLE BOŞLUKLAR GİDERİLDİ) VE MİNİMALİST HUD ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Sol Taraf: Logo — arka planı (gömülü dama deseni)
                      // temizlenmiş, kenarlarına sıkı kırpılmış şeffaf PNG.
                      // Eski görselin etrafındaki boşluğu gizlemek için
                      // kullanılan Transform.scale hilesine artık gerek yok.
                      Expanded(
                        flex: 44,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            height: 54,
                            child: Image.asset(
                              'assets/images/logo/ignis_wordmark.png',
                              fit: BoxFit.contain,
                              alignment: Alignment.centerLeft,
                              filterQuality: FilterQuality.medium,
                              // P0-D: decode gösterilen boyuta indiriliyor.
                              cacheHeight: (54 * MediaQuery.of(context).devicePixelRatio).round(),
                              errorBuilder: (context, error, stackTrace) => Text(
                                'Ignis',
                                style: GoogleFonts.lora(color: theme.primaryAmber, fontSize: 22, fontWeight: FontWeight.bold)
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      // Sağ Taraf: Sayaçlar (Taşma korumalı, optimize edilmiş esnek oran)[cite: 3]
                      // 4-5 haneli değerlere de yer açacak şekilde büyütüldü —
                      // bu artık uygulama genelinde kullanılacak referans
                      // sayaç/rozet tasarımı.
                      Expanded(
                        flex: 56,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // XP Sayaç — XpShopService.instance.xpNotifier'a canlı bağlı,
                            // diğer tüm ekranlarla aynı anda senkron güncellenir.
                            Flexible(
              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                decoration: BoxDecoration(
                                  color: theme.surfaceDark.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(color: theme.borderSubtle),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(PhosphorIcons.lightningBold, color: theme.infoTeal, size: 15),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: ValueListenableBuilder<int>(
                                        valueListenable: XpShopService.instance.xpNotifier,
                                        builder: (context, value, _) => Text(_formatNumber(value), overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            // NOT (Ejderha Rotası V2 — Faz 1): Elmas sayacı top bar'dan
                            // kaldırıldı. XpShopService.gemsNotifier ve ilişkili metodlar
                            // (addGems/spendGems) veri modelinde @Deprecated olarak
                            // bırakıldı — okuma yolları kapatılıyor, alan silinmiyor.
                            // Streak Sayaç — dokununca Alışkanlıklar sayfası açılır
                            // (seri = alışkanlık zinciri; en görünür giriş noktası).
                            Flexible(
                              child: Tooltip(
                                message: 'Alışkanlıklarım',
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _openHabitTracker,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: theme.surfaceDark.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(13),
                                      border: Border.all(color: theme.primaryAmber.withValues(alpha: 0.45)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(PhosphorIcons.fireBold, color: theme.primaryAmber, size: 15),
                                        const SizedBox(width: 4),
                                        Flexible(child: Text(_formatNumber(_currentStreak), overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13))),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            // Profil İkonu
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                                ).then((_) => refreshDashboardStats());
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.surfaceDark.withValues(alpha: 0.75),
                                  border: Border.all(color: theme.borderSubtle),
                                ),
                                child: Icon(PhosphorIcons.shieldCheckBold, color: theme.textPrimary, size: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- 2. HERO: KAYDIRILABİLİR, KİŞİYE ÖZEL ÖNERİ KARUSELİ ---
                  // Eskiden tek, sabit bir "Günün Görevi" kartıydı. Artık
                  // kullanıcının o anki durumuna göre (seri riski, boss
                  // kelimeler, tekrar bekleyenler, bitmeye yakın/yeni kitap)
                  // öncelik sırasıyla 2-4 kart üretiliyor; ilk kart her zaman
                  // Günün Görevi. Sağa/sola kaydırılabilir, altta sayfa noktaları.
                  _buildHeroCarousel(theme, goalProgress),
                  const SizedBox(height: 16),

                  // EJDERHA ROTASI V2 — FAZ 7: AI Koç (Ignis) giriş bandı.
                  // İnce, tek satırlık tıklanabilir kart — sohbet ekranını
                  // açar. Kota/Premium mantığı tamamen ai_coach_repository
                  // ve ai_coach_screen içinde; burada yalnızca bir giriş
                  // noktası var.
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiCoachScreen()));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.surfaceDark.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          // EJDERHA ROTASI V2 — Görsel Entegrasyonu: eski 🐉
                          // emoji placeholder'ı yerine yeni üretilen, yuvarlak
                          // rünik arkaplanlı ignis_avatar_badge.png kullanılıyor.
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(color: const Color(0xFFA855F7).withValues(alpha: 0.15), shape: BoxShape.circle),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/mascot/ignis_avatar_badge.png',
                                width: 34,
                                height: 34,
                                cacheWidth: (34 * MediaQuery.of(context).devicePixelRatio).round(),
                                cacheHeight: (34 * MediaQuery.of(context).devicePixelRatio).round(),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('AI Koç Ignis\'e sor', style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 13.5)),
                                Text('İlerlemen, öğrenme sistemi ve Premium hakkında sor', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: theme.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                          Icon(PhosphorIcons.caretRightBold, color: theme.textMuted, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // AŞAMA 4 — "Günlük Durum" kartı: Ignis Anları'nın kalıcı,
                  // sessiz versiyonu — bir seans sonu popup'ı beklemeden
                  // bugünkü ilerleme her zaman burada görünür.
                  _buildIgnisDailyStatusCard(),
                  const SizedBox(height: 24),

                  // --- 3. DEVAM EDEN KİTAPLAR (YÜKSEK KONTRASTLI MİNİ BARLAR) ---[cite: 3, 4]
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Devam Eden Kitaplar', style: GoogleFonts.lora(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: widget.onNavigateToLibrary,
                        child: Text('Tümünü Gör >', style: GoogleFonts.inter(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    // P0-A: başlık 2 satıra çıkınca (P1-8) sabit 115px'lik kart
                    // 1px RenderFlex overflow veriyordu — ikinci satır için pay
                    // eklendi ve aşağıdaki Spacer kaldırıldı.
                    height: 132,
                    child: _userBooks.isEmpty
                        ? Center(child: Text('Henüz kitap eklenmedi.', style: GoogleFonts.inter(color: theme.textMuted, fontSize: 12)))
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _userBooks.length,
                            itemBuilder: (context, index) {
                              final book = _userBooks[index];
                              final totalPages = book.pages.isEmpty ? 1 : book.pages.length;
                              final progress = (book.currentPage / totalPages).clamp(0.0, 1.0);
                              final percent = (progress * 100).toInt();
                              final isSelected = index == 0;

                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: GestureDetector(
                                  onTap: () => _openReaderDirectly(book),
                                  child: Container(
                                    width: 110,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: theme.surfaceDark.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected ? theme.primaryAmber : theme.borderSubtle,
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [BoxShadow(color: theme.primaryAmber.withValues(alpha: 0.15), blurRadius: 12)]
                                          : [],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        BookCover(title: book.title),
                                        const SizedBox(height: 8),
                                        // P1-8: dar kart genişliğinde tek satır uzun başlıkları
                                        // ("The Adventures of Tom Sawyer") ortadan kesiyordu — 2 satıra çıkarıldı.
                                        Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13, height: 1.15)),
                                        const SizedBox(height: 2),
                                        // P1-7: "%0 okundu" yerine davet metni.
                                        Text(
                                          percent == 0 ? 'Yeni kitap ✨' : '%$percent okundu',
                                          style: GoogleFonts.inter(color: theme.textSecondary, fontSize: 10),
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: progress,
                                            minHeight: 4,
                                            backgroundColor: theme.borderSubtle,
                                            valueColor: AlwaysStoppedAnimation<Color>(isSelected ? theme.primaryAmber : theme.infoTeal),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 28),

                  // --- 4. GÜNLÜK SERİ MÜHÜR ÇUBUĞU ---[cite: 3]
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.surfaceDark.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: theme.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: theme.surfaceLight, shape: BoxShape.circle),
                                  child: Icon(PhosphorIcons.fireBold, color: theme.primaryAmber, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Günlük Seri', style: GoogleFonts.inter(color: theme.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
                                    Text('Devam et!', style: GoogleFonts.inter(color: theme.textSecondary, fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                            Text('$_currentStreak gün', style: GoogleFonts.lora(color: theme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(7, (index) {
                            final isCompleted = index < (_currentStreak % 7 == 0 && _currentStreak > 0 ? 7 : _currentStreak % 7);
                            return Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isCompleted ? theme.primaryAmber : theme.surfaceLight,
                                shape: BoxShape.circle,
                                border: Border.all(color: isCompleted ? theme.primaryAmber : theme.borderSubtle, width: 1.5),
                                boxShadow: isCompleted ? [BoxShadow(color: theme.primaryAmber.withValues(alpha: 0.3), blurRadius: 8)] : [],
                              ),
                              child: Center(
                                child: isCompleted
                                    ? Icon(PhosphorIcons.checkBold, color: theme.background, size: 15)
                                    : null,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                        // P0 (kullanıcı isteği): Alışkanlık Takibi ekranına
                        // giden AÇIK, keşfedilebilir bir buton yoktu — tek yol
                        // "X gün >" yazısına rastgele dokunmaktı (hem burada
                        // hem profil ekranında "Başarı Serisi" kartının
                        // içinde gizliydi). Kullanıcı zaten her gün bu seri
                        // kartına bakıyor, o yüzden en doğal yer TAM BURASI —
                        // ama artık gerçek bir buton: tam genişlikte, ripple'lı,
                        // net etiketli, ok ikonlu.
                        Material(
                          color: theme.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const HabitTrackerScreen()),
                              ).then((_) => refreshDashboardStats());
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              child: Row(
                                children: [
                                  Icon(PhosphorIcons.flameBold, color: theme.primaryAmber, size: 16),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Tüm Alışkanlıkları Gör',
                                      style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                  ),
                                  Icon(PhosphorIcons.caretRightBold, color: theme.textMuted, size: 14),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- 5. GELİŞİM İSTATİSTİKLERİ ---[cite: 3]
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: theme.surfaceDark.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Row(
                              children: [
                                Icon(PhosphorIcons.timerBold, size: 14, color: theme.infoTeal),
                                const SizedBox(width: 6),
                                Text('$_totalReadMinutes dk', style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Okuma Süresi', style: GoogleFonts.inter(color: theme.textSecondary, fontSize: 10)),
                          ],
                        ),
                        Container(height: 24, width: 1, color: theme.borderSubtle),
                        Column(
                          children: [
                            Row(
                              children: [
                                Icon(PhosphorIcons.bookOpenTextBold, size: 14, color: theme.primaryAmber),
                                const SizedBox(width: 6),
                                Text('${_userBooks.length}', style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Aktif Kitap', style: GoogleFonts.inter(color: theme.textSecondary, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. KATMAN — P1-13: "Derse Başla" hero kartı scroll'da görünürlükten
          // çıkınca beliren, tab bar üstüne oturan yarı saydam aksiyon çubuğu.
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: IgnorePointer(
              ignoring: !_showStickyCta,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                offset: _showStickyCta ? Offset.zero : const Offset(0, 0.4),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _showStickyCta ? 1.0 : 0.0,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _onStartLessonTap,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)]),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(PhosphorIcons.playFill, size: 15, color: Color(0xFF070B14)),
                            const SizedBox(width: 8),
                            Text('Derse Başla', style: GoogleFonts.outfit(color: const Color(0xFF070B14), fontWeight: FontWeight.w900, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
/// Ana Sayfa hero karuselindeki tek bir öneri kartının verisi.
class _HeroSuggestion {
  final String eyebrow;
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final IconData ctaIcon;
  // AppBranding.poseAsset() anahtarı
  final String pose;
  // Sadece "Günün Görevi" kartında gösterilen günlük hedef ilerlemesi.
  final double? progress;
  final VoidCallback onTap;

  const _HeroSuggestion({
    required this.eyebrow,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.ctaIcon,
    required this.pose,
    required this.onTap,
    this.progress,
  });
}
