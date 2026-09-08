// ============================================================================
// DOSYA ADI: lib/profile_screen.dart
// AÇIKLAMA: Profil, Okuma Isı Haritası, İhtişamlı Başarılar ve Dinamik Mağaza Kozmetikleri
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
import 'dictionary_screen.dart';
import 'leaderboard_screen.dart';
import 'shop_screen.dart';
import 'achievement_service.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  const ProfileScreen({super.key, this.onToggleTheme});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  int _totalReadMinutes = 0;
  int _totalWordsExamined = 0;
  int _totalFlashcards = 0;
  int _masteredFlashcardsCount = 0;
  int _streakDays = 1;
  bool _hasFreezeShield = false;
  int _selectedTab = 0;

  bool _hasGoldenCrown = false;
  String _activeFrame = 'none';

  List<int> _heatmapDailyPages = [];
  Set<String> _unlockedBadges = {};

  final List<Map<String, dynamic>> _allBadges = [
    {'id': 'first_step', 'title': 'İlk Adım', 'emoji': '🐣', 'hint': 'Sisteme giriş yap ve ilk kitabını incele.', 'color': const Color(0xFF38BDF8)},
    {'id': 'librarian', 'title': 'Kütüphaneci Adayı', 'emoji': '📕', 'hint': 'Kütüphanene bir kitap ekle.', 'color': const Color(0xFF10B981)},
    {'id': 'first_curiosity', 'title': 'İlk Merak', 'emoji': '🔍', 'hint': 'Okurken bilmediğin bir kelimenin anlamını sorgula.', 'color': const Color(0xFF818CF8)},
    {'id': 'first_spark', 'title': 'İlk Kıvılcım', 'emoji': '⭐', 'hint': 'Hafıza havuzuna ilk kelimeni ekle.', 'color': const Color(0xFFF59E0B)},
    {'id': 'apprentice_reader', 'title': 'Çırak Okur', 'emoji': '⏱️', 'hint': 'Kronometre ile ilk okuma seansını tamamla.', 'color': const Color(0xFF6366F1)},
    {'id': 'night_owl', 'title': 'Gece Baykuşu', 'emoji': '🦉', 'hint': 'Gece yarısı ile sabaha karşı (00:00-04:00) okuma yap.', 'color': const Color(0xFFA855F7)},
    {'id': 'early_bird', 'title': 'Sabah Memuru', 'emoji': '☕', 'hint': 'Sabah erkenden (05:00-08:00) okuma seansı yap.', 'color': const Color(0xFFF59E0B)},
    {'id': 'shield_master', 'title': 'Seri Kalkanı', 'emoji': '🛡️', 'hint': 'Mağazadan veya etkinliklerden bir seri kalkanı kuşan.', 'color': const Color(0xFF38BDF8)},
    {'id': 'weekend_warrior', 'title': 'Hafta Sonu Savaşçısı', 'emoji': '📅', 'hint': 'Hafta sonu bir günde 20 sayfadan fazla oku.', 'color': const Color(0xFFEF4444)},
    {'id': 'time_bender', 'title': 'Zaman Bükücü', 'emoji': '⏳', 'hint': 'Uygulamada 45 dakikalık okuma süresini devir.', 'color': const Color(0xFFC084FC)},
    {'id': 'page_monster', 'title': 'Sayfa Canavarı', 'emoji': '📖', 'hint': 'Toplam 100 sayfa kitap oku.', 'color': const Color(0xFF10B981)},
    {'id': 'bound_scholar', 'title': 'Ciltli Alim', 'emoji': '📜', 'hint': 'Toplam 500 sayfa devir.', 'color': const Color(0xFFF59E0B)},
    {'id': 'marathoner', 'title': 'Maratoncu', 'emoji': '🏃', 'hint': 'Tek bir günde 40 sayfadan fazla oku.', 'color': const Color(0xFFEC4899)},
    {'id': 'text_detective', 'title': 'Metin Dedektifi', 'emoji': '🕵️', 'hint': 'Okurken 100 farklı kelimeyi incele.', 'color': const Color(0xFF818CF8)},
    {'id': 'synapse_master', 'title': 'Sinaps Ustası', 'emoji': '🧠', 'hint': 'Öğrenme havuzuna 25 kelime ekle.', 'color': const Color(0xFFEC4899)},
    {'id': 'diamond_memory', 'title': 'Elmas Hafıza', 'emoji': '💎', 'hint': 'Öğrenme havuzuna 50 kelime ekle.', 'color': const Color(0xFF38BDF8)},
    {'id': 'voice_guide', 'title': 'Sesli Rehber', 'emoji': '🗣️', 'hint': '10 dakika boyunca metin seslendirmesi dinle.', 'color': const Color(0xFF10B981)},
    {'id': 'curious_mind', 'title': 'Meraklı Zihin', 'emoji': '🤔', 'hint': 'En az 50 kez sözlüğü kullan.', 'color': const Color(0xFF6366F1)},
    {'id': 'word_collector', 'title': 'Koleksiyoncu', 'emoji': '🌟', 'hint': 'Kelime kütüphanende 30 kelime biriktir.', 'color': const Color(0xFFF59E0B)},
    {'id': 'speed_of_light', 'title': 'Işık Hızı', 'emoji': '⚡', 'hint': 'Toplamda 20 dakikalık hızlı pratik tamamla.', 'color': const Color(0xFFFDE047)},
    {'id': 'ghost_reader', 'title': 'Hayalet Okur', 'emoji': '🥷', 'hint': 'Sessizce toplam 30 sayfa devir.', 'color': const Color(0xFF94A3B8)},
    {'id': 'legendary_scholar', 'title': 'Efsanevi Alim', 'emoji': '👑', 'hint': '300 sayfa okuyup 50 kelime avlayarak tahta otur!', 'color': const Color(0xFFF59E0B)},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProfileData();
  }

  Future<void> refreshProfileData() async {
    await _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final cards = await DatabaseHelper.instance.getFlashcards();
      if (!mounted) return;

      int masteredCount = cards.where((c) => (c['is_mastered'] as int? ?? 0) == 1).length;

      final streakResult = await StreakFreezeService.instance.checkAndUpdateStreak();
      if (!mounted) return;

      await XpShopService.instance.getTotalXp();
      await XpShopService.instance.getGemsBalance();
      final crown = await XpShopService.instance.hasItem('golden_crown');
      final frame = await XpShopService.instance.getActiveCosmetic('frame', defaultVal: 'none');

      final unlocked = <String>{};
      for (var badge in _allBadges) {
        if (await AchievementService.instance.isBadgeUnlocked(badge['id']!)) {
          unlocked.add(badge['id']!);
        }
      }

      if (!mounted) return;

      final List<int> heatmapData = [];
      final now = DateTime.now();
      for (int i = 69; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final key = 'daily_pages_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        heatmapData.add(prefs.getInt(key) ?? 0);
      }

      if (!mounted) return;
      setState(() {
        _totalReadMinutes = prefs.getInt('stats_total_read_minutes') ?? 0;
        _totalWordsExamined = prefs.getInt('stats_total_words_examined') ?? 0;
        _totalFlashcards = cards.length;
        _masteredFlashcardsCount = masteredCount;
        _streakDays = streakResult['streakDays'] ?? 1;
        _hasFreezeShield = streakResult['hasFreezeShield'] ?? false;
        _heatmapDailyPages = heatmapData;
        _hasGoldenCrown = crown;
        _activeFrame = frame;
        _unlockedBadges = unlocked;
      });
    } catch (_) {}
  }

  void _navigateTo(Widget screen) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)).then((_) {
      if (mounted) _loadProfileData();
    });
  }

  void _showBadgeDetailDialog(Map<String, dynamic> badge, bool isUnlocked) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: isUnlocked ? badge['color'].withValues(alpha: 0.15) : const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(color: isUnlocked ? badge['color'] : const Color(0xFF334155), width: 2),
                  boxShadow: isUnlocked ? [BoxShadow(color: badge['color'].withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2)] : [],
                ),
                child: Center(
                  child: isUnlocked 
                      ? Text(badge['emoji'], style: const TextStyle(fontSize: 40)).animate().scale(curve: Curves.elasticOut, duration: 800.ms)
                      : const Icon(PhosphorIcons.lockFill, color: Color(0xFF475569), size: 36),
                ),
              ),
              const SizedBox(height: 16),
              Text(badge['title'], style: GoogleFonts.outfit(color: isUnlocked ? Colors.white : const Color(0xFF94A3B8), fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isUnlocked ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isUnlocked ? 'KİLİDİ AÇILDI ✓' : 'KİLİTLİ', 
                  style: GoogleFonts.outfit(color: isUnlocked ? const Color(0xFF34D399) : const Color(0xFFFCA5A5), fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isUnlocked ? "Bu başarımı başarıyla kazandın! Koleksiyonunda parlıyor." : badge['hint'],
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: const Color(0xFF070B14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Kapat', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // DİNAMİK AVATAR ÇERÇEVE RENDER YÖNETİCİSİ
  Widget _buildCosmeticAvatar() {
    Gradient? frameGradient;
    Color borderColor = const Color(0xFF38BDF8);
    bool shouldAnimate = false;

    switch (_activeFrame) {
      case 'flame_border':
        frameGradient = const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFF59E0B)]);
        borderColor = const Color(0xFFEC4899);
        shouldAnimate = true;
        break;
      case 'neon_frame':
        frameGradient = const LinearGradient(colors: [Color(0xFFA855F7), Color(0xFF38BDF8)]);
        borderColor = const Color(0xFFA855F7);
        shouldAnimate = true;
        break;
      case 'emerald_frame':
        frameGradient = const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)]);
        borderColor = const Color(0xFF10B981);
        break;
      case 'titan_frame':
        frameGradient = const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFF78350F)]);
        borderColor = const Color(0xFFF59E0B);
        break;
      case 'storm_frame':
        frameGradient = const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF1E3A8A)]);
        borderColor = const Color(0xFF38BDF8);
        shouldAnimate = true;
        break;
      case 'cosmic_frame':
        frameGradient = const LinearGradient(colors: [Color(0xFFC084FC), Color(0xFF6366F1), Color(0xFFEC4899)]);
        borderColor = const Color(0xFFC084FC);
        shouldAnimate = true;
        break;
      default:
        frameGradient = null;
        borderColor = const Color(0xFF38BDF8).withValues(alpha: 0.4);
    }

    Widget avatarWidget = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: frameGradient,
        border: frameGradient == null ? Border.all(color: borderColor, width: 2) : null,
      ),
      child: Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(color: Color(0xFF1E293B), shape: BoxShape.circle),
          child: const Center(child: Icon(PhosphorIcons.userBold, color: Color(0xFF38BDF8), size: 28)),
        ),
      ),
    );

    if (shouldAnimate) {
      return avatarWidget
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(begin: const Offset(1, 1), end: const Offset(1.04, 1.04), duration: 1200.ms);
    }
    return avatarWidget;
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
              _buildModernProfileHeader(),
              const SizedBox(height: 18),
              _buildMasteryProgressBanner(),
              const SizedBox(height: 16),
              _buildLeagueRankCard(),
              const SizedBox(height: 18),
              _buildTabSelector(),
              const SizedBox(height: 18),
              if (_selectedTab == 0) ...[
                _buildReadingHeatmapCard(),
                const SizedBox(height: 16),
                _buildStatsGrid(),
              ] else ...[
                _buildAchievementsGrid(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Koleksiyon Vitrini', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
            Text('${_unlockedBadges.length} / ${_allBadges.length}', style: GoogleFonts.outfit(color: const Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _allBadges.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) {
            final badge = _allBadges[index];
            final isUnlocked = _unlockedBadges.contains(badge['id']);
            final Color badgeColor = badge['color'];

            return GestureDetector(
              onTap: () => _showBadgeDetailDialog(badge, isUnlocked),
              child: Container(
                decoration: BoxDecoration(
                  color: isUnlocked ? badgeColor.withValues(alpha: 0.1) : const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isUnlocked ? badgeColor.withValues(alpha: 0.5) : const Color(0xFF1F2937),
                    width: isUnlocked ? 1.5 : 1.0,
                  ),
                  boxShadow: isUnlocked ? [BoxShadow(color: badgeColor.withValues(alpha: 0.15), blurRadius: 10, spreadRadius: 1)] : [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: isUnlocked ? badgeColor.withValues(alpha: 0.15) : const Color(0xFF1E293B),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isUnlocked 
                            ? Text(badge['emoji'], style: const TextStyle(fontSize: 22))
                            : const Icon(PhosphorIcons.lockFill, color: Color(0xFF475569), size: 20),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        badge['title'],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: isUnlocked ? Colors.white : const Color(0xFF64748B),
                          fontWeight: isUnlocked ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 10.5,
                          height: 1.2,
                        ),
                      ),
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
                Text('Profil', style: GoogleFonts.outfit(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                Text('İlerleme & Başarı Odası', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
            Row(
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: XpShopService.instance.gemsNotifier,
                  builder: (context, gems, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF38BDF8))),
                      child: Row(
                        children: [
                          const Icon(PhosphorIcons.diamondBold, color: Color(0xFF38BDF8), size: 15),
                          const SizedBox(width: 5),
                          Text('$gems', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<int>(
                  valueListenable: XpShopService.instance.xpNotifier,
                  builder: (context, xp, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF59E0B))),
                      child: Row(
                        children: [
                          const Icon(PhosphorIcons.lightningBold, color: Color(0xFFF59E0B), size: 15),
                          const SizedBox(width: 4),
                          Text('$xp XP', style: GoogleFonts.outfit(color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5), width: 1.5),
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  _buildCosmeticAvatar(),
                  if (_hasGoldenCrown)
                    Positioned(
                      top: -14,
                      child: Icon(PhosphorIcons.crownBold, color: const Color(0xFFF59E0B), size: 22)
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
                    Text('Aktif Seri: $_streakDays Gün 🔥', style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _navigateTo(const ShopScreen()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (_hasFreezeShield ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B)).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _hasFreezeShield ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_hasFreezeShield ? PhosphorIcons.shieldCheckBold : PhosphorIcons.shieldPlusBold, color: _hasFreezeShield ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B), size: 14),
                      const SizedBox(width: 4),
                      Text(_hasFreezeShield ? 'Korumada' : 'Kalkan Al!', style: GoogleFonts.outfit(color: _hasFreezeShield ? const Color(0xFF93C5FD) : const Color(0xFFFDE68A), fontWeight: FontWeight.w900, fontSize: 10.5)),
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

  Widget _buildMasteryProgressBanner() {
    final double percentage = _totalFlashcards > 0 ? (_masteredFlashcardsCount / _totalFlashcards).clamp(0.0, 1.0) : 0.0;
    final int percentInt = (percentage * 100).round();

    return GestureDetector(
      onTap: () => _navigateTo(const DictionaryScreen()),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('🟢', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text('Mastered Words Vitrini', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                  child: Text('%$percentInt Tamamlandı', style: GoogleFonts.outfit(color: const Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 11.5)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Toplam havuzdaki $_totalFlashcards kelimeden $_masteredFlashcardsCount tanesi kalıcı hafızaya alındı.', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 7,
                backgroundColor: const Color(0xFF1F2937),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeagueRankCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _navigateTo(const LeaderboardScreen()),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
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
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                decoration: BoxDecoration(color: _selectedTab == 0 ? const Color(0xFF6366F1) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text('📊 Isı Haritası', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                decoration: BoxDecoration(color: _selectedTab == 1 ? const Color(0xFF6366F1) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text('🏆 Başarılar', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingHeatmapCard() {
    final totalRead70Days = _heatmapDailyPages.fold(0, (sum, pages) => sum + pages);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF1F2937))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Okuma Isı Haritası (Son 70 Gün)', style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              Text('$totalRead70Days Sayfa', style: GoogleFonts.outfit(color: const Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 11.5)),
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
                          color: pages == 0 ? const Color(0xFF1E293B) : const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

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
        _buildStatCard('Koleksiyon Arşivi', '$_totalWordsExamined Kelime', PhosphorIcons.magnifyingGlassBold, const Color(0xFF10B981), () => _navigateTo(const DictionaryScreen())),
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
        decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF1F2937))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 20),
                Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
            Text(title, style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}