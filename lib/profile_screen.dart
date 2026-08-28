// ============================================================================
// DOSYA ADI: lib/profile_screen.dart
// AÇIKLAMA: Ayrı Üst Bar Kaldırılmış, Entegre HUD ve Kusursuz Hiyerarşili Profil
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'database_helper.dart';
import 'library_screen.dart';
import 'flashcards_screen.dart';
import 'habit_tracker_screen.dart';
import 'streak_freeze_service.dart';
import 'xp_shop_service.dart';
import 'achievement_service.dart';
import 'celebration_dialog.dart';
import 'shop_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  const ProfileScreen({super.key, this.onToggleTheme});

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
  int _selectedTab = 0;

  // Kozmetik & Mağaza Eşyaları Durumu
  bool _hasGoldenCrown = false;
  bool _hasFlameBorder = false;

  // 70 Günlük (10 Hafta) Isı Haritası Verisi
  List<int> _heatmapDailyPages = [];
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
    final crown = await XpShopService.instance.hasItem('golden_crown');
    final flame = prefs.getBool('item_flame_border') ?? false;

    // 70 Günlük Okuma Verisinin Çekilmesi (GitHub Tarzı Matris İçin)
    final List<int> heatmapData = [];
    final now = DateTime.now();
    for (int i = 69; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = 'daily_pages_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      heatmapData.add(prefs.getInt(key) ?? 0);
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
      _heatmapDailyPages = heatmapData;
      _userTotalXp = xp;
      _userGems = gems;
      _hasGoldenCrown = crown;
      _hasFlameBorder = flame;
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
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          title: Row(
            children: [
              Text(badge.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Text(badge.title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🔒 Henüz Kilitli', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
              const SizedBox(height: 8),
              Text(badge.subtitle, style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13)),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
              onPressed: () => Navigator.pop(context),
              child: Text('Tamam', style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. ÜST BAR YERİNE MODERN ENTEGRE BAŞLIK VE KAYNAK HUD
              _buildModernProfileHeader(),
              const SizedBox(height: 18),

              // 2. LİG DERECESİ & SEZON KARTI
              _buildLeagueRankCard(),
              const SizedBox(height: 18),

              // 3. SEKMELER (İstatistikler / Başarılar)
              _buildTabSelector(),
              const SizedBox(height: 18),

              // 4. SEÇİLİ SEKME İÇERİĞİ
              if (_selectedTab == 0) ...[
                _buildReadingHeatmapCard(),
                const SizedBox(height: 16),
                _buildStatsGrid(),
              ] else ...[
                _buildBadgesRoom(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // WIDGET: Modern Profil Başlığı & Kaynak Paneli (HUD)
  // ==========================================================================
  Widget _buildModernProfileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profil',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                Text(
                  'İlerleme & Başarı Odası',
                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            Row(
              children: [
                // Elmas Sayaç Kapsülü
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _navigateTo(const ShopScreen()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(PhosphorIcons.diamondBold, color: Color(0xFF38BDF8), size: 15),
                        const SizedBox(width: 5),
                        Text('$_userGems', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // XP Sayaç Kapsülü
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(PhosphorIcons.lightningBold, color: Colors.orange, size: 15),
                      const SizedBox(width: 4),
                      Text('$_userTotalXp', style: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Eren'in Hero Kartı ve Kalkan Durumu
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _hasFlameBorder
                          ? const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFF59E0B)])
                          : null,
                      boxShadow: _hasFlameBorder
                          ? [BoxShadow(color: const Color(0xFFEC4899).withValues(alpha: 0.6), blurRadius: 16, spreadRadius: 3)]
                          : null,
                    ),
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E293B),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(PhosphorIcons.userBold, color: Color(0xFF38BDF8), size: 28),
                        ),
                      ),
                    ),
                  ),
                  if (_hasGoldenCrown)
                    Positioned(
                      top: -14,
                      child: const Icon(PhosphorIcons.crownBold, color: Color(0xFFF59E0B), size: 22)
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveY(duration: 1000.ms, begin: 0, end: -3),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Eren', style: GoogleFonts.outfit(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                        if (_hasGoldenCrown) ...[
                          const SizedBox(width: 4),
                          const Icon(PhosphorIcons.sparkleBold, color: Color(0xFFFDE68A), size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Aktif Seri: $_streakDays Gün 🔥',
                      style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // Kalkan Durumu / Mağaza Yönlendirmesi
              GestureDetector(
                onTap: () => _navigateTo(const ShopScreen()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (_hasFreezeShield ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B)).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _hasFreezeShield ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _hasFreezeShield ? PhosphorIcons.shieldCheckBold : PhosphorIcons.shieldPlusBold,
                        color: _hasFreezeShield ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _hasFreezeShield ? 'Korumada' : 'Kalkan Al!',
                        style: GoogleFonts.outfit(
                          color: _hasFreezeShield ? const Color(0xFF93C5FD) : const Color(0xFFFDE68A),
                          fontWeight: FontWeight.w900,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // WIDGET: Lig Derecesi ve Sezon Rozeti Kartı
  // ==========================================================================
  Widget _buildLeagueRankCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(PhosphorIcons.trophyBold, color: Color(0xFFF59E0B), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('12. Arena: Kelime Ustası', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                    Text('#4 Sırada', style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 3),
                Text('Lider ile aranda sadece 50 XP fark var!', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // WIDGET: Sekme Seçici
  // ==========================================================================
  Widget _buildTabSelector() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1F2937)),
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
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? const Color(0xFF4F46E5) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _selectedTab == 0
                      ? [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 2))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '📊 İvme & Isı Haritası',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: _selectedTab == 0 ? Colors.white : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTab = 1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? const Color(0xFF4F46E5) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _selectedTab == 1
                      ? [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 2))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '🏆 Başarılar Odası',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: _selectedTab == 1 ? Colors.white : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // WIDGET: Isı Haritası
  // ==========================================================================
  Widget _buildReadingHeatmapCard() {
    final totalRead70Days = _heatmapDailyPages.fold(0, (sum, pages) => sum + pages);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(PhosphorIcons.calendarCheckBold, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Text('Okuma Isı Haritası (Son 70 Gün)', style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$totalRead70Days Sayfa', style: GoogleFonts.outfit(color: const Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(10, (colIndex) {
                return Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Column(
                    children: List.generate(7, (rowIndex) {
                      final itemIndex = (colIndex * 7) + rowIndex;
                      final pages = itemIndex < _heatmapDailyPages.length ? _heatmapDailyPages[itemIndex] : 0;
                      return Container(
                        width: 15,
                        height: 15,
                        margin: const EdgeInsets.only(bottom: 5),
                        decoration: BoxDecoration(
                          color: _getHeatmapColor(pages),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Az', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 9.5)),
              const SizedBox(width: 4),
              _buildColorDot(const Color(0xFF1E293B)),
              _buildColorDot(const Color(0xFF065F46)),
              _buildColorDot(const Color(0xFF059669)),
              _buildColorDot(const Color(0xFF10B981)),
              _buildColorDot(const Color(0xFF34D399)),
              const SizedBox(width: 4),
              Text('Çok', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 9.5)),
            ],
          ),
        ],
      ),
    );
  }

  Color _getHeatmapColor(int pages) {
    if (pages == 0) return const Color(0xFF1E293B);
    if (pages <= 5) return const Color(0xFF065F46);
    if (pages <= 15) return const Color(0xFF059669);
    if (pages <= 30) return const Color(0xFF10B981);
    return const Color(0xFF34D399);
  }

  Widget _buildColorDot(Color c) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
    );
  }

  // ==========================================================================
  // WIDGET: 4'lü Hızlı İstatistik Grid'i
  // ==========================================================================
  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        _buildStatCard('Okuma Süresi', '$_totalReadMinutes dk', PhosphorIcons.timerBold, const Color(0xFF38BDF8), () => _navigateTo(const LibraryScreen())),
        _buildStatCard('Kelime Havuzu', '$_totalFlashcards Kart', PhosphorIcons.cardsBold, const Color(0xFFEC4899), () => _navigateTo(const FlashcardsScreen())),
        _buildStatCard('İncelenen Kelime', '$_totalWordsExamined Kelime', PhosphorIcons.magnifyingGlassBold, const Color(0xFF10B981), () => _navigateTo(const FlashcardsScreen())),
        _buildStatCard('Başarı Serisi', '$_streakDays Gün', PhosphorIcons.fireBold, const Color(0xFFF59E0B), () => _navigateTo(const HabitTrackerScreen())),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1F2937)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 20),
                ),
                Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
            Text(title, style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // WIDGET: Başarılar Odası
  // ==========================================================================
  Widget _buildBadgesRoom() {
    return Column(
      children: [
        _buildBadgeCategory('🌱 Yeni Başlayanlar', [
          _BadgeData('🐣', 'İlk Adım', 'Uygulamaya ilk adımı at', _unlockedBadgesMap['first_step'] ?? true),
          _BadgeData('📕', 'Kütüphaneci Adayı', 'İlk kitabını yükle', _unlockedBadgesMap['librarian'] ?? true),
          _BadgeData('🔍', 'İlk Merak', 'İlk kelime anlamını incele', _unlockedBadgesMap['first_curiosity'] ?? (_totalWordsExamined > 0)),
          _BadgeData('⭐', 'İlk Kıvılcım', 'İlk kelime kartını kaydet', _unlockedBadgesMap['first_spark'] ?? (_totalFlashcards > 0)),
          _BadgeData('⏱️', 'Çırak Okur', 'İlk okuma seansını tamamla', _unlockedBadgesMap['apprentice_reader'] ?? (_totalReadMinutes > 0)),
        ]),
        const SizedBox(height: 16),
        _buildBadgeCategory('🌅 Zaman & Alışkanlık', [
          _BadgeData('🦉', 'Gece Baykuşu', '00:00 - 04:00 arası oku', _unlockedBadgesMap['night_owl'] ?? false),
          _BadgeData('☕', 'Sabah Memuru', '05:00 - 08:00 arası oku', _unlockedBadgesMap['early_bird'] ?? false),
          _BadgeData('🛡️', 'Seri Kalkanı', 'Serini koruyan kalkanı hak et', _hasFreezeShield),
          _BadgeData('📅', 'Hafta Sonu', 'Hafta sonu 20+ sayfa oku', _unlockedBadgesMap['weekend_warrior'] ?? false),
          _BadgeData('⏳', 'Zaman Bükücü', 'Kesintisiz 45+ dk oku', _unlockedBadgesMap['time_bender'] ?? (_totalReadMinutes >= 45)),
        ]),
        const SizedBox(height: 16),
        _buildBadgeCategory('📚 Okuma Miktarları', [
          _BadgeData('📖', 'Sayfa Canavarı', 'Toplam 100 sayfa oku', _unlockedBadgesMap['page_monster'] ?? false),
          _BadgeData('📜', 'Ciltli Alim', 'Toplam 500 sayfa oku', _unlockedBadgesMap['bound_scholar'] ?? false),
          _BadgeData('🏃', 'Maratoncu', 'Bir günde 40+ sayfa oku', _unlockedBadgesMap['marathoner'] ?? false),
          _BadgeData('🕵️', 'Metin Dedektifi', '100+ kelime incele', _unlockedBadgesMap['text_detective'] ?? (_totalWordsExamined >= 100)),
        ]),
      ],
    );
  }

  Widget _buildBadgeCategory(String title, List<_BadgeData> badges) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: badges.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, index) {
            final badge = badges[index];
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showBadgeDetailModal(badge),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: badge.isUnlocked ? const Color(0xFFF59E0B) : const Color(0xFF1F2937),
                    width: badge.isUnlocked ? 1.5 : 1,
                  ),
                  boxShadow: badge.isUnlocked
                      ? [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 3))]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      badge.emoji,
                      style: TextStyle(
                        fontSize: 28,
                        color: badge.isUnlocked ? null : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      badge.title,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badge.isUnlocked ? Colors.white : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      badge.subtitle,
                      style: GoogleFonts.inter(fontSize: 8.5, color: const Color(0xFF64748B), height: 1.2),
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
}

class _BadgeData {
  final String emoji;
  final String title;
  final String subtitle;
  final bool isUnlocked;

  _BadgeData(this.emoji, this.title, this.subtitle, this.isUnlocked);
}