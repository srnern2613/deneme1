// ============================================================================
// DOSYA ADI: lib/profile_screen.dart
// AÇIKLAMA: Profil, Okuma Isı Haritası, İhtişamlı Başarılar, Dinamik Mağaza
//            Kozmetikleri ve Reaktif AppHeader Entegrasyonu.
// ============================================================================

import 'package:flutter/foundation.dart' show ValueListenable, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'core/theme/draconic_theme.dart';
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
import 'ignis_moment_dialog.dart'; // Faz F: Dev/Test tetikleyicileri
import 'celebration_dialog.dart'; // Ignis Anı (seans sonu) dev/test önizlemesi
import 'core/coach/ignis_moments_engine.dart'; // Ignis Anı (seans sonu) dev/test önizlemesi
import 'core/auth/auth_service.dart'; // Hesap Sistemi
import 'auth_screen.dart'; // Hesap Sistemi
import 'core/notifications/notification_service.dart'; // Ayarlar → Bildirimler
import 'core/design_system/ignis_alert.dart'; // Tema-uyumlu bilgilendirme pop-up'ı (SnackBar yerine)
import 'core/branding/app_branding.dart'; // Ignis Önerisi kartındaki poz görseli için
import 'coach_messages.dart'; // Dev/Test: egzersiz bildirimi önizlemesi
import 'ai_coach_screen.dart'; // Dev/Test: AI Koç hazır soru ekranı

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

  // Gelişim paneli için ek veriler.
  int _totalPagesRead = 0;
  int _dueTodayCount = 0;
  // Son 7 günün (eskiden bugüne) günlük çalışma sayısı: yeni kelime + tekrar.
  List<int> _weekActivity = List<int>.filled(7, 0);

  // Profildeki "Ignis Önerisi" kartı — seans-sonu popup kotasını tüketmeyen
  // salt-okunur önizleme (bkz. IgnisMomentsEngine.getProfileInsightPreview).
  IgnisMoment? _ignisInsight;

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
    {'id': 'shield_master', 'title': 'Seri Kalkanı', 'emoji': '🛡️', 'hint': 'Bir gün ara verdiğinde seri kalkanın serini kurtarsın.', 'color': const Color(0xFF38BDF8)},
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
        // P0 (#21): leaderboard_screen.dart ile aynı düzeltme, senkron.
        {'name': 'Demirpençe', 'xp': (userCurrentXp - 180).clamp(0, 999999), 'isUser': false},
        {'name': 'Yıldıztüy', 'xp': (userCurrentXp - 230).clamp(0, 999999), 'isUser': false},
        {'name': 'Kayadamar', 'xp': (userCurrentXp - 280).clamp(0, 999999), 'isUser': false},
        {'name': 'Rüzgarkanat', 'xp': (userCurrentXp - 330).clamp(0, 999999), 'isUser': false},
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

      final int totalReadMinutes = prefs.getInt('stats_total_read_minutes') ?? 0;
      final int totalWordsExamined = prefs.getInt('stats_total_words_examined') ?? 0;
      final int totalPagesRead = prefs.getInt('stats_total_pages_read') ?? 0;
      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final int dailyPages = prefs.getInt('daily_pages_$todayKey') ?? 0;
      // "Şu anda kalkanım var mı" (UI/paywall banner için) — 'hasFreezeShield'
      // varsayılan olarak true (hediye kalkan) ya da Premium'da hep true.
      final bool hasShield = streakResult['hasFreezeShield'] ?? false;

      // Faz F3: rozet motoru daha önce HİÇ çağrılmıyordu — "3/22 rozet
      // açıldı" gibi görünen eski/kalıcı badge_unlocked_* bayrakları
      // geçmişteki bir sürümden kalmaydı, yeni rozetler hiç açılmıyordu.
      // Ana Sayfa'daki seri kaybı/günlük hedef anlarıyla aynı desende:
      // Profil her açıldığında güncel istatistiklerle kontrol ediyoruz.
      //
      // P0 (#23): 'shield_master' rozeti buradaki 'hasShield' (varsayılan
      // hediye kalkan) DEĞİL, kalkanın GERÇEKTEN bir seriyi kurtardığı
      // 'everSavedByShield' kalıcı bayrağını kullanmalı — aksi halde her
      // yeni kullanıcı hiçbir şey yapmadan bu rozeti açıyordu.
      final bool hasEverSavedByShield = streakResult['everSavedByShield'] ?? false;
      final newlyUnlocked = await AchievementService.instance.checkAndUnlockAchievements(
        totalPagesRead: totalPagesRead,
        totalFlashcards: cards.length,
        totalReadMinutes: totalReadMinutes,
        wordsExamined: totalWordsExamined,
        dailyPages: dailyPages,
        hasShield: hasEverSavedByShield,
      );

      final unlocked = <String>{};
      for (var badge in _allBadges) {
        if (await AchievementService.instance.isBadgeUnlocked(badge['id']!)) {
          unlocked.add(badge['id']!);
        }
      }

      // Ignis Önerisi kartı — salt okunur, seans-sonu popup kotasını
      // tüketmez, profil her açıldığında güncel içgörüyü gösterir.
      final ignisInsight = await IgnisMomentsEngine.instance.getProfileInsightPreview(
        precomputedStreakResult: streakResult,
      );

      // Gelişim paneli: bugün vakti gelen tekrarlar + son 7 günlük aktivite.
      // Biri başarısız olsa bile profilin geri kalanı yüklenmeye devam etsin.
      int dueTodayCount = 0;
      try {
        dueTodayCount = await DatabaseHelper.instance.getDueTodayCount();
      } catch (_) {}
      final List<int> weekActivity = List<int>.filled(7, 0);
      try {
        final range = await DatabaseHelper.instance.getDailyStatsRange(7);
        for (int i = 0; i < 7; i++) {
          final d = now.subtract(Duration(days: 6 - i));
          final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          for (final row in range) {
            if (row['stat_date'] == key) {
              weekActivity[i] = ((row['new_words_count'] as int?) ?? 0) + ((row['review_count'] as int?) ?? 0);
            }
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _totalReadMinutes = totalReadMinutes;
        _totalWordsExamined = totalWordsExamined;
        _totalFlashcards = cards.length;
        _masteredFlashcardsCount = masteredCount;
        _streakDays = streakResult['streakDays'] ?? 1;
        _hasFreezeShield = hasShield;
        _hasGoldenCrown = crown;
        _activeFrame = frame;
        _unlockedBadges = unlocked;
        _leagueRank = leagueRank;
        _leagueXpGap = leagueXpGap;
        _leagueRivalName = leagueRivalName;
        _ignisInsight = ignisInsight;
        _totalPagesRead = totalPagesRead;
        _dueTodayCount = dueTodayCount;
        _weekActivity = weekActivity;
      });

      // Yeni açılan rozet(ler) varsa — build tamamlandıktan sonra, Ignis
      // pop-up'ıyla kutla (aynı frame-sonrası deseni: bkz. main.dart'taki
      // streakLossMoment). Birden fazla açıldıysa şimdilik en yenisini
      // (listenin sonuncusu) gösteriyoruz — art arda pop-up yığını UX'i
      // bozar.
      if (newlyUnlocked.isNotEmpty && mounted) {
        final badge = newlyUnlocked.last;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          IgnisMomentDialog.show(
            context,
            pose: 'celebrating',
            title: '${badge.emoji} ${badge.title}',
            message: badge.celebrationText,
            primaryLabel: 'Harika! 🎉',
            badgeEmoji: badge.emoji,
          );
        });
      }
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
          // BUG ÖNLEME: `_frameOptions` listesi ileride büyürse (yeni
          // kozmetik çerçeveler eklenirse) aşağıdaki `GridView` taşabilir —
          // Ayarlar sheet'inde yaşanan overflow bug'ının aynısı. Bu sheet
          // `isScrollControlled: true` KULLANMIYOR (sabit yükseklik), o
          // yüzden burada hem yüksekliği ekranla sınırlıyor hem de
          // kaydırılabilir yapıyoruz.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: SingleChildScrollView(
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
            ),
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
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(
        children: [
          // Profile'a özel atmosferik zemin: taş kemer/kapı + uzakta kale
          // silueti, aşağıya doğru koyu zemine eriyor — yalnızca görsel bir
          // katman, hiçbir veri/servis çağrısını etkilemez.
          Positioned.fill(
            child: Image.asset(
              'assets/images/section_illustrations/profil.webp',
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
                    theme.background.withValues(alpha: 0.55),
                    theme.background,
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
                  _buildIgnisInsightCard(),
                  const SizedBox(height: 16),
                  _buildLeagueRankCard(),
                  const SizedBox(height: 22),
                  // EJDERHA ROTASI V2 — FAZ 6: Apple tarzı minimal Profil —
                  // eski sekme seçici (Isı Haritası/Başarılar) ve ısı
                  // haritası kaldırıldı; istatistikler iOS Ayarlar tarzı
                  // temiz bir liste olarak sunuluyor, başarılar hep görünür.
                  _buildGrowthPanel(),
                  const SizedBox(height: 22),
                  // Faz B2: eski 22 rozetlik tam ızgara + Yaklaşan Rozetler
                  // yığını yerine kompakt özet satırı — tamamı Başarı
                  // Odası sheet'inde (bkz. _openAchievementRoomSheet).
                  _buildBadgesSummaryRow(),
                  // Faz B1: Görünüm anahtarı ve Ayarlar bölümü artık burada
                  // değil — sağ üstteki dişli çark rozetinden açılan
                  // _openProfileSettingsSheet() içinde.
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Ignis Önerisi kartı — bugün pratik yoksa bile bir teşvik mesajıyla
  // görünür kalır (bkz. getProfileInsightPreview), asistan sessizce
  // kaybolmaz. "Daha Fazla Bilgi" Premium olmayan kullanıcıya kısa bir
  // bilgi + geçiş butonu gösterir, Premium kullanıcıya ise anlık
  // genişletilmiş verileri.
  Widget _buildIgnisInsightCard() {
    final insight = _ignisInsight;
    if (insight == null) return const SizedBox.shrink();
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    // Tüm kart dokunulabilir — sadece "Daha Fazla Bilgi" metnine değil,
    // kartın herhangi bir yerine dokununca da aynı akış açılır.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _onIgnisInsightMoreInfoTap,
        child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              AppBranding.poseAsset(insight.pose),
              width: 42,
              height: 42,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: theme.infoTeal.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(PhosphorIcons.sparkleBold, color: theme.infoTeal, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IGNIS ÖNERİSİ', style: GoogleFonts.outfit(color: theme.infoTeal, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 3),
                Text(insight.title, style: GoogleFonts.outfit(color: theme.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(insight.message, style: GoogleFonts.inter(color: theme.textSecondary, fontSize: 12, height: 1.4)),
                const SizedBox(height: 6),
                // Kartın tamamı zaten dokunulabilir (bkz. dıştaki InkWell) —
                // bu sadece bir görsel ipucu/affordance.
                Text(
                  'Daha Fazla Bilgi →',
                  style: GoogleFonts.inter(color: theme.infoTeal, fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  void _onIgnisInsightMoreInfoTap() {
    HapticFeedback.selectionClick();
    if (EntitlementRepository.instance.isPremium) {
      _showIgnisInsightPremiumDetail();
    } else {
      IgnisAlert.show(
        context,
        message: 'Haftalık projeksiyon, ustalaşma oranı ve daha fazla detaylı içgörü Premium\'da. '
            'Şu an sadece en güncel özet gösteriliyor.',
        type: IgnisAlertType.info,
        actionLabel: 'Premium\'a Geç',
        onAction: () => EntitlementRepository.instance.presentPaywall(),
      );
    }
  }

  Future<void> _showIgnisInsightPremiumDetail() async {
    final status = await IgnisMomentsEngine.instance.getDailyStatusSnapshot();
    if (!mounted) return;
    IgnisAlert.show(
      context,
      message: 'Bugün ${status.newWordsToday} yeni kelime + ${status.reviewsToday} tekrar yaptın. '
          'Haftalık projeksiyon: ${status.weeklyProjection} kelime. '
          'Serin: $_streakDays gün, ustalaşılan kelime: $_masteredFlashcardsCount.',
      type: IgnisAlertType.success,
    );
  }

  // Lobi'deki gibi nefes alan, custom başlık alanı — Scaffold'un standart
  // appBar sıkışıklığı yerine SafeArea içinde serbest bir Row. Rozet
  // AppHeader'ın kullandığı AYNI canlı XpShopService.xpNotifier'ı dinler;
  // hiçbir yeni state veya iş mantığı eklenmedi, sadece görsel sunum.
  // EJDERHA ROTASI V2 — FAZ 1: Elmas rozeti kaldırıldı.
  Widget _buildProfileHeaderRow() {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Row(
      children: [
        const ScreenHeaderBadge(icon: PhosphorIcons.userBold, color: Color(0xFFA855F7)),
        const SizedBox(width: 12),
        const Expanded(
          child: RuneTitle(title: 'Profil', subtitle: 'İlerleme & Başarı Odası'),
        ),
        _buildHeaderStatPill(
          icon: PhosphorIcons.lightningBold,
          color: theme.infoTeal,
          listenable: XpShopService.instance.xpNotifier,
        ),
        const SizedBox(width: 8),
        // UI/UX Düzeltme Listesi — Faz B1: Görünüm (Zindan/Parşömen) anahtarı
        // ve Ayarlar artık ekranın ortasında gömülü değil, Apple standardına
        // uygun sağ üstteki dişli çark rozetinden açılan bir bottom sheet'te
        // — Arena sekmesindeki "Ayarlar" rozetiyle aynı 44x44pt dokunma
        // alanı ve görsel dil.
        ScreenHeaderBadge(
          icon: PhosphorIcons.gearSixBold,
          color: theme.infoTeal,
          onTap: _openProfileSettingsSheet,
        ),
      ],
    );
  }

  // Faz B1: Profil > Ayarlar bottom sheet — Görünüm anahtarı, Satın
  // Alımları Geri Yükle ve Sürüm bilgisi artık burada. Diğer sabit-koyu
  // sheet'lerle (Arena Ayarları, Rozet Detayı, Çerçeve Seçici) aynı görsel
  // dili kullanır: her zaman koyu (0xFF111827) — açık/koyu tema anahtarının
  // kendisi bu sheet'in İÇİNDE olduğu için sheet'in kendisini tema tokenına
  // bağlamak döngüsel bir bağımlılık yaratır, bu yüzden bilinçli olarak
  // sabit-koyu bırakıldı (diğer sheet'lerle tutarlı).
  Future<void> _openProfileSettingsSheet() async {
    HapticFeedback.lightImpact();
    // Bildirimler bölümü bu sheet açılmadan ÖNCE tek seferlik yükleniyor —
    // switch/saat seçici local StatefulBuilder state'i olarak tutulacak.
    final prefs = await SharedPreferences.getInstance();
    bool dailyReminderEnabled = prefs.getBool('notif_daily_reminder_enabled') ?? false;
    int reminderHour = prefs.getInt('notif_reminder_hour') ?? 20;
    int reminderMinute = prefs.getInt('notif_reminder_minute') ?? 0;
    bool streakLossAlertEnabled = prefs.getBool('notif_streak_loss_enabled') ?? true;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      // BUG DÜZELTMESİ: bu sheet artık sabit koyu değil — aktif temaya
      // (Zindan/Parşömen) göre değişiyor, çünkü tam olarak bu tema
      // anahtarını İÇİNDE barındırıyor (bkz. aşağıdaki `theme` değişkeni).
      // Material arka planı artık burada SABİT değil, AnimatedBuilder'ın
      // içindeki Container'a taşındı — böylece kullanıcı sheet AÇIKKEN
      // Zindan/Parşömen arasında geçiş yaparsa arka plan da anında tepki
      // verir (sadece metin/simge renkleri değil).
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return AnimatedBuilder(
          animation: ThemeController.instance,
          builder: (context, _) {
            final isDark = ThemeController.instance.isDark;
            final reducedMotion = ThemeController.instance.reducedMotion;
            final theme = Theme.of(context).extension<DraconicTheme>()!;
            return StatefulBuilder(
              builder: (context, setModalState) {
                // Tek bir sürükleme hareketinin birden fazla frame'inde
                // primaryDelta > 6 tekrar tekrar sağlanıp Navigator.maybePop()
                // birden fazla kez çağrılmasın diye (teorik olarak kapanma
                // animasyonu sürerken ekstra pop() çağrısı, sheet'in ALTINDAKİ
                // bir sayfayı de yanlışlıkla kapatabilirdi) — tek seferlik kilit.
                bool sheetDragDismissed = false;
                return DecoratedBox(
              decoration: BoxDecoration(
                color: theme.surfaceLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(sheetContext).padding.bottom + 28),
              // BUG DÜZELTMESİ: bu sheet'e zamanla (Erişilebilirlik/
              // Bildirimler/Veri Yönetimi/Hakkında) yeni bölümler eklendikçe
              // içerik ekran boyunu aştı ve "BOTTOM OVERFLOWED BY N PIXELS"
              // hatası verdi — sabit `Column` ekranın kalan yüksekliğine
              // sığmayan içeriği kırpmadan taşırıyordu. `isScrollControlled:
              // true` zaten sheet'in tam ekran yüksekliğine çıkmasına izin
              // veriyor; eksik olan, içeriğin kendi içinde KAYDIRILABİLİR
              // olmasıydı. `ConstrainedBox` ekranın kullanılabilir
              // yüksekliğini (klavye/çentik payı düşülmüş) üst sınır olarak
              // veriyor, `SingleChildScrollView` de o sınırı aşan içeriği
              // taşırma yerine kaydırılabilir yapıyor.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BUG DÜZELTMESİ (2. tur): tutamaç + "Ayarlar" başlığı artık
                  // SingleChildScrollView'ın TAMAMEN DIŞINDA — kaydırılabilir
                  // listeyle aynı jest arenasını hiç paylaşmıyor. Önceki
                  // sürümde ikisi aynı Column'un (dolayısıyla aynı
                  // SingleChildScrollView'ın) içindeydi; sürükleme ile
                  // kaydırma arasında jest arenası rekabeti oluşabiliyordu —
                  // bu da "üstten tutup kapatamıyorum" şikayetinin asıl
                  // sebebiydi. Artık yapısal olarak imkansız: tutamaç hiç
                  // kaydırılabilir bir atanın içinde değil. Ayrıca görünür üst
                  // boşluk 32px'ten 64px'e çıkarıldı — sheet'in tepesi durum
                  // çubuğundan/çentikten daha belirgin biçimde ayrılıyor.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) {
                      if (sheetDragDismissed) return;
                      if ((details.primaryDelta ?? 0) > 6) {
                        sheetDragDismissed = true;
                        Navigator.of(sheetContext).maybePop();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(color: theme.borderSubtle, borderRadius: BorderRadius.circular(3)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(PhosphorIcons.gearSixBold, color: Color(0xFF38BDF8), size: 22),
                              const SizedBox(width: 10),
                              Text('Ayarlar', style: GoogleFonts.outfit(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      // Toplam güvenli yükseklikten (üst güvenli alan +
                      // görünür üst boşluk + alt kenar boşluğu) yukarıdaki
                      // sabit tutamaç/başlık bloğunun yaklaşık payını (110)
                      // düşüyoruz — geri kalan liste bu sınırı aşarsa kendi
                      // içinde kayar, aşmazsa içeriğe göre küçülür. Tamamı
                      // MediaQuery'nin GERÇEK değerlerinden hesaplandığı için
                      // hangi çözünürlük/cihaz olursa olsun doğru sonuç verir.
                      maxHeight: MediaQuery.of(sheetContext).size.height
                          - MediaQuery.of(sheetContext).padding.top
                          - 64
                          - MediaQuery.of(sheetContext).padding.bottom
                          - 28
                          - 110,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  Text('GÖRÜNÜM', style: GoogleFonts.outfit(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: theme.surfaceDark, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSheetAppearanceOption(
                            theme: theme,
                            label: 'Zindan',
                            selected: isDark,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ThemeController.instance.setDark(true);
                            },
                          ),
                        ),
                        Expanded(
                          child: _buildSheetAppearanceOption(
                            theme: theme,
                            label: 'Parşömen',
                            selected: !isDark,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ThemeController.instance.setDark(false);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('HESAP VE VERİ', style: GoogleFonts.outfit(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  _buildSheetRow(
                    theme: theme,
                    icon: AuthService.instance.isSignedIn ? PhosphorIcons.signOutBold : PhosphorIcons.userBold,
                    iconColor: const Color(0xFF34D399),
                    title: AuthService.instance.isSignedIn
                        ? (AuthService.instance.currentUser?.email ?? 'Hesabım')
                        : 'Giriş Yap / Kayıt Ol',
                    trailingValue: AuthService.instance.isSignedIn ? 'Çıkış Yap' : null,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      if (!AuthService.instance.isAvailable) {
                        IgnisAlert.show(context, message: 'Hesap sistemi henüz yapılandırılmadı.', type: IgnisAlertType.info);
                        return;
                      }
                      if (AuthService.instance.isSignedIn) {
                        await AuthService.instance.signOut();
                      } else {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
                      }
                      if (mounted) setState(() {});
                    },
                  ),
                  _buildSheetRow(
                    theme: theme,
                    icon: PhosphorIcons.arrowClockwiseBold,
                    iconColor: const Color(0xFF818CF8),
                    title: 'Satın Alımları Geri Yükle',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _handleRestorePurchases();
                    },
                  ),
                  // "UYGULAMA BİLGİSİ" (Sürüm) aşağıdaki yeni "HAKKINDA" bölümüne
                  // taşındı (Geri Bildirim/Gizlilik ile birlikte) — burada tekrar
                  // yok.
                  // Gerçek cihaz testinde "Dev/Test Araçları" bölümünün son
                  // kullanıcı sürümünde (release build) hiç görünmemesi
                  // gerekiyor — artık sadece debug build'de render ediliyor
                  // (bkz. flashcards_screen.dart'taki aynı kDebugMode kararı).
                  if (kDebugMode) ...[
                    const SizedBox(height: 22),
                    Text('DEV/TEST ARAÇLARI', style: GoogleFonts.outfit(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(
                      'Sadece önizleme — gerçek seri/istatistik verisi değişmez.',
                      style: GoogleFonts.inter(color: theme.textMuted, fontSize: 10.5),
                    ),
                    const SizedBox(height: 10),
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.bugBold,
                      iconColor: const Color(0xFFEF4444),
                      title: 'Seri Kaybı Pop-up\'ını Göster',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        IgnisMomentDialog.show(
                          context,
                          pose: 'sad',
                          title: 'Serin Kırıldı...',
                          message: 'Sorun değil, herkesin ara verdiği günler olur. Bugün yeniden başlayalım — bir sonraki serin daha güçlü olacak!',
                          primaryLabel: 'Yeniden Başla 💪',
                        );
                      },
                    ),
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.fireBold,
                      iconColor: const Color(0xFFF59E0B),
                      title: 'Kutlama Pop-up\'ını Göster',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        IgnisMomentDialog.show(
                          context,
                          pose: 'celebrating',
                          title: '7 Günlük Seri!',
                          message: '7 gündür kesintisiz pratik yapıyorsun. Bu disiplin kalıcı hafızanın temeli.',
                          primaryLabel: 'Harika, Devam! 🔥',
                        );
                      },
                    ),
                    // Faz F2 önizlemeleri: yeni eklenen duygu pozlarını
                    // (loving/angry/worried) ve rozet kutlamasını gerçek bir
                    // hedefe/savaşa/rozete ulaşmadan test edebilmek için.
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.targetBold,
                      iconColor: const Color(0xFFF472B6),
                      title: 'Günlük Hedef Pop-up\'ını Göster',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        IgnisMomentDialog.show(
                          context,
                          pose: 'loving',
                          title: 'Günlük Hedefin Tamam!',
                          message: 'Bugünkü hedefini tamamladın. Bu istikrar seni çok uzağa taşıyacak — seninle gurur duyuyorum!',
                          primaryLabel: 'Teşekkürler! 💖',
                        );
                      },
                    ),
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.skullBold,
                      iconColor: const Color(0xFFEF4444),
                      title: 'Boss Yenilgi Pop-up\'ını Göster',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        IgnisMomentDialog.show(
                          context,
                          pose: 'angry',
                          title: 'Boss Hâlâ Ayakta!',
                          message: 'Bu kelime biraz zor görünüyor. Pes etme! Tekrarlarını tamamlayıp güçlendiğinde tekrar rövanşa çıkabilirsin.',
                          primaryLabel: 'Tekrar Dene 🔥',
                        );
                      },
                    ),
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.warningBold,
                      iconColor: const Color(0xFF94A3B8),
                      title: 'Savaştan Çıkış Uyarısını Göster',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        IgnisMomentDialog.show(
                          context,
                          pose: 'worried',
                          title: 'Savaştan çık?',
                          message: 'Bossu yenmeden çıkarsan bu turdaki ilerleme kaybolur.',
                          primaryLabel: 'Anladım',
                        );
                      },
                    ),
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.trophyBold,
                      iconColor: const Color(0xFFFBBF24),
                      title: 'Rozet Kazanma Pop-up\'ını Göster',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        IgnisMomentDialog.show(
                          context,
                          pose: 'celebrating',
                          title: '🧠 Sinaps Ustası',
                          message: 'Hafızanı test ettin ve kazandın! Bu rozet, öğrendiklerinin kalıcı hâle geldiğinin kanıtı.',
                          primaryLabel: 'Harika! 🎉',
                          badgeEmoji: '🧠',
                        );
                      },
                    ),
                    // Ignis Anı (seans sonu bilgilendirme) — gerçek motoru
                    // (IgnisMomentsEngine.getSessionEndMoment) çağırır, tıpkı
                    // her pratik ekranının seans sonunda yaptığı gibi; bu
                    // yüzden bugün henüz pratik yapılmadıysa motor null
                    // döner ve aşağıdaki yedek metin gösterilir.
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.sparkleBold,
                      iconColor: const Color(0xFF38BDF8),
                      title: 'Ignis Anı Pop-up\'ını Göster',
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final moment = await IgnisMomentsEngine.instance.getSessionEndMoment();
                        if (!context.mounted) return;
                        CelebrationDialog.show(
                          context,
                          emoji: '✨',
                          title: 'Ignis Anı Önizlemesi',
                          subtitle: 'Bu, seans sonunda gördüğün bilgilendirme kartının aynısı.',
                          earnedXp: 0,
                          earnedGems: 0,
                          ignisMomentTitle: moment?.title ?? 'Bugün Henüz Pratik Yok',
                          ignisMomentMessage: moment?.message ??
                              'Sistem çalışıyor, ama bugün henüz bir pratik seansı kaydı olmadığı için gerçek veri gösteremiyorum. Bir seans tamamladığında burada gerçek ilerlemen görünecek.',
                          ignisMomentPose: moment?.pose ?? 'teacher',
                          actionLabel: 'Kapat',
                          onAction: () {},
                        );
                      },
                    ),
                    // Yukarıdaki gerçek-motor butonu veri/rastgelelik
                    // koşullarına bağlı (dünden fazla kelime + %50 ihtimal)
                    // — bu yüzden "Dünden Daha İyisin" türünü sabit
                    // örnek verilerle deterministik olarak önizlemek için
                    // ayrı bir buton.
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.trendUpBold,
                      iconColor: const Color(0xFF34D399),
                      title: 'Ignis Anı: Dünle Karşılaştırma Önizle',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        CelebrationDialog.show(
                          context,
                          emoji: '✨',
                          title: 'Ignis Anı Önizlemesi',
                          subtitle: 'Örnek veriyle sabit önizleme (dün: 3, bugün: 6 kelime).',
                          earnedXp: 0,
                          earnedGems: 0,
                          ignisMomentTitle: 'Dünden Daha İyisin!',
                          ignisMomentMessage: 'Dün 3 yeni kelime öğrenmiştin, bugün 6 — güzel bir sıçrama!',
                          ignisMomentPose: 'happy',
                          actionLabel: 'Kapat',
                          onAction: () {},
                        );
                      },
                    ),
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.lockKeyBold,
                      iconColor: const Color(0xFF94A3B8),
                      title: 'Profil Önerisi: Premium-Dışı Bilgi Önizle',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        IgnisAlert.show(
                          context,
                          message: 'Haftalık projeksiyon, ustalaşma oranı ve daha fazla detaylı içgörü Premium\'da. '
                              'Şu an sadece en güncel özet gösteriliyor.',
                          type: IgnisAlertType.info,
                          actionLabel: 'Premium\'a Geç',
                          onAction: () => EntitlementRepository.instance.presentPaywall(),
                        );
                      },
                    ),
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.crownBold,
                      iconColor: const Color(0xFFFBBF24),
                      title: 'Profil Önerisi: Premium Detay Önizle',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showIgnisInsightPremiumDetail();
                      },
                    ),
                    // Eylül 2026 yeni tasarımları — gerçek duruma ulaşmadan
                    // (yanlış cevap, süre dolması, boş havuz vb.) tek tek
                    // görüp test edebilmek için.
                    const SizedBox(height: 14),
                    Text('YENİ TASARIM ÖNİZLEMELERİ', style: GoogleFonts.outfit(color: theme.textMuted, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.sparkleBold,
                      iconColor: const Color(0xFFF59E0B),
                      title: 'Ignis Poz Galerisi (18 poz)',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _devPreviewPoseGallery();
                      },
                    ),
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.xBold,
                      iconColor: const Color(0xFF10B981),
                      title: 'Egzersiz Bildirimi: Yanlış Cevap',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _devPreviewCheerToast(CoachMessages.wrongAnswerMessages.first);
                      },
                    ),
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.fireBold,
                      iconColor: const Color(0xFF10B981),
                      title: 'Egzersiz Bildirimi: Doğru Serisi',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _devPreviewCheerToast('🎯 Muazzam seri! Odaklanman zirvede.');
                      },
                    ),
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.timerBold,
                      iconColor: const Color(0xFF10B981),
                      title: 'Egzersiz Bildirimi: Süre Doldu',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _devPreviewCheerToast('⏳ Süre doldu! Odaklan ve devam et.');
                      },
                    ),
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.signOutBold,
                      iconColor: const Color(0xFF94A3B8),
                      title: 'Egzersizden Çıkış Onayı',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _devPreviewExitDialog();
                      },
                    ),
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.compassBold,
                      iconColor: const Color(0xFFF59E0B),
                      title: 'Boş Kelime Havuzu Ekranı',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _devPreviewEmptyPool();
                      },
                    ),
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.chatCircleTextBold,
                      iconColor: const Color(0xFFA855F7),
                      title: 'AI Koç (Hazır Sorular + Premium Teklifi)',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiCoachScreen()));
                      },
                    ),
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.targetBold,
                      iconColor: const Color(0xFFF59E0B),
                      title: 'Alışkanlıklar Sayfası',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _navigateTo(const HabitTrackerScreen());
                      },
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text('ERİŞİLEBİLİRLİK', style: GoogleFonts.outfit(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  _buildSheetSwitchRow(
                    theme: theme,
                    icon: PhosphorIcons.waveSineBold,
                    iconColor: const Color(0xFF38BDF8),
                    title: 'Azaltılmış Hareket/Animasyon',
                    subtitle: 'Cam/glow efektlerini kapatır, daha sade bir görünüm.',
                    value: reducedMotion,
                    onChanged: (v) => ThemeController.instance.setReducedMotion(v),
                  ),
                  const SizedBox(height: 22),
                  Text('BİLDİRİMLER', style: GoogleFonts.outfit(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  _buildSheetSwitchRow(
                    theme: theme,
                    icon: PhosphorIcons.bellRingingBold,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Günlük Hatırlatma',
                    value: dailyReminderEnabled,
                    onChanged: (v) async {
                      if (v) {
                        final granted = await NotificationService.instance.requestPermission();
                        if (!granted) {
                          if (sheetContext.mounted) {
                            IgnisAlert.show(sheetContext, message: 'Bildirim izni verilmedi — cihaz ayarlarından açabilirsin.', type: IgnisAlertType.error);
                          }
                          return;
                        }
                        await NotificationService.instance.scheduleDailyReminder(hour: reminderHour, minute: reminderMinute);
                      } else {
                        await NotificationService.instance.cancelDailyReminder();
                      }
                      setModalState(() => dailyReminderEnabled = v);
                      await prefs.setBool('notif_daily_reminder_enabled', v);
                    },
                  ),
                  if (dailyReminderEnabled)
                    _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.clockBold,
                      iconColor: const Color(0xFFF59E0B),
                      title: 'Hatırlatma Saati',
                      trailingValue: '${reminderHour.toString().padLeft(2, '0')}:${reminderMinute.toString().padLeft(2, '0')}',
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: sheetContext,
                          initialTime: TimeOfDay(hour: reminderHour, minute: reminderMinute),
                        );
                        if (picked != null) {
                          setModalState(() {
                            reminderHour = picked.hour;
                            reminderMinute = picked.minute;
                          });
                          await prefs.setInt('notif_reminder_hour', picked.hour);
                          await prefs.setInt('notif_reminder_minute', picked.minute);
                          // Saat değiştiyse zaten kurulu olan alarmı yeni
                          // saate göre yeniden kur.
                          await NotificationService.instance.scheduleDailyReminder(hour: picked.hour, minute: picked.minute);
                        }
                      },
                    ),
                  _buildSheetSwitchRow(
                    theme: theme,
                    icon: PhosphorIcons.fireBold,
                    iconColor: const Color(0xFFEF4444),
                    title: 'Seri Kaybı Uyarısı',
                    subtitle: 'Akşam 21:30\'da, o gün pratik yapmadıysan hatırlatır.',
                    value: streakLossAlertEnabled,
                    onChanged: (v) async {
                      if (v) {
                        final granted = await NotificationService.instance.requestPermission();
                        if (!granted) {
                          if (sheetContext.mounted) {
                            IgnisAlert.show(sheetContext, message: 'Bildirim izni verilmedi — cihaz ayarlarından açabilirsin.', type: IgnisAlertType.error);
                          }
                          return;
                        }
                        await NotificationService.instance.scheduleStreakLossAlert();
                      } else {
                        await NotificationService.instance.cancelStreakLossAlert();
                      }
                      setModalState(() => streakLossAlertEnabled = v);
                      await prefs.setBool('notif_streak_loss_enabled', v);
                    },
                  ),
                  const SizedBox(height: 22),
                  Text('VERİ YÖNETİMİ', style: GoogleFonts.outfit(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  _buildSheetRow(
                    theme: theme,
                    icon: PhosphorIcons.trashBold,
                    iconColor: const Color(0xFFEF4444),
                    title: 'İlerlemeyi Sıfırla',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _confirmResetProgress();
                    },
                  ),
                  const SizedBox(height: 22),
                  Text('HAKKINDA', style: GoogleFonts.outfit(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  _buildSheetRow(
                    theme: theme,
                    icon: PhosphorIcons.infoBold,
                    iconColor: const Color(0xFF64748B),
                    title: 'Sürüm',
                    trailingValue: '1.0.0',
                  ),
                  _buildSheetRow(
                    theme: theme,
                    icon: PhosphorIcons.chatCircleTextBold,
                    iconColor: const Color(0xFF34D399),
                    title: 'Geri Bildirim Gönder',
                    onTap: () async {
                      await Clipboard.setData(const ClipboardData(text: 'srnern2613@gmail.com'));
                      if (sheetContext.mounted) {
                        IgnisAlert.show(sheetContext, message: 'E-posta adresi panoya kopyalandı.', type: IgnisAlertType.success);
                      }
                    },
                  ),
                  Opacity(
                    opacity: 0.45,
                    child: _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.fileTextBold,
                      iconColor: const Color(0xFF64748B),
                      title: 'Gizlilik Politikası (yakında)',
                    ),
                  ),
                  Opacity(
                    opacity: 0.45,
                    child: _buildSheetRow(
                      theme: theme,
                      icon: PhosphorIcons.fileTextBold,
                      iconColor: const Color(0xFF64748B),
                      title: 'Kullanım Şartları (yakında)',
                    ),
                  ),
                ],
                  ),
                ),
              ),
                ],
                ),
                ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _confirmResetProgress() async {
    // Yanlışlıkla dokunmaya karşı ikinci bir kilit: "Evet, Sıfırla" butonu,
    // kullanıcı aşağıdaki onay kutucuğunu işaretleyene kadar devre dışı
    // (gri/pasif) kalıyor. Tek bir AlertDialog'da iki adım gibi davranır —
    // ayrı bir ekran/adım eklemeden kazara silmeyi pratik olarak imkansız
    // hale getirir.
    bool understood = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFF1F2937))),
          title: Text('İlerlemeni Sıfırla', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Öğrendiğin tüm kelimeler, vurgulamalar, kitap ilerlemen ve günlük istatistiklerin KALICI olarak silinecek. Bu işlem geri alınamaz.',
                style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setDialogState(() => understood = !understood),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: understood,
                        activeColor: const Color(0xFFEF4444),
                        onChanged: (v) => setDialogState(() => understood = v ?? false),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Bunun geri alınamayacağını anlıyorum, tüm ilerlemem silinsin.',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Vazgeç', style: GoogleFonts.outfit(color: const Color(0xFF94A3B8)))),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                disabledBackgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.25),
              ),
              onPressed: understood ? () => Navigator.pop(ctx, true) : null,
              child: Text('Evet, Sıfırla', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance.resetAllProgress();
      if (!mounted) return;
      await _loadProfileData();
      if (!mounted) return;
      IgnisAlert.show(context, message: 'İlerlemen sıfırlandı.', type: IgnisAlertType.success);
    }
  }

  // BUG DÜZELTMESİ: bu 3 yardımcı widget yalnızca Profil > Ayarlar
  // sheet'inde kullanılıyor ve artık `theme` (DraconicTheme) alıyor —
  // eskiden sabit koyu renklere (Colors.white, 0xFF64748B vb.) bağlıydı,
  // bu da Parşömen temasındayken bile sheet'in koyu görünmesine sebep
  // oluyordu.
  Widget _buildSheetSwitchRow({
    required DraconicTheme theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle, style: GoogleFonts.inter(color: theme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildSheetAppearanceOption({required DraconicTheme theme, required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF59E0B) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? const Color(0xFF070B14) : theme.textSecondary),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // DEV/TEST — yeni tasarım önizlemeleri (sadece debug build'de görünür)
  // --------------------------------------------------------------------------

  /// Egzersiz ekranlarındaki üst bildirimi (CheerToast) ekranın üstünde
  /// ~3 saniye gösterir. Poz, mesaja göre otomatik seçilir.
  void _devPreviewCheerToast(String message) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Stack(children: [CheerToast(message: message)]),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (entry.mounted) entry.remove();
    });
  }

  void _devPreviewExitDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        icon: Image.asset(
          AppBranding.poseAsset('suspicious'),
          width: 88,
          height: 88,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Egzersizden çık?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Kalan soruları tamamlamadan çıkıyorsun. Bu ana kadarki cevapların zaten kaydedildi.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Devam Et')),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Çık')),
        ],
      ),
    );
  }

  void _devPreviewEmptyPool() {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          backgroundColor: theme.background,
          elevation: 0,
          iconTheme: IconThemeData(color: theme.textPrimary),
          title: Text('Önizleme: Boş Havuz', style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.bold)),
        ),
        body: const EmptyWordPoolState(
          message: 'Bu mod için havuzunda yeterli kelime yok. Kitaplığından yeni kelimeler ekleyebilirsin.',
        ),
      ),
    ));
  }

  /// Tüm Ignis pozlarını mevcut temanın zemininde gösterir — temizlenmiş
  /// görsellerin hem koyu hem açık temada düzgün durduğunu kontrol etmek için.
  void _devPreviewPoseGallery() {
    const poses = [
      'happy', 'excited', 'loving', 'thinking', 'suspicious', 'sad',
      'angry', 'celebrating', 'teacher', 'greeting', 'worried', 'reading',
      'warrior', 'sleepy', 'proud', 'explorer', 'confused', 'listening',
    ];
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                child: Text('Ignis Poz Galerisi', style: GoogleFonts.outfit(color: theme.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: poses.length,
                  itemBuilder: (context, i) => Container(
                    decoration: BoxDecoration(
                      color: theme.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                            child: Image.asset(
                              AppBranding.poseAsset(poses[i]),
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomCenter,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(PhosphorIcons.warningBold, color: theme.dangerRed),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(poses[i], style: GoogleFonts.inter(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetRow({required DraconicTheme theme, required IconData icon, required Color iconColor, required String title, String? trailingValue, VoidCallback? onTap}) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title, style: GoogleFonts.inter(color: theme.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w600)),
          ),
          if (trailingValue != null)
            Text(trailingValue, style: GoogleFonts.outfit(color: theme.textSecondary, fontSize: 13.5, fontWeight: FontWeight.w700)),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(PhosphorIcons.caretRightBold, color: theme.textMuted, size: 14),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: row);
  }

  Widget _buildHeaderStatPill({required IconData icon, required Color color, required ValueListenable<int> listenable}) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.surfaceDark.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: theme.borderSubtle, width: 1),
        ),
        child: ValueListenableBuilder<int>(
          valueListenable: listenable,
          builder: (context, value, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Text('$value', style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
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

  // Faz B2: Profil ekranındaki 22 rozetlik ızgara + "Yaklaşan Rozetler"
  // dikey yığını kaldırıldı (görsel gürültü şikayeti) — yerine sadece bu
  // kompakt özet satırı var; tamamı artık _openAchievementRoomSheet()'te.
  Widget _buildBadgesSummaryRow() {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    // NOT: _unlockedBadges bir Set<String> — kilidi açılma zamanı
    // tutulmuyor. "Son 3 rozet" bu yüzden _allBadges listesindeki sıraya
    // göre (liste kabaca kolay→zor ilerliyor) en yüksek indeksli açık
    // rozetler alınarak YAKLAŞIK hesaplanıyor; gerçek bir "en son açılan"
    // değil. Gerçek zaman damgası eklenirse burası ona göre güncellenmeli.
    final unlockedInOrder = _allBadges.where((b) => _unlockedBadges.contains(b['id'])).toList();
    final recentThree = unlockedInOrder.length <= 3 ? unlockedInOrder.reversed.toList() : unlockedInOrder.reversed.take(3).toList();

    return GestureDetector(
      onTap: _openAchievementRoomSheet,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.surfaceDark.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.borderSubtle, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Rozetler', style: GoogleFonts.outfit(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${_unlockedBadges.length} / ${_allBadges.length}', style: GoogleFonts.outfit(color: theme.infoTeal, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 4),
                    Icon(PhosphorIcons.caretRightBold, color: theme.textMuted, size: 14),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (recentThree.isEmpty)
              Text(
                'Henüz kilidi açılmış bir rozetin yok — Başarı Odası\'nı aç ve ilk hedefini seç.',
                style: GoogleFonts.inter(color: theme.textSecondary, fontSize: 12.5, height: 1.4),
              )
            else
              Row(
                children: [
                  for (final badge in recentThree) ...[
                    _buildBadgeCircle(badge, true),
                    const SizedBox(width: 12),
                  ],
                  if (recentThree.length < 3)
                    Expanded(child: Text('Devamı için dokun →', style: GoogleFonts.inter(color: theme.textMuted, fontSize: 12))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCircle(Map<String, dynamic> badge, bool isUnlocked) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    final Color badgeColor = badge['color'];
    return GestureDetector(
      onTap: () => _showBadgeDetailDialog(badge, isUnlocked),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isUnlocked ? badgeColor.withValues(alpha: 0.15) : theme.surfaceLight,
          shape: BoxShape.circle,
          border: Border.all(color: isUnlocked ? badgeColor.withValues(alpha: 0.5) : theme.borderSubtle, width: 1.5),
        ),
        child: Center(
          child: isUnlocked
              ? Text(badge['emoji'], style: const TextStyle(fontSize: 24))
              : Icon(PhosphorIcons.lockFill, color: theme.textMuted, size: 20),
        ),
      ),
    );
  }

  // Faz B2: "Başarı Odası" — önceden ana profil ekranında dikey olarak
  // yığılan Yaklaşan Rozetler + tam rozet ızgarası artık burada, sürüklenip
  // büyütülebilen bir sheet içinde. Diğer büyük sheet'lerle (Rozet Detayı,
  // Çerçeve Seçici) aynı sabit-koyu palet kullanılıyor.
  void _openAchievementRoomSheet() {
    HapticFeedback.lightImpact();
    final upcoming = _computeUpcomingBadges();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(sheetContext).padding.bottom + 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Başarı Odası', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('${_unlockedBadges.length} / ${_allBadges.length} rozet açıldı', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13)),
                  if (upcoming.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Yaklaşan Rozetler', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    ...upcoming.map((badge) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(
                            onTap: () => _showBadgeDetailDialog(badge, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF334155), width: 1),
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
                  ],
                  const SizedBox(height: 20),
                  Text('Koleksiyon Vitrini', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
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
                            color: isUnlocked ? badgeColor.withValues(alpha: 0.12) : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isUnlocked ? badgeColor.withValues(alpha: 0.5) : const Color(0xFF334155),
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
                                      : const Icon(PhosphorIcons.lockFill, color: Color(0xFF64748B), size: 20),
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
              ),
            );
          },
        );
      },
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
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    final double percentage = _totalFlashcards > 0 ? (_masteredFlashcardsCount / _totalFlashcards).clamp(0.0, 1.0) : 0.0;
    final int percentInt = (percentage * 100).round();

    return GestureDetector(
      onTap: () => _navigateTo(const DictionaryScreen()),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.surfaceDark.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.borderSubtle, width: 1),
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
                    Text('Kalıcı Hafıza', style: GoogleFonts.outfit(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: theme.successEmerald.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
                      // P1-7: "%0 Tamamlandı" yerine davet metni.
                      child: Text(
                        percentInt == 0 ? 'Henüz başlamadın' : '%$percentInt Tamamlandı',
                        style: GoogleFonts.outfit(color: const Color(0xFF6EE7B7), fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(PhosphorIcons.caretRightBold, color: theme.textMuted, size: 14),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Toplam havuzdaki $_totalFlashcards kelimeden $_masteredFlashcardsCount tanesi kalıcı hafızaya alındı.', style: GoogleFonts.inter(color: theme.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 7,
                backgroundColor: theme.borderSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(theme.successEmerald),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeagueRankCard() {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _navigateTo(const LeaderboardScreen()),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surfaceDark.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.borderSubtle, width: 1),
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
                      Flexible(child: Text('12. Arena: Kelime Ustası', style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14), overflow: TextOverflow.ellipsis)),
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
                    style: GoogleFonts.inter(color: theme.textSecondary, fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(PhosphorIcons.caretRightBold, color: theme.textMuted, size: 14),
          ],
        ),
      ),
    );
  }

  // EJDERHA ROTASI V2 — FAZ 6: Apple/iOS Ayarlar tarzı temiz liste — eski
  // 2x2 kutu grid'i yerine tek grup içinde ince ayraçlarla bölünen satırlar.
  // Aynı 4 istatistik ve aynı navigasyon hedefleri korunuyor.
  // Faz B3: dikey iOS Ayarlar tarzı liste yerine 2x2 kart ızgarası —
  // "liste elemanları alt alta duruyor, bilişsel yük azaltılmalı" geri
  // bildirimine göre. Dokunma alanı ve navigasyon hedefleri değişmedi.
  // GELİŞİM PANELİ — eski 4'lü "Okuma Süresi / Kelime Havuzu / Koleksiyon
  // Arşivi / Başarı Serisi" ızgarasının yerine. Tamamı tema token'larıyla
  // (her iki temada da uyumlu), gerçek veriye bağlı ve her kart ilgili
  // ekrana götürüyor. Haftalık aktivite kartı ve Seri kartı Alışkanlıklar
  // sayfasının Profil'deki giriş noktası.
  Widget _buildGrowthPanel() {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text('Gelişimin', style: GoogleFonts.lora(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Text('Son 7 gün', style: GoogleFonts.inter(color: theme.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 12),
        _buildWeeklyActivityCard(theme),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildGrowthTile(
                theme: theme,
                icon: PhosphorIcons.cardsBold,
                color: theme.infoTeal,
                value: '$_totalFlashcards',
                label: 'Kelime Hazinesi',
                detail: _dueTodayCount > 0 ? '$_dueTodayCount tekrar bekliyor' : 'Bugün tekrar yok ✓',
                detailHighlighted: _dueTodayCount > 0,
                onTap: () => _navigateTo(const FlashcardsScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGrowthTile(
                theme: theme,
                icon: PhosphorIcons.bookOpenBold,
                color: theme.successEmerald,
                value: _formatReadTime(_totalReadMinutes),
                label: 'Okuma',
                detail: '$_totalPagesRead sayfa okundu',
                onTap: () => _navigateTo(const LibraryScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildGrowthTile(
                theme: theme,
                icon: PhosphorIcons.magnifyingGlassBold,
                color: theme.cognitiveIndigo,
                value: '$_totalWordsExamined',
                label: 'Sözlük',
                detail: 'incelenen kelime',
                onTap: () => _navigateTo(const DictionaryScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGrowthTile(
                theme: theme,
                icon: PhosphorIcons.fireBold,
                color: theme.primaryAmber,
                value: '$_streakDays gün',
                label: 'Seri & Alışkanlıklar',
                detail: _hasFreezeShield ? 'Kalkan aktif 🛡️' : 'Alışkanlıklarını takip et',
                onTap: () => _navigateTo(const HabitTrackerScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatReadTime(int minutes) {
    if (minutes < 60) return '$minutes dk';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h sa' : '$h sa $m dk';
  }

  Widget _buildWeeklyActivityCard(DraconicTheme theme) {
    const dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final now = DateTime.now();
    final int weekTotal = _weekActivity.fold<int>(0, (sum, v) => sum + v);
    final int maxValue = _weekActivity.fold<int>(0, (m, v) => v > m ? v : m);
    final int activeDays = _weekActivity.where((v) => v > 0).length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _navigateTo(const HabitTrackerScreen()),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: theme.surfaceDark.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: theme.primaryAmber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: Icon(PhosphorIcons.chartBarBold, color: theme.primaryAmber, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Haftalık Aktivite', style: GoogleFonts.outfit(color: theme.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w800)),
                        Text(
                          weekTotal == 0 ? 'Bu hafta henüz pratik yok' : '$weekTotal kelime çalışıldı · $activeDays/7 gün aktif',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: theme.textSecondary, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.primaryAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Alışkanlıklar', style: GoogleFonts.outfit(color: theme.primaryAmber, fontSize: 11.5, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 3),
                        Icon(PhosphorIcons.caretRightBold, color: theme.primaryAmber, size: 11),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 84,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final value = i < _weekActivity.length ? _weekActivity[i] : 0;
                    final day = now.subtract(Duration(days: 6 - i));
                    final isToday = i == 6;
                    final double barHeight = maxValue == 0 || value == 0 ? 4 : 6 + 44 * (value / maxValue);
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 18,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: value == 0
                                  ? theme.borderSubtle
                                  : (isToday ? theme.primaryAmber : theme.primaryAmber.withValues(alpha: 0.45)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dayNames[day.weekday - 1],
                            style: GoogleFonts.inter(
                              color: isToday ? theme.primaryAmber : theme.textMuted,
                              fontSize: 10.5,
                              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrowthTile({
    required DraconicTheme theme,
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    required String detail,
    required VoidCallback onTap,
    bool detailHighlighted = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.surfaceDark.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: color, size: 17),
                  ),
                  const Spacer(),
                  Icon(PhosphorIcons.caretRightBold, color: theme.textMuted, size: 13),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(color: theme.textPrimary, fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: detailHighlighted ? color : theme.textMuted,
                  fontSize: 11,
                  fontWeight: detailHighlighted ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Faz B1: eski _buildAyarlarSection / _buildAppearanceSection /
  // _buildAppearanceOption kaldırıldı — içerikleri (Görünüm anahtarı,
  // Satın Alımları Geri Yükle, Sürüm) artık _openProfileSettingsSheet()
  // içinde, sağ üstteki dişli çark rozetinden açılıyor.
  Future<void> _handleRestorePurchases() async {
    HapticFeedback.selectionClick();
    final restored = await EntitlementRepository.instance.restorePurchases();
    if (!mounted) return;
    IgnisAlert.show(
      context,
      message: restored ? 'Satın alımların geri yüklendi.' : 'Geri yüklenecek bir satın alma bulunamadı.',
      type: restored ? IgnisAlertType.success : IgnisAlertType.info,
    );
  }
}
