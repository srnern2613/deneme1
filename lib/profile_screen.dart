// ==============================================================
// DOSYA ADI: lib/profile_screen.dart
// AÇIKLAMA: Dinamik Profil, Seri Kalkanı ve Eksiksiz Rozetler Odası
// ==============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'library_screen.dart';
import 'flashcards_screen.dart';
import 'habit_tracker_screen.dart';
import 'streak_freeze_service.dart';
import 'xp_shop_service.dart';
import 'achievement_service.dart';
import 'celebration_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _totalReadMinutes = 0;
  int _totalWordsExamined = 0;
  int _totalFlashcards = 0;
  int _streakDays = 1;
  bool _hasFreezeShield = true;
  int _userTotalXp = 100;
  int _userGems = 50;
  List<int> _weeklyPages = [0, 0, 0, 0, 0, 0, 0];
  int _selectedTab = 0;
  Map<String, bool> _unlockedBadgesMap = {};

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final cards = await DatabaseHelper.instance.getFlashcards();
    final streakResult = await StreakFreezeService.instance.checkAndUpdateStreak();
    final xp = await XpShopService.instance.getTotalXp();
    final gems = await XpShopService.instance.getGemsBalance();

    List<int> pagesList = [];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      pagesList.add(prefs.getInt('daily_pages_$key') ?? 0);
    }

    final badgeKeys = [
      'first_step', 'librarian', 'first_curiosity', 'first_spark', 'apprentice_reader',
      'night_owl', 'early_bird', 'shield_master', 'weekend_warrior', 'time_bender',
      'page_monster', 'bound_scholar', 'marathoner', 'text_detective',
      'synapse_master', 'diamond_memory', 'voice_guide', 'curious_mind', 'word_collector',
      'speed_of_light', 'ghost_reader', 'legendary_scholar',
    ];

    final Map<String, bool> badgeStatus = {};
    for (var k in badgeKeys) {
      badgeStatus[k] = await AchievementService.instance.isBadgeUnlocked(k);
    }

    if (!mounted) return;
    setState(() {
      _totalReadMinutes = prefs.getInt('stats_total_read_minutes') ?? 0;
      _totalWordsExamined = prefs.getInt('stats_total_words_examined') ?? 0;
      _totalFlashcards = cards.length;
      _streakDays = streakResult['streakDays'];
      _hasFreezeShield = streakResult['hasFreezeShield'];
      _weeklyPages = pagesList;
      _userTotalXp = xp;
      _userGems = gems;
      _unlockedBadgesMap = badgeStatus;
    });
  }

  void _navigateTo(Widget screen) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    ).then((_) => _loadProfileData());
  }

  void _showBadgeDetailModal(_BadgeData badge) {
    HapticFeedback.selectionClick();
    if (badge.isUnlocked) {
      CelebrationDialog.show(
        context,
        emoji: badge.emoji,
        title: badge.title,
        subtitle: badge.subtitle,
        actionLabel: 'Harika!',
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Text(badge.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Text(badge.title),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔒 Bu rozet henüz kilitli!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 8),
              Text('Kilidi açmak için: ${badge.subtitle}', style: const TextStyle(fontSize: 13)),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    }
  }

  void _showShieldInfoDialog() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Text('🛡️', style: TextStyle(fontSize: 24)),
            SizedBox(width: 10),
            Text('Seri Kalkanı'),
          ],
        ),
        content: Text(
          _hasFreezeShield
              ? 'Seri kalkanın AKTİF! Uygulamaya 1 gün giremesen bile serin sıfırlanmayacak.'
              : 'Seri kalkanın boşta. Mağazadan veya günlük hedefleri tamamlayarak kalkan kazanabilirsin!',
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int totalWeeklyRead = _weeklyPages.reduce((a, b) => a + b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil & Başarılar', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💎', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 3),
                    Text(
                      '$_userGems',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.cyan[700]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 3),
                    Text(
                      '$_userTotalXp',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.amber),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🔥', style: TextStyle(fontSize: 30)),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Eren',
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Aktif Seri: $_streakDays Gün 🔥',
                          style: TextStyle(
                            color: colors.onPrimary.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _showShieldInfoDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Text(_hasFreezeShield ? '🛡️' : '⏳', style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text(
                            _hasFreezeShield ? 'Kalkan' : 'Kalkan Yok',
                            style: TextStyle(color: colors.onPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTab = 0);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? colors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '📊 İstatistikler',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _selectedTab == 0 ? colors.onPrimary : colors.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTab = 1);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? colors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '🏆 Başarılar Odası',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _selectedTab == 1 ? colors.onPrimary : colors.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_selectedTab == 0) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131B2E) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Haftalık Okuma İvmesi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('$totalWeeklyRead Sayfa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.primary)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 100,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (index) {
                          final pages = _weeklyPages[index];
                          final double heightFactor = (pages / 35.0).clamp(0.15, 1.0);
                          final daysLabel = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'][index];
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('$pages', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.onSurface.withValues(alpha: 0.6))),
                              const SizedBox(height: 4),
                              Container(
                                width: 22,
                                height: 55 * heightFactor,
                                decoration: BoxDecoration(
                                  color: pages > 0 ? colors.primary : colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(daysLabel, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.5))),
                            ],
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _buildStatCard('Okuma Süresi', '$_totalReadMinutes dk', Icons.timer_rounded, Colors.blue, isDark, () => _navigateTo(const LibraryScreen())),
                  _buildStatCard('Kelime Havuzu', '$_totalFlashcards Kart', Icons.style_rounded, Colors.pink, isDark, () => _navigateTo(const FlashcardsScreen())),
                  _buildStatCard('İncelenen Kelime', '$_totalWordsExamined Kelime', Icons.search_rounded, Colors.teal, isDark, () => _navigateTo(const FlashcardsScreen())),
                  _buildStatCard('Başarı Serisi', '$_streakDays Gün', Icons.local_fire_department_rounded, Colors.orange, isDark, () => _navigateTo(const HabitTrackerScreen())),
                ],
              ),
            ],

            if (_selectedTab == 1) ...[
              // 1. 🌱 Yeni Başlayanlar
              _buildBadgeCategory('🌱 Yeni Başlayanlar', [
                _BadgeData('🐣', 'İlk Adım', 'Uygulamaya ilk adımı at', _unlockedBadgesMap['first_step'] ?? true),
                _BadgeData('📕', 'Kütüphaneci Adayı', 'İlk kitabını yükle', _unlockedBadgesMap['librarian'] ?? true),
                _BadgeData('🔍', 'İlk Merak', 'İlk kelime anlamını incele', _unlockedBadgesMap['first_curiosity'] ?? (_totalWordsExamined > 0)),
                _BadgeData('⭐', 'İlk Kıvılcım', 'İlk kelime kartını kaydet', _unlockedBadgesMap['first_spark'] ?? (_totalFlashcards > 0)),
                _BadgeData('⏱️', 'Çırak Okur', 'İlk okuma seansını tamamla', _unlockedBadgesMap['apprentice_reader'] ?? (_totalReadMinutes > 0)),
              ], isDark),
              const SizedBox(height: 16),

              // 2. 🌅 Zaman & Alışkanlık
              _buildBadgeCategory('🌅 Zaman & Alışkanlık', [
                _BadgeData('🦉', 'Gece Baykuşu', '00:00 - 04:00 arası oku', _unlockedBadgesMap['night_owl'] ?? false),
                _BadgeData('☕', 'Sabah Memuru', '05:00 - 08:00 arası oku', _unlockedBadgesMap['early_bird'] ?? false),
                _BadgeData('🛡️', 'Seri Kalkanı', 'Serini koruyan kalkanı hak et', _hasFreezeShield),
                _BadgeData('📅', 'Hafta Sonu', 'Hafta sonu 20+ sayfa oku', _unlockedBadgesMap['weekend_warrior'] ?? false),
                _BadgeData('⏳', 'Zaman Bükücü', 'Kesintisiz 45+ dk oku', _unlockedBadgesMap['time_bender'] ?? (_totalReadMinutes >= 45)),
              ], isDark),
              const SizedBox(height: 16),

              // 3. 📚 Okuma Miktarları
              _buildBadgeCategory('📚 Okuma Miktarları', [
                _BadgeData('📖', 'Sayfa Canavarı', 'Toplam 100 sayfa oku', _unlockedBadgesMap['page_monster'] ?? (totalWeeklyRead >= 100)),
                _BadgeData('📜', 'Ciltli Alim', 'Toplam 500 sayfa oku', _unlockedBadgesMap['bound_scholar'] ?? false),
                _BadgeData('🏃', 'Maratoncu', 'Bir günde 40+ sayfa oku', _unlockedBadgesMap['marathoner'] ?? false),
                _BadgeData('🕵️', 'Metin Dedektifi', '100+ kelime incele', _unlockedBadgesMap['text_detective'] ?? (_totalWordsExamined >= 100)),
              ], isDark),
              const SizedBox(height: 16),

              // 4. 📇 Hafıza & SRS
              _buildBadgeCategory('📇 Hafıza & Kelime (SRS)', [
                _BadgeData('🧠', 'Sinaps Ustası', 'Kelime havuzuna 25+ kart ekle', _unlockedBadgesMap['synapse_master'] ?? (_totalFlashcards >= 25)),
                _BadgeData('💎', 'Elmas Hafıza', '50+ kelime kartı oluştur', _unlockedBadgesMap['diamond_memory'] ?? (_totalFlashcards >= 50)),
                _BadgeData('🗣️', 'Sesli Rehber', 'Sesli kitapta 10+ dk dinleme yap', _unlockedBadgesMap['voice_guide'] ?? (_totalReadMinutes >= 10)),
                _BadgeData('🔍', 'Meraklı Zihin', '50+ kelimenin anlamına bak', _unlockedBadgesMap['curious_mind'] ?? (_totalWordsExamined >= 50)),
                _BadgeData('🌟', 'Koleksiyoncu', '30+ kelimeyi hafızaya al', _unlockedBadgesMap['word_collector'] ?? (_totalFlashcards >= 30)),
              ], isDark),
              const SizedBox(height: 16),

              // 5. 🕵️ Gizli & Prestij
              _buildBadgeCategory('🕵️ Gizli & Prestij', [
                _BadgeData('⚡', 'Işık Hızı', '20+ dk odaklanarak oku', _unlockedBadgesMap['speed_of_light'] ?? (_totalReadMinutes >= 20)),
                _BadgeData('🥷', 'Hayalet Okur', 'Toplam 30+ sayfa bitir', _unlockedBadgesMap['ghost_reader'] ?? (totalWeeklyRead >= 30)),
                _BadgeData('👑', 'Efsanevi Alim', '300+ sayfa ve 50+ kelime tamamla', _unlockedBadgesMap['legendary_scholar'] ?? false),
              ], isDark),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCategory(String title, List<_BadgeData> badges, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: badges.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) {
            final badge = badges[index];
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showBadgeDetailModal(badge),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131B2E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: badge.isUnlocked ? Colors.amber.withValues(alpha: 0.6) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                    width: badge.isUnlocked ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      badge.emoji,
                      style: TextStyle(fontSize: 26, color: badge.isUnlocked ? null : Colors.grey.withValues(alpha: 0.4)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      badge.title,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badge.isUnlocked ? null : Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badge.subtitle,
                      style: TextStyle(fontSize: 8.5, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDark, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: color, size: 22),
                    Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeData {
  final String emoji;
  final String title;
  final String subtitle;
  final bool isUnlocked;

  _BadgeData(this.emoji, this.title, this.subtitle, this.isUnlocked);
}