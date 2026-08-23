// ==============================================================
// main.dart
// --------------------------------------------------------------
// KİŞİSEL GELİŞİM / E-KİTAP OKUYUCU / SÖZLÜK / ALIŞKANLIK TAKİP
// UYGULAMASI - ANA SAYFA (HOME) + GERÇEK MODÜL ENTEGRASYONU
//
// Bu sürümde, projede zaten var olan 3 dosya gerçek olarak
// bağlanıyor:
//   1) database_helper.dart  -> DatabaseHelper (SQLite erişimi)
//   2) dictionary_screen.dart -> DictionaryScreen (Sözlük ekranı)
//   3) flashcards_screen.dart -> FlashcardsScreen (Kelime kartları)
//
// ÖNEMLİ NOT: Bu dosyaları göremediğim için DictionaryScreen ve
// FlashcardsScreen'in "const Constructor({super.key})" ile (yani
// ekstra parametre istemeden) açılabildiğini, DatabaseHelper'ın
// da "DatabaseHelper.instance" adlı bir singleton (tekil) nesne
// ve "getFlashcards()" adlı, geriye bir Future<List<...>> döndüren
// bir metod sunduğunu varsaydım. Sizin dosyalarınızda imzalar
// farklıysa, sadece ilgili tek satırı güncellemeniz yeterli
// olacak şekilde kodu yorumlarla işaretledim.
// ==============================================================

import 'package:flutter/material.dart';
import 'dart:math';

// --------------------------------------------------------------
// PROJENİZDEKİ 3 HAZIR DOSYAYI İÇERİ AKTARIYORUZ
// --------------------------------------------------------------
// Bu import satırları, o dosyaların projenizde "lib/" klasörünün
// hemen altında main.dart ile AYNI DİZİNDE olduğunu varsayar.
// Eğer siz onları örneğin "lib/screens/" veya "lib/data/" gibi alt
// klasörlere koyduysanız, yol (path) kısmını ona göre güncelleyin
// (örn: 'screens/dictionary_screen.dart').
import 'database_helper.dart'; // SQLite veritabanı yardımcı sınıfı: DatabaseHelper.instance
import 'dictionary_screen.dart'; // Sözlük / arama / kelime ekleme ekranı: DictionaryScreen
import 'flashcards_screen.dart'; // Kayıtlı kartları listeleyen çalışma ekranı: FlashcardsScreen

// ==============================================================
// 1) GİRİŞ NOKTASI (ENTRY POINT)
// ==============================================================
void main() {
  runApp(const MyApp());
}

// ==============================================================
// 2) MyApp - Uygulamanın kök widget'ı ve tema yöneticisi
// --------------------------------------------------------------
// StatefulWidget seçildi çünkü açık/koyu tema arasında geçiş
// yapılabilmesi için bir state (ThemeMode) tutulması gerekiyor.
// ==============================================================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // O anki tema modu. ThemeMode.system => cihazın sistem ayarına
  // göre otomatik açık/koyu tema seçilir; kullanıcı manuel olarak
  // da değiştirebilir (aşağıdaki _toggleTheme fonksiyonu ile).
  ThemeMode _themeMode = ThemeMode.system;

  // Tema değiştirme fonksiyonu: setState çağrısı Flutter'a
  // "state değişti, ekranı yeniden çiz" der.
  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kişisel Gelişim Uygulaması',
      debugShowCheckedModeBanner: false, // Sağ üstteki "DEBUG" bandını kaldırır (sadece görsel temizlik)

      // ---------------- AÇIK TEMA ----------------
      // ColorScheme.fromSeed: Tek bir "tohum renk" vererek
      // Material 3'ün otomatik olarak uyumlu bir renk paleti
      // (birincil/ikincil/arka plan vb.) türetmesini sağlar.
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF), // Mor-mavi: modern, göz yormayan marka rengi
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA), // Hafif gri-mavi arka plan: kartlar üzerinde daha belirgin durur
        cardTheme: CardThemeData(
          elevation: 0, // Gölge yerine düz renk/kenarlık: modern "flat" görünüm
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // Yuvarlatılmış köşeler: yumuşak modern kart hissi
          ),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(height: 1.4), // Satır aralığını artırarak okunabilirliği yükseltir
        ),
      ),

      // ---------------- KOYU TEMA ----------------
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121218),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF1E1E27),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(height: 1.4),
        ),
      ),

      themeMode: _themeMode, // Hangi temanın aktif olduğunu belirler
      home: RootScreen(onToggleTheme: _toggleTheme), // Uygulamanın ana ekranı: alt gezinmeli iskelet
    );
  }
}

// ==============================================================
// 3) RootScreen - Alt gezinme çubuğunu (BottomNavigationBar)
//    yöneten iskelet ekran
// --------------------------------------------------------------
// 4 sekme barındırır: Ana Sayfa / Kitaplık / Flashcards / Profil.
// 3. sekme (index 2), placeholder DEĞİL, doğrudan projenizdeki
// gerçek FlashcardsScreen widget'ını gösterir.
// ==============================================================
class RootScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const RootScreen({super.key, required this.onToggleTheme});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  // Şu an seçili sekmenin index'i.
  int _currentIndex = 0;

  // DashboardScreen'in state'ine (private _DashboardScreenState)
  // dışarıdan erişebilmek için bir GlobalKey tanımlıyoruz. Bunu,
  // kullanıcı "Flashcards" sekmesinde kart ekleyip/silip tekrar
  // "Ana Sayfa" sekmesine döndüğünde, Dashboard'daki kart
  // sayacını GÜNCEL tutmak için kullanacağız. GlobalKey, aynı
  // dosya (library) içinde private bir State sınıfına da
  // erişebilir; bu yüzden main.dart içinde tek dosyada
  // sorunsuz çalışır.
  final GlobalKey<_DashboardScreenState> _dashboardKey =
      GlobalKey<_DashboardScreenState>();

  // Her sekmeye karşılık gelen ekranları tutan liste.
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      // 0) Ana Sayfa: Dashboard, GlobalKey ile referanslanıyor ki
      // dışarıdan (sekme değişince) sayaç yenileme fonksiyonunu
      // çağırabilelim.
      DashboardScreen(key: _dashboardKey, onToggleTheme: widget.onToggleTheme),

      // 1) Kitaplık: e-kitap okuyucu modülü henüz eklenmediği için
      // şimdilik bilgilendirici bir placeholder ekran gösteriyoruz.
      const PlaceholderScreen(
        title: 'Kitaplığım',
        icon: Icons.menu_book_rounded,
        description:
            'Telifsiz ve eklediğiniz e-kitaplar burada listelenecek.\n(Bu modül ileride eklenecektir.)',
      ),

      // 2) Flashcards: Kendi hazırladığınız GERÇEK ekran doğrudan
      // burada. "const" kullanabilmemiz için FlashcardsScreen'in
      // parametresiz (sadece key alan) bir constructor'a sahip
      // olduğunu varsayıyoruz. Eğer sizin FlashcardsScreen'iniz
      // zorunlu parametre istiyorsa (örn. belirli bir deste id'si),
      // "const" kelimesini kaldırıp parametreyi burada verin.
      const FlashcardsScreen(),

      // 3) Profil: henüz geliştirilmedi, placeholder.
      const PlaceholderScreen(
        title: 'Profil',
        icon: Icons.person_rounded,
        description: 'Kullanıcı bilgileri ve ayarlar burada yer alacak.',
      ),
    ];
  }

  // Alt menüde bir sekmeye tıklandığında çalışan fonksiyon.
  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Kullanıcı tekrar "Ana Sayfa" sekmesine (index 0) döndüğünde,
    // Flashcards sekmesinde eklediği/sildiği kartlar varsa
    // Dashboard'daki sayaç kartının güncel sayıyı göstermesi için
    // yenileme fonksiyonunu tetikliyoruz. "?." kullanıyoruz çünkü
    // Dashboard henüz oluşturulmamışsa (currentState null ise)
    // hata almamak için.
    if (index == 0) {
      _dashboardKey.currentState?.refreshFlashcardCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack: Seçili olmayan ekranları widget ağacından
      // tamamen kaldırmak yerine "gizli" tutar; böylece sekmeler
      // arası geçişte state (örn. FlashcardsScreen'in scroll
      // konumu) korunur ve ekranlar sıfırdan yeniden kurulmaz.
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow, // Etiketleri her zaman göster: daha anlaşılır gezinme
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Kitaplık',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style_rounded),
            label: 'Flashcards',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ==============================================================
// 4) DashboardScreen - ANA SAYFA (HOME) İÇERİĞİ
// --------------------------------------------------------------
// İçindekiler:
//   - Selamlama + tema değiştirme butonu
//   - Günün motivasyon sözü kartı (yenilenebilir)
//   - 2 sayaç kartı: biri GERÇEK veritabanı verisi (kayıtlı kart
//     sayısı), diğeri şimdilik örnek/mock veri (okunan sayfa)
//   - Hızlı erişim menüsü: Sözlük ve Flashcards butonları gerçek
//     ekranlara yönlendiriyor ve dönüşte sayaç yenileniyor
// ==============================================================
class DashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const DashboardScreen({super.key, required this.onToggleTheme});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ------------------------------------------------------------
  // KULLANICI VE MOTİVASYON SÖZÜ (MOCK VERİ)
  // ------------------------------------------------------------
  final String _userName = 'Ahmet'; // İleride gerçek kullanıcı profilinden gelecek

  final List<Quote> _quotes = const [
    Quote('Bugün okuduğun bir sayfa, yarının sende bıraktığı bir tohumdur.', 'Anonim'),
    Quote('Küçük adımlar, büyük değişimlerin başlangıcıdır.', 'Lao Tzu'),
    Quote('Bir kitap, bin yol açar.', 'Anonim'),
    Quote('Disiplin, hedef ile başarı arasındaki köprüdür.', 'Jim Rohn'),
    Quote('Her gün %1 daha iyi ol, bir yıl sonra 37 kat gelişmiş olursun.', 'James Clear'),
  ];

  late int _quoteIndex; // Şu an gösterilen sözün index'i

  // ------------------------------------------------------------
  // FLASHCARD SAYACI (GERÇEK VERİTABANI VERİSİ)
  // ------------------------------------------------------------
  // Bu değişken, DatabaseHelper üzerinden çekilen GERÇEK kayıtlı
  // flashcard sayısını tutar. Başlangıçta 0, veri yüklenirken
  // _isLoadingCards true olur ve kart üzerinde küçük bir yükleniyor
  // (loading) göstergesi gösteririz.
  int _flashcardCount = 0;
  bool _isLoadingCards = true; // Veritabanından veri çekilirken true; kullanıcıya "yükleniyor" hissi vermek için kullanılır

  @override
  void initState() {
    super.initState();
    // Rastgele bir motivasyon sözüyle başlıyoruz.
    _quoteIndex = Random().nextInt(_quotes.length);

    // Widget ilk oluşturulduğunda veritabanından kart sayısını
    // çekiyoruz. "await" kullanamayız çünkü initState "async"
    // olamaz; bu yüzden ayrı bir async fonksiyonu (aşağıdaki
    // refreshFlashcardCount) çağırıyoruz ve sonucunu beklemiyoruz
    // (fire-and-forget), fonksiyon kendi içinde setState çağırarak
    // ekranı güncelleyecek.
    refreshFlashcardCount();
  }

  // "Yeni söz göster" butonuna basıldığında çağrılır.
  void _refreshQuote() {
    setState(() {
      _quoteIndex = Random().nextInt(_quotes.length);
    });
  }

  // --------------------------------------------------------------
  // refreshFlashcardCount()
  // --------------------------------------------------------------
  // DatabaseHelper.instance üzerinden SQLite veritabanındaki
  // flashcard'ları çeker ve sadece adedini (uzunluğunu) state'e
  // yazar. Bu fonksiyonu bilerek "public" (başında alt çizgi
  // olmadan) tanımladık, çünkü RootScreen, GlobalKey aracılığıyla
  // bu fonksiyonu DIŞARIDAN çağırabilsin istiyoruz (kullanıcı
  // Flashcards sekmesinden Ana Sayfa'ya döndüğünde sayaç güncel
  // kalsın diye).
  //
  // NOT: DatabaseHelper.instance.getFlashcards() metodunun ismi
  // ve dönüş tipi sizin dosyanızdaki gerçek imzayla uyuşmuyorsa,
  // sadece bu fonksiyonun İÇİNİ güncellemeniz yeterlidir; kodun
  // geri kalanı (UI) hiçbir değişiklik gerektirmez.
  Future<void> refreshFlashcardCount() async {
    // Yükleniyor durumunu aktif ediyoruz ki kullanıcı arayüzde
    // (StatCard içinde) küçük bir bekleme göstergesi görsün.
    setState(() {
      _isLoadingCards = true;
    });

    try {
      // DatabaseHelper.instance: Singleton (tekil) nesne - tüm
      // uygulama boyunca tek bir veritabanı bağlantısı/örneği
      // kullanılmasını sağlar, her seferinde yeni nesne
      // oluşturmayı önler.
      // getFlashcards(): Veritabanındaki tüm kayıtlı kelime
      // kartlarını (muhtemelen List<Flashcard> ya da
      // List<Map<String, dynamic>> olarak) getirir. Dönen listenin
      // somut tipini bilmemize gerek yok; sadece ".length" (eleman
      // sayısı) bize yetiyor, bu yüzden herhangi bir List tipiyle
      // uyumlu çalışır.
      final cards = await DatabaseHelper.instance.getFlashcards();

      // Widget hâlâ ekranda mı (dispose edilmemiş mi) diye kontrol
      // ediyoruz. Asenkron bir işlem (await) bittiğinde kullanıcı
      // başka bir ekrana geçmiş olabilir; bu durumda setState
      // çağırmak hataya yol açar. "mounted" bunu güvenceye alır.
      if (!mounted) return;

      setState(() {
        _flashcardCount = cards.length; // Listenin uzunluğu = kayıtlı kart adedi
        _isLoadingCards = false;
      });
    } catch (e) {
      // Veritabanı okuma sırasında bir hata olursa (örn. tablo
      // henüz oluşturulmadıysa) uygulamanın çökmesini önlüyoruz;
      // sayaç 0 olarak kalır ve yükleniyor durumu kapanır.
      if (!mounted) return;
      setState(() {
        _isLoadingCards = false;
      });
      debugPrint('Flashcard sayısı alınırken hata oluştu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textStyles = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          // SingleChildScrollView: İçerik ekran boyunu aşarsa
          // (küçük ekranlarda) dikey kaydırmaya izin vererek taşma
          // (overflow) hatalarını önler.
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreetingHeader(colors, textStyles),
              const SizedBox(height: 20),
              _buildQuoteCard(colors, textStyles),
              const SizedBox(height: 24),
              _buildStatsRow(colors, textStyles),
              const SizedBox(height: 28),
              Text(
                'Hızlı Erişim',
                style: textStyles.headlineSmall?.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 12),
              _buildQuickAccessGrid(context, colors, textStyles),
              const SizedBox(height: 12), // Alt gezinme çubuğunun içeriğe binmemesi için ekstra boşluk
            ],
          ),
        ),
      ),
    );
  }

  // Selamlama alanı: "Merhaba, [isim]" başlığı + tema değiştirme
  // ikon butonu.
  Widget _buildGreetingHeader(ColorScheme colors, TextTheme textStyles) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          // Expanded: kalan yatay alanı doldurur, böylece uzun
          // isimlerde metin taşmaz, ikon her zaman sağda sabit kalır.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Merhaba, $_userName 👋',
                style: textStyles.headlineSmall?.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 4),
              Text(
                'Bugün gelişime bir adım daha yaklaş.',
                style: textStyles.bodyMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6), // Soluk renk: ikincil bilgi vurgusu
                ),
              ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 22,
          backgroundColor: colors.primaryContainer,
          child: IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: colors.onPrimaryContainer,
            ),
            onPressed: widget.onToggleTheme, // MyApp'ten aşağı aktarılan tema değiştirme fonksiyonu
            tooltip: 'Temayı değiştir',
          ),
        ),
      ],
    );
  }

  // Günün motivasyon sözü kartı: gradient arka plan + yenileme
  // butonu + yumuşak geçiş animasyonu.
  Widget _buildQuoteCard(ColorScheme colors, TextTheme textStyles) {
    final Quote currentQuote = _quotes[_quoteIndex];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.tertiary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.format_quote_rounded, color: colors.onPrimary, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'GÜNÜN SÖZÜ',
                    style: textStyles.bodyMedium?.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1, // Harf aralığı: "etiket" görünümü verir
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: colors.onPrimary),
                onPressed: _refreshQuote,
                tooltip: 'Yeni söz göster',
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            // AnimatedSwitcher: söz değiştiğinde metnin ani
            // "zıplama" yerine yumuşak (fade) bir geçişle
            // değişmesini sağlar.
            duration: const Duration(milliseconds: 300),
            child: Text(
              '"${currentQuote.text}"',
              key: ValueKey<String>(currentQuote.text), // AnimatedSwitcher'ın "değişikliği" fark edebilmesi için gerekli
              style: textStyles.titleMedium?.copyWith(
                color: colors.onPrimary,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '- ${currentQuote.author}',
            style: textStyles.bodyMedium?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.85),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // İki kompakt istatistik kartını yan yana gösterir.
  Widget _buildStatsRow(ColorScheme colors, TextTheme textStyles) {
    return Row(
      children: [
        Expanded(
          // "Bugün Okunan" kartı: şu an için okuma tracker modülü
          // entegre edilmediğinden mock (örnek) veri kullanıyoruz.
          child: StatCard(
            icon: Icons.menu_book_rounded,
            iconColor: colors.primary,
            iconBackground: colors.primaryContainer,
            title: 'Bugün Okunan',
            value: '24 sayfa',
            subtitle: '≈ 35 dakika',
            isLoading: false,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          // "Tekrar Edilen" kartı: GERÇEK veri. DatabaseHelper'dan
          // çekilen _flashcardCount değerini gösteriyoruz.
          // _isLoadingCards true iken kart üzerinde küçük bir
          // dönen gösterge (CircularProgressIndicator) gösterilir.
          child: StatCard(
            icon: Icons.style_rounded,
            iconColor: colors.tertiary,
            iconBackground: colors.tertiaryContainer,
            title: 'Kayıtlı Kelime Kartı',
            value: '$_flashcardCount kart', // Veritabanından gelen gerçek sayı
            subtitle: 'Toplam kayıtlı kart',
            isLoading: _isLoadingCards,
          ),
        ),
      ],
    );
  }

  // Hızlı erişim menüsü: 2x2 grid. Sözlük ve Flashcards kartları
  // GERÇEK ekranlara yönlendirir; diğer ikisi henüz eklenmediği
  // için placeholder ekrana gider.
  Widget _buildQuickAccessGrid(
    BuildContext context,
    ColorScheme colors,
    TextTheme textStyles,
  ) {
    final List<_QuickAccessItemData> items = [
      _QuickAccessItemData(
        title: 'Kitaplığım',
        subtitle: 'Telifsiz ve eklenen kitaplar',
        icon: Icons.menu_book_rounded,
        color: colors.primary,
        onTap: () => _openPlaceholder(
          context,
          title: 'Kitaplığım',
          icon: Icons.menu_book_rounded,
          description:
              'Telifsiz klasik eserler ve kendi eklediğiniz e-kitaplar\nburada listelenecek. (E-kitap okuyucu modülü ileride\nentegre edilecek.)',
        ),
      ),
      _QuickAccessItemData(
        title: 'Kelime Kartları',
        subtitle: 'Flashcards / SRS',
        icon: Icons.style_rounded,
        color: colors.secondary,
        // Buraya tıklanınca GERÇEK FlashcardsScreen açılıyor.
        onTap: () => _openRealScreenAndRefresh(
          context,
          const FlashcardsScreen(), // Sizin hazırladığınız gerçek ekran
        ),
      ),
      _QuickAccessItemData(
        title: 'Hobi & Okuma Takibi',
        subtitle: 'Günlük tracker',
        icon: Icons.local_fire_department_rounded,
        color: colors.tertiary,
        onTap: () => _openPlaceholder(
          context,
          title: 'Hobi & Okuma Takibi',
          icon: Icons.local_fire_department_rounded,
          description:
              'Günlük okuma/hobi alışkanlıklarınızı işaretleyip\nseri (streak) takibi yapabileceğiniz ekran burada olacak.',
        ),
      ),
      _QuickAccessItemData(
        title: 'Sözlük / Çeviri',
        subtitle: 'Çevrimdışı sözlük',
        icon: Icons.translate_rounded,
        color: colors.error,
        // Buraya tıklanınca GERÇEK DictionaryScreen açılıyor.
        onTap: () => _openRealScreenAndRefresh(
          context,
          const DictionaryScreen(), // Sizin hazırladığınız gerçek ekran
        ),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true, // Dış SingleChildScrollView zaten kaydırma sağladığı için grid kendi içinde kaymasın diye
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 sütunlu grid
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.15, // Hafif yatay dikdörtgen kart oranı
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return QuickAccessCard(
          title: item.title,
          subtitle: item.subtitle,
          icon: item.icon,
          color: item.color,
          onTap: item.onTap,
        );
      },
    );
  }

  // --------------------------------------------------------------
  // _openRealScreenAndRefresh()
  // --------------------------------------------------------------
  // Sözlük veya Flashcards gibi GERÇEK ekranları açan ve kullanıcı
  // geri döndüğünde ("pop" ettiğinde) flashcard sayacını otomatik
  // olarak yenileyen ortak fonksiyon. "Future<void>" ve "async"
  // kullanıyoruz çünkü Navigator.push bir Future döner ve bu
  // Future, kullanıcı o ekrandan GERİ DÖNDÜĞÜNDE tamamlanır -
  // yani "await" ile tam olarak "kullanıcı geri geldiğinde çalış"
  // anını yakalamış oluyoruz.
  Future<void> _openRealScreenAndRefresh(
    BuildContext context,
    Widget screen,
  ) async {
    // MaterialPageRoute: yeni bir sayfayı, sağdan kayarak gelen
    // standart bir geçiş animasyonuyla navigasyon yığınına (stack)
    // ekler.
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );

    // Kullanıcı ekrandan geri döndü; belki yeni bir kelime kartı
    // eklemiştir ya da silmiştir. Bu yüzden sayaç kartının GÜNCEL
    // veriyi göstermesi için veritabanından tekrar okuyoruz.
    // "mounted" kontrolü: widget bu sırada ekrandan kaldırılmışsa
    // (dispose edilmişse) setState çağırıp hata almamak için.
    if (!mounted) return;
    refreshFlashcardCount();
  }

  // Henüz geliştirilmemiş modüller (Kitaplık, Hobi Takibi) için
  // bilgilendirici placeholder ekranına yönlendiren yardımcı
  // fonksiyon.
  void _openPlaceholder(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String description,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlaceholderScreen(
          title: title,
          icon: icon,
          description: description,
          showAppBar: true, // Grid'den açıldığı için geri butonlu bir AppBar gerekiyor
        ),
      ),
    );
  }
}

// ==============================================================
// 5) Quote - Motivasyon sözü verisini tutan basit, değişmez sınıf
// ==============================================================
class Quote {
  final String text;
  final String author;

  const Quote(this.text, this.author);
}

// ==============================================================
// 6) StatCard - Kompakt istatistik kartı (yeniden kullanılabilir)
// --------------------------------------------------------------
// StatelessWidget: kendi başına state tutmuyor, sadece dışarıdan
// gelen verileri gösteriyor. "isLoading" parametresi eklendi;
// böylece veritabanından veri gelene kadar kullanıcıya küçük bir
// yükleniyor göstergesi sunabiliyoruz.
// ==============================================================
class StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String value;
  final String subtitle;
  final bool isLoading; // true ise değer yerine küçük bir yükleniyor animasyonu gösterilir

  const StatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.value,
    required this.subtitle,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textStyles = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: iconBackground,
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: textStyles.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            // isLoading true ise (veritabanından veri henüz
            // gelmediyse) değer yerine küçük, boyutu kısıtlanmış
            // bir CircularProgressIndicator gösteriyoruz.
            isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    value,
                    style: textStyles.titleMedium?.copyWith(fontSize: 17),
                  ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: textStyles.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================================
// 7) QuickAccessCard - Hızlı erişim grid'indeki tek bir kart
// ==============================================================
class QuickAccessCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const QuickAccessCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textStyles = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias, // InkWell'in dalga efekti kartın yuvarlak köşelerini taşmasın diye
      child: InkWell(
        // InkWell: Material Design'a özgü "dalga" (ripple) dokunma
        // efektini sağlar; kullanıcıya görsel geri bildirim verir.
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.15), // Ana rengin soluk hali: arka plan için
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(), // Column içindeki boşluğu esnek şekilde dolduran widget
              Text(
                title,
                style: textStyles.titleMedium?.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: textStyles.bodyMedium?.copyWith(
                  fontSize: 11,
                  color: colors.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================================
// 8) _QuickAccessItemData - Grid verisini taşıyan yardımcı sınıf
// --------------------------------------------------------------
// Sadece bu dosya içinde kullanılan (private) basit bir veri
// taşıyıcı. Grid listesini oluştururken kod tekrarını önler.
// ==============================================================
class _QuickAccessItemData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _QuickAccessItemData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

// ==============================================================
// 9) PlaceholderScreen - Henüz geliştirilmemiş modüller için
//    geçici (placeholder) ekran
// --------------------------------------------------------------
// "Kitaplık" ve "Profil" sekmeleri ile "Hobi & Okuma Takibi" grid
// öğesi henüz gerçek bir ekrana sahip olmadığı için bu genel
// amaçlı bilgilendirme ekranını kullanıyoruz. İleride bu modüller
// geliştirildikçe, bu widget'ın çağrıldığı yerler gerçek ekranlarla
// (örn. LibraryScreen, HabitTrackerScreen) değiştirilecek.
// ==============================================================
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final bool showAppBar; // true: geri butonlu AppBar (grid'den açılış); false: AppBar yok (alt menüden açılış)

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
    this.showAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textStyles = Theme.of(context).textTheme;

    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(title)) : null,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(icon, size: 40, color: colors.onPrimaryContainer),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: textStyles.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: textStyles.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 18),
                Chip(
                  label: const Text('Yapım Aşamasında'),
                  avatar: const Icon(Icons.construction_rounded, size: 16),
                  backgroundColor: colors.secondaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
