// ============================================================================
// DOSYA ADI: lib/profile_screen.dart
// AÇIKLAMA: Profil, Okuma Isı Haritası, İhtişamlı Başarılar, Dinamik Mağaza
//            Kozmetikleri ve Reaktif AppHeader Entegrasyonu.
// ============================================================================

import 'package:flutter/foundation.dart' show ValueListenable;
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
import 'achievement_service.dart';
import 'core/design_system/primitives.dart'; // ScreenHeaderBadge & RuneTitle
import 'core/entitlement/paywall_trigger.dart';
import 'core/entitlement/entitlement_repository.dart';
import 'core/design_system/platform_tokens.dart';
import 'core/theme/theme_controller.dart'; // T-6: Görünüm anahtarı

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

  // Lig kartı artık leaderboard_screen.dart'taki GERÇEK sıralama algoritmasının
  // (kullanıcının gerçek XP'sinden türetilen simülasyon) burada yeniden
  // çalıştırılmış hâlini gösteriyor — önceden sabit/sahte metindi.
  int _leagueRank = 2;
  int _leagueXpGap = 0;
  String _leagueRivalName = '';

  bool _hasGoldenCrown = false;
  String _activeFrame = 'none';

  Set<String> _unlockedBadges = {};

  // EJDERHA ROTASI V2 — FAZ 6: Apple tarzı minimal Profil. Eski Mağaza'nın
  // (Faz 1'de kaldırıldı) elmasla çerçeve satın alma akışı yerine, tüm
  // çerçeveler artık Premium'un bir parçası — kilitli/kilitli-değil önizleme
  // popup'ından doğrudan seçiliyor, ayrı bir satın alma adımı yok.
  static const List<Map<String, dynamic>> _frameOptions = [
    {'id': 'none', 'label': 'Yok', 'gradient': null, 'free': true},
    {'id': 'flame_border', 'label': 'Alev', 'gradient': [Color(0xFFEC4899), Color(0xFFF59E0B)], 'free': false},
    {'id': 'neon_frame', 'label': 'Neon', 'gradient': [Color(0xFFA855F7), Color(0xFF38BDF8)], 'free': false},
    {'id': 'emerald_frame', 'label': 'Zümrüt', 'gradient': [Color(0xFF10B981), Color(0xFF34D399)], 'free': false},
    {'id': 'titan_frame', 'label': 'Titan', 'gradient': [Color(0xFFF59E0B), Color(0xFF78350F)], 'free': false},
    {'id': 'storm_frame', 'label': 'Fırtına', 'gradient': [Color(0xFF38BDF8), Color(0xFF1E3A8A)], 'free': false},
    {'id': 'cosmic_frame', 'label': 'Kozmik', 'gradient': [Color(0xFFC084FC), Color(0xFF6366F1), Color(0xFFEC4899)], 'free': false},
  ];

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

      final totalXp = await XpShopService.instance.getTotalXp();
      final crown = await XpShopService.instance.hasItem('golden_crown');
      final frame = await XpShopService.instance.getActiveCosmetic('frame', defaultVal: 'none');

      // Lig sıralaması: leaderboard_screen.dart'taki AYNI simülasyon
      // algoritması (sabit ofsetli rakip listesi, kullanıcının gerçek
      // XP'sinden türetilir) burada salt-okunur biçimde tekrar çalıştırılıyor
      // — hiçbir veri yazılmıyor, sadece Profil kartı için gösterim hesabı.
      final int userCurrentXp = totalXp > 0 ? totalXp : 4108;
      final List<Map<String, dynamic>> simulatedLeague = [
        {'name': 'Seydihan Akıl.', 'xp': userCurrentXp + 30, 'isUser': false},
        {'name': 'Eren (Sen)', 'xp': userCurrentXp, 'isUser': true},
        {'name': 'Sezer', 'xp': (userCurrentXp - 10).clamp(0, 999999), 'isUser': false},
        // UI/UX Düzeltme Listesi — P0-6: leaderboard_screen.dart ile aynı
        // isim havuzu, oradaki düzeltmeyle senkron tutuldu (bkz. o dosyadaki not).
        {'name': 'Alevkanat', 'xp': (userCurrentXp - 55).clamp(0, 999999), 'isUser': false},
        {'name': 'Gölgeavcı', 'xp': (userCurrentXp - 90).clamp(0, 999999), 'isUser': false},
        {'name': 'Gece.', 'xp': (userCurrentXp - 130).clamp(0, 999999), 'isUser': false},
        {'name': 'Deniz Acar', 'xp': (userCurrentXp - 180).clamp(0, 999999), 'isUser': false},
        {'name': 'Selin Öztürk', 'xp': (userCurrentXp - 230).clamp(0, 999999), 'isUser': false},
        {'name': 'Emre Aydın', 'xp': (userCurrentXp - 280).clamp(0, 999999), 'isUser': false},
        {'name': 'Kaan Vural', 'xp': (userCurrentXp - 330).clamp(0, 999999), 'isUser': false},
      ];
      simulatedLeague.sort((a, b) => (b['xp'] as int).compareTo(a['xp'] as int));
      final leagueUserIndex = simulatedLeague.indexWhere((e) => e['isUser'] == true);
      final leagueRank = leagueUserIndex != -1 ? leagueUserIndex + 1 : 2;
      int leagueXpGap = 0;
      String leagueRivalName = '';
      if (leagueUserIndex > 0) {
        final rival = simulatedLeague[leagueUserIndex - 1];
        leagueXpGap = ((rival['xp'] as int) - userCurrentXp + 1).clamp(1, 9999);
        leagueRivalName = rival['name'] as String;
      }

      final unlocked = <String>{};
      for (var badge in _allBadges) {
        if (await AchievementService.instance.isBadgeUnlocked(badge['id']!)) {
          unlocked.add(badge['id']!);
        }
      }

      if (!mounted) return;
      setState(() {
        _totalReadMinutes = prefs.getInt('stats_total_read_minutes') ?? 0;
        _totalWordsExamined = prefs.getInt('stats_total_words_examined') ?? 0;
        _totalFlashcards = cards.length;
        _masteredFlashcardsCount = masteredCount;
        _streakDays = streakResult['streakDays'] ?? 1;
        _hasFreezeShield = streakResult['hasFreezeShield'] ?? false;
        _hasGoldenCrown = crown;
        _activeFrame = frame;
        _unlockedBadges = unlocked;
        _leagueRank = leagueRank;
        _leagueXpGap = leagueXpGap;
        _leagueRivalName = leagueRivalName;
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

  // EJDERHA ROTASI V2 — FAZ 6: Çerçeve Önizleme Popup'ı. Avatara dokununca
  // açılır; kilitli (Premium olmayan) çerçeveler soluk + kilit ikonlu
  // gösterilir ve dokunuşları merkezi paywall'ı açar. Kilitsiz bir çerçeveye
  // dokunmak anında aktif çerçeve olarak kaydedilir — ayrı bir "satın alma"
  // adımı yok, hepsi Premium'un bir parçası.
  void _showFramePickerSheet() {
    HapticFeedback.lightImpact();
    final bool isPremium = EntitlementRepository.instance.isPremium;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text('Avatar Çerçevesi', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                isPremium ? 'Dilediğin çerçeveyi seç.' : 'Çerçeveler Premium ile açılır.',
                style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12.5),
              ),
              const SizedBox(height: 18),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _frameOptions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (context, index) {
                  final frame = _frameOptions[index];
                  final String id = frame['id'] as String;
                  final bool isFree = frame['free'] as bool;
                  final bool isLocked = !isFree && !isPremium;
                  final bool isActive = _activeFrame == id;
                  final List<Color>? gradientColors = frame['gradient'] as List<Color>?;

                  return GestureDetector(
                    onTap: () async {
                      if (isLocked) {
                        Navigator.pop(ctx);
                        final unlocked = await EntitlementRepository.instance.presentPaywall();
                        if (unlocked) _showFramePickerSheet();
                        return;
                      }
                      await XpShopService.instance.setActiveCosmetic('frame', id);
                      // `ctx` alt sayfanın (bottom sheet) kendi BuildContext'i;
                      // State'in `mounted`'ı onun hâlâ ağaçta olduğunu garanti
                      // etmiyor (use_build_context_synchronously uyarısı bu
                      // yüzden çıkıyordu) — doğru kontrol `ctx.mounted`.
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      _loadProfileData();
                    },
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: gradientColors != null ? LinearGradient(colors: gradientColors) : null,
                                border: gradientColors == null ? Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 2) : null,
                                boxShadow: isActive ? [BoxShadow(color: const Color(0xFFFDE68A).withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 1)] : [],
                              ),
                              child: Center(
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(color: Color(0xFF1E293B), shape: BoxShape.circle),
                                  child: Icon(PhosphorIcons.userBold, color: isLocked ? const Color(0xFF475569) : const Color(0xFF38BDF8), size: 20),
                                ),
                              ),
                            ),
                            if (isLocked)
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(color: Color(0xFF111827), shape: BoxShape.circle),
                                  child: const Icon(PhosphorIcons.lockSimpleBold, color: Color(0xFF94A3B8), size: 12),
                                ),
                              ),
                            if (isActive)
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                                  child: const Icon(PhosphorIcons.checkBold, color: Colors.white, size: 10),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          frame['label'] as String,
                          style: GoogleFonts.inter(color: isLocked ? const Color(0xFF64748B) : Colors.white, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
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
      body: Stack(
        children: [
          // Profile'a özel atmosferik zemin: taş kemer/kapı + uzakta kale
          // silueti, aşağıya doğru koyu zemine eriyor — yalnızca görsel bir
          // katman, hiçbir veri/servis çağrısını etkilemez.
          Positioned.fill(
            child: Image.asset(
              'assets/images/profile_background_pic.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF070B14).withValues(alpha: 0.55),
                    const Color(0xFF070B14),
                  ],
                  stops: const [0.0, 0.35, 0.7],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              // UI/UX Düzeltme Listesi — P0-1: sabit 110 yerine gerçek bar
              // yüksekliği + viewPadding.bottom + 16'dan okunuyor.
              padding: EdgeInsets.fromLTRB(20, 16, 20, PlatformTokens.scrollBottomPadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeaderRow(),
                  const SizedBox(height: 28),
                  _buildModernProfileCard(),
                  const SizedBox(height: 18),
                  _buildMasteryProgressBanner(),
                  const SizedBox(height: 16),
                  _buildLeagueRankCard(),
                  const SizedBox(height: 22),
                  // EJDERHA ROTASI V2 — FAZ 6: Apple tarzı minimal Profil —
                  // eski sekme seçici (Isı Haritası/Başarılar) ve ısı
                  // haritası kaldırıldı; istatistikler iOS Ayarlar tarzı
                  // temiz bir liste olarak sunuluyor, başarılar hep görünür.
                  _buildSettingsStyleStatsList(),
                  const SizedBox(height: 22),
                  _buildAchievementsGrid(),
                  const SizedBox(height: 22),
                  // T-6: Zindan/Parşömen görünüm anahtarı — alt yapı
                  // (ThemeController/DraconicTheme) Sıra 1'de kurulmuştu ama
                  // hiçbir ekranda gerçek bir kontrol yoktu, bu boşluğu kapatıyor.
                  _buildAppearanceSection(),
                  const SizedBox(height: 12),
                  // P1-17: Profil'e gerçek bir "Ayarlar" bölümü — önceden
                  // yalnızca istatistik kısayolları vardı, satın alma/sürüm
                  // gibi Apple Ayarlar'ın beklediği temel satırlar yoktu.
                  _buildAyarlarSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Lobi'deki gibi nefes alan, custom başlık alanı — Scaffold'un standart
  // appBar sıkışıklığı yerine SafeArea içinde serbest bir Row. Rozet
  // AppHeader'ın kullandığı AYNI canlı XpShopService.xpNotifier'ı dinler;
  // hiçbir yeni state veya iş mantığı eklenmedi, sadece görsel sunum.
  // EJDERHA ROTASI V2 — FAZ 1: Elmas rozeti kaldırıldı.
  Widget _buildProfileHeaderRow() {
    return Row(
      children: [
        const ScreenHeaderBadge(icon: PhosphorIcons.userBold, color: Color(0xFFA855F7)),
        const SizedBox(width: 12),
        const Expanded(
          child: RuneTitle(title: 'Profil', subtitle: 'İlerleme & Başarı Odası'),
        ),
        _buildHeaderStatPill(
          icon: PhosphorIcons.lightningBold,
          color: const Color(0xFF38BDF8),
          listenable: XpShopService.instance.xpNotifier,
        ),
      ],
    );
  }

  Widget _buildHeaderStatPill({required IconData icon, required Color color, required ValueListenable<int> listenable}) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFF1F2937), width: 1),
        ),
        child: ValueListenableBuilder<int>(
          valueListenable: listenable,
          builder: (context, value, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Text('$value', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      );
  }

  // achievement_service.dart'taki check() eşikleriyle BİREBİR aynı sayılar —
  // yeni bir hesaplama mantığı değil, zaten var olan eşiklerin burada
  // ilerleme yüzdesi göstermek için tekrar kullanılması. Sadece Profil
  // ekranında zaten yüklü olan sayaçları (_totalFlashcards, _totalWordsExamined,
  // _totalReadMinutes) kullandığından yeni bir servis çağrısı gerekmiyor.
  static const Map<String, int> _badgeThresholds = {
    'synapse_master': 25, // _totalFlashcards
    'diamond_memory': 50, // _totalFlashcards
    'word_collector': 30, // _totalFlashcards
    'text_detective': 100, // _totalWordsExamined
    'curious_mind': 50, // _totalWordsExamined
    'voice_guide': 10, // _totalReadMinutes
    'speed_of_light': 20, // _totalReadMinutes
    'time_bender': 45, // _totalReadMinutes
  };
  static const Set<String> _flashcardBadges = {'synapse_master', 'diamond_memory', 'word_collector'};
  static const Set<String> _wordsBadges = {'text_detective', 'curious_mind'};

  List<Map<String, dynamic>> _computeUpcomingBadges() {
    final results = <Map<String, dynamic>>[];
    for (final badge in _allBadges) {
      final id = badge['id'] as String;
      if (_unlockedBadges.contains(id)) continue;
      final threshold = _badgeThresholds[id];
      if (threshold == null) continue;
      final int current = _flashcardBadges.contains(id)
          ? _totalFlashcards
          : _wordsBadges.contains(id)
              ? _totalWordsExamined
              : _totalReadMinutes;
      final ratio = (current / threshold).clamp(0.0, 1.0);
      if (ratio <= 0) continue;
      results.add({...badge, 'current': current, 'threshold': threshold, 'ratio': ratio});
    }
    results.sort((a, b) => (b['ratio'] as double).compareTo(a['ratio'] as double));
    return results.take(2).toList();
  }

  Widget _buildAchievementsGrid() {
    final upcoming = _computeUpcomingBadges();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (upcoming.isNotEmpty) ...[
          Text('Yaklaşan Rozetler', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...upcoming.map((badge) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => _showBadgeDetailDialog(badge, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1F2937), width: 1),
                    ),
                    child: Row(
                      children: [
                        Text(badge['emoji'] as String, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(badge['title'] as String, style: GoogleFonts.outfit(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: badge['ratio'] as double,
                                  minHeight: 5,
                                  backgroundColor: const Color(0xFF334155),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFDE68A)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${badge['current']}/${badge['threshold']}', style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 6),
        ],
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

  // Hero profil kartı — EJDERHA ROTASI V2: Ignis maskotu ve konuşma balonu
  // kaldırıldı (Faz A, "Ignis Temizliği"). Sade, Apple tarzı minimalist bir
  // kart: koyu gradient + ince altın kenarlık, dikkat dağıtıcı üst rozet
  // katmanı olmadan doğrudan avatar + isim + seri durumuna odaklanıyor.
  Widget _buildModernProfileCard() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF17213C), Color(0xFF0B0F1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFDE68A).withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showFramePickerSheet,
            child: Stack(
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
                const SizedBox(height: 4),
                // Streak sayısı artık sadece alt istatistik gridinde
                // (tekrarı önlemek için) — burada, kalkan yokken Loss
                // Aversion ilkesine uygun büyütülmüş bir uyarı var;
                // kalkan varken minimal bir "güvende" onayı gösteriliyor.
                // EJDERHA ROTASI V2 — FAZ 2: Seri Koruma artık elmasla değil
                // Premium üyelikle açılıyor; dokunuş doğrudan merkezi
                // PaywallTrigger'ı tetikliyor (bkz. streak_freeze_service.dart).
                if (!_hasFreezeShield)
                  PaywallTrigger(
                    onUnlocked: _loadProfileData,
                    child: Row(
                      children: [
                        const Icon(PhosphorIcons.fireBold, color: Color(0xFFEF4444), size: 14),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Serin risk altında, kalkanın yok!',
                            style: GoogleFonts.inter(color: const Color(0xFFFCA5A5), fontSize: 11.5, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      const Icon(PhosphorIcons.shieldCheckBold, color: Color(0xFF34D399), size: 13),
                      const SizedBox(width: 5),
                      Text('Seri güvende', style: GoogleFonts.inter(color: const Color(0xFF6EE7B7), fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
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
          color: const Color(0xFF0F172A).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF1F2937), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 14, spreadRadius: 0, offset: const Offset(0, 4)),
          ],
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
                    // P1-16: İngilizce/Türkçe karışımı ("Mastered Words Vitrini")
                    // tamamen Türkçe başlığa çevrildi.
                    Text('Kalıcı Hafıza', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF34D399).withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
                      // P1-7: "%0 Tamamlandı" yerine davet metni.
                      child: Text(
                        percentInt == 0 ? 'Henüz başlamadın' : '%$percentInt Tamamlandı',
                        style: GoogleFonts.outfit(color: const Color(0xFF6EE7B7), fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(PhosphorIcons.caretRightBold, color: Color(0xFF64748B), size: 14),
                  ],
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
                backgroundColor: const Color(0xFF334155),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
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
          color: const Color(0xFF0F172A).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF1F2937), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 14, spreadRadius: 0, offset: const Offset(0, 4)),
          ],
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
                      Flexible(child: Text('12. Arena: Kelime Ustası', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14), overflow: TextOverflow.ellipsis)),
                      Text('#$_leagueRank. Sırada', style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // P1-8: maxLines eksikti, tek başına overflow:ellipsis hiçbir işe
                  // yaramıyordu (Text sınırsız satıra sarıyordu) — metin gerçekte
                  // sözcük ortasından ("...sadece 31 XP k...") kesiliyordu. Artık
                  // gerçekten tek satırda kesiliyor.
                  Text(
                    _leagueRank <= 1
                        ? 'Zirvedesin! Kimse seni geçemiyor 👑'
                        : '$_leagueRivalName\'i geçmek için sadece $_leagueXpGap XP kaldı!',
                    style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(PhosphorIcons.caretRightBold, color: Color(0xFF64748B), size: 14),
          ],
        ),
      ),
    );
  }

  // EJDERHA ROTASI V2 — FAZ 6: Apple/iOS Ayarlar tarzı temiz liste — eski
  // 2x2 kutu grid'i yerine tek grup içinde ince ayraçlarla bölünen satırlar.
  // Aynı 4 istatistik ve aynı navigasyon hedefleri korunuyor.
  Widget _buildSettingsStyleStatsList() {
    final rows = [
      (title: 'Okuma Süresi', value: '$_totalReadMinutes dk', icon: PhosphorIcons.timerBold, color: const Color(0xFF38BDF8), onTap: () => _navigateTo(const LibraryScreen())),
      (title: 'Kelime Havuzu', value: '$_totalFlashcards Kart', icon: PhosphorIcons.cardsBold, color: const Color(0xFFEC4899), onTap: () => _navigateTo(const FlashcardsScreen())),
      (title: 'Koleksiyon Arşivi', value: '$_totalWordsExamined Kelime', icon: PhosphorIcons.magnifyingGlassBold, color: const Color(0xFF10B981), onTap: () => _navigateTo(const DictionaryScreen())),
      (title: 'Başarı Serisi', value: '$_streakDays Gün', icon: PhosphorIcons.fireBold, color: const Color(0xFFF59E0B), onTap: () => _navigateTo(const HabitTrackerScreen())),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1F2937), width: 1),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _buildSettingsRow(rows[i]),
            if (i < rows.length - 1) const Divider(height: 1, color: Color(0xFF1F2937), indent: 56),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsRow(({String title, String value, IconData icon, Color color, VoidCallback onTap}) row) {
    return InkWell(
      onTap: row.onTap,
      child: Padding(
        // P1-5: satır yüksekliği ~86pt'ten iOS gruplu liste aralığına indirildi.
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: row.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9)),
              child: Icon(row.icon, color: row.color, size: 16),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(row.title, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Text(row.value, style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            const Icon(PhosphorIcons.caretRightBold, color: Color(0xFF475569), size: 14),
          ],
        ),
      ),
    );
  }

  // P1-17: Ayarlar bölümü — şimdilik yalnızca alt yapısı hazır iki satır
  // (satın alma geri yükleme + sürüm). Bildirimler, Uygulama dili,
  // Verilerimi sıfırla ve Gizlilik/Şartlar bilinçli olarak bu turda
  // EKLENMEDİ: Bildirimler için A-10'daki bildirim izni altyapısı henüz
  // kurulmadı; Uygulama dili çok-dilli mimari planı henüz uygulanmadı
  // (bkz. yayin_oncesi_kontrol_listesi.md); Verilerimi sıfırla, hangi
  // tabloların/anahtarların silineceğine dair ayrı bir kapsam kararı
  // gerektiriyor (yanlış silme riski); Gizlilik/Şartlar için gerçek bir
  // URL yok — sahte bir link koymak yanıltıcı olur. Sahte/pasif satırlar
  // yerine gerçekten çalışan iki satır eklendi.
  Widget _buildAyarlarSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1F2937), width: 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _handleRestorePurchases,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: const Color(0xFF818CF8).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9)),
                    child: const Icon(PhosphorIcons.arrowClockwiseBold, color: Color(0xFF818CF8), size: 16),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text('Satın Alımları Geri Yükle', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  const Icon(PhosphorIcons.caretRightBold, color: Color(0xFF475569), size: 14),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF1F2937), indent: 56),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: const Color(0xFF64748B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9)),
                  child: const Icon(PhosphorIcons.infoBold, color: Color(0xFF64748B), size: 16),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('Sürüm', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                Text('1.0.0', style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // T-6: Profil > Görünüm — Zindan (Karanlık) / Parşömen (Aydınlık) arasında
  // iki seçenekli segmented control. NOT: ekranların büyük çoğunluğu hâlâ
  // kendi ham hex renklerini kullanıyor (T-1'in geri kalanı tamamlanmadı),
  // bu yüzden bu anahtarın şu an GÖRÜNÜR etkisi sınırlı — yalnızca
  // MaterialApp'in `scaffoldBackgroundColor`'ı ve `DraconicTheme` extension'ı
  // değişir. Ekranlar teker teker `Theme.of(context).extension<DraconicTheme>()`'e
  // taşındıkça bu anahtarın etkisi büyüyecek.
  Widget _buildAppearanceSection() {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDark;
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF1F2937), width: 1),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Text('Görünüm', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: const Color(0xFF070B14), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAppearanceOption(label: 'Zindan', selected: isDark, onTap: () {
                      HapticFeedback.selectionClick();
                      ThemeController.instance.setDark(true);
                    }),
                    _buildAppearanceOption(label: 'Parşömen', selected: !isDark, onTap: () {
                      HapticFeedback.selectionClick();
                      ThemeController.instance.setDark(false);
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppearanceOption({required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF59E0B) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? const Color(0xFF070B14) : const Color(0xFF94A3B8)),
        ),
      ),
    );
  }

  Future<void> _handleRestorePurchases() async {
    HapticFeedback.selectionClick();
    final restored = await EntitlementRepository.instance.restorePurchases();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(restored ? 'Satın alımların geri yüklendi.' : 'Geri yüklenecek bir satın alma bulunamadı.'),
        backgroundColor: const Color(0xFF1F2937),
      ),
    );
  }
}
