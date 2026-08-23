// ==============================================================
// main.dart
// --------------------------------------------------------------
// KİŞİSEL GELİŞİM / E-KİTAP OKUYUCU / SÖZLÜK / ALIŞKANLIK TAKİP
// UYGULAMASI - ANA SAYFA (HOME) + GERÇEK MODÜL ENTEGRASYONU
// ==============================================================

import 'package:flutter/material.dart';
import 'dart:math';

// PROJEDEKİ MODÜLLER
import 'database_helper.dart';
import 'dictionary_screen.dart';
import 'flashcards_screen.dart';
import 'library_screen.dart'; // Kitaplık modülü bağlandı

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
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
      themeMode: _themeMode,
      home: RootScreen(onToggleTheme: _toggleTheme),
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
  final GlobalKey<_DashboardScreenState> _dashboardKey =
      GlobalKey<_DashboardScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      // 0) Ana Sayfa (Dashboard)
      DashboardScreen(key: _dashboardKey, onToggleTheme: widget.onToggleTheme),

      // 1) Kitaplık: GERÇEK LibraryScreen bağlandı
      const LibraryScreen(),

      // 2) Flashcards: GERÇEK FlashcardsScreen
      const FlashcardsScreen(),

      // 3) Profil: Placeholder
      const PlaceholderScreen(
        title: 'Profil',
        icon: Icons.person_rounded,
        description: 'Kullanıcı bilgileri ve ayarlar burada yer alacak.',
      ),
    ];
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    if (index == 0) {
      _dashboardKey.currentState?.refreshFlashcardCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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

class DashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const DashboardScreen({super.key, required this.onToggleTheme});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String _userName = 'Ahmet';

  final List<Quote> _quotes = const [
    Quote('Bugün okuduğun bir sayfa, yarının sende bıraktığı bir tohumdur.', 'Anonim'),
    Quote('Küçük adımlar, büyük değişimlerin başlangıcıdır.', 'Lao Tzu'),
    Quote('Bir kitap, bin yol açar.', 'Anonim'),
    Quote('Disiplin, hedef ile başarı arasındaki köprüdür.', 'Jim Rohn'),
    Quote('Her gün %1 daha iyi ol, bir yıl sonra 37 kat gelişmiş olursun.', 'James Clear'),
  ];

  late int _quoteIndex;
  int _flashcardCount = 0;
  bool _isLoadingCards = true;

  @override
  void initState() {
    super.initState();
    _quoteIndex = Random().nextInt(_quotes.length);
    refreshFlashcardCount();
  }

  void _refreshQuote() {
    setState(() {
      _quoteIndex = Random().nextInt(_quotes.length);
    });
  }

  Future<void> refreshFlashcardCount() async {
    setState(() {
      _isLoadingCards = true;
    });

    try {
      final cards = await DatabaseHelper.instance.getFlashcards();
      if (!mounted) return;

      setState(() {
        _flashcardCount = cards.length;
        _isLoadingCards = false;
      });
    } catch (e) {
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
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingHeader(ColorScheme colors, TextTheme textStyles) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
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
                  color: colors.onSurface.withValues(alpha: 0.6),
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
            onPressed: widget.onToggleTheme,
            tooltip: 'Temayı değiştir',
          ),
        ),
      ],
    );
  }

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
                      letterSpacing: 1.1,
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
            duration: const Duration(milliseconds: 300),
            child: Text(
              '"${currentQuote.text}"',
              key: ValueKey<String>(currentQuote.text),
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

  Widget _buildStatsRow(ColorScheme colors, TextTheme textStyles) {
    return Row(
      children: [
        Expanded(
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
          child: StatCard(
            icon: Icons.style_rounded,
            iconColor: colors.tertiary,
            iconBackground: colors.tertiaryContainer,
            title: 'Kayıtlı Kelime Kartı',
            value: '$_flashcardCount kart',
            subtitle: 'Toplam kayıtlı kart',
            isLoading: _isLoadingCards,
          ),
        ),
      ],
    );
  }

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
        // Grid'den tıklandığında da doğrudan GERÇEK LibraryScreen açılır
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const LibraryScreen()),
        ),
      ),
      _QuickAccessItemData(
        title: 'Kelime Kartları',
        subtitle: 'Flashcards / SRS',
        icon: Icons.style_rounded,
        color: colors.secondary,
        onTap: () => _openRealScreenAndRefresh(
          context,
          const FlashcardsScreen(),
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
        onTap: () => _openRealScreenAndRefresh(
          context,
          const DictionaryScreen(),
        ),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.15,
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

  Future<void> _openRealScreenAndRefresh(
    BuildContext context,
    Widget screen,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );

    if (!mounted) return;
    refreshFlashcardCount();
  }

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
          showAppBar: true,
        ),
      ),
    );
  }
}

class Quote {
  final String text;
  final String author;

  const Quote(this.text, this.author);
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String value;
  final String subtitle;
  final bool isLoading;

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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
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

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final bool showAppBar;

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